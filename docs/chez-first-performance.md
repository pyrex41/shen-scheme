# Chez-first performance implementation

The useful extension is an explicit typed numerical region inside Chez, backed
by managed flvectors and callable from ordinary Shen. This prototype improves a
complete numerical application without another runtime. Existing native module
and application modes remain the first tools for ordinary symbolic applications.
A small compiler shortcut was tested and rejected rather than included without
an application benefit.

## What is implemented

- [Managed numerical package](../lib/performance/README.md): explicit binary64
  conversion, checked allocation/access/copy, ordinary Shen vector adapters,
  opaque owner type declarations, revocation and idempotent initialization.
- A restricted SOR/residual operation, generated from one closed descriptor.
  Its validated entry runs at Chez optimize-level 2; its bounded typed loops run
  at level 3. Global compiler settings and generic Shen arithmetic are unchanged.
- [Application and semantic checks](../tests/performance/): ordinary Shen drives
  the convergence loop; complete requests include initialization, import,
  computation, convergence decisions, export, checksum/error reductions and
  cleanup. `make test-performance` runs the semantic qualification and is part
  of `make test`.
- [Native-mode application harness](../benchmarks/chez-first/README.md): identical
  application sources across ordinary loading, compatible modules, sealed
  modules, application bundles and WPO bundles. Builds and execution use separate
  fresh processes, with effects, metadata and binding contracts checked.
- Six additional dynamic-call compiler assertions preserve lexical shadowing,
  currying, effect order and early-error behavior. The compiler itself is restored
  to the unchanged fork source.

This is a source-checkout prototype. It does not automatically lower arbitrary
Shen numerical functions, infer machine types from `number`, or introduce a
second backend. The numerical API has an explicitly bounded finite domain; its
README defines the shape, ownership, failure and compilation contracts.

From the repository root, this loads the package and runs a small region through
ordinary Shen. The result is zero for the all-zero 3×3 grid:

```sh
_build/bin/shen-scheme eval -q \
  -e '(eval-kl [scm.load "lib/performance/load.ss"])' \
  -e '(eval-kl [scm.performance-load "lib/performance"])' \
  -e '(let A (perf.f64-new 9 (perf.f64 0)) R (perf.sor-batch-residual A 3 3 10 (perf.f64 1.25)) (do (perf.f64-close A) R))'
```

## Exact baseline and measurement limits

All accepted numerical and native-mode measurements use the unchanged fork
`680e2e95ed9dd0ca6d2f688453efca2a37e50021`, unmodified Shen kernel
`ec16a9fa4fc2e87e2aa336fb1ae30e8ac2266394`, Chez 10.3.0 on native macOS arm64.
The runtime reports Shen 43.1. This is an exact pinned comparison, not a claim
against every implementation or future latest release. The runtime image hash
is `534374a34b76ace7b20b7899eae6ca465e7a4d73a4f1465d245e12dc2f9115f0`.

The baseline is an independent source snapshot with no mutable sibling-cache
links. Its manifest binds tracked source, all 23 kernel KL files, generated
Scheme, launcher, runtime and boot images. The historical build recipe and
failures are retained. The public preparation script now accepts explicit local
archive/cache paths; that parameterized revision was syntax/CLI checked, not
used to replace the measured baseline.

Collaborating agents measured serially, but unrelated host activity remained
extreme. **Every timing here is exploratory, not quiet-host qualification.**
Each lane keeps its exact denominator, source/artifact hashes, request order,
CPU/wall, cumulative Chez allocation and GC data. Fixed-size allocation probes
show observed allocation at that size; they do not prove an asymptotic property.
The native-mode runner enforced the 180-second deadline for child process
launch/execution, but final hashing was outside that deadline: total command
housekeeping took about 206 seconds. This missed the intended aggregate bound;
the valid process measurements are retained, with the limit recorded explicitly.
Only native arm64 was executed. C, Julia and x86 performance are not qualified
by this work.

## Complete numerical application

The representative application solves the harmonic boundary problem `u=x+y`
on a 100×100 grid with zero interior, ascending in-place SOR, omega 1.25 and
batches of ten sweeps. Each mode reaches the same residual threshold after
3,470 sweeps. All 10,000 cells match, along with residual, checksum and analytical
error reductions. Smaller 11×11 solves also match.

The dynamic baseline uses ordinary Shen boxed SOR loops and a shared generic
Scheme residual helper. The managed path calls the public Shen numerical API.
In this numerical cohort, both the ordinary Shen SOR and the common Shen
convergence loop are loaded at optimize-level 3, as is the generated typed
kernel. Common Scheme fixture/reduction helpers and checked API entry code use
level 2. The precompiled core runtime remains release level 2. This differs from
the native-mode cohort below, which uses release level 2 for its workloads.
A direct typed control uses the *same checked generated implementation*, so it
measures the wrapper boundary rather than serving as an independent algorithm.
Independent grid comparison and logging occur after the request timer.
Runtime/package loading and kernel generation precede these request clocks;
their startup cost is not included in the numerical speedup.

Five fresh serial processes ran three requests per mode, rotating mode order:
45/45 requests passed. Persistent results summarize requests 1 and 2 within
each process, then the five process summaries. GC remains enabled.

| Complete request | CPU ms | Wall ms | Allocated bytes | GC collections |
| --- | ---: | ---: | ---: | ---: |
| Ordinary dynamic baseline | 796.903 | 961.289 | 3,520,987,824 | 419 |
| Managed region through Shen | 87.024 | 92.954 | 1,025,608 | 0 |
| Same checked implementation directly | 80.121 | 82.501 | 1,025,608 | 0 |

