/**
 * BJT Full-Text Search Database Generator
 *
 * Creates an optimized FTS5 database for the Buddha Jayanti Tripitaka (BJT) edition.
 * The FTS5 table is contentless: it stores only the search index, which keeps it
 * ~75% smaller. The text itself sits beside it in bjt_content, compressed per page.
 *
 * Size comparison:
 *   - Regular FTS5:     ~455 MB (stores text redundantly)
 *   - Contentless FTS5: ~110-120 MB (index only)
 *
 * FTS5 Benefits over FTS4:
 *   - bm25() ranking function for relevance-sorted results
 *   - Better query syntax (NEAR, column filters, boolean operators)
 *   - Actively maintained (FTS4 is legacy)
 *
 * Trade-off:
 *   - snippet() function not available in contentless mode - the app builds
 *     its own snippets from bjt_content
 *   - Queries require JOIN with metadata table
 *
 * Database structure:
 *   - bjt_fts: Contentless FTS5 index (text search with bm25 ranking)
 *   - bjt_meta: Metadata table (filename, eind, language, type, level)
 *   - bjt_content: The text itself, one zlib blob per page per language
 *
 * Usage:
 *   cd tools
 *   npm install better-sqlite3  # First time only
 *   node bjt-populate.js
 *
 * Input:  ../assets/text/*.json (BJT text files)
 * Output: bjt.db (~110-120 MB)
 *
 * Based on: tipitaka.lk/dev/fts-populate.js
 * Modified for: The Wisdom Project - Multi-edition architecture
 */

"use strict";

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// Try to use better-sqlite3 (recommended)
let Database;
try {
    Database = require('better-sqlite3');
} catch (e) {
    console.error('ERROR: better-sqlite3 not installed');
    console.error('Run: npm install better-sqlite3');
    process.exit(1);
}

const { finalizeDatabase } = require('./db-finalize');

// =============================================================================
// CONFIGURATION
// =============================================================================

const CONFIG = {
    // Edition identifier (for multi-edition support)
    EDITION_ID: 'bjt',
    EDITION_NAME: 'Buddha Jayanti Tripitaka',

    // Step 1: Create the table structure (run first)
    CREATE_TABLE: true,

    // Step 2: Populate data (run after table is created)
    POPULATE_DATA: true,

    // Input folder containing JSON text files
    // Path is relative to this script (tools/)
    INPUT_FOLDER: path.join(__dirname, '../assets/text/'),

    // Tree JSON file (for nodeKey computation)
    TREE_JSON: path.join(__dirname, '../assets/data/tree.json'),

    // Output database file
    OUTPUT_DB: path.join(__dirname, '../assets/databases/bjt.db'),
};

// =============================================================================
// SINHALA UNICODE RANGE FOR TOKENIZER
// =============================================================================

function getSinhalaTokenChars() {
    const chars = [];
    // Sinhala Unicode block: U+0D80 to U+0DFF
    for (let i = 0x0d80; i <= 0x0dff; i++) {
        chars.push(String.fromCharCode(i));
    }
    return chars.join('');
}

// =============================================================================
// TEXT PROCESSING
// =============================================================================

/**
 * Cleans text for indexing by removing formatting markers
 * @param {string} text - Raw text with formatting markers
 * @returns {string} - Clean text for indexing
 */
function cleanTextForIndexing(text) {
    if (!text) return '';

    // Remove formatting markers:
    // - * (bold markers)
    // - _ (underline markers)
    // - ~ (strikethrough)
    // - $ (special markers)
    // - \u200d (zero-width joiner)
    // - {XX} (footnote pointers like {1}, {ab})
    let cleaned = text.replace(/[\*_~\$\u200d]|\{\S{0,2}\}/g, '');

    // Replace newlines with spaces (prevents matching issues at line boundaries)
    cleaned = cleaned.replace(/\n/g, ' ');

    // Trim whitespace
    return cleaned.trim();
}

