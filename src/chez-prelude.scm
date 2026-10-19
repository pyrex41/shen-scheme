;; Copyright (c) 2012-2021 Bruno Deferrari.  All rights reserved.
;; BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause

(define-syntax raise-error
  (syntax-rules ()
    ((_ location message obj ...)
     (error location message obj ...))))

(define *shen-globals* (make-hashtable symbol-hash eq?))

(define (shen-global-parameter-set! var parameter)
  (symbol-hashtable-set! *shen-globals* var parameter))

(define (shen-global-set! var value)
  (let ((cell (symbol-hashtable-cell *shen-globals* var #f)))
    (if (cdr cell)
        ((cdr cell) value)
        (set-cdr! cell (make-parameter value)))))

(define *hash-table-default* (string-append "_" "-"))

(define (shen-global-get var default)
  (let ((res (symbol-hashtable-ref *shen-globals* var *hash-table-default*)))
    (if (eq? res *hash-table-default*)
        (default var)
        (res))))

(define (kl-var-clean sym)
  (if (symbol? sym)
      (let* ((str (symbol->string sym))
             (len (string-length str)))
        (if (and (> len 3)
                 (string=? "kl:" (substring str 0 3)))
         (string->symbol (substring str 3 len))
         sym))
      sym))

(define (error-message e)
  (let* ((msg (condition-message e))
         (irritants (if (irritants-condition? e) (condition-irritants e) '())))
    (cond ((format-condition? e)
           (apply format msg (map kl-var-clean irritants)))
          ((null? irritants) msg)
          (else (format "~a: ~{~s~}" msg irritants)))))

(define (error-location e)
  (if (who-condition? e)
      (condition-who e)
      '*unknown-location*))

;; Byte strings
;;
;; The kernel's strings are byte strings: its reader turns each byte of a
;; source file into one character (`n->string` of the byte), as shen-go and
;; shen-c do, so a UTF-8 "λ" is the two characters U+00CE U+00BB. Everything
;; that crosses to the operating system keeps that view:
;;
;; - Output to a binary port writes a character below 256 as that one byte.
;;   A character at or above 256 can only come from Scheme-side construction
;;   (`n->string` of a large number, `scm.` code, a textual port); it is written
;;   as its UTF-8 encoding, so Unicode text built in Scheme still prints.
;; - File names, command-line arguments and `read-file-as-string` convert
;;   between byte strings and Chez's Unicode strings at the boundary.
;; - Textual ports (only ever made by Scheme code) take Scheme strings as is.

(define (shen-byte-string? s)
  (let ((n (string-length s)))
    (let loop ((i 0))
      (cond ((fx=? i n) #t)
            ((fx<? (char->integer (string-ref s i)) 256) (loop (fx+ i 1)))
            (else #f)))))

(define (shen-string->bytevector s)
  (if (shen-byte-string? s)
      (let* ((n (string-length s))
             (bv (make-bytevector n)))
        (do ((i 0 (fx+ i 1)))
            ((fx=? i n) bv)
          (bytevector-u8-set! bv i (char->integer (string-ref s i)))))
      (call-with-bytevector-output-port
       (lambda (out)
         (string-for-each
          (lambda (c)
            (let ((k (char->integer c)))
              (if (fx<? k 256)
                  (put-u8 out k)
                  (put-bytevector out (string->utf8 (string c))))))
          s)))))

(define (bytevector->shen-string bv)
  (let* ((n (bytevector-length bv))
         (s (make-string n)))
    (do ((i 0 (fx+ i 1)))
        ((fx=? i n) s)
      (string-set! s i (integer->char (bytevector-u8-ref bv i))))))

(define (os-string->shen-string s)
  (bytevector->shen-string (string->utf8 s)))

(define strict-utf-8
  (make-transcoder (utf-8-codec) (eol-style none) (error-handling-mode raise)))

;; A byte string holding UTF-8 becomes the Unicode string Chez passes to the
;; OS; anything else (a Scheme string, or bytes that are not UTF-8) is kept.
(define (shen-string->os-string s)
  (if (shen-byte-string? s)
      (guard (e (#t s))
        (bytevector->string (shen-string->bytevector s) strict-utf-8))
      s))

(define (full-path-for-file filename)
  (let ((filename (shen-string->os-string filename)))
    (if (path-absolute? filename)
        filename
        (string-append (current-directory)
                       (string (directory-separator))
                       filename))))

(define (shen-scheme-file-exists? filename)
  (file-exists? (shen-string->os-string filename)))

(define (open-binary-input-file filename)
  (open-file-input-port filename))

(define (open-binary-output-file filename)
  (open-file-output-port filename (file-options no-fail)))

(define (time->float t)
  (+ (time-second t)
     (/ (time-nanosecond t) 1e+9)))

(define (should-flush? p)
  (let ((name (port-name p)))
    (or (equal? name "stdout") (equal? name "stderr"))))

(define (write-byte byte o)
  (put-u8 o byte)
  (and (should-flush? o)
       (flush-output-port o))
  byte)

(define (read-byte i)
  (let ((byte (get-u8 i)))
    (if (eof-object? byte)
        -1
        byte)))

(define (read-file-as-string filename)
  (let* ((in (open-file-input-port (full-path-for-file filename)))
         (bytes (get-bytevector-all in)))
    (close-input-port in)
    (if (eof-object? bytes)
        ""
        (bytevector->shen-string bytes))))

(define (read-file-as-bytelist filename)
  (let* ((in (open-file-input-port (full-path-for-file filename)))
         (bytes (get-bytevector-all in)))
    (close-input-port in)
    (if (eof-object? bytes)
        '()
        (bytevector->u8-list bytes))))

(define (hashtable-fold ht f init)
  (let-values (((keys values) (hashtable-entries ht)))
    (let ((limit (vector-length keys)))
      (let loop ((i 0)
                 (acc init))
        (if (fx=? i limit)
            acc
            (let ((k (vector-ref keys i))
                  (v (vector-ref values i)))
              (loop (fx+ i 1) (((f k) v) acc))))))))
