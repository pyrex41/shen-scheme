\* Copyright (c) 2012-2021 Bruno Deferrari.  All rights reserved.
   BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\* Generate kl/stlib.kl from Mark Tarver's Lib/StLib .shen sources.

   Tarver's S41.2 refresh unbundles the standard library: it ships as lazy
   .shen sources under Lib/StLib rather than a precompiled stlib.kl. This
   script reproduces, from those sources, the flat KLambda that shen-scheme's
   normal kl/stlib.kl -> compiled/stlib.scm pipeline expects.

   Mechanism (must run in a KERNEL-ONLY refresh shen-scheme -- see
   scripts/do-build-stage1.shen -- so registering StLib's own macros does not
   collide with an existing standard library):

   - Each source file is processed in upstream install.shen order.
   - `read-file` package-expands and macroexpands each form (using macros
     registered by earlier files), so package-local names are resolved and
     macro sugar (Maths/Strings/Vectors macros) is expanded in function bodies.
   - Macro/support files (Maths/macros.shen etc.) are EVALUATED wholesale so
     their macros + expansion helpers are registered for the files that follow;
     they emit nothing themselves.
   - Function files emit: `define` -> defun (via shen.shendef->kldef, arity
     recorded), `declare` -> declare (types), `set` -> global initialiser.
   - A trailing (shen.initialise-arity-table ...) registers every stdlib
     function's arity (shen-scheme does not derive arity from a bare defun).

   Not yet reproduced (see KERNEL-PROVENANCE.md): the user-facing reader macros
   (implicit-tolerance sqrt/log/expt, for-loops, string s-op sugar) and the
   (datatype ...) typechecker rules. Stdlib functions themselves are fully
   expanded and callable; the macros only add optional-argument sugar. *\

(set gen-stlib-dir "S41.2-refresh/S41/Lib/StLib/")

\* [relative-path eval-whole?] in upstream install.shen order. *\
(set gen-stlib-files
     [["Symbols/symbols1.shen" false] ["Symbols/symbols2.shen" false]
      ["Maths/macros.shen" true] ["Maths/maths.shen" false]
      ["Maths/rationals.dtype" false] ["Maths/rationals.shen" false]
      ["Maths/complex.dtype" false] ["Maths/complex.shen" false]
      ["Maths/numerals.dtype" false] ["Maths/numerals.shen" false]
      ["Lists/lists.shen" false]
      ["Strings/macros.shen" true] ["Strings/strings.shen" false]
      ["Strings/smart.shen" false]
      ["Vectors/macros.shen" true]
      ["IO/prettyprint.shen" false] ["IO/delete-file.shen" false]
      ["IO/files.shen" false]
      ["Tuples/tuples.shen" false]])

(set gen-stlib-arities [])

(define gen-stlib-emit
  Form Out -> (pr (make-string "~R~%~%" Form) Out))

(define gen-stlib-record-arity
  [defun Name Args _] -> (set gen-stlib-arities [Name (length Args) | (value gen-stlib-arities)])
  _ -> skip)

(define gen-stlib-proc-form
  [define Name | Rules] Out -> (let KL (shen.shendef->kldef Name Rules)
                                    _ (gen-stlib-record-arity KL)
                                    (gen-stlib-emit KL Out))
  [declare Name Type] Out -> (gen-stlib-emit [declare Name Type] Out)
  [set Var Val] Out -> (gen-stlib-emit [set Var Val] Out)
  _ Out -> skip)

(define gen-stlib-proc-file
  Path true Out -> (do (map (/. Form (eval Form)) (read-file Path)) skip)
  Path false Out -> (do (map (/. Form (gen-stlib-proc-form Form Out)) (read-file Path)) skip))

(define gen-stlib-arity-list
  [] -> []
  [X | Xs] -> [cons X (gen-stlib-arity-list Xs)])

(define gen-stlib
  -> (let Out (open "kl/stlib.kl" out)
          _ (map (/. FE (gen-stlib-proc-file (@s (value gen-stlib-dir) (hd FE)) (hd (tl FE)) Out))
                 (value gen-stlib-files))
          AT (gen-stlib-emit [shen.initialise-arity-table (gen-stlib-arity-list (value gen-stlib-arities))] Out)
          C (close Out)
          (output "Generated kl/stlib.kl (~A functions).~%"
                  (/ (length (value gen-stlib-arities)) 2))))

(set *home-directory* "")
(gen-stlib)
