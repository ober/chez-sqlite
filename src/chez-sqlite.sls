#!chezscheme
;;; chez-sqlite — SQLite3 for Chez Scheme

(library (chez-sqlite)
  (export
    sqlite-open sqlite-close
    sqlite-exec sqlite-prepare sqlite-finalize
    sqlite-step sqlite-reset sqlite-clear-bindings
    sqlite-bind! sqlite-bind-null!
    sqlite-column-count sqlite-column-name sqlite-column-type
    sqlite-column-value sqlite-columns
    sqlite-query sqlite-eval
    sqlite-last-insert-rowid sqlite-changes
    sqlite-errmsg
    SQLITE_ROW SQLITE_DONE SQLITE_OK
    ;; Column types
    SQLITE_INTEGER SQLITE_FLOAT SQLITE_TEXT SQLITE_BLOB SQLITE_NULL)

  (import (chezscheme))

  ;; Load shared objects — try .so first (Linux), fall back to .dylib (macOS)
  (define _l1
    (or (guard (e [#t #f]) (load-shared-object "libsqlite3.so"))
        (guard (e [#t #f]) (load-shared-object "libsqlite3.dylib"))
        (error 'chez-sqlite "Cannot find libsqlite3 (.so or .dylib)")))
  (define _l2
    (or (guard (e [#t #f]) (load-shared-object "chez_sqlite_shim.so"))
        (error 'chez-sqlite "Cannot find chez_sqlite_shim.so — add vendor/chez-sqlite to DYLD_LIBRARY_PATH / LD_LIBRARY_PATH")))

  ;; ---- FFI bindings ----
  (define c-open    (foreign-procedure "chez_sqlite_open" (string u8* int) void*))
  (define c-close   (foreign-procedure "chez_sqlite_close" (void*) int))
  (define c-exec    (foreign-procedure "chez_sqlite_exec" (void* string u8* int) int))
  (define c-prepare (foreign-procedure "chez_sqlite_prepare" (void* string u8* int) void*))
  (define c-finalize (foreign-procedure "chez_sqlite_finalize" (void*) int))
  (define c-reset   (foreign-procedure "chez_sqlite_reset" (void*) int))
  (define c-clear   (foreign-procedure "chez_sqlite_clear_bindings" (void*) int))
  (define c-step    (foreign-procedure "chez_sqlite_step" (void*) int))
  (define c-col-count (foreign-procedure "chez_sqlite_column_count" (void*) int))
  (define c-col-name  (foreign-procedure "chez_sqlite_column_name" (void* int) string))
  (define c-col-type  (foreign-procedure "chez_sqlite_column_type" (void* int) int))
  (define c-col-int64  (foreign-procedure "chez_sqlite_column_int64" (void* int) integer-64))
  (define c-col-double (foreign-procedure "chez_sqlite_column_double" (void* int) double-float))
  (define c-col-text   (foreign-procedure "chez_sqlite_column_text" (void* int) string))
  (define c-col-bytes  (foreign-procedure "chez_sqlite_column_bytes" (void* int) int))
  (define c-col-blob   (foreign-procedure "chez_sqlite_column_blob" (void* int u8* int) void))
  (define c-bind-int64  (foreign-procedure "chez_sqlite_bind_int64" (void* int integer-64) int))
  (define c-bind-double (foreign-procedure "chez_sqlite_bind_double" (void* int double-float) int))
  (define c-bind-text   (foreign-procedure "chez_sqlite_bind_text" (void* int string) int))
  (define c-bind-blob   (foreign-procedure "chez_sqlite_bind_blob" (void* int u8* int) int))
  (define c-bind-null   (foreign-procedure "chez_sqlite_bind_null" (void* int) int))
  (define c-last-rowid  (foreign-procedure "chez_sqlite_last_insert_rowid" (void*) integer-64))
  (define c-changes     (foreign-procedure "chez_sqlite_changes" (void*) int))
  (define c-errmsg      (foreign-procedure "chez_sqlite_errmsg" (void*) string))

  ;; ---- Constants ----
  (define SQLITE_ROW  ((foreign-procedure "chez_SQLITE_ROW" () int)))
  (define SQLITE_DONE ((foreign-procedure "chez_SQLITE_DONE" () int)))
  (define SQLITE_OK   ((foreign-procedure "chez_SQLITE_OK" () int)))
  (define SQLITE_INTEGER 1)
  (define SQLITE_FLOAT   2)
  (define SQLITE_TEXT    3)
  (define SQLITE_BLOB    4)
  (define SQLITE_NULL    5)

  ;; ---- Helpers ----
  (define (errbuf->string buf)
    (let loop ([i 0])
      (if (or (= i (bytevector-length buf)) (= (bytevector-u8-ref buf i) 0))
        (let ([r (make-bytevector i)])
          (bytevector-copy! buf 0 r 0 i)
          (utf8->string r))
        (loop (+ i 1)))))

  ;; ---- Public API ----

  (define (sqlite-open path)
    (let ([errbuf (make-bytevector 512 0)])
      (let ([db (c-open path errbuf 512)])
        (when (zero? db)
          (error 'sqlite-open (errbuf->string errbuf) path))
        db)))

  (define (sqlite-close db)
    (c-close db))

  (define (sqlite-exec db sql)
    (let ([errbuf (make-bytevector 512 0)])
      (let ([rc (c-exec db sql errbuf 512)])
        (unless (= rc SQLITE_OK)
          (error 'sqlite-exec (errbuf->string errbuf) sql)))))

  (define (sqlite-prepare db sql)
    (let ([errbuf (make-bytevector 512 0)])
      (let ([stmt (c-prepare db sql errbuf 512)])
        (when (zero? stmt)
          (error 'sqlite-prepare (errbuf->string errbuf) sql))
        stmt)))

  (define (sqlite-finalize stmt) (c-finalize stmt))
  (define (sqlite-step stmt) (c-step stmt))
  (define (sqlite-reset stmt) (c-reset stmt))
  (define (sqlite-clear-bindings stmt) (c-clear stmt))

  (define (sqlite-bind! stmt idx val)
    (cond
      [(flonum? val)  (c-bind-double stmt idx val)]
      [(integer? val) (c-bind-int64 stmt idx val)]
      [(string? val)  (c-bind-text stmt idx val)]
      [(bytevector? val) (c-bind-blob stmt idx val (bytevector-length val))]
      [(not val)      (c-bind-null stmt idx)]
      [else (error 'sqlite-bind! "unsupported type" val)]))

  (define (sqlite-bind-null! stmt idx) (c-bind-null stmt idx))

  (define (sqlite-column-count stmt) (c-col-count stmt))
  (define (sqlite-column-name stmt col) (c-col-name stmt col))
  (define (sqlite-column-type stmt col) (c-col-type stmt col))

  (define (sqlite-column-value stmt col)
    (case (c-col-type stmt col)
      [(1) (c-col-int64 stmt col)]   ;; INTEGER
      [(2) (c-col-double stmt col)]  ;; FLOAT
      [(3) (c-col-text stmt col)]    ;; TEXT
      [(4) (let* ([n (c-col-bytes stmt col)]
                  [bv (make-bytevector n)])
             (c-col-blob stmt col bv n)
             bv)]                    ;; BLOB
      [(5) #f]                       ;; NULL
      [else #f]))

  (define (sqlite-columns stmt)
    (let ([n (c-col-count stmt)])
      (let loop ([i 0] [acc '()])
        (if (= i n) (reverse acc)
          (loop (+ i 1) (cons (c-col-name stmt i) acc))))))

  ;; Execute a query, return all rows as list of vectors.
  (define (sqlite-query db sql . args)
    (let ([stmt (sqlite-prepare db sql)])
      (let bind ([params args] [idx 1])
        (unless (null? params)
          (sqlite-bind! stmt idx (car params))
          (bind (cdr params) (+ idx 1))))
      (let loop ([rows '()])
        (let ([rc (sqlite-step stmt)])
          (cond
            [(= rc SQLITE_ROW)
             (let* ([ncols (c-col-count stmt)]
                    [row (make-vector ncols)])
               (do ([i 0 (+ i 1)])
                   ((= i ncols))
                 (vector-set! row i (sqlite-column-value stmt i)))
               (loop (cons row rows)))]
            [(= rc SQLITE_DONE)
             (sqlite-finalize stmt)
             (reverse rows)]
            [else
             (sqlite-finalize stmt)
             (error 'sqlite-query (c-errmsg db) sql)])))))

  ;; Execute SQL, return nothing (for INSERT/UPDATE/DELETE).
  (define (sqlite-eval db sql . args)
    (let ([stmt (sqlite-prepare db sql)])
      (let bind ([params args] [idx 1])
        (unless (null? params)
          (sqlite-bind! stmt idx (car params))
          (bind (cdr params) (+ idx 1))))
      (let ([rc (sqlite-step stmt)])
        (sqlite-finalize stmt)
        (unless (or (= rc SQLITE_DONE) (= rc SQLITE_ROW))
          (error 'sqlite-eval (c-errmsg db) sql)))))

  (define (sqlite-last-insert-rowid db) (c-last-rowid db))
  (define (sqlite-changes db) (c-changes db))
  (define (sqlite-errmsg db) (c-errmsg db))

  ) ;; end library
