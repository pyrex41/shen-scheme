\\ Restricted example API; the generic package does not install this operation.
(tc -)
(define perf.sor-batch-residual Owner Rows Cols Sweeps Omega ->
 ((foreign scm.performance-sor-batch-residual) Owner Rows Cols Sweeps Omega))
(declare perf.sor-batch-residual [perf.f64-array --> [number --> [number --> [number --> [number --> number]]]]])
