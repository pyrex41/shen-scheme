\* Copyright (c) 2012-2021 Bruno Deferrari.  All rights reserved. *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

(define hash
  Val Bound -> ((foreign scm.fxmod) ((foreign scm.equal-hash) Val) Bound))

(define not
  Val -> ((foreign scm.not) Val))

(define boolean?
  Val -> ((foreign scm.boolean?) Val))

(define integer?
  Val -> ((foreign scm.integer?) Val))

\* *hush* gates only the standard-output stream, not explicit file sinks: a
   pr to a file is the program's output, not chatter to silence. (Fork-
   specific. The kernel's pr suppresses every sink under *hush*, so `eval -q`
   wrote empty files.) Like the kernel's pr, a binary sink gets one byte per
   character of the byte string (src/chez-prelude.scm), written as one
   bytevector. *\
(define pr
  String Sink -> (trap-error
                  (let Hushed ((foreign scm.and) (value *hush*) ((foreign scm.eq?) Sink (value *stoutput*)))
                       P (if ((foreign scm.textual-port?) Sink)
                             ((foreign scm.or) Hushed ((foreign scm.put-string) Sink String))
                             ((foreign scm.or) Hushed ((foreign scm.put-bytevector) Sink ((foreign scm.shen-string->bytevector) String))))
                       F ((foreign scm.and)
                            (not Hushed)
                            ((foreign scm.should-flush?) Sink)
                            ((foreign scm.flush-output-port) Sink))
                    String)
                  (/. E String)))

(define variable?
  Val -> ((foreign scm.and)
          ((foreign scm.symbol?) Val)
          ((foreign scm.char-upper-case?) ((foreign scm.string-ref) ((foreign scm.symbol->string) Val) 0))))

(define shen.analyse-symbol?
  S -> ((foreign scm.analyse-symbol?) S))

(define symbol?
  Val -> (and ((foreign scm.symbol?) Val)
              (shen.analyse-symbol? (str Val))))

(define shen.pvar?
  V -> ((foreign scm.and)
        (absvector? V)
        ((foreign scm.and)
         ((foreign scm.fx>?) ((foreign scm.vector-length) V) 0)
         (= ((foreign scm.vector-ref) V 0) shen.pvar))))

(define shen.numbyte?
  N -> ((foreign scm.and) ((foreign scm.fx>=?) N 48) ((foreign scm.fx<=?) N 57)))

(define shen.byte->digit
  N -> ((foreign scm.fx-) N 48))

(define shen.dict
  Size -> ((foreign scm.make-equal-hashtable) Size))

(define shen.dict?
  X -> ((foreign scm.hashtable?) X))

(define shen.dict-count
  Dict -> ((foreign scm.hashtable-size) Dict))

(define shen.dict->
  Dict K V -> (do ((foreign scm.hashtable-set!) Dict K V)
                  V))

(define shen.<-dict
  Dict K -> (let Res ((foreign scm.hashtable-ref) Dict K $%value-not-found%$)
              (if ((foreign scm.eq?) Res $%value-not-found%$)
                  (error "value ~A not found in dict~%" K)
                  Res)))

(define shen.dict-rm
  Dict K -> (do ((foreign scm.hashtable-delete!) Dict K)
                K))

\* hashtable-fold defined in prelude.scm *\
(define shen.dict-fold
  F Dict Init -> ((foreign scm.hashtable-fold) Dict F Init))

(define shen.dict-keys
  Dict -> ((foreign scm.vector->list)
           ((foreign scm.hashtable-keys) Dict)))

(define shen.dict-values
  Dict -> ((foreign scm.vector->list)
           ((foreign scm.hashtable-values) Dict)))

\* read-file-as-* defined in prelude.scm *\

(define read-file-as-bytelist
  Filename -> ((foreign scm.read-file-as-bytelist) ((foreign scm.string-append) (value *home-directory*) Filename)))

