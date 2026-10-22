\\ Explicit managed binary64 region API. These definitions are ordinary Shen;
\\ no number type declaration silently narrows an exact integer to binary64.
(tc -)
(define perf.f64-new N Value -> ((foreign scm.performance-f64-create) N Value))
(define perf.f64-close Owner -> ((foreign scm.performance-f64-close!) Owner))
(define perf.f64-length Owner -> ((foreign scm.performance-f64-length) Owner))
(define perf.f64-ref Owner I -> ((foreign scm.performance-f64-ref) Owner I))
(define perf.f64-set Owner I Value -> ((foreign scm.performance-f64-set!) Owner I Value))
(define perf.f64-copy Destination Source -> ((foreign scm.performance-f64-copy!) Destination Source))
(define perf.f64-import Vector -> ((foreign scm.performance-f64-import) Vector))
(define perf.f64-export Owner -> ((foreign scm.performance-f64-export) Owner))
(define perf.f64 Value -> ((foreign scm.performance-f64) Value))
(define perf.f64-from-vector Vector -> ((foreign scm.performance-f64-from-vector) Vector))
(define perf.f64-to-vector Owner -> ((foreign scm.performance-f64-to-vector) Owner))
\\ Trusted boundary declarations describe ordinary Shen values. number stays
\\ broader than binary64; the checked helper enforces machine representation.
(declare perf.f64 [number --> number])
(declare perf.f64-new [number --> [number --> perf.f64-array]])
(declare perf.f64-close [perf.f64-array --> perf.f64-array])
(declare perf.f64-length [perf.f64-array --> number])
(declare perf.f64-ref [perf.f64-array --> [number --> number]])
(declare perf.f64-set [perf.f64-array --> [number --> [number --> perf.f64-array]]])
(declare perf.f64-copy [perf.f64-array --> [perf.f64-array --> perf.f64-array]])
\\ Raw abstract-vector storage has no standard-vector length stamp; keep its
\\ boundary opaque and validate its actual representation at runtime.
(declare perf.f64-import [perf.absvector --> perf.f64-array])
(declare perf.f64-export [perf.f64-array --> perf.absvector])
(declare perf.f64-from-vector [[vector number] --> perf.f64-array])
(declare perf.f64-to-vector [perf.f64-array --> [vector number]])