// =============================================================================
// TREE LOADING AND NODEKEY COMPUTATION
// =============================================================================

/**
 * Loads tree.json and builds a map of filename -> sorted nodes
 * Each node has { key, eInd: [pageIndex, entryIndex] }
 * Nodes are sorted by eInd for efficient lookup
 *
 * @returns {Map<string, Array<{key: string, eInd: number[]}>>}
 */
function loadTreeIndex() {
    console.log('Loading tree.json for nodeKey computation...');

    if (!fs.existsSync(CONFIG.TREE_JSON)) {
        console.error(`ERROR: Tree file not found: ${CONFIG.TREE_JSON}`);
        process.exit(1);
    }

    const treeJson = JSON.parse(fs.readFileSync(CONFIG.TREE_JSON, 'utf-8'));

    // Group nodes by filename (contentFileId)
    // tree.json format: { nodeKey: [pali, sinh, level, [pageIdx, entryIdx], parent, filename], ... }
    const nodesByFile = new Map();

    for (const [nodeKey, nodeData] of Object.entries(treeJson)) {
        // nodeData format: [pali, sinh, level, [pageIdx, entryIdx], parent, filename]
        const filename = nodeData[5];
        const eInd = nodeData[3]; // [pageIndex, entryIndex]

        if (!filename) continue; // Skip nodes without content file

        if (!nodesByFile.has(filename)) {
            nodesByFile.set(filename, []);
        }

        nodesByFile.get(filename).push({
            key: nodeKey,
            eInd: eInd
        });
    }

    // Sort each file's nodes by eInd (pageIndex first, then entryIndex)
    for (const nodes of nodesByFile.values()) {
        nodes.sort((a, b) => {
            if (a.eInd[0] !== b.eInd[0]) return a.eInd[0] - b.eInd[0];
            return a.eInd[1] - b.eInd[1];
        });
    }

    console.log(`  ✓ Loaded ${nodesByFile.size} content files from tree.json`);
    return nodesByFile;
}

/**
 * Finds the nodeKey for a given entry position within a file.
 * Uses the same algorithm as tipitaka.lk's getKeyForEInd:
 * - Iterate sorted nodes in reverse order
 * - Return the first (last in order) node whose eInd <= entry position
 *
 * This finds the "containing" sutta/section for an entry.
 *
 * @param {Array<{key: string, eInd: number[]}>} sortedNodes - Nodes sorted by eInd
 * @param {number} pageIndex - Entry's page index
 * @param {number} entryIndex - Entry's index within page
 * @returns {string} The nodeKey that contains this entry
 */
function findNodeKeyForEntry(sortedNodes, pageIndex, entryIndex) {
    if (!sortedNodes || sortedNodes.length === 0) {
        return '';
    }

    // Iterate in reverse to find the last node where eInd <= [pageIndex, entryIndex]
    // This is equivalent to tipitaka.lk's getKeyForEInd logic
    for (let i = sortedNodes.length - 1; i >= 0; i--) {
        const node = sortedNodes[i];
        const [nodePageIdx, nodeEntryIdx] = node.eInd;

        // Check if node's eInd <= entry position
        // (same as isEIndLessEqual in old app)
        if (nodePageIdx < pageIndex ||
            (nodePageIdx === pageIndex && nodeEntryIdx <= entryIndex)) {
            return node.key;
        }
    }

    // Fallback to first node if no match found (shouldn't happen normally)
    return sortedNodes[0].key;
}

// =============================================================================
// DATABASE OPERATIONS
// =============================================================================

/**
 * Creates the FTS5 tables for the BJT edition
 * @param {Database} db - SQLite database instance
 */
