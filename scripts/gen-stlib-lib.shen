\* Copyright (c) 2012-2021 Bruno Deferrari.  All rights reserved.
   BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\* Helpers for generating kl/stlib.kl from Tarver's Lib/StLib sources by
   intercepting eval-kl during a genuine install.shen load (see the REPL driver
   in scripts/gen-stlib.shen). This captures the compiled defuns (including
   macro expanders and datatype functions) that the real load produces, then
   reconstructs the arity / macro / systemf / global / type registrations from
   the post-load environment -- the same things the community stlib.kl baked
   into stlib.initialise-{arities,macros,...}, which shen-scheme does not derive
   from a bare defun. These functions contain no `foreign` forms so they can be
   loaded normally; only the driver needs the REPL's compiled `foreign scm.`. *\

(set g2.*out* (value *home-directory*))

(define g2-symname
  X -> (trap-error (hd X) (/. E X)))

(define g2-defun?
  [defun | _] -> true
  _ -> false)

\* Keep only defun forms, in load order. *\
(define g2-only-defuns
  Forms -> (g2-only-defuns-h Forms []))

(define g2-only-defuns-h
  [] Acc -> (reverse Acc)
  [[defun Name Args Body] | Rest] Acc
  -> (g2-only-defuns-h Rest [[defun Name Args Body] | Acc])
  [_ | Rest] Acc -> (g2-only-defuns-h Rest Acc))

\* De-duplicate defuns by name, LAST definition wins (matches load semantics);
   preserve first-seen order otherwise. *\
(define g2-dedup
  Defuns -> (let Names (g2-uniq-names (map (/. D (hd (tl D))) Defuns) [])
                 (map (/. N (g2-last-defun N Defuns)) Names)))

(define g2-uniq-names
  [] Acc -> (reverse Acc)
  [N | Rest] Acc -> (g2-uniq-names Rest Acc) where (element? N Acc)
  [N | Rest] Acc -> (g2-uniq-names Rest [N | Acc]))

(define g2-last-defun
  N Defuns -> (g2-last-defun-h N Defuns []))

(define g2-last-defun-h
  _ [] Found -> Found
  N [[defun N Args Body] | Rest] _ -> (g2-last-defun-h N Rest [defun N Args Body])
  N [_ | Rest] Found -> (g2-last-defun-h N Rest Found))

\* The maths / prettyprint datatype recognisers (name#type) must NOT be baked:
   a persisted print#type would shadow a user/kernel `print` datatype (the
   shen-julia hazard). We drop them here; the datatype's TYPE rules still take
   effect because we re-emit the datatype registration below. *\
(define g2-hashtype?
  Name -> (element? "#" (explode (str Name))))

(define g2-keep-defun?
  [defun Name | _] -> (not (g2-hashtype? Name)))

\* --- registrations reconstructed from post-load environment --- *\

\* stlib macros = everything added to *macros* beyond the kernel's shen.macros. *\
(define g2-stlib-macro-names
  -> (g2-macro-names-h (value *macros*) []))

(define g2-macro-names-h
  [] Acc -> (reverse Acc)
  [[Name | _] | Rest] Acc -> (g2-macro-names-h Rest Acc) where (= Name shen.macros)
  [[Name | _] | Rest] Acc -> (g2-macro-names-h Rest [Name | Acc])
  [_ | Rest] Acc -> (g2-macro-names-h Rest Acc))

(define g2-record-macro-form
  Name -> [shen.record-macro Name [lambda (protect X) [Name (protect X)]]])

\* arity + lambda-table entry for EVERY stdlib function -- externals AND the
   internal helpers (e.g. maths.process-options) that macro expanders call, which
   also need a registered arity to be applied. Derived from the defun arg count. *\
(define g2-arity-regs
  Defuns -> (map (/. D [update-lambda-table (hd (tl D)) (length (hd (tl (tl D))))]) Defuns))

\* systemf mirrors install.shen's tail: adjoin exported fns into shen's
   external-symbols so (external shen) / package resolution match a real install. *\
(define g2-systemf-forms
  Externals -> (map (/. F [systemf F]) Externals))

\* set / declare forms don't pass through eval-kl; harvest them from source. *\
(define g2-source-forms
  Dir Files -> (g2-source-forms-h Dir Files []))

(define g2-source-forms-h
  _ [] Acc -> (reverse Acc)
  Dir [File | Rest] Acc
  -> (g2-source-forms-h Dir Rest
        (append (reverse (g2-set-decl-forms (read-file (cn Dir File)))) Acc)))

(define g2-set-decl-forms
  Forms -> (g2-set-decl-h Forms []))

(define g2-set-decl-h
  [] Acc -> (reverse Acc)
  [[set Var Val] | Rest] Acc -> (g2-set-decl-h Rest [[set Var Val] | Acc])
  [[declare Name Type] | Rest] Acc -> (g2-set-decl-h Rest [[declare Name Type] | Acc])
  [_ | Rest] Acc -> (g2-set-decl-h Rest Acc))

\* --- output --- *\

(define g2-emit
  Form Out -> (pr (make-string "~R~%~%" Form) Out))

(define g2-write
  Defuns Inits Out -> (do (for-each (/. F (g2-emit F Out)) Defuns)
                          (for-each (/. F (g2-emit F Out)) Inits)
                          done))

(define for-each
  _ [] -> done
  F [X | Xs] -> (do (F X) (for-each F Xs)))

(define g2-filter
  _ [] -> []
  F [X | Xs] -> [X | (g2-filter F Xs)] where (F X)
  F [_ | Xs] -> (g2-filter F Xs))

(set g2.*dir* "S41.2-refresh/S41/Lib/StLib/")
(set g2.*source-files*
     ["Symbols/symbols1.shen" "Symbols/symbols2.shen" "Maths/maths.shen"
      "Maths/rationals.dtype" "Maths/rationals.shen" "Maths/complex.dtype"
      "Maths/complex.shen" "Maths/numerals.dtype" "Maths/numerals.shen"
      "Lists/lists.shen" "Strings/strings.shen" "Strings/smart.shen"
      "Vectors/macros.shen" "IO/prettyprint.shen" "IO/delete-file.shen"
      "IO/files.shen" "Tuples/tuples.shen"])

\* Entry point: Captured is the reversed eval-kl capture list. Must run AFTER
   install.shen has loaded (so *macros* / external / arity reflect the stdlib). *\
(define g2-run
  Captured
  -> (let Defuns (g2-filter (function g2-keep-defun?) (g2-dedup (g2-only-defuns Captured)))
          Externals (external stlib)
          MacroForms (map (function g2-record-macro-form) (g2-stlib-macro-names))
          ArityForms (g2-arity-regs Defuns)
          SystemfForms (g2-systemf-forms Externals)
          SetDeclForms (g2-source-forms (value g2.*dir*) (value g2.*source-files*))
          Inits (append SetDeclForms (append MacroForms (append ArityForms SystemfForms)))
          Out (open "kl/stlib.kl" out)
          _ (g2-write Defuns Inits Out)
          C (close Out)
          (output "Generated kl/stlib.kl: ~A defuns, ~A macros, ~A arity regs.~%"
                  (length Defuns) (length MacroForms) (length ArityForms))))
