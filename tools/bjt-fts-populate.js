/**
 * BJT Full-Text Search Database Generator
 *
 * Creates an optimized FTS5 database for the Buddha Jayanti Tripitaka (BJT) edition.
 * This uses a contentless approach that reduces database size by ~75% by storing
 * only the search index (not the actual text, which is already in JSON files).
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
 *   - snippet() function not available in contentless mode - context fetched from JSON files
 *   - Queries require JOIN with metadata table
 *
 * Database structure:
 *   - bjt_fts: Contentless FTS5 index (text search with bm25 ranking)
 *   - bjt_meta: Metadata table (filename, eind, language, type, level)
 *   - bjt_suggestions: Word frequency for auto-complete (95K+ words)
 *
 * Usage:
 *   cd tools
 *   npm install better-sqlite3  # First time only
 *   node bjt-fts-populate.js
 *
 * Input:  ../assets/text/*.json (BJT text files)
 * Output: bjt-fts.db (~110-120 MB)
 *
 * Based on: tipitaka.lk/dev/fts-populate.js
 * Modified for: The Wisdom Project - Multi-edition architecture
 */

"use strict";

const fs = require('fs');
const path = require('path');

// Try to use better-sqlite3 (recommended)
let Database;
try {
    Database = require('better-sqlite3');
} catch (e) {
    console.error('ERROR: better-sqlite3 not installed');
    console.error('Run: npm install better-sqlite3');
    process.exit(1);
}

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

    // Generate word frequency for auto-suggestions
    GENERATE_SUGGESTIONS: false,

    // Minimum word frequency to include in suggestions (filters out rare words)
    MIN_WORD_FREQUENCY: 3,

    // Maximum suggestions to keep per language
    MAX_SUGGESTIONS: 50000,

    // Input folder containing JSON text files
    // Path is relative to this script (tools/)
    INPUT_FOLDER: path.join(__dirname, '../assets/text/'),

    // Tree JSON file (for nodeKey computation)
    TREE_JSON: path.join(__dirname, '../assets/data/tree.json'),

    // Output database file
    OUTPUT_DB: path.join(__dirname, '../assets/databases/bjt-fts.db'),
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

/**
 * Extracts words from text for suggestion generation
 * @param {string} text - Text to extract words from
 * @returns {string[]} - Array of words
 */
