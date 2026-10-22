;; Application fixture shared by every kernel mode. Helpers safe opt2; actual
;; Shen request/loop drives convergence. No C/Lua/foreign-pointer dependency.
(define performance-test-active #f)
(define (performance-test-open mode rows cols)
 (unless (memq mode '(dynamic region typed-control)) (error 'test-open "unknown mode"))
 (let* ([n (* rows cols)] [boxed (make-vector n 0.0)])
  (do ([i 0 (+ i 1)]) ((= i rows))
   (do ([j 0 (+ j 1)]) ((= j cols))
    (when (or (= i 0) (= j 0) (= i (- rows 1)) (= j (- cols 1)))
     (vector-set! boxed (+ (* i cols) j)
      (fl+ (fl/ (fixnum->flonum i) (fixnum->flonum (- rows 1)))
           (fl/ (fixnum->flonum j) (fixnum->flonum (- cols 1))))))))
  (let ([state (vector mode (if (eq? mode 'dynamic) boxed (performance-f64-import boxed)))])
   (set! performance-test-active state) state)))
(define (performance-test-dynamic-residual grid rows cols)
 (let row ([i 1] [maximum 0.0])
  (if (= i (- rows 1)) maximum
   (row (+ i 1)
    (let cell ([j 1] [maximum maximum])
     (if (= j (- cols 1)) maximum
      (let* ([k (+ (* i cols) j)]
             [sum (+ (+ (+ (vector-ref grid (- k cols)) (vector-ref grid (+ k cols)))
                           (vector-ref grid (- k 1))) (vector-ref grid (+ k 1)))]
             [residual (abs (- (* 4.0 (vector-ref grid k)) sum))])
       (cell (+ j 1) (max maximum residual)))))))))
(define (performance-test-advance state rows cols count)
 (let ([storage (vector-ref state 1)])
  (case (vector-ref state 0)
   [(dynamic) (kl:sq.sor storage rows cols count 1.25)
              (performance-test-dynamic-residual storage rows cols)]
   [(region) (kl:perf.sor-batch-residual storage rows cols count 1.25)]
   ;; Strong typed control uses same generated opt3 kernel directly, after the
   ;; identical public validation, plus finite-output validation as region API.
   [(typed-control) (performance-sor-batch-residual storage rows cols count 1.25)])))
(define (performance-test-finish state rows cols sweeps residual tolerance)
 (let* ([storage (vector-ref state 1)]
        [out (if (eq? (vector-ref state 0) 'dynamic) storage (performance-f64-export storage))]
        [sum 0.0] [squares 0.0] [maximum 0.0])
  (unless (<= residual tolerance) (error 'finish "failed convergence"))
  (do ([i 0 (+ i 1)]) ((= i rows))
   (do ([j 0 (+ j 1)]) ((= j cols))
    (let* ([value (vector-ref out (+ (* i cols) j))]
           [exact (fl+ (fl/ (fixnum->flonum i) (fixnum->flonum (- rows 1)))
                       (fl/ (fixnum->flonum j) (fixnum->flonum (- cols 1))))]
           [delta (fl- value exact)])
     (performance-binary64 'finish value)
     (set! sum (fl+ sum value))
     (set! squares (fl+ squares (fl* delta delta)))
     (set! maximum (flmax maximum (flabs delta)))
     (when (or (= i 0) (= j 0) (= i (- rows 1)) (= j (- cols 1)))
      (unless (fl=? value exact) (error 'finish "boundary changed"))))))
  (unless (<= maximum (+ 1e-10 (* tolerance (/ (+ (expt (- rows 1) 2) (expt (- cols 1) 2)) 16.0))))
   (error 'finish "analytical bound failed" maximum))
  (unless (eq? (vector-ref state 0) 'dynamic) (performance-f64-close! storage))
  (set! performance-test-active #f)
  (vector sweeps residual sum (flsqrt (fl/ squares (fixnum->flonum (* rows cols)))) maximum out)))
