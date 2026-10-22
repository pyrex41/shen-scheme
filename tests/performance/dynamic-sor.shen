\\ Ordinary Shen 43.1 successive over-relaxation on a flat, zero-based
\\ abstract vector. The caller validates storage, dimensions, finite binary64
\\ cells/Omega, and a nonnegative sweep count. Boundaries remain untouched.
\\ Grouping matches NIST SciMark: (((up + down) + left) + right), followed
\\ by (Omega * .25) * neighbors + (1 - Omega) * old. Return the mutated grid.
(tc -)

(define sq.sor
  G Rows Cols Sweeps Omega ->
    (sq.sweeps G Rows Cols Sweeps (* Omega 0.25) (- 1 Omega)))

(define sq.sweeps
  G Rows Cols 0 WM4 OneMinus -> G
  G Rows Cols Sweeps WM4 OneMinus ->
    (do (sq.rows G Rows Cols WM4 OneMinus 1)
        (sq.sweeps G Rows Cols (- Sweeps 1) WM4 OneMinus)))

(define sq.rows
  G Rows Cols WM4 OneMinus I -> G where (= I (- Rows 1))
  G Rows Cols WM4 OneMinus I ->
    (do (sq.columns G Cols WM4 OneMinus (* I Cols) 1)
        (sq.rows G Rows Cols WM4 OneMinus (+ I 1))))

(define sq.columns
  G Cols WM4 OneMinus Base J -> G where (= J (- Cols 1))
  G Cols WM4 OneMinus Base J ->
    (let Index (+ Base J)
         Vertical (+ (<-address G (- Index Cols))
                     (<-address G (+ Index Cols)))
         WithLeft (+ Vertical (<-address G (- Index 1)))
         Neighbors (+ WithLeft (<-address G (+ Index 1)))
         Weighted (* WM4 Neighbors)
         OldWeighted (* OneMinus (<-address G Index))
      (do (address-> G Index (+ Weighted OldWeighted))
          (sq.columns G Cols WM4 OneMinus Base (+ J 1)))))

(define sq.lua-pipeline
  G Rows Cols Sweeps Omega ->
    ((foreign scm.sor-lua-pipeline!) G Rows Cols Sweeps Omega))

(define sq.lua-step
  G Rows Cols Sweeps Omega ->
    ((foreign scm.sor-lua-step!) G Rows Cols Sweeps Omega))

(define sq.chez-pipeline
  G Rows Cols Sweeps Omega ->
    ((foreign scm.sor-chez-pipeline!) G Rows Cols Sweeps Omega))

(define sq.chez-boxed
  G Rows Cols Sweeps Omega ->
    ((foreign scm.sor-chez-boxed!) G Rows Cols Sweeps Omega))
