\\ Dynamic operators preserve lexical shadowing, currying and evaluation order.
\\ This file runs with the compiler test driver's assert-equal helpers.

(assert-equal
 (_scm.kl->scheme [lambda F [F]])
 [lambda [F] [F]])

(assert-equal
 (_scm.kl->scheme [lambda + [+ 1 2]])
 [lambda [+] [[+ 1] 2]])

(assert-equal
 (eval-kl [let + [lambda X [lambda Y [- X Y]]] [+ 8 3]])
 5)

(assert-equal
 (let F (/. X (/. Y [X Y])) (F 8 3))
 [8 3])

(assert-equal
 (compiler-order-run
  (freeze
   ((compiler-order-mark operator
     (/. X (do (compiler-order-mark applied true)
               (/. Y [X Y]))))
    (compiler-order-mark first 8)
    (compiler-order-mark second 3))))
 [[8 3] [operator first applied second]])

(assert-equal
 (compiler-order-run
  (freeze
   (trap-error
    ((compiler-order-mark operator
      (/. X (do (compiler-order-mark applied true)
                (simple-error "dynamic call stopped"))))
     (compiler-order-mark first 8)
     (compiler-order-mark second 3))
    (/. E stopped))))
 [stopped [operator first applied]])
