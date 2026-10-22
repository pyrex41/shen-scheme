;; Safe release-only measurements using the port's existing native APIs.
(unless (and (equal? (kl:value '*version*) "43.1")
             (equal? (scheme-version) "Chez Scheme Version 10.3.0")
             (= (optimize-level) 2))
 (error 'chez-first "runtime/profile mismatch"))
(load (getenv "CF_CONFIG"))
(define cf-mode (string->symbol (getenv "CF_MODE")))
(define cf-measure? (equal? (getenv "CF_MEASURE") "1"))
(define cf-build? (equal? (getenv "CF_ACTION") "build"))
(define cf-sample (string->number (getenv "CF_SAMPLE")))
(define cf-port (open-output-file (getenv "CF_OUTPUT")))
(define (cf-clock kind)
 (let ([t (current-time kind)]) (+ (* (time-second t) 1000000000) (time-nanosecond t))))
(define (cf-timed fn count)
 (let ([wall (cf-clock 'time-monotonic)] [cpu (cf-clock 'time-process)]
       [alloc (+ (bytes-allocated) (bytes-deallocated))] [gc (collections)]
       [gc-cpu (cf-clock 'time-collector-cpu)] [answer #f])
  (do ([i 0 (fx+ i 1)]) ((fx= i count)) (set! answer (fn)))
  (list (- (cf-clock 'time-monotonic) wall) (- (cf-clock 'time-process) cpu)
        (- (+ (bytes-allocated) (bytes-deallocated)) alloc)
        (- (collections) gc) (- (cf-clock 'time-collector-cpu) gc-cpu) answer)))
(define (cf-row phase reps result)
 (fprintf cf-port "~a,~a,~a,~a,~a,~a,~a,~a,~a,~a\n"
  cf-sample cf-app cf-mode phase reps (car result) (cadr result)
  (list-ref result 2) (list-ref result 3) (list-ref result 4))
 (flush-output-port cf-port))
(display "sample,app,mode,phase,reps,wall_ns,cpu_ns,allocated_bytes,gc_count,gc_cpu_ns\n" cf-port)
(define (cf-call name . args) (apply (eval name) args))
(kl:set '*hush* cf-measure?)
(kl:set '*cf.effects* '())
;; Checking and execution are different operations. Disable typechecking for
;; each application load consistently. Ordinary Shen load includes translation,
;; code compilation/evaluation and metadata/effects; it is not a pure parse timer.
(kl:tc '-)
(define cf-release (cf-call 'kl:shen-scheme.native-compile-profile-options 'release))
(unless (equal? cf-release '(2 0 #f #f #f)) (error 'cf "release settings changed" cf-release))
(printf "CF_BOOTSTRAP cpu_ns=~a allocated_bytes=~a gc_count=~a gc_cpu_ns=~a\n"
 (cf-clock 'time-process)
 (- (+ (bytes-allocated) (bytes-deallocated)) (initial-bytes-allocated))
 (collections) (cf-clock 'time-collector-cpu))
(printf "CF_READY app=~a mode=~a Shen=~a Chez=~a release=~s\n"
 cf-app cf-mode (kl:value '*version*) (scheme-version) cf-release)
(flush-output-port (current-output-port))
(define (cf-build)
 (case cf-mode
  [(dynamic) (void)]
  [(compatible sealed)
   (cf-call 'kl:shen-scheme.compile-module
     (if (eq? cf-mode 'compatible) cf-compatible cf-sealed) cf-object)]
  [(app app-wpo)
   (cf-call 'kl:shen-scheme.build-module-app/emit/options
     cf-app-descriptor cf-module-dir cf-object cf-cache-dir cf-release
     (eq? cf-mode 'app-wpo))]
  [else (error 'cf "unknown mode")]))
(when cf-build?
 (let ([built (cf-timed cf-build 1)])
  (unless (null? (kl:value '*cf.effects*)) (error 'cf "build executed initializers"))
  (when cf-measure? (cf-row 'artifact-build 1 built))
  (let ([port (open-output-file (string-append cf-object ".build-result.ss"))])
   (write (list-ref built 5) port) (newline port) (close-port port)))
 (close-output-port cf-port)
 (printf "CF_BUILD PASS app=~a mode=~a\n" cf-app cf-mode)
 (exit 0))
(define (cf-load)
 (if (eq? cf-mode 'dynamic)
  (for-each kl:load cf-sources)
  (cf-call 'kl:shen-scheme.load-compiled cf-object)))
(let ([loaded (cf-timed cf-load 1)])
 (unless (equal? (kl:value '*cf.effects*) (list (string->symbol cf-app)))
  (error 'cf "initializer effect mismatch" (kl:value '*cf.effects*)))
 (when cf-measure? (cf-row 'load 1 loaded)))
(define cf-entry
 (eval (case (string->symbol cf-app)
  [(interpreter) 'kl:cf.interpreter-request]
  [(cminus) 'kl:cf.cminus-request]
  [(numeric) 'kl:cf.numeric-request])))
(define (cf-request)
 (case (string->symbol cf-app)
  [(interpreter) (cf-entry 100)]
  [(cminus) (cf-entry cf-parser-input)]
  [(numeric) (cf-entry 20 0.0001 2000)]))
;; Fixed request controls are checked before any application call. Keeping the
;; numeric workload ordinary Shen does not justify accepting invalid controls.
(unless (and (exact? 20) (<= 3 20 1000) (flonum? 0.0001)
             (> 0.0001 0.0) (< 0.0001 +inf.0) (<= 1 2000 10000))
 (error 'cf "invalid numeric controls"))
(define cf-verified-cells 0)
(define cf-bits (make-bytevector 8))
(define (cf-verify result)
 (case (string->symbol cf-app)
  [(interpreter) (unless (= result 100) (error 'cf "interpreter output" result))]
  [(cminus) (unless (equal? result cf-parser-expected) (error 'cf "parser AST" result))]
  [(numeric)
   (unless (and (list? result) (= (length result) 3)
                (vector? (car result)) (= (vector-length (car result)) 400)
                (= (cadr result) cf-expected-sweeps))
    (error 'cf "numeric result shape/sweeps" result))
   (do ([i 0 (fx+ i 1)]) ((fx= i 400))
    (let ([value (vector-ref (car result) i)])
     (bytevector-ieee-double-native-set! cf-bits 0 value)
     (unless (= (bytevector-u64-native-ref cf-bits 0)
                (bytevector-u64-ref cf-expected-grid (* i 8) (endianness little)))
      (error 'cf "grid binary64 mismatch" i value
       (bytevector-ieee-double-ref cf-expected-grid (* i 8) (endianness little))
       (cadr result) (caddr result)))
     (set! cf-verified-cells (+ cf-verified-cells 1))))
   (unless (and (= (caddr result) cf-expected-residual) (<= (caddr result) 0.0001))
    (error 'cf "stopping residual/convergence mismatch"))
   (do ([i 0 (fx+ i 1)]) ((fx= i 20))
    (do ([j 0 (fx+ j 1)]) ((fx= j 20))
     (let* ([x (/ (* j 1.0) 19)] [y (/ (* i 1.0) 19)]
            [actual (vector-ref (car result) (+ (* i 20) j))])
      (unless (< (abs (- actual (- (* x x) (* y y)))) 0.01)
       (error 'cf "analytical solution error bound" i j)))))]))
;; Reject invalid fixed request controls before unsafe assumptions; all code in
;; this study stays at safe optimize2. Public workload functions are benchmark
;; application code, not a new unchecked foreign numeric API.
(unless (and (= cf-reps (max 1 cf-reps)) (<= cf-reps 1000)) (error 'cf "repetition bound"))
(collect)
(let ([first (cf-timed cf-request 1)])
 (cf-verify (list-ref first 5))
 (when cf-measure? (cf-row 'first 1 first)))
(let ([warm (cf-timed cf-request 1)]) (cf-verify (list-ref warm 5)))
(let ([repeated (cf-timed cf-request cf-reps)])
 (cf-verify (list-ref repeated 5))
 (when cf-measure? (cf-row 'repeated cf-reps repeated)))
;; Deliberate semantic boundary: public replacement is always installed, but
;; sealed/application internal calls retain their compiled local binding.
(unless (= (cf-call 'kl:cf.binding-caller 5) 6) (error 'cf "binding guard before"))
(kl:eval '(define cf.rebinding X -> (+ X 100)))
(unless (= (cf-call 'kl:cf.rebinding 5) 105) (error 'cf "public redefinition failed"))
(unless (= (cf-call 'kl:cf.binding-caller 5)
           (if (memq cf-mode '(dynamic compatible)) 105 6))
 (error 'cf "binding mode semantic mismatch"))
(unless (equal? (kl:value '*cf.effects*) (list (string->symbol cf-app)))
 (error 'cf "execution changed initializer effects"))
(close-output-port cf-port)
(printf "CF_VALIDATION PASS app=~a mode=~a cells=~a\n" cf-app cf-mode cf-verified-cells)
