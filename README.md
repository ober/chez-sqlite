# chez-sqlite

SQLite3 bindings for Chez Scheme.

## Requirements

- Chez Scheme 10.x
- libsqlite3 (`apt install libsqlite3-dev`)
- GCC

## Build & Test

```bash
make
make test
```

## Usage

```scheme
(import (chez-sqlite))

(define db (sqlite-open "my.db"))

;; Create table
(sqlite-exec db "CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT)")

;; Insert with parameters
(sqlite-eval db "INSERT INTO items (name) VALUES (?)" "hello")

;; Query
(for-each
  (lambda (row) (printf "~a ~a~%" (vector-ref row 0) (vector-ref row 1)))
  (sqlite-query db "SELECT * FROM items"))

(sqlite-close db)
```

## API

| Function | Description |
|----------|-------------|
| `(sqlite-open path)` | Open database |
| `(sqlite-close db)` | Close database |
| `(sqlite-exec db sql)` | Execute SQL (no results) |
| `(sqlite-eval db sql args...)` | Execute with parameters |
| `(sqlite-query db sql args...)` | Query, returns list of vectors |
| `(sqlite-prepare db sql)` | Prepare statement |
| `(sqlite-bind! stmt idx val)` | Bind parameter (auto-typed) |
| `(sqlite-step stmt)` | Step statement |
| `(sqlite-column-value stmt col)` | Get column value |
| `(sqlite-columns stmt)` | Get column names |
| `(sqlite-finalize stmt)` | Finalize statement |
| `(sqlite-last-insert-rowid db)` | Last inserted row ID |
| `(sqlite-changes db)` | Rows changed by last statement |
# chez-sqlite
