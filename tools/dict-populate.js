/**
 * Dictionary Database Generator (Optimized)
 *
 * Creates an optimized dictionary database for fast word lookups from multiple
 * Pali-English and Pali-Sinhala dictionaries.
 *
 * Uses a simple table with indexed word column for optimal performance with
 * exact word lookups and prefix searches (LIKE 'word%').
 *
 * Database structure:
 *   - dictionary: Main table (id, word, dict_id, meaning, rank)
 *     - id INTEGER PRIMARY KEY: Auto-incrementing unique ID (uses SQLite's rowid)
 *   - Single index on word column for fast lookups
 *
 * Special Processing:
 *   - DPD & DPDC: Words are romanized Pali → convert to Sinhala script
 *   - CR: Remove <br/> tags from meanings
 *   - All: Strip trailing numbers from words (e.g., "word1" → "word")
 *
 * Usage:
 *   cd tools
 *   npm install better-sqlite3 @pnfo/pali-converter  # First time only
 *   node dict-populate.js
 *
 * Input:  ../assets/dictionary/*.json
 * Output: ../assets/databases/dict.db
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
    // Input folder containing dictionary JSON files
    INPUT_FOLDER: path.join(__dirname, '../assets/dictionary/'),

    // Output database file
    OUTPUT_DB: path.join(__dirname, '../assets/databases/dict.db'),

    // Dictionary configuration with priority ranking (higher = more important)
    // Format: [id, filename, rank, needsConversion]
    DICTIONARIES: [
        // Sinhala target dictionaries (highest priority for Sinhala users)
        ['BUS', 'sinhala/buddhadatta_dict.json', 100, false],
        ['MS', 'sinhala/sumangala_dict.json', 90, false],

        // English target dictionaries
        ['BUE', 'en-buddhadatta.json', 80, false],
        ['DPD', 'en-dpd.json', 70, true],           // romanized → Sinhala
        ['VRI', 'en-vri.json', 60, false],
        ['PTS', 'en-pts.json', 50, false],
        ['CR', 'en-critical.json', 40, false],      // needs <br/> removal
        ['DPDC', 'en-dpd-construction.json', 30, true], // romanized → Sinhala
        ['ND', 'en-nyanatiloka.json', 20, false],
        ['PN', 'en-dppn.json', 10, false],
    ],
};


// =============================================================================
// TEXT PROCESSING
// =============================================================================

/**
 * Removes trailing numbers from words (e.g., "abaddha1" → "abaddha")
 * @param {string} word - Word that may have trailing number
 * @returns {string} - Word without trailing number
 */
function stripTrailingNumber(word) {
    return word.replace(/\d+$/, '');
}

/**
 * Removes <br/> tags from meaning text
 * @param {string} meaning - Meaning text with possible <br/> tags
 * @returns {string} - Cleaned meaning
 */
function removeBRTags(meaning) {
    // Remove -<br/> (join words without space)
    meaning = meaning.replace(/-<br\/>/g, '');
    // Replace <br/> with space
    return meaning.replace(/<br\/>/g, ' ');
}

// =============================================================================
// DATABASE OPERATIONS
// =============================================================================

/**
 * Creates the dictionary table with index
 * @param {Database} db - SQLite database instance
 */
function createTables(db) {
    console.log('Creating dictionary table...');

    // Drop existing table and index if they exist
    db.exec('DROP TABLE IF EXISTS dictionary');
    db.exec('DROP INDEX IF EXISTS idx_word');

    // Create main dictionary table
    // id INTEGER PRIMARY KEY is an alias for SQLite's built-in rowid (no extra storage)
    const createTableSQL = `
        CREATE TABLE dictionary (
            id INTEGER PRIMARY KEY,
            word TEXT NOT NULL,
            dict_id TEXT NOT NULL,
            meaning TEXT NOT NULL,
            rank INTEGER DEFAULT 0
        )
    `;
    db.exec(createTableSQL);

    // Create index on word column for fast lookups
    db.exec('CREATE INDEX idx_word ON dictionary(word)');

    console.log('  ✓ dictionary: Main table (id, word, dict_id, meaning, rank)');
    console.log('  ✓ idx_word: Index on word column for fast lookups');
}

// =============================================================================
// MAIN PROCESSING
// =============================================================================

