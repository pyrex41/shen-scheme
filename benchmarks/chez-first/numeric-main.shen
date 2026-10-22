(tc -)
\\ Pure Shen complete harmonic SOR solve: init, sweeps, residual, stopping,
\\ complete abstract-vector result and summary. No foreign numerical kernel.
(define cf.numeric-request
  N Tolerance Cap ->
    (let G (absvector (* N N))
         _ (cf.init G N 0 0)
      (cf.solve G N Tolerance Cap 0 (cf.residual G N 1 1 0.0))))
(define cf.init
  G N I J -> G where (= I N)
  G N I J -> (cf.init G N (+ I 1) 0) where (= J N)
  G N I J ->
    (let K (+ (* I N) J)
         X (/ (* J 1.0) (- N 1))
         Y (/ (* I 1.0) (- N 1))
         V (if (or (= I 0) (= J 0) (= I (- N 1)) (= J (- N 1)))
               (- (* X X) (* Y Y)) 0.0)
      (do (address-> G K V) (cf.init G N I (+ J 1)))))
(define cf.solve
  G N Tolerance Cap Sweeps Residual -> [G Sweeps Residual]
    where (or (<= Residual Tolerance) (= Sweeps Cap))
  G N Tolerance Cap Sweeps Residual ->
    (let Count (if (> (+ Sweeps 10) Cap) (- Cap Sweeps) 10)
         _ (cf.sweeps G N Count)
         Next (cf.residual G N 1 1 0.0)
      (cf.solve G N Tolerance Cap (+ Sweeps Count) Next)))
(define cf.sweeps
  G N 0 -> G
  G N S -> (do (cf.rows G N 1) (cf.sweeps G N (- S 1))))
(define cf.rows
  G N I -> G where (= I (- N 1))
  G N I -> (do (cf.cols G N I 1) (cf.rows G N (+ I 1))))
(define cf.cols
  G N I J -> G where (= J (- N 1))
  G N I J ->
    (let K (+ (* I N) J)
         UpDown (+ (<-address G (- K N)) (<-address G (+ K N)))
         WithLeft (+ UpDown (<-address G (- K 1)))
         Neighbors (+ WithLeft (<-address G (+ K 1)))
         New (+ (* (* 1.25 0.25) Neighbors) (* -0.25 (<-address G K)))
      (do (address-> G K New) (cf.cols G N I (+ J 1)))))
(define cf.residual
  G N I J Maximum -> Maximum where (= I (- N 1))
  G N I J Maximum -> (cf.residual G N (+ I 1) 1 Maximum)
    where (= J (- N 1))
  G N I J Maximum ->
    (let K (+ (* I N) J)
         UpDown (+ (<-address G (- K N)) (<-address G (+ K N)))
         WithLeft (+ UpDown (<-address G (- K 1)))
         Neighbors (+ WithLeft (<-address G (+ K 1)))
         Delta (- Neighbors (* 4.0 (<-address G K)))
         Abs (if (< Delta 0.0) (- 0.0 Delta) Delta)
         Next (if (> Abs Maximum) Abs Maximum)
      (cf.residual G N I (+ J 1) Next)))
(define cf.rebinding
  X -> (+ X 1))
(define cf.binding-caller
  X -> (cf.rebinding X))
(set *cf.effects* [numeric | (value *cf.effects*)])
