;; Restricted SOR example on the separately loaded generic managed-f64 API.
;; Finite constructor/setter/import preserve finite storage. Solver-specific
;; bounds describe the tested harmonic workload; finite output is checked after execution.
;; General finite f64 cells alone do not guarantee arithmetic cannot overflow.
(define (performance-sor-validate owner rows cols sweeps omega)
 (performance-live 'performance-sor-batch-residual owner)
 (for-each (lambda (n)
   (unless (and (fixnum? n) (<= 3 n 256))
    (error 'performance-sor-batch-residual "dimensions must be exact 3..256")))
  (list rows cols))
 (unless (= (performance-length owner) (fx* rows cols))
  (error 'performance-sor-batch-residual "shape differs from array length"))
 (unless (and (fixnum? sweeps) (<= 0 sweeps 10000))
  (error 'performance-sor-batch-residual "sweeps must be exact 0..10000"))
 (performance-binary64 'performance-sor-batch-residual omega)
 (unless (fl=? omega 1.25)
  (error 'performance-sor-batch-residual "prototype requires explicit omega 1.25"))
 (unless (performance-sor-input-valid? (performance-storage owner) (performance-length owner))
  (error 'performance-sor-batch-residual "solver region requires cells in [0,2]"))
 #t)

(define (performance-sor-batch-residual owner rows cols sweeps omega)
 (performance-sor-validate owner rows cols sweeps omega)
 (let ([answer (performance-sor-kernel (performance-storage owner) (make-flvector 1 0.0)
                         rows cols sweeps omega)])
  ;; Numeric overflow is an execution failure, distinct from pre-write argument
  ;; rejection. Close the owner on failure; no invalid values can be reused.
  (let ([grid (performance-storage owner)])
   (guard (e [else (performance-f64-close! owner) (raise e)])
    (performance-binary64 'performance-sor-batch-residual answer)
    (unless (performance-sor-output-finite? grid (performance-length owner))
     (error 'performance-sor-batch-residual "nonfinite execution output"))))
  answer))
