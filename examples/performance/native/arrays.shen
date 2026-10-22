\\ The generic API must be initialized in the compiling and loading processes.
(define perf-example.native-array-demo
  {number --> number}
  N -> (let A (perf.f64-new N (perf.f64 2))
            B (perf.f64-new N (perf.f64 0))
            Copy (perf.f64-copy B A)
            Value (perf.f64-ref B 0)
         (do (perf.f64-close A)
             (do (perf.f64-close B) Value))))
