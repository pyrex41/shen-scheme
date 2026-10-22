(define perf-test.typed-create
 {number --> perf.f64-array}
 N -> (perf.f64-new N (perf.f64 0)))
(define perf-test.typed-step
 {perf.f64-array --> number}
 Owner -> (perf.sor-batch-residual Owner 3 3 0 (perf.f64 1.25)))
