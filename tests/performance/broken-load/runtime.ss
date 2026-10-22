;; Intentional loader-failure fixture; never imported by the real package.
(kl:tc '-)
(error 'performance-load-test "intentional failure")