The paired median CPU speedup is **9.157×**, range 8.110–9.927, with five wins
in five processes. This is an application result for this workload. It is not a
general Shen speedup or a comparison with a tuned C/Julia solver. The API/direct
paired ratio is 0.968× with mixed outcomes; no wrapper speed advantage is claimed.

A resident residual-only probe allocates 1,760 bytes for 100 scans of this grid
in every process. The implementation stores its running maximum in a one-cell
flvector instead of carrying a generic boxed value through nested loops. The
older roughly 54 MB residual result belongs to a different experiment/runtime;
it is historical context, not a matched causal denominator here.

See [numerical results](../lib/performance/RESULTS.md) for exact output values,
contracts and evidence details.

## Existing native compilation modes

The shipped interpreter and c-minus parser, plus a separate ordinary-Shen 20×20
SOR application, passed all 75 app/mode/sample cells. The cohort contains 285
stage rows and 135 fresh build/run processes. Each cell checks complete results,
initializer effects and the intentional binding contract. Compatible modules
observe public helper redefinition; sealed/bundled callers retain local bindings.
This changes what may be optimized and is not transparent dynamic equivalence.

Representative median repeated CPU cost per complete request:

| Application | Dynamic | Application bundle | WPO bundle |
| --- | ---: | ---: | ---: |
| Interpreter | 5.60 us | 5.24 us | 9.08 us |
| c-minus parser | 94.60 us | 90.55 us | 94.05 us |
| 20×20 ordinary Shen SOR solve | 387 us | 387 us | 399 us |

Paired dynamic/application-bundle CPU ratios are 1.074×, 1.030× and 1.005×
respectively. The small, variable differences do not establish a substantial
execution gain. Allocation per request is identical across all five modes for
each application: about 24 KB, 249 KB and 2.058 MB respectively. This smaller
solver is a different workload from the 100×100 managed-region comparison above.

Cached compatible loading does help: c-minus loads in about 110 ms CPU versus
156 ms dynamically, and the small solver in 1.09 ms versus 6.02 ms. That requires
a separate artifact build costing about 180 ms and 11.5 ms CPU respectively.
Symbolic native loading still allocates heavily while preserving compile-time
metadata. Source review identifies datatype metadata replay through Shen eval
as a candidate to investigate; this cohort does not isolate its causal share.

Use native compilation to move source work into a reusable artifact when the
application lifecycle benefits. These results do not justify default WPO or
expecting native packaging alone to remove generic numerical allocation. See
[native-mode report](../benchmarks/chez-first/REPORT.md) for every mode, ranges,
build/load/first/repeated boundaries and separately recorded bootstrap costs.

## Compiler experiment: rejected

The candidate skipped an unused `arity` lookup for lexical/computed operators.
Generated Scheme and input KL were byte-identical for the shipped interpreter,
the shipped c-minus parser and a synthetic lexical-call control. Semantic and
kernel suites passed before measurement.

Five alternating baseline/candidate pairs ran 30 fresh processes and produced
70 phase rows. Reading and typed loading were measured separately from
KL-to-Scheme translation. The translation clock includes no Scheme evaluation.
Both precompiled runtime compilers use release optimize-level 2; the launcher
workload setting was the normal level 0, matched between variants.

| Translation case | Paired CPU baseline/candidate | Candidate wins | Allocation |
| --- | ---: | ---: | --- |
| Shipped interpreter | 0.833× | 0/5 | Equal |
| Shipped c-minus parser | 1.038× | 3/5 | Equal |
| Synthetic lexical-call control | 1.128× | 4/5 | Equal |

The real applications do not justify adoption. The interpreter shows a measured
regression in this cohort; busy-host and separately generated runtime images
limit causal attribution to the source change. The synthetic control alone is
insufficient. Original compiler source is restored, and the candidate patch,
compiler, generated sources and runtime remain under
`.work/chez-first/rejected-compiler-v2/` with matching measured hashes.

## Evidence and next implementation boundary

Local raw evidence is retained under `.work/chez-first/`, which is deliberately
ignored by Git:

| Area | Receipt |
| --- | --- |
| Immutable baseline | `baseline/manifest.json`, `baseline/logs/` |
| Numerical semantics | `numeric/fork-correctness-api-v3.stdout` |
| Numerical measurements | `numeric/measurement/`, `numeric/final-audit.json` |
| Independent numerical audit | `review/numeric-final-audit.json` |
| Native-mode cohort | `modes/final/` |
| Independent native-mode audit | `review/modes-final-audit.json` |
| Compiler paired cohort | `compiler-paired/` |
| Independent compiler audit | `review/compiler-final-audit.json` |
| Rejected candidate | `rejected-compiler-v2/manifest.json` |
| Final integrated qualification | `final-qualification/` |

These receipts are local artifacts, not published release assets. Source,
workloads and standalone result descriptions are in the worktree.

The final integrated build passes `make test`, including all 68 numerical
semantic checks and the six additional compiler assertions, plus the separate
authenticated community kernel suite (154 passed, zero failed). A coherent
final rebuild and numerical/kernel smoke follow the build-library tests. The
compiler source exactly matches the frozen unchanged fork. Independent reviews
recompute numerical, compiler and native-mode summaries from raw data and verify
source and artifact bindings. The native audit checks all 285 rows, 135 process
receipts, 250 identity hashes, 1,300 retained artifact hashes and 630 summary
calculations.

The next numerical extension should preserve this explicit storage/operation
boundary and add another useful operation from a real application. Add AOT
initialization/module support before presenting the package as a native-module
feature. If a measured operation still merits C or Julia, compare it through the
same complete-request contract, including conversion, startup/compilation,
ownership and repeated use. No dual-runtime dispatcher is needed to test that.
