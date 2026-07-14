\\ REPL driver for regenerating kl/stlib.kl from Tarver's Lib/StLib sources.
\\ Pipe this to a KERNEL-ONLY stage-1 shen-scheme on stdin (see `make gen-stlib`);
\\ it MUST run through the REPL, not `script`, because the `(foreign scm.)` escape
\\ used to wrap eval-kl only compiles on the REPL's path.
\\
\\ It loads the helpers (scripts/gen-stlib-lib.shen), wraps eval-kl to record every
\\ compiled defun, loads Lib/StLib/install.shen (hushed) through the kernel's own
\\ loader so macros/datatypes/types register as real side effects, then g2-run
\\ writes the captured defuns + reconstructed registrations to kl/stlib.kl.
(load "scripts/gen-stlib-lib.shen")
((foreign scm.) "(define _cap (quote ()))")
((foreign scm.) "(define _orig kl:eval-kl)")
((foreign scm.) "(set! kl:eval-kl (lambda (f) (set! _cap (cons f _cap)) (_orig f)))")
(set *hush* true)
(cd "S41.2-refresh/S41/Lib/StLib/")
(load "install.shen")
(cd "")
(set *hush* false)
((foreign scm.) "(set! kl:eval-kl _orig)")
(g2-run ((foreign scm.reverse) ((foreign scm.) "_cap")))
