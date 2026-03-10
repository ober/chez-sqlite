#!chezscheme
(import (chezscheme) (chez-sqlite))

(define pass-count 0)
(define fail-count 0)

(define-syntax chk
  (syntax-rules (=>)
    [(_ expr => expected)
     (let ([result expr] [exp expected])
       (if (equal? result exp)
         (set! pass-count (+ pass-count 1))
         (begin (set! fail-count (+ fail-count 1))
                (display "FAIL: ") (write 'expr)
                (display " => ") (write result)
                (display " expected ") (write exp) (newline))))]))

(define test-db "/tmp/chez-sqlite-test.db")

;; Clean up from previous runs
(when (file-exists? test-db) (delete-file test-db))

;; Open database
(define db (sqlite-open test-db))
(chk (not (zero? db)) => #t)

;; Create table
(sqlite-exec db "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, score REAL)")

;; Insert rows
(sqlite-eval db "INSERT INTO users (name, score) VALUES (?, ?)" "Alice" 95.5)
(sqlite-eval db "INSERT INTO users (name, score) VALUES (?, ?)" "Bob" 87.3)
(sqlite-eval db "INSERT INTO users (name, score) VALUES (?, ?)" "Charlie" 92.0)

(chk (sqlite-last-insert-rowid db) => 3)
(chk (sqlite-changes db) => 1)

;; Query all rows
(let ([rows (sqlite-query db "SELECT id, name, score FROM users ORDER BY id")])
  (chk (length rows) => 3)
  (chk (vector-ref (car rows) 1) => "Alice")
  (chk (vector-ref (cadr rows) 1) => "Bob")
  (chk (> (vector-ref (car rows) 2) 95.0) => #t))

;; Query with parameter
(let ([rows (sqlite-query db "SELECT name FROM users WHERE score > ?" 90.0)])
  (chk (length rows) => 2))

;; Update
(sqlite-eval db "UPDATE users SET score = ? WHERE name = ?" 99.9 "Alice")
(let ([rows (sqlite-query db "SELECT score FROM users WHERE name = ?" "Alice")])
  (chk (> (vector-ref (car rows) 0) 99.0) => #t))

;; Delete
(sqlite-eval db "DELETE FROM users WHERE name = ?" "Charlie")
(let ([rows (sqlite-query db "SELECT * FROM users")])
  (chk (length rows) => 2))

;; NULL handling
(sqlite-eval db "INSERT INTO users (name, score) VALUES (?, ?)" "NullUser" #f)
(let ([rows (sqlite-query db "SELECT score FROM users WHERE name = ?" "NullUser")])
  (chk (vector-ref (car rows) 0) => #f))

;; Column names
(let ([stmt (sqlite-prepare db "SELECT id, name, score FROM users")])
  (chk (sqlite-columns stmt) => '("id" "name" "score"))
  (sqlite-finalize stmt))

;; Transaction
(sqlite-exec db "BEGIN")
(sqlite-eval db "INSERT INTO users (name, score) VALUES (?, ?)" "TxnUser" 50.0)
(sqlite-exec db "ROLLBACK")
(let ([rows (sqlite-query db "SELECT * FROM users WHERE name = ?" "TxnUser")])
  (chk (null? rows) => #t))

;; Blob support
(sqlite-exec db "CREATE TABLE blobs (id INTEGER PRIMARY KEY, data BLOB)")
(let ([bv #vu8(1 2 3 4 5)])
  (sqlite-eval db "INSERT INTO blobs (data) VALUES (?)" bv)
  (let ([rows (sqlite-query db "SELECT data FROM blobs")])
    (chk (equal? (vector-ref (car rows) 0) bv) => #t)))

;; Close
(sqlite-close db)

;; Cleanup
(delete-file test-db)

(newline)
(display "sqlite tests: ")
(display pass-count) (display " passed, ")
(display fail-count) (display " failed")
(newline)
(when (> fail-count 0) (exit 1))