function extractWords(text) {
    if (!text) return [];

    // Replace punctuation and numbers with spaces
    const cleaned = text.replace(/[\.\:\[\]\(\)\{\}\-–,\d'"''""\?\n\t\r]/g, ' ');

    // Split by whitespace and filter empty strings
    return cleaned.split(/\s+/).filter(word => word.length > 0);
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

    // Drop existing tables if they exist
    db.exec(`DROP TABLE IF EXISTS ${editionPrefix}_fts`);
    db.exec(`DROP TABLE IF EXISTS ${editionPrefix}_meta`);

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
 * Creates the suggestions table for auto-complete
 * @param {Database} db - SQLite database instance
 */
function createSuggestionsTable(db) {
    const editionPrefix = CONFIG.EDITION_ID;
    console.log('Creating suggestions table...');

    db.exec(`DROP TABLE IF EXISTS ${editionPrefix}_suggestions`);

    const createSQL = `
        CREATE TABLE ${editionPrefix}_suggestions (
            word TEXT PRIMARY KEY,
            language TEXT NOT NULL,
            frequency INTEGER NOT NULL
        )
    `;

    db.exec(createSQL);

    // Create indexes for fast prefix search
    db.exec(`CREATE INDEX idx_${editionPrefix}_suggestions_word ON ${editionPrefix}_suggestions(word)`);
    db.exec(`CREATE INDEX idx_${editionPrefix}_suggestions_lang ON ${editionPrefix}_suggestions(language)`);

    console.log(`  ✓ ${editionPrefix}_suggestions: Word frequency for auto-complete`);
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

    const db = new Database(CONFIG.OUTPUT_DB);

    // Enable WAL mode for better write performance
    db.pragma('journal_mode = WAL');

    try {
        // Step 1: Create table structure
        if (CONFIG.CREATE_TABLE) {
            createFTSTables(db);
            if (CONFIG.GENERATE_SUGGESTIONS) {
                createSuggestionsTable(db);
            }
            console.log('');
        }

        // Step 2: Populate data
        if (CONFIG.POPULATE_DATA) {
            populateData(db);
        }

        // Optimize database
        console.log('');
        console.log('Optimizing database...');
        db.exec('VACUUM');

        // Report final size
        const stats = fs.statSync(CONFIG.OUTPUT_DB);
        const sizeMB = (stats.size / 1024 / 1024).toFixed(2);
        console.log(`Final database size: ${sizeMB} MB`);

    } finally {
        db.close();
    }

    // Copy database to assets/databases/
    console.log('');
    console.log('Copying database to assets/databases/...');
    const assetsDbDir = path.join(__dirname, '../assets/databases');
    const targetDbPath = path.join(assetsDbDir, 'bjt-fts.db');

    // Create directory if it doesn't exist
    if (!fs.existsSync(assetsDbDir)) {
        fs.mkdirSync(assetsDbDir, { recursive: true });
        console.log(`  Created directory: ${assetsDbDir}`);
    }

    // Copy the database file
    fs.copyFileSync(CONFIG.OUTPUT_DB, targetDbPath);
    console.log(`  ✓ Copied to: ${targetDbPath}`);

    console.log('');
    console.log('✓ Done!');
    console.log('');
    console.log('Database is ready to use in your Flutter app.');
    console.log('Make sure pubspec.yaml includes: assets/databases/bjt-fts.db');
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

    // Word frequency maps for suggestions
    const wordFrequencyPali = new Map();
    const wordFrequencySinh = new Map();

    // Counters
    let docId = 1;
    let totalEntries = 0;
    let processedFiles = 0;

    // Begin transaction for bulk insert (much faster)
    const insertMany = db.transaction((entries) => {
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

            // Get sorted nodes for this file (for nodeKey computation)
            const sortedNodes = nodesByFile.get(fileKey) || [];

            // Process each page
            data.pages.forEach((page, pageIndex) => {
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

                            // Collect words for suggestions
                            if (CONFIG.GENERATE_SUGGESTIONS) {
                                for (const word of extractWords(text)) {
                                    wordFrequencyPali.set(
                                        word,
                                        (wordFrequencyPali.get(word) || 0) + 1
                                    );
                                }
                            }
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

                            // Collect words for suggestions
                            if (CONFIG.GENERATE_SUGGESTIONS) {
                                for (const word of extractWords(text)) {
                                    wordFrequencySinh.set(
                                        word,
                                        (wordFrequencySinh.get(word) || 0) + 1
                                    );
                                }
                            }
                        }
                    });
                }
            });

            // Insert entries in a transaction (much faster than individual inserts)
            if (entries.length > 0) {
                insertMany(entries);
                totalEntries += entries.length;
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

    // Save suggestions if enabled
    if (CONFIG.GENERATE_SUGGESTIONS) {
        saveSuggestions(db, wordFrequencyPali, wordFrequencySinh);
    }
}

/**
 * Saves word frequency data to suggestions table
 * @param {Database} db - SQLite database instance
 * @param {Map} wordFrequencyPali - Pali word frequencies
 * @param {Map} wordFrequencySinh - Sinhala word frequencies
 */
function saveSuggestions(db, wordFrequencyPali, wordFrequencySinh) {
    const editionPrefix = CONFIG.EDITION_ID;

    console.log('');
    console.log('Generating auto-complete suggestions...');

    const insertSuggestion = db.prepare(`
        INSERT OR REPLACE INTO ${editionPrefix}_suggestions(word, language, frequency)
        VALUES (?, ?, ?)
    `);

    const insertMany = db.transaction((suggestions) => {
        for (const s of suggestions) {
            insertSuggestion.run(s.word, s.language, s.frequency);
        }
    });

    // Filter and sort Pali words
    const paliSuggestions = Array.from(wordFrequencyPali.entries())
        .filter(([word, freq]) => freq >= CONFIG.MIN_WORD_FREQUENCY && word.length > 1)
        .sort((a, b) => b[1] - a[1])
        .slice(0, CONFIG.MAX_SUGGESTIONS)
        .map(([word, frequency]) => ({ word, language: 'pali', frequency }));

    // Filter and sort Sinhala words
    const sinhSuggestions = Array.from(wordFrequencySinh.entries())
        .filter(([word, freq]) => freq >= CONFIG.MIN_WORD_FREQUENCY && word.length > 1)
        .sort((a, b) => b[1] - a[1])
        .slice(0, CONFIG.MAX_SUGGESTIONS)
        .map(([word, frequency]) => ({ word, language: 'sinh', frequency }));

    // Insert into database
    insertMany([...paliSuggestions, ...sinhSuggestions]);

    console.log(`  ✓ Pali suggestions: ${paliSuggestions.length.toLocaleString()}`);
    console.log(`  ✓ Sinhala suggestions: ${sinhSuggestions.length.toLocaleString()}`);
    console.log(`  ✓ Total: ${(paliSuggestions.length + sinhSuggestions.length).toLocaleString()} words`);
}

// =============================================================================
// RUN
// =============================================================================

main();
