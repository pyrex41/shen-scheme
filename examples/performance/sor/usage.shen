\\ Load the generic package and this example's Scheme helper first, as shown in
\\ README.md. This ordinary typed Shen example uses explicit binary64 values.
(define sor-example.zero-residual
 {number --> number}
 N -> (let Grid (perf.f64-new (* N N) (perf.f64 0))
           Residual (perf.sor-batch-residual Grid N N 10 (perf.f64 1.25))
           Closed (perf.f64-close Grid)
        Residual))
