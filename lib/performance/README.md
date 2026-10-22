# Managed binary64 arrays for Shen/Chez

This optional package provides checked binary64 arrays backed by Chez-managed flvectors. It installs only storage, ownership and conversion APIs. It does not install a numerical kernel, SOR descriptor, compiler optimization or foreign-memory dependency. Chez10.3 or later with flvector primitives is required; C/Lua libraries are not used.

Load the defining Scheme file once, then initialize with an explicit package root:

```scheme
(load "/path/to/shen-scheme/lib/performance/load.ss")
(performance-load "/path/to/shen-scheme/lib/performance")
```

Sibling loading is independent of the caller's working directory. `performance-load` is idempotent after success and preserves existing owner records. It restores the caller's typechecking flag after success or exceptions. Loading `load.ss` itself again resets its defining state and is unsupported with live owners; call `performance-load` again instead.

## Ordinary Shen API

```shen
(define array-example
  {number --> number}
  N -> (let A (perf.f64-new N (perf.f64 0))
            Set (perf.f64-set A 0 (perf.f64 2))
            Value (perf.f64-ref A 0)
            Closed (perf.f64-close A)
         Value))
```

This example requires N>=1; runtime checks reject other indices. `perf.f64` is an explicit conversion: finite flonums pass through and exact integers in[-2^53,2^53] convert exactly. Larger integers, rationals, complex values, NaN and infinities reject. Shen's reader can normalize `0.0` to an exact integer; `(perf.f64 0)` supplies an explicit binary64 zero. No `number` declaration silently narrows a number.

| Function | Contract |
|---|---|
| `perf.f64 Value` | Explicit bounded conversion described above |
| `perf.f64-new N Value` | New owner; exact length0..1048576; Value must already be a finite binary64 flonum |
| `perf.f64-length Owner` | Length of a live owner |
| `perf.f64-ref Owner I` | Checked zero-based exact index |
| `perf.f64-set Owner I Value` | Checked index and finite binary64 value; returns owner |
| `perf.f64-copy Destination Source` | Distinct live owners of identical length; returns destination |
| `perf.f64-close Owner` | Idempotently revoke owner access; memory is reclaimed by GC |
| `perf.f64-import Vector` | Import raw zero-based abstract-vector cells, without a length header; validate every value before copying |
| `perf.f64-export Owner` | Fresh raw zero-based abstract vector, without a length header |
| `perf.f64-from-vector Vector` | Import a standard one-based Shen vector with its length header at index0 |
| `perf.f64-to-vector Owner` | Fresh standard one-based Shen vector with a length header |

Owners have the opaque declared type `perf.f64-array`. Raw abstract-vector boundaries use opaque `perf.absvector`; standard vector converters use `(vector number)`. These declarations permit ordinary tc+ callers and catch owner/string mistakes. Machine guards remain necessary because Shen `number` includes more than binary64. Raw abstract-vector import is primarily for untyped/foreign callers; standard typed Shen code should use the standard-vector converters.

There are no public mutable views sharing storage. Export copies the values. Copy rejects identical owners even at zero length, and any alias to a closed owner rejects subsequent accesses. Invalid shape/index/value/alias arguments reject before writes. Records and helper identifiers are private implementation conventions, not a sandbox against an adversarial Scheme program. Generic owners contain only managed storage and length; they carry no example-specific reduction workspace.

## Numerical examples and compilation

The separately loaded [SOR example](../../examples/performance/sor/README.md) demonstrates a restricted typed numerical operation and ordinary Shen orchestration. Loading this generic package does not install its API or kernels. A fresh-process generic-only test checks that separation.

The API consists of ordinary Shen foreign wrappers plus trusted declarations. Target runtimes must initialize the Scheme helper before calling the API. There is no automatic AOT loader, general region DSL, sealed-module intrinsic or new compiler representation rule. Compatible-module use requires explicit helper initialization during both compilation and execution; use the [qualified native-module example](../../examples/performance/native/README.md). Generic loading alone does not make arbitrary foreign calls valid in every sealed context.

From the repository root, run the generic-only fresh-process smoke with the current built launcher:

```
_build/bin/shen-scheme script tests/performance/generic.shen
```

The full example suite is `tests/performance/run.shen`; it explicitly loads the example. [RESULTS.md](RESULTS.md) identifies historical pre-rebase measurements, which do not qualify current refactored code.