(define read-file-as-string
  Filename -> ((foreign scm.read-file-as-string) ((foreign scm.string-append) (value *home-directory*) Filename)))

\* tuples *\

(define @p
  X Y -> ((foreign scm.vector) shen.tuple X Y))

\* vectors *\

(define vector
  N -> (let Vector ((foreign scm.make-vector) (+ N 1) (fail))
            ZeroStamp (address-> Vector 0 N)
          Vector))

\\ Shen/Scheme uses byte streams; S43.1 exposes these hooks publicly.
(define char-stream? S -> false)

(define read-unit-string
  _ -> (error "character input streams are not supported~%"))

(define write-string
  _ _ -> (error "character output streams are not supported~%"))

\* Shen 42.0 expands source input+ calls to shen.input-h+, but its
   lambda table still refers to input+ directly. *\

(define input+
  Type Stream -> (shen.input-h+ Type Stream))

\* REPL stdin-EOF handling (fork-specific).

   Canonical Shen loops forever when the REPL's standard input is exhausted:
   the reader hits EOF with an empty buffer, raises "error: empty stream",
   shen.loop catches it, prints it, and recurses -- re-reading EOF endlessly.

   We detect EOF at the input layer (not by string-matching the downstream
   error) and exit cleanly. _scm.*in-repl* is set only for the REPL's extent
   (shen.repl below), so the exit is scoped to REPL command input on
   *stinput*; a program's own (read-byte (stinput)) still gets -1 at EOF.

   Since kernel 42.1 the reader must still process input that reaches EOF
   without a trailing newline (e.g. `printf '(+ 1 2)' | shen-scheme`). So the
   first EOF after pending, not-yet-terminated input is passed through as -1
   (the reader then evaluates the buffered line), and only an EOF with no
   pending input exits. _scm.*repl-pending* tracks whether any non-whitespace
   byte was read since the last line terminator. *\
(define _scm.repl-active?
  -> (trap-error (value _scm.*in-repl*) (/. E false)))

(define _scm.repl-pending?
  -> (trap-error (value _scm.*repl-pending*) (/. E false)))

(define _scm.repl-track-byte
  10 -> (set _scm.*repl-pending* false)
  13 -> (set _scm.*repl-pending* false)
  9 -> skip
  32 -> skip
  _ -> (set _scm.*repl-pending* true))

(define shen.my-read-byte
  Stream -> (let B (read-byte Stream)
              (if (and (_scm.repl-active?)
                       ((foreign scm.eq?) Stream (value *stinput*)))
                  (if (= B -1)
                      (if (_scm.repl-pending?)
                          (do (set _scm.*repl-pending* false) -1)
                          ((foreign scm.exit) 0))
                      (do (_scm.repl-track-byte B) B))
                  B)))

(define shen.repl
  -> (do (set _scm.*in-repl* true)
         (do (set _scm.*repl-pending* false)
             (do (shen.credits) (shen.loop)))))

\* To print location of errors *\

(package shen [scm.error-location scm.raise scm.remember-exception!]

\\ Unwind temporary declarations without discarding Chez condition fields.
(define unwind-types
  E [F _ | Table] -> (do (destroy F) (unwind-types E Table))
  E _ -> ((foreign scm.raise) E))

(define toplevel-display-exception
  E -> (let Saved ((foreign scm.remember-exception!) E)
            Msg (error-to-string E)
            Loc ((foreign scm.error-location) E)
        (if (interactive-error? E Loc Msg)
            (output "~A" Msg)
            (output "Exception in ~A: ~A" Loc Msg))))

(define show-exceptions?
  -> (trap-error (value *show-exceptions*) (/. E false)))

(define interactive-error?
  _ _ _ -> true where (not (show-exceptions?))
  E abort _ -> true
  E shen.string-match _ -> true
  E shen.toplineread_loop "line read aborted" -> true
  E shen.f_error "aborted" -> true
  E shen.typecheck-and-evaluate "type error" -> true
  E shen.type-error _ -> true
  _ _ _ -> false)

)
