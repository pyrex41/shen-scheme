;; Bounded allocation regression control, not an accepted timing comparison.
(load "lib/performance/load.ss")
(performance-load (path-build (current-directory) "lib/performance"))
(load "examples/performance/sor/load.ss")
(performance-sor-load (path-build (current-directory) "examples/performance/sor"))
(let* ([owner (performance-f64-create 10000 0.0)] [before (statistics)])
 (do ([i 0 (+ i 1)]) ((= i 100))
  (unless (fl=? 0.0 (performance-sor-batch-residual owner 100 100 0 1.25))
   (error 'allocation-test "zero grid residual differs")))
 (let ([allocated (- (sstats-bytes (statistics)) (sstats-bytes before))])
  ;; A per-interior-cell box would exceed15MB across these scans. This generous
  ;; control includes the checked API and its fresh managed workspace per call.
  (unless (<= 0 allocated 1000000) (error 'allocation-test "allocation exceeds bounded regression limit" allocated))
  (printf "PERFORMANCE_ALLOCATION PASS ~s bytes for 100 checked residual calls\n" allocated))
 (performance-f64-close! owner))
