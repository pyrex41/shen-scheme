;; Restricted operation definition, not a general-purpose compiler or a claim
;; that Shen's number type is binary64. The descriptor is a closed vocabulary.
(define (performance-region-form descriptor)
 (unless (equal? descriptor '(sor-residual-v1 row-major binary64 ascending no-contract))
  (error 'performance-region-form "unsupported region definition" descriptor))
 '(lambda (grid scratch rows cols sweeps omega)
   (let ([wm4 (fl* omega 0.25)] [om (fl- 1.0 omega)]
         [row-limit (fx* (fx- rows 1) cols)])
    (do ([s 0 (fx+ s 1)]) ((fx= s sweeps))
     (do ([row cols (fx+ row cols)]) ((fx= row row-limit))
      (let loop ([index (fx+ row 1)] [left (flvector-ref grid row)])
       (unless (fx= index (fx- (fx+ row cols) 1))
        (let* ([neighbors (fl+ (fl+ (fl+ (flvector-ref grid (fx- index cols))
                                        (flvector-ref grid (fx+ index cols))) left)
                                   (flvector-ref grid (fx+ index 1)))]
               [value (fl+ (fl* wm4 neighbors) (fl* om (flvector-ref grid index)))])
         (flvector-set! grid index value)
         (loop (fx+ index 1) value))))))
    ;; The one-cell managed typed reduction state avoids a boxed loop-carried
    ;; maximum. Residual scans run only after the entire batch completes.
    (flvector-set! scratch 0 0.0)
    (do ([row cols (fx+ row cols)]) ((fx= row row-limit))
     (do ([index (fx+ row 1) (fx+ index 1)]) ((fx= index (fx- (fx+ row cols) 1)))
      (let* ([sum (fl+ (fl+ (fl+ (flvector-ref grid (fx- index cols))
                                 (flvector-ref grid (fx+ index cols)))
                            (flvector-ref grid (fx- index 1)))
                       (flvector-ref grid (fx+ index 1)))]
             [residual (flabs (fl- (fl* 4.0 (flvector-ref grid index)) sum))])
       (flvector-set! scratch 0
        (flmax (flvector-ref scratch 0) residual)))))
    (flvector-ref scratch 0))))
(define performance-sor-kernel
 (parameterize ([optimize-level 3] [debug-level 0])
  (eval (performance-region-form '(sor-residual-v1 row-major binary64 ascending no-contract)))))
;; Trusted opt3 validators still check every cell before/after execution. Inline
;; typed comparisons keep values unboxed on their success path; failure returns
;; #f to the safe public entry instead of passing a boxed cell to a helper.
(define performance-sor-input-valid?
 (parameterize ([optimize-level 3])
  (eval '(lambda (grid n)
   (let loop ([i 0])
    (or (fx= i n)
        (let ([x (flvector-ref grid i)])
         (and (fl>=? x 0.0) (fl<=? x 2.0) (loop (fx+ i 1))))))))))
(define performance-sor-output-finite?
 (parameterize ([optimize-level 3])
  (eval '(lambda (grid n)
   (let loop ([i 0])
    (or (fx= i n)
        (let ([x (flvector-ref grid i)])
         (and (fl=? x x) (not (fl=? x +inf.0)) (not (fl=? x -inf.0))
              (loop (fx+ i 1))))))))))
