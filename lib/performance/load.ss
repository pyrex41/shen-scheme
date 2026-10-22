;; Load this defining file ONCE, then call performance-load as often as needed.
;; Supply an explicit package directory, independently of caller CWD.
(define performance-package-loaded? #f)
(define (performance-load directory)
 (unless (and (string? directory) (file-exists? (path-build directory "api.shen")))
  (error 'performance-load "expected package directory containing api.shen" directory))
 (if performance-package-loaded?
     'already-loaded
     (let ([caller-tc (kl:value 'shen.*tc*)])
      (dynamic-wind
       (lambda () (void))
       (lambda ()
        (kl:tc '-)
        (parameterize ([optimize-level 2])
         (load (path-build directory "runtime.ss")))
        (kl:load (path-build directory "api.shen"))
        (set! performance-package-loaded? #t)
        'loaded)
       (lambda () (kl:tc (if caller-tc '+ '-)))))))
