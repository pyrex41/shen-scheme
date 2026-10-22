;; Load this defining file once, after lib/performance/load.ss. Explicit roots
;; avoid changing the working directory or guessing a repository installation.
(define performance-sor-example-loaded? #f)
(define (performance-sor-load directory)
 (unless (guard (e [else #f]) performance-package-loaded?)
  (error 'performance-sor-load "load the generic performance package first"))
 (unless (and (string? directory) (file-exists? (path-build directory "api.shen")))
  (error 'performance-sor-load "expected SOR example directory containing api.shen" directory))
 (if performance-sor-example-loaded?
     'already-loaded
     (let ([caller-tc (kl:value 'shen.*tc*)])
      (dynamic-wind
       (lambda () (void))
       (lambda ()
        (kl:tc '-)
        (parameterize ([optimize-level 2])
         (load (path-build directory "regions.ss"))
         (load (path-build directory "runtime.ss")))
        (kl:load (path-build directory "api.shen"))
        (set! performance-sor-example-loaded? #t)
        'loaded)
       (lambda () (kl:tc (if caller-tc '+ '-)))))))
