# Restricted managed-array SOR example

This example builds one checked numerical operation on the generic managed-f64 API. It is deliberately separate from `lib/performance`: generic arrays do not contain SOR fields, and the generic loader installs no SOR function or descriptor.

Initialize the generic package first, then the example, using explicit absolute roots:

```scheme
(load "/path/to/shen-scheme/lib/performance/load.ss")
(performance-load "/path/to/shen-scheme/lib/performance")
(load "/path/to/shen-scheme/examples/performance/sor/load.ss")
(performance-sor-load "/path/to/shen-scheme/examples/performance/sor")
```

Load each defining `load.ss` file once. Both initialization procedures are idempotent after success and preserve the caller's typechecking flag after success or exceptions. The example loader rejects initialization before the generic package is available. The explicit roots avoid changing or relying on the caller's working directory.

The ordinary Shen API is:

```
perf.sor-batch-residual Owner Rows Cols Sweeps Omega -> Residual
```

`Owner` has type `perf.f64-array`. The other arguments are declared `number`, but checked helpers enforce exact bounded dimensions/counts and explicit binary64 omega. `usage.shen` is a runnable typed usage definition after initialization:

```shen
(define sor-example.zero-residual
  {number --> number}
  N -> (let Grid (perf.f64-new (* N N) (perf.f64 0))
            Residual (perf.sor-batch-residual Grid N N 10 (perf.f64 1.25))
            Closed (perf.f64-close Grid)
         Residual))
```

For example `(sor-example.zero-residual 5)` returns binary64 zero. The array is resident managed storage across operation calls; there is no C buffer, raw pointer, second runtime or hidden copy per SOR batch.

## Operation and checked domain

The closed descriptor `(sor-residual-v1 row-major binary64 ascending no-contract)` generates an optimized Scheme lambda. This is one restricted operation definition, not a general code generator, optimizer or region DSL. It uses explicit flonum arithmetic, fixnum indices and typed flvector loads/stores at optimize-level3, behind safe optimize-level2 entry validation.

Exact dimensions must be3..256, the array length must equal their product, and the exact sweep count must be0..10000. Omega must be the explicit binary64 value1.25 and every input cell must be in[0,2]. All argument checks finish before mutation. These bounds describe the tested harmonic `u=x+y` solver with zero interior; arbitrary grids in[0,2] can produce values outside that range, and a subsequent checked call then rejects before writing. No general convergence or range invariant is promised for arbitrary input.

The update grouping is `(((up+down)+left)+right)`, followed by `(omega*.25)*neighbors + (1-omega)*old`, ascending sweep/row/column order. After the entire batch completes, a separate scan returns the maximum unscaled discrete Laplacian residual. It does not observe partially updated neighbors during the final sweep.

The running maximum uses a one-cell managed flvector workspace allocated **per operation call**, not a field in the generic array owner. This differs from the historical prototype and requires fresh allocation evidence before making current performance claims. The workspace and array use normal Chez GC-managed storage.

Finite inputs do not by themselves prove arithmetic cannot overflow. Nonfinite execution output closes the owner and raises an execution error after the kernel; no rollback is promised for such execution failures. Argument rejection and execution failure have different mutation contracts. No general NaN/Inf or signed-zero equivalence beyond the bounded solver workload is claimed.

## Tests and application

`tests/performance/solve.shen` supplies an actual ordinary Shen convergence loop. Shared application helpers initialize the harmonic boundary and zero interior, materialize the complete output, calculate checksum and analytical error norms, verify boundaries/error bounds and close owners. The dynamic baseline uses ordinary Shen boxed loops. The checked region path calls the Shen-facing API; the direct typed control calls the exact same checked implementation, so it is an API-boundary control, not an independent competing algorithm.

Run from the repository root with the current launcher:

```
_build/bin/shen-scheme script tests/performance/generic.shen
_build/bin/shen-scheme script tests/performance/run.shen
```

The generic smoke must run in a separate fresh process. It checks that the SOR API/kernel/descriptor are absent after generic loading. The full suite explicitly loads the example and passes73 checks: the previous68 plus5 example-loader separation/TC controls. The fresh-process generic smoke passes12 checks. The bounded `tests/performance/allocation.shen` control allocates32,160 bytes for100 checked residual calls with the per-call workspace; it makes no speed-comparison claim. Measurement scripts also explicitly load this example and allocate their own residual-probe workspace.

The example uses ordinary foreign wrappers; helpers must be explicitly initialized in both build and run environments for a compatible-module application. No automatic AOT initialization, sealed-module support or general compiler integration is claimed. Historical timing/allocation receipts are described in [the archival results](../../../lib/performance/RESULTS.md); they predate the rebase and this factorization.