function createFTSTables(db) {
    const editionPrefix = CONFIG.EDITION_ID;
    console.log(`Creating ${CONFIG.EDITION_NAME} FTS tables...`);

    const sinhalaChars = getSinhalaTokenChars();

    // Drop existing tables and indexes if they exist
    db.exec(`DROP TABLE IF EXISTS ${editionPrefix}_fts`);
    db.exec(`DROP TABLE IF EXISTS ${editionPrefix}_meta`);
    db.exec(`DROP INDEX IF EXISTS idx_${editionPrefix}_meta_filename`);
    db.exec(`DROP INDEX IF EXISTS idx_${editionPrefix}_meta_language`);

    // Create metadata table (stores location info, NOT the text)
    // This is much smaller than storing full text
    const createMetaSQL = `
        CREATE TABLE ${editionPrefix}_meta (
            id INTEGER PRIMARY KEY,
            filename TEXT NOT NULL,
            eind TEXT NOT NULL,
            language TEXT NOT NULL,
            type TEXT NOT NULL,
            level INTEGER NOT NULL,
            nodeKey TEXT NOT NULL
        )
    `;
    db.exec(createMetaSQL);

    // Create indexes on metadata table for fast lookups
    db.exec(`CREATE INDEX idx_${editionPrefix}_meta_filename ON ${editionPrefix}_meta(filename)`);
    db.exec(`CREATE INDEX idx_${editionPrefix}_meta_language ON ${editionPrefix}_meta(language)`);
    // Note: No index on nodeKey - it's only read from results, never queried by SQL

    // Create contentless FTS5 table (stores only search index)
    // FTS5 syntax: columns come before options
    // content='' tells SQLite not to store the text (contentless mode)
    // bm25() ranking function is available even in contentless mode
    //
    // OPTIONAL: Add prefix='2 3' for faster prefix queries (adds ~10-20% to DB size)
    // Example: tokenize="unicode61 tokenchars '...'", prefix='2 3'
    //
    // Note: FTS5 tokenize directive requires double quotes outside, single quotes inside
    const createFTSSQL = `
        CREATE VIRTUAL TABLE ${editionPrefix}_fts USING fts5(
            text,
            content='',
            tokenize="unicode61 tokenchars '${sinhalaChars}'"
        )
    `;

    db.exec(createFTSSQL);
    console.log(`  ✓ ${editionPrefix}_fts: Search index (contentless FTS5 with bm25 ranking)`);
    console.log(`  ✓ ${editionPrefix}_meta: Metadata (filename, eind, language, type, level, nodeKey)`);
}

/**
 * Creates the content table the app reads text from, in place of the JSON.
 *
 * The contract — blob = that page's language side verbatim, zlib-framed — is
 * enforced by section 5 of static_site_generator/tool/verify_corpus_invariants.dart.
 * pageNum is a column because it sits beside pali/sinh in the JSON, not inside them.
 * @param {Database} db - SQLite database instance
 */
function createContentTable(db) {
    const editionPrefix = CONFIG.EDITION_ID;

    db.exec(`DROP TABLE IF EXISTS ${editionPrefix}_content`);
    db.exec(`
        CREATE TABLE ${editionPrefix}_content (
            filename TEXT NOT NULL,
            pageIndex INTEGER NOT NULL,
            language TEXT NOT NULL,
            pageNum INTEGER NOT NULL,
            blob BLOB NOT NULL,
            PRIMARY KEY (filename, pageIndex, language)
        )
    `);
    console.log(`  ✓ ${editionPrefix}_content: Page text (one zlib blob per page per language)`);
}

// =============================================================================
// MAIN PROCESSING
// =============================================================================