async function main() {
    console.log('='.repeat(70));
    console.log('Dictionary Database Generator');
    console.log('='.repeat(70));
    console.log('');

    // Validate input folder exists
    if (!fs.existsSync(CONFIG.INPUT_FOLDER)) {
        console.error(`ERROR: Input folder not found: ${CONFIG.INPUT_FOLDER}`);
        console.error('Please ensure dictionary files are in: assets/dictionary/');
        process.exit(1);
    }

    // Load pali-converter for DPD/DPDC conversion
    let convert, Script;
    try {
        const paliConverter = await import('@pnfo/pali-converter');
        convert = paliConverter.convert;
        Script = paliConverter.Script;
        console.log('✓ Loaded @pnfo/pali-converter for romanized Pali conversion');
    } catch (e) {
        console.error('ERROR: @pnfo/pali-converter not installed');
        console.error('Run: npm install @pnfo/pali-converter');
        process.exit(1);
    }

    // Open/create database
    console.log(`Database: ${CONFIG.OUTPUT_DB}`);
    console.log('');

    const db = new Database(CONFIG.OUTPUT_DB);

    // Enable WAL mode for better write performance
    db.pragma('journal_mode = WAL');

    try {
        // Create table structure
        createTables(db);
        console.log('');

        // Populate data
        await populateData(db, convert, Script);

        // Optimize database
        console.log('');
        console.log('Optimizing database...');

        // VACUUM to reclaim disk space and defragment
        // (No FTS5 optimize needed - this is a regular table)
        console.log('  Running VACUUM...');
        db.exec('VACUUM');
        console.log('  ✓ Database vacuumed');

        // Report final size
        console.log('');
        const stats = fs.statSync(CONFIG.OUTPUT_DB);
        const sizeMB = (stats.size / 1024 / 1024).toFixed(2);
        console.log(`Final database size: ${sizeMB} MB`);

    } finally {
        db.close();
    }

    console.log('');
    console.log('✓ Done!');
    console.log('');
    console.log('Database is ready to use in your Flutter app.');
    console.log('Make sure pubspec.yaml includes: assets/databases/dict.db');
}

/**
 * Populates the dictionary table with data from dictionary JSON files
 * @param {Database} db - SQLite database instance
 * @param {Function} convert - Pali converter function
 * @param {Object} Script - Script enum from pali-converter
 */
async function populateData(db, convert, Script) {
    console.log('Populating dictionary table...');
    console.log(`Input folder: ${CONFIG.INPUT_FOLDER}`);
    console.log('');

    // Prepare insert statement
    const insertStmt = db.prepare(`
        INSERT INTO dictionary(id, word, dict_id, meaning, rank)
        VALUES (?, ?, ?, ?, ?)
    `);

    // Counters
    let docId = 1;
    let totalEntries = 0;
    let skippedEntries = 0;

    // Begin transaction for bulk insert (much faster)
    const insertMany = db.transaction((entries) => {
        for (const entry of entries) {
            insertStmt.run(
                entry.id,
                entry.word,
                entry.dictId,
                entry.meaning,
                entry.rank
            );
        }
    });

    // Process each dictionary
    for (const [dictId, filename, rank, needsConversion] of CONFIG.DICTIONARIES) {
        const filePath = path.join(CONFIG.INPUT_FOLDER, filename);

        if (!fs.existsSync(filePath)) {
            console.warn(`  ⚠ Skipping ${dictId}: File not found: ${filename}`);
            continue;
        }

        console.log(`Processing ${dictId} (${filename})...`);

        try {
            const content = fs.readFileSync(filePath, 'utf-8');
            const data = JSON.parse(content);

            const entries = [];
            let dictEntryCount = 0;
            let dictSkipped = 0;

            for (const [rawWord, rawMeaning] of data) {
                // Strip trailing numbers from word
                let word = stripTrailingNumber(rawWord);
                let meaning = rawMeaning;

                // Special processing based on dictionary
                if (dictId === 'CR') {
                    meaning = removeBRTags(meaning);
                }

                // Convert romanized Pali to Sinhala script for DPD/DPDC
                if (needsConversion) {
                    try {
                        const siWord = convert(word, Script.SI, Script.RO);
                        if (siWord) {
                            word = siWord;
                            // For DPDC, also convert the meaning (which contains word breakdowns)
                            if (dictId === 'DPDC') {
                                meaning = convert(meaning, Script.SI, Script.RO) || meaning;
                            }
                        } else {
                            dictSkipped++;
                            continue;
                        }
                    } catch (convErr) {
                        // Skip words that can't be converted
                        dictSkipped++;
                        continue;
                    }
                }

                // Skip if word or meaning is empty
                if (!word || !meaning) {
                    dictSkipped++;
                    continue;
                }

                entries.push({
                    id: docId++,
                    word: word,
                    dictId: dictId,
                    meaning: meaning,
                    rank: rank
                });

                dictEntryCount++;
            }

            // Insert entries in a transaction
            if (entries.length > 0) {
                insertMany(entries);
                totalEntries += entries.length;
            }

            skippedEntries += dictSkipped;
            console.log(`  ✓ ${dictId}: ${dictEntryCount.toLocaleString()} entries${dictSkipped > 0 ? ` (${dictSkipped} skipped)` : ''}`);

        } catch (error) {
            console.error(`  ✗ Error processing ${dictId}: ${error.message}`);
        }
    }

    console.log('');
    console.log(`✓ Indexed ${totalEntries.toLocaleString()} entries total`);
    if (skippedEntries > 0) {
        console.log(`  (${skippedEntries.toLocaleString()} entries skipped due to conversion issues)`);
    }
}

// =============================================================================
// RUN
// =============================================================================

main().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
