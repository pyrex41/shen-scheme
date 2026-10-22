# Managed binary64 regions for Shen/Chez

This prototype provides explicit, checked binary64 arrays backed by Chez's **managed flvectors** and one restricted compiled operation: an in-place row-major SOR batch followed by a residual scan. It requires Chez10.3 or later with flvector primitives. It uses no C library, Lua runtime, external buffers or unmanaged pointers. Shen `number` annotations remain unchanged: exact integers are never silently treated as binary64.

Load the Scheme entry once, then supply an explicit package root:

```scheme
(load "/path/to/shen-scheme/lib/performance/load.ss")
(performance-load "/path/to/shen-scheme/lib/performance")
```

The root makes sibling loading independent of the caller's working directory. The loader restores the caller's typechecking flag after success or an exception; its internal untyped API definitions do not disable typechecking for subsequent user work. The loaded ordinary Shen API is:

| Function | Contract |
|---|---|
| `perf.f64-new N Value` | New managed owner; exact length0..1048576; Value must already be a finite binary64 flonum |
| `perf.f64-length Owner` | Length of a live owner |
| `perf.f64-ref Owner I` | Checked zero-based exact index |
| `perf.f64-set Owner I Value` | Checked index and finite binary64 store; returns owner |
| `perf.f64-import Vector` | Validate every boxed-vector cell before creating/copying managed storage |
| `perf.f64-export Owner` | Fresh boxed abstract vector |
| `perf.f64-copy Destination Source` | Distinct live owners of identical length; returns destination |
| `perf.f64-close Owner` | Idempotently revoke owner access; actual memory is GC-managed |
| `perf.sor-batch-residual Owner Rows Cols Sweeps Omega` | Mutate the complete batch, then return the max unscaled discrete Laplacian residual |

`perf.f64` is an explicit conversion constructor: finite flonums pass through; exact integers in[-2^53,2^53] convert exactly. Larger integers, rationals and complex values reject. For example `(perf.f64-new 100 (perf.f64 0))` works directly in ordinary Shen. `perf.f64-from-vector` and `perf.f64-to-vector` convert standard one-based Shen vectors with their length header at index0; `perf.f64-import`/`export` instead use raw zero-based abstract vectors without a header. These layouts are deliberately distinct.

`performance-load` is idempotent after its first successful call, preserving existing owner records. Load `load.ss` itself only once; reloading that defining file resets its loader state and is unsupported with live owners.

A Shen zero literal may normalize to an exact integer even when written `0.0`. Use `(perf.f64 0)` when constructing a binary64 zero in ordinary Shen. Other exact integers are rejected where binary64 is required. Constructors/imports own their storage; export returns a copy. There are no public views sharing mutable flvector storage. Reusing the same owner as source and destination is rejected, and aliases to a closed owner reject all subsequent accesses. The Scheme helper identifiers are implementation internals, not a sandbox against an adversarial Scheme program.

## Restricted region and numerical domain

`regions.ss` validates the exact closed descriptor `(sor-residual-v1 row-major binary64 ascending no-contract)` and generates an optimized Scheme lambda. It is a restricted operation definition, not a general code generator. The operation uses explicit flonum arithmetic, fixnum index loops and typed flvector loads/stores, compiled at optimize-level3 behind safe optimize-level2 entry validation. It neither changes the Shen compiler nor rewrites generic arithmetic.

The prototype SOR interface is deliberately bounded: exact dimensions3..256, product equal to array length, exact sweeps0..10000, explicit binary64 omega1.25, and input cells in[0,2]. These checks complete before any cell changes. The admitted application is the harmonic `u=x+y` boundary on a unit square with zero interior. That application preserves the tested finite numerical domain across batches. This is not a general convergence guarantee for arbitrary input grids.

Binary64 arithmetic can overflow even for finite inputs. Nonfinite execution results close the owner and raise an execution error after the kernel; they are distinct from argument rejection before writes. A caller must not assume rollback on a numerical execution failure. Inputs outside the bounded cell range or outputs subsequently outside it reject at the next checked call. The operation does not promise general NaN/Inf or signed-zero semantics beyond its admitted finite solver workload.

The update grouping is `(((up+down)+left)+right)` then `(omega*.25)*neighbors + (1-omega)*old`, ascending sweep/row/column order. Residual is scanned **after the entire batch**, not during its final sweep. A managed one-cell reduction array stores the running maximum, exposing typed storage instead of passing a boxed maximum through nested loops. This is a concrete representation choice whose allocation effect must be measured, not inferred from source.

## Compilation and use

The API definitions are ordinary Shen foreign wrappers with trusted public type declarations. Owners have an opaque `perf.f64-array` type; raw zero-based abstract vectors have opaque `perf.absvector` boundary declarations, while standard one-based vectors use `(vector number)`. These types prevent accidental owner/string mixing under tc+; number remains broader than binary64, so machine checks are still required. No proof rule treats a forged Scheme record as a valid owner. Load the Scheme helper in the target runtime before loading/calling those definitions. This prototype supports the normal explicit dynamic/compatible API. It does not add sealed-module declarations, effect metadata, intrinsic lowering or AOT packaging rules; a sealed/AOT application must arrange the same helper initialization in its runtime and use a supported foreign-definition context. Loading the package alone does not make arbitrary foreign calls acceptable in every sealed module.

`tests/performance/solve.shen` is an actual ordinary Shen convergence loop. `application.ss` supplies identical initialization, output copying, checksum/analytical error reductions and owner cleanup for all modes. The dynamic baseline uses ordinary Shen boxed SOR loops; the region uses the checked Shen-facing managed API. The typed control calls the same checked generated Chez implementation directly, measuring the ordinary wrapper boundary without inventing a weaker native competitor. It is an API-overhead control, not an independent algorithm implementation.

Run correctness from the repository root using the current built Shen launcher:

```
_build/bin/shen-scheme script tests/performance/run.shen
```

The suite checks pre-write rejection, closed aliases, exact-vs-binary64 distinctions and full output-grid equality for complete harmonic solves. Performance/true-allocation measurements require a separately granted serial measurement window. Raw artifacts live in `.work/chez-first/numeric/`; no old evidence is overwritten.
