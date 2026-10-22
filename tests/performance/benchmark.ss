(load "lib/performance/load.ss")
(performance-load (path-build (current-directory) "lib/performance"))
(load "examples/performance/sor/load.ss")
(performance-sor-load (path-build (current-directory) "examples/performance/sor"))
(parameterize ([optimize-level 3])
 (kl:load "tests/performance/dynamic-sor.shen")
 (kl:load "tests/performance/solve.shen"))
(parameterize ([optimize-level 2]) (load "tests/performance/application.ss"))
(define (clock kind) (let ([t (current-time kind)]) (+ (* (time-second t) 1000000000) (time-nanosecond t))))
(define sample (string->number (or (getenv "NUMERIC_SAMPLE") "0")))
(define modes '(dynamic region typed-control))
(define rotated (append (list-tail modes (modulo sample 3)) (list-head modes (modulo sample 3))))
(define reference #f)
(for-each
 (lambda (mode)
  (do ([request 0 (+ request 1)]) ((= request 3))
   (let* ([stats (statistics)] [wall (clock 'time-monotonic)] [cpu (clock 'time-process)]
          [result (kl:perf-test.solve mode 100 100 1e-5)]
          [cpu-ns (- (clock 'time-process) cpu)] [wall-ns (- (clock 'time-monotonic) wall)]
          [bytes (- (sstats-bytes (statistics)) (sstats-bytes stats))]
          [gcs (- (sstats-gc-count (statistics)) (sstats-gc-count stats))])
    (unless reference (set! reference result))
    (unless (equal? result reference) (error 'benchmark "full grid mismatch" mode))
    (unless (= (vector-ref result 0) 3470) (error 'benchmark "wrong stopping count"))
    (printf "RESULT ~s ~s ~s ~s ~s ~s ~s ~s\n" mode request wall-ns cpu-ns bytes gcs
      (vector-ref result 0) (vector-ref result 1))
    (flush-output-port (current-output-port))))) rotated)
;; Separate allocation-only residual probe on resident managed storage.
(let* ([owner (performance-f64-create 10000 0.0)] [scratch (make-flvector 1 0.0)]
       [storage (performance-storage owner)] [stats (statistics)])
 (do ([i 0 (+ i 1)]) ((= i 100)) (performance-sor-kernel storage scratch 100 100 0 1.25))
 (printf "RESIDUAL_ALLOC_100 ~s\n" (- (sstats-bytes (statistics)) (sstats-bytes stats)))
 (performance-f64-close! owner))
(printf "NUMERIC_PASS\n")
