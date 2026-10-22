(tc -)
(define perf-test.solve
 Mode Rows Cols Tolerance ->
 (let State ((foreign scm.performance-test-open) Mode Rows Cols)
      Residual ((foreign scm.performance-test-advance) State Rows Cols 0)
  (perf-test.loop State Rows Cols Tolerance 0 Residual)))
(define perf-test.loop
 State Rows Cols Tolerance Sweeps Residual ->
 (if (or (<= Residual Tolerance) (= Sweeps 20000))
     ((foreign scm.performance-test-finish) State Rows Cols Sweeps Residual Tolerance)
     (let Next ((foreign scm.performance-test-advance) State Rows Cols 10)
      (perf-test.loop State Rows Cols Tolerance (+ Sweeps 10) Next))))