function main() {
    console.log('='.repeat(70));
    console.log(`${CONFIG.EDITION_NAME} - Full-Text Search Database Generator`);
    console.log('='.repeat(70));
    console.log('');

    // Validate input folder exists
    if (!fs.existsSync(CONFIG.INPUT_FOLDER)) {
        console.error(`ERROR: Input folder not found: ${CONFIG.INPUT_FOLDER}`);
        console.error('Please ensure BJT text files are in: assets/text/');
        process.exit(1);
    }

    // Open/create database
    console.log(`Database: ${CONFIG.OUTPUT_DB}`);
    console.log(`Edition:  ${CONFIG.EDITION_ID} (${CONFIG.EDITION_NAME})`);
    console.log('');

    // Ensure the output directory exists before opening the database
    const dbDir = path.dirname(CONFIG.OUTPUT_DB);
    if (!fs.existsSync(dbDir)) {
        fs.mkdirSync(dbDir, { recursive: true });
        console.log(`  Created directory: ${dbDir}`);
        console.log('');
    }

    const db = new Database(CONFIG.OUTPUT_DB);

    // Enable WAL mode for better write performance
    db.pragma('journal_mode = WAL');

    try {
        // Step 1: Create table structure
        if (CONFIG.CREATE_TABLE) {
            createFTSTables(db);
            createContentTable(db);
            console.log('');
        }

        // Step 2: Populate data
        if (CONFIG.POPULATE_DATA) {
            populateData(db);
        }

        // Optimize database
        console.log('');
        console.log('Optimizing database...');

        // Optimize FTS5 index (merge internal b-tree segments)
        // This merges FTS5's internal index segments into one large segment,
        // which significantly improves MATCH query performance.
        // VACUUM alone doesn't optimize FTS5's internal structures.
        console.log('  Optimizing FTS5 index...');
        db.exec(`INSERT INTO ${CONFIG.EDITION_ID}_fts(${CONFIG.EDITION_ID}_fts) VALUES('optimize')`);
        console.log('  ✓ FTS5 index optimized');

    } finally {
        db.close();
    }

    // The file this script hands over is not the file it just wrote — see
    // finalizeDatabase. (It replaces the plain VACUUM that used to run above:
    // VACUUM INTO reclaims the same space and does three more things.)
    finalizeDatabase(CONFIG.OUTPUT_DB);

    console.log('');
    console.log('✓ Done!');
    console.log('');
    const dbFileName = path.basename(CONFIG.OUTPUT_DB);
    console.log('Database is ready to use in your Flutter app.');
    console.log(`Make sure pubspec.yaml includes: assets/databases/${dbFileName}`);
}

/**
 * Populates the FTS table with data from JSON files
 * @param {Database} db - SQLite database instance
 */
