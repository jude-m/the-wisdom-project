/**
 * Turns a freshly built database into a shippable one. Shared by
 * `bjt-fts-populate.js` and `dict-populate.js` — both write in WAL mode, and
 * both ship their output as a Flutter asset, so both need the same last pass.
 */

"use strict";

const fs = require('fs');
const path = require('path');

// Both callers check for this first, with a friendlier message.
const Database = require('better-sqlite3');

/**
 * Rebuilds a finished database into its shippable form: 8 KiB pages, no WAL
 * flag, and query statistics. Replaces the file in place.
 *
 * Three separate problems, one pass — none of them optional, all of them
 * measured (2026-09-11, and in the Drift/wasm spike):
 *
 *  - **The WAL flag blocks the web build outright.** `journal_mode = WAL`
 *    leaves bytes 18/19 of the header at 2. The wasm SQLite Drift ships is
 *    compiled `SQLITE_OMIT_WAL`, and rejects such a file on the *first prepare*
 *    with `SQLITE_NOTADB (26): file is not a database` — before any FTS5 code
 *    runs, and saying nothing about WAL. VACUUM INTO writes a fresh header.
 *  - **8 KiB pages halve the read I/O** the web build does per query (1,384 →
 *    703 reads; first query 505 → 325 ms). On disk it is roughly neutral for
 *    the FTS index, but it is worth ~8 MB once `bjt_content` lands, and that
 *    megabyte is paid twice because the DB is copied out of the bundle on first
 *    launch. Page size can only be set on a fresh file, which is what INTO makes.
 *  - **Without ANALYZE the planner inverts the scope+language join** and runs a
 *    separate MATCH per meta row. Measured on the real index, `බුද්ධ*` +
 *    `dn-%` + `pali`: **8,736 ms before, 8 ms after**. The stats cost 60 ms to
 *    compute and 6 rows to store. Older SQLite is where this bites — `sqflite`
 *    on Android uses the *system* SQLite, so the fix cannot wait for the engine.
 *
 * @param {string} dbPath - Database to rebuild in place
 */
function finalizeDatabase(dbPath) {
    console.log('');
    console.log('Finalizing database...');

    // Named `<name>.finalize-tmp.db` so `.gitignore`'s `assets/databases/*.db`
    // already covers it: a killed run must not leave a stray file in git status.
    const tmpPath = `${dbPath.replace(/\.db$/, '')}.finalize-tmp.db`;

    // Load-bearing, not defensive: VACUUM INTO refuses an output that exists.
    if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);

    // page_size is read off the source *connection* when INTO builds the new
    // file, so setting it on a WAL database is fine — the pragma is a no-op on
    // the source itself and only the output is affected.
    const source = new Database(dbPath);
    try {
        console.log('  Rebuilding at 8 KiB pages (VACUUM INTO)...');
        source.pragma('page_size = 8192');
        source.exec(`VACUUM INTO '${tmpPath.replace(/'/g, "''")}'`);
    } finally {
        source.close();
    }
    console.log('  ✓ Rebuilt (this also reclaims space, as VACUUM did)');

    // ANALYZE and the header check both run on the temp file, so a rejected
    // database never reaches the path the release build reads. Deliberately
    // not reopened in WAL mode: that would undo the header fix.
    const rebuilt = new Database(tmpPath);
    try {
        console.log('  Running ANALYZE...');
        rebuilt.exec('ANALYZE');
        console.log('  ✓ Query statistics written');
    } finally {
        rebuilt.close();
    }

    assertShippableHeader(tmpPath, path.basename(dbPath));

    // Only now is the original replaceable. Its sidecars belong to the file
    // being dropped, not to the one taking its place.
    fs.renameSync(tmpPath, dbPath);
    for (const sidecar of [`${dbPath}-wal`, `${dbPath}-shm`]) {
        if (fs.existsSync(sidecar)) fs.unlinkSync(sidecar);
    }

    const sizeMB = (fs.statSync(dbPath).size / 1024 / 1024).toFixed(2);
    console.log('');
    console.log(`Final database size: ${sizeMB} MB`);
}

/**
 * Fails the build if a database would be rejected by the web (wasm) build.
 *
 * Bytes 18/19 are the write/read format versions: 1 = rollback journal, 2 = WAL.
 * A 2 in either is the `SQLITE_NOTADB` described in finalizeDatabase. The same
 * two conditions are checked again in `validate-release.sh`, which is the gate
 * for databases that arrive without going through this script.
 *
 * @param {string} dbPath - File to check
 * @param {string} [label] - Name to report it by (it is usually a temp file)
 */
function assertShippableHeader(dbPath, label = path.basename(dbPath)) {
    const header = Buffer.alloc(20);
    const fd = fs.openSync(dbPath, 'r');
    try {
        fs.readSync(fd, header, 0, 20, 0);
    } finally {
        fs.closeSync(fd);
    }

    const problems = [];
    if (!header.subarray(0, 16).equals(Buffer.from('SQLite format 3\0', 'latin1'))) {
        problems.push('not a SQLite database');
    }
    if (header[18] > 1 || header[19] > 1) {
        problems.push(`WAL-flagged (bytes 18/19 = ${header[18]}/${header[19]}), `
            + 'which the wasm build rejects as "file is not a database"');
    }

    if (problems.length > 0) {
        console.error('');
        console.error(`ERROR: the rebuilt ${label} is not shippable:`);
        for (const problem of problems) console.error(`  - ${problem}`);
        console.error(`  Rejected file left at: ${dbPath}`);
        console.error('  The previous database was not replaced.');
        process.exit(1);
    }
    console.log(`  ✓ Header is web-safe (page size ${header.readUInt16BE(16)} B, `
        + 'no WAL flag)');
}

module.exports = { finalizeDatabase, assertShippableHeader };
