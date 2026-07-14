\\ Stage-1 build: a kernel-only shen-scheme (no standard library) used only as
\\ the host for scripts/gen-stlib.shen, which needs to register Tarver's StLib
\\ macros without colliding with an existing standard library. Identical to
\\ do-build.shen except *build-stage1* drops stlib from the compile.

(package shen []

(define process-application
  [F | X] Types -> (let ArityF (arity F)
                        N (length X)
                        (cases (element? [F | X] Types)           [F | X]
                               (shen-call? F)                     [F | X]
                               (foreign? [F | X])                 (unpack-foreign [F | X])
                               (fn-call? [F | X])                 (fn-call [F | X])
                               (zero-place? [F | X])              [F | X]
                               (undefined-f? F ArityF)            (simple-curry [[fn F] | X])
                               (variable? F)                      (simple-curry [F | X])
                               (application? F)                   (simple-curry [F | X])
                               (partial-application*? F ArityF N) (lambda-function [F | X] (- ArityF N))
                               (overapplication? F ArityF N)      (simple-curry [F | X])
                               true                               [F | X])))

)

(set _scm.*build-stage1* true)

(load "scripts/build.shen")

(build program "shen-scheme.scm")