function populateData(db) {
    const editionPrefix = CONFIG.EDITION_ID;

    console.log('Populating FTS index...');
    console.log(`Input folder: ${CONFIG.INPUT_FOLDER}`);

    // Load tree index for nodeKey computation
    const nodesByFile = loadTreeIndex();
    console.log('');

    // Get list of JSON files
    const jsonFiles = fs.readdirSync(CONFIG.INPUT_FOLDER)
        .filter(name => name.endsWith('.json'))
        .sort();

    console.log(`Found ${jsonFiles.length} JSON files to process`);
    console.log('');

    // Prepare insert statements
    // 1. Insert metadata (filename, eind, language, nodeKey, etc.)
    const insertMeta = db.prepare(`
        INSERT INTO ${editionPrefix}_meta(id, filename, eind, language, type, level, nodeKey)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    // 2. Insert into FTS index (text only, with matching rowid)
    const insertFTS = db.prepare(`
        INSERT INTO ${editionPrefix}_fts(rowid, text)
        VALUES (?, ?)
    `);

    // 3. Insert one compressed page (per language) into the content table
    const insertContent = db.prepare(`
        INSERT INTO ${editionPrefix}_content(filename, pageIndex, language, pageNum, blob)
        VALUES (?, ?, ?, ?, ?)
    `);

    // Counters
    let docId = 1;
    let totalEntries = 0;
    let totalPages = 0;
    let processedFiles = 0;

    // Begin transaction for bulk insert (much faster)
    const insertMany = db.transaction((entries, pages) => {
        for (const page of pages) {
            insertContent.run(
                page.filename,
                page.pageIndex,
                page.language,
                page.pageNum,
                page.blob
            );
        }
        for (const entry of entries) {
            // Insert metadata (including nodeKey)
            insertMeta.run(
                entry.rowid,
                entry.filename,
                entry.eind,
                entry.language,
                entry.type,
                entry.level,
                entry.nodeKey
            );
            // Insert into FTS index
            insertFTS.run(
                entry.rowid,
                entry.text
            );
        }
    });

    // Process each JSON file
    for (const filename of jsonFiles) {
        const fileKey = filename.replace('.json', '');
        const filePath = path.join(CONFIG.INPUT_FOLDER, filename);

        try {
            const content = fs.readFileSync(filePath, 'utf-8');
            const data = JSON.parse(content);

            if (!data.pages || !Array.isArray(data.pages)) {
                console.warn(`  ⚠ Skipping ${filename}: No pages array found`);
                continue;
            }

            const entries = [];
            const pages = [];

            // Get sorted nodes for this file (for nodeKey computation)
            const sortedNodes = nodesByFile.get(fileKey) || [];

            // Process each page
            data.pages.forEach((page, pageIndex) => {
                // Store each language side whole, including entries whose text
                // cleans to nothing and so never reach the index below.
                for (const language of ['pali', 'sinh']) {
                    if (page[language] == null) continue;
                    pages.push({
                        filename: fileKey,
                        pageIndex: pageIndex,
                        language: language,
                        pageNum: page.pageNum,
                        // Level 9: smaller than the default for a slower build; reads unchanged
                        blob: zlib.deflateSync(
                            Buffer.from(JSON.stringify(page[language]), 'utf-8'),
                            { level: 9 }
                        )
                    });
                }

                // Process Pali entries
                if (page.pali && page.pali.entries) {
                    page.pali.entries.forEach((entry, entryIndex) => {
                        const text = cleanTextForIndexing(entry.text);
                        if (text) {
                            // Compute nodeKey for this entry
                            const nodeKey = findNodeKeyForEntry(sortedNodes, pageIndex, entryIndex);

                            entries.push({
                                rowid: docId++,
                                filename: fileKey,
                                eind: `${pageIndex}-${entryIndex}`,
                                language: 'pali',
                                type: entry.type || 'paragraph',
                                level: entry.level || 0,
                                nodeKey: nodeKey,
                                text: text
                            });
                        }
                    });
                }

                // Process Sinhala entries
                if (page.sinh && page.sinh.entries) {
                    page.sinh.entries.forEach((entry, entryIndex) => {
                        const text = cleanTextForIndexing(entry.text);
                        if (text) {
                            // Compute nodeKey for this entry
                            const nodeKey = findNodeKeyForEntry(sortedNodes, pageIndex, entryIndex);

                            entries.push({
                                rowid: docId++,
                                filename: fileKey,
                                eind: `${pageIndex}-${entryIndex}`,
                                language: 'sinh',
                                type: entry.type || 'paragraph',
                                level: entry.level || 0,
                                nodeKey: nodeKey,
                                text: text
                            });
                        }
                    });
                }
            });

            // Insert entries and pages in a transaction (much faster than individual inserts)
            if (entries.length > 0 || pages.length > 0) {
                insertMany(entries, pages);
                totalEntries += entries.length;
                totalPages += pages.length;
            }

            processedFiles++;

            // Progress indicator every 50 files
            if (processedFiles % 50 === 0) {
                console.log(`  Progress: ${processedFiles}/${jsonFiles.length} files (${totalEntries.toLocaleString()} entries)`);
            }

        } catch (error) {
            console.error(`  ✗ Error processing ${filename}: ${error.message}`);
        }
    }

    console.log('');
    console.log(`✓ Indexed ${totalEntries.toLocaleString()} entries from ${processedFiles} files`);
    console.log(`✓ Stored ${totalPages.toLocaleString()} page rows in ${editionPrefix}_content`);
}

// =============================================================================
// RUN
// =============================================================================

main();
