/* chez_sqlite_shim.c — SQLite3 wrapper for Chez Scheme FFI */

#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Open a database. Returns sqlite3* handle or NULL on error.
   Error message written to errbuf. */
void *chez_sqlite_open(const char *path, char *errbuf, int errbuflen) {
    sqlite3 *db = NULL;
    int rc = sqlite3_open(path, &db);
    if (rc != SQLITE_OK) {
        if (db) {
            snprintf(errbuf, errbuflen, "%s", sqlite3_errmsg(db));
            sqlite3_close(db);
        } else {
            snprintf(errbuf, errbuflen, "out of memory");
        }
        return NULL;
    }
    return db;
}

/* Close a database. */
int chez_sqlite_close(void *db) {
    return sqlite3_close((sqlite3 *)db);
}

/* Execute a simple SQL statement (no results). Returns 0 or error code.
   Error message written to errbuf. */
int chez_sqlite_exec(void *db, const char *sql, char *errbuf, int errbuflen) {
    char *msg = NULL;
    int rc = sqlite3_exec((sqlite3 *)db, sql, NULL, NULL, &msg);
    if (rc != SQLITE_OK && msg) {
        snprintf(errbuf, errbuflen, "%s", msg);
        sqlite3_free(msg);
    }
    return rc;
}

/* Prepare a statement. Returns stmt handle or NULL. */
void *chez_sqlite_prepare(void *db, const char *sql, char *errbuf, int errbuflen) {
    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2((sqlite3 *)db, sql, -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        snprintf(errbuf, errbuflen, "%s", sqlite3_errmsg((sqlite3 *)db));
        return NULL;
    }
    return stmt;
}

/* Finalize (destroy) a prepared statement. */
int chez_sqlite_finalize(void *stmt) {
    return sqlite3_finalize((sqlite3_stmt *)stmt);
}

/* Reset a prepared statement for re-execution. */
int chez_sqlite_reset(void *stmt) {
    return sqlite3_reset((sqlite3_stmt *)stmt);
}

/* Clear all bindings on a statement. */
int chez_sqlite_clear_bindings(void *stmt) {
    return sqlite3_clear_bindings((sqlite3_stmt *)stmt);
}

/* Step a prepared statement. Returns:
   100 (SQLITE_ROW) = row available
   101 (SQLITE_DONE) = no more rows
   other = error */
int chez_sqlite_step(void *stmt) {
    return sqlite3_step((sqlite3_stmt *)stmt);
}

/* Get number of columns in result set. */
int chez_sqlite_column_count(void *stmt) {
    return sqlite3_column_count((sqlite3_stmt *)stmt);
}

/* Get column name. */
const char *chez_sqlite_column_name(void *stmt, int col) {
    return sqlite3_column_name((sqlite3_stmt *)stmt, col);
}

/* Get column type: 1=INTEGER, 2=FLOAT, 3=TEXT, 4=BLOB, 5=NULL */
int chez_sqlite_column_type(void *stmt, int col) {
    return sqlite3_column_type((sqlite3_stmt *)stmt, col);
}

/* Get integer column value. */
long long chez_sqlite_column_int64(void *stmt, int col) {
    return sqlite3_column_int64((sqlite3_stmt *)stmt, col);
}

/* Get float column value. */
double chez_sqlite_column_double(void *stmt, int col) {
    return sqlite3_column_double((sqlite3_stmt *)stmt, col);
}

/* Get text column value. */
const char *chez_sqlite_column_text(void *stmt, int col) {
    const char *text = (const char *)sqlite3_column_text((sqlite3_stmt *)stmt, col);
    return text ? text : "";
}

/* Get blob column size. */
int chez_sqlite_column_bytes(void *stmt, int col) {
    return sqlite3_column_bytes((sqlite3_stmt *)stmt, col);
}

/* Copy blob data to output buffer. */
void chez_sqlite_column_blob(void *stmt, int col, unsigned char *out, int len) {
    const void *blob = sqlite3_column_blob((sqlite3_stmt *)stmt, col);
    if (blob && len > 0) memcpy(out, blob, len);
}

/* ---- Bind parameters ---- */

int chez_sqlite_bind_int64(void *stmt, int idx, long long val) {
    return sqlite3_bind_int64((sqlite3_stmt *)stmt, idx, val);
}

int chez_sqlite_bind_double(void *stmt, int idx, double val) {
    return sqlite3_bind_double((sqlite3_stmt *)stmt, idx, val);
}

int chez_sqlite_bind_text(void *stmt, int idx, const char *val) {
    return sqlite3_bind_text((sqlite3_stmt *)stmt, idx, val, -1, SQLITE_TRANSIENT);
}

int chez_sqlite_bind_blob(void *stmt, int idx, const unsigned char *val, int len) {
    return sqlite3_bind_blob((sqlite3_stmt *)stmt, idx, val, len, SQLITE_TRANSIENT);
}

int chez_sqlite_bind_null(void *stmt, int idx) {
    return sqlite3_bind_null((sqlite3_stmt *)stmt, idx);
}

/* Get last insert rowid. */
long long chez_sqlite_last_insert_rowid(void *db) {
    return sqlite3_last_insert_rowid((sqlite3 *)db);
}

/* Get number of rows changed. */
int chez_sqlite_changes(void *db) {
    return sqlite3_changes((sqlite3 *)db);
}

/* Get error message from db handle. */
const char *chez_sqlite_errmsg(void *db) {
    return sqlite3_errmsg((sqlite3 *)db);
}

/* Constants */
int chez_SQLITE_ROW(void)  { return SQLITE_ROW; }
int chez_SQLITE_DONE(void) { return SQLITE_DONE; }
int chez_SQLITE_OK(void)   { return SQLITE_OK; }
