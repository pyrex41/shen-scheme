# Existing Chez-native modes: measured gains and limits

The existing native features already provide useful deployment artifacts and
reduce application load work. They do **not** remove the allocation cost of
these ordinary Shen applications. Sealing and whole-program optimization did
not produce a consistent repeated-execution improvement across the three
workloads. This study supports improving the existing Chez port, rather than
adding a second runtime; it does not support making sealed/WPO compilation the
default performance solution.

These are exploratory measurements on a busy shared Apple Silicon host.
Five fresh samples covered each application/mode combination: **75 validated
cells, 135 fresh processes and 285 timing rows**, all accepted. Source, baseline,
fixtures and native artifact hashes matched before/after. Baseline qualification
and these application checks are separate evidence; this is not whole-port or
cross-platform qualification.

## Sources, semantics and boundaries

The frozen baseline is fork `680e2e95`, upstream kernel `ec16a9f`, Shen 43.1,
Chez 10.3.0, safe release optimize level 2/debug level 0. No candidate compiler changes or
optimize level 3 control enters this cohort. The baseline manifest is
[manifest.json](../../.work/chez-first/baseline/manifest.json).

The unchanged bundled interpreter evaluates a constructed 100-level let/successor
expression. The unchanged bundled C-minus parser parses a complete program with
a declaration, 30 assignments and return. The numeric application is a complete
ordinary Shen 20×20 harmonic SOR solver: allocation/initialization, ascending
in-place sweeps, residual scans, convergence decision and full output. It stops
after 60 sweeps. All 400 cells match an independently calculated binary64 oracle;
the residual and analytical error bound also pass. These are full application
requests, not calls into a foreign numeric kernel.

All modes use the same sources and inputs. `dynamic` is ordinary Shen load;
`compatible` and `sealed` use existing compile-module; `app` and `app-wpo` use a
closed build-module-app graph, with WPO calling actual Chez
compile-whole-program. WPO leaves `(shen-scheme runtime)` external. Native
descriptors retain **both runtime and compiletime metadata**, including datatype
and parser metadata. This makes their load contract comparable to ordinary
load. Raw build-app has different metadata behavior and is not substituted.

The initializer effect occurs exactly once during application load and never
during native build. A public helper is then redefined: ordinary/compatible
callers observe the replacement; sealed/app/WPO callers retain their deliberate
local binding. The latter modes therefore require an explicit closed-code
boundary and are not transparent replacements for ordinary Shen redefinition.
All 75 cells pass these semantic guards.

Native artifacts are built in one fresh process and loaded/executed in another.
Build includes reading, expansion/lowering, Chez compilation and output; ordinary
load includes source translation/compilation/evaluation and metadata/effects.
Typechecking is disabled consistently. Checking performance is outside this
lane. Bootstrap, application load, first request and repeated requests are
separate measurements. Full first, warm and recorded final results are checked;
verification is outside the request timers. Repeated batches contain 100
interpreter requests, 20 parser requests or one complete SOR solve. Input/result
construction stays inside each request, except common parser tokenization.

## Repeated execution

Numbers are medians across five fresh processes. Times are microseconds per
complete request; allocation is bytes per request, calculated from the delta of
Chez `bytes-allocated + bytes-deallocated`, so collection does not create a
negative heap-occupancy metric. Small fractional allocation values come from
normalizing fixed batch overhead. No recorded repeated batch triggers a GC;
this does not mean the application is allocation-free.

| Application | Mode | CPU µs/request | Wall µs/request | Bytes/request |
|---|---|---:|---:|---:|
| Interpreter | dynamic | 5.60 | 5.58 | 24,002.08 |
| Interpreter | compatible | 5.45 | 5.45 | 24,002.08 |
| Interpreter | sealed | 5.28 | 5.30 | 24,002.08 |
| Interpreter | app | 5.24 | 5.23 | 24,002.08 |
| Interpreter | app-wpo | 9.08 | 11.13 | 24,002.08 |
| C-minus | dynamic | 94.60 | 94.80 | 248,842.40 |
| C-minus | compatible | 105.30 | 107.10 | 248,842.40 |
| C-minus | sealed | 107.95 | 108.40 | 248,842.40 |
| C-minus | app | 90.55 | 90.60 | 248,842.40 |
| C-minus | app-wpo | 94.05 | 94.00 | 248,842.40 |
| SOR | dynamic | 387.00 | 387.00 | 2,057,728 |
| SOR | compatible | 387.00 | 388.00 | 2,057,728 |
| SOR | sealed | 390.00 | 389.00 | 2,057,728 |
| SOR | app | 387.00 | 387.00 | 2,057,728 |
| SOR | app-wpo | 399.00 | 406.00 | 2,057,728 |

Ratios below are calculated **within each sample**, ordinary/native CPU, then
summarized. Above 1 favors native. A ratio of medians is not substituted for paired
ratios. Ranges and win counts show the instability hidden by a single headline.

| Application | Mode | Paired CPU ratio median [min,max] | Native wins/5 |
|---|---|---:|---:|
| Interpreter | compatible | 1.004 [0.517,1.035] | 4 |
| Interpreter | sealed | 1.040 [0.903,1.118] | 4 |
| Interpreter | app | 1.074 [0.705,1.109] | 4 |
| Interpreter | app-wpo | 0.605 [0.475,1.122] | 2 |
| C-minus | compatible | 0.918 [0.726,1.687] | 2 |
| C-minus | sealed | 0.872 [0.847,1.973] | 2 |
| C-minus | app | 1.030 [0.724,1.975] | 4 |
| C-minus | app-wpo | 1.024 [0.968,1.735] | 4 |
| SOR | compatible | 0.997 [0.985,1.914] | 2 |
| SOR | sealed | 1.005 [0.513,1.924] | 3 |
| SOR | app | 1.005 [0.951,1.934] | 3 |
| SOR | app-wpo | 1.005 [0.767,1.847] | 3 |

There is no allocation reduction in any mode. For example, making the SOR
application closed and applying WPO still allocates about 2.06 MB per 20×20 solve.
That is direct evidence that a native-packaging switch alone does not solve its
numeric representation/allocation problem. It does not identify how much time
each individual boxed operation consumes; that needs a separately qualified
representation or compiler experiment.

## Build versus prebuilt load

Times below are milliseconds; each cell is CPU / wall median. Allocation is
decimal MB for application load alone. Build and load medians are independently
summarized stages, not an end-to-end sum. A deployment that already has an
artifact can benefit from the load saving; generating a fresh artifact adds the
separately shown build cost and another process bootstrap.

| Application | Mode | Artifact build ms CPU/wall | Load ms CPU/wall | Load MB |
|---|---|---:|---:|---:|
| Interpreter | dynamic | — | 60.610 / 64.691 | 166.923 |
| Interpreter | compatible | 74.929 / 90.415 | 56.259 / 62.642 | 147.558 |
| Interpreter | sealed | 71.714 / 76.857 | 51.829 / 52.676 | 147.575 |
| Interpreter | app | 76.821 / 118.846 | 62.373 / 64.611 | 147.441 |
| Interpreter | app-wpo | 94.799 / 231.922 | 66.661 / 74.806 | 147.441 |
| C-minus | dynamic | — | 156.179 / 160.345 | 415.478 |
| C-minus | compatible | 179.962 / 187.728 | 110.491 / 113.367 | 318.548 |
| C-minus | sealed | 199.724 / 226.176 | 118.269 / 130.235 | 318.681 |
| C-minus | app | 215.487 / 320.846 | 106.335 / 107.879 | 318.497 |
| C-minus | app-wpo | 269.612 / 469.576 | 114.156 / 117.823 | 318.496 |
| SOR | dynamic | — | 6.017 / 6.111 | 10.808 |
| SOR | compatible | 11.529 / 15.684 | 1.093 / 1.426 | 2.504 |
| SOR | sealed | 12.853 / 18.222 | 1.256 / 1.778 | 2.506 |
| SOR | app | 14.317 / 87.952 | 1.073 / 1.851 | 2.347 |
| SOR | app-wpo | 25.479 / 139.338 | 1.013 / 1.909 | 2.347 |

Compatible prebuilt load beats ordinary load CPU in all five parser and SOR
pairs. Median paired factors are 1.516×[1.049,1.879] for the parser and
5.140×[3.672,6.011] for SOR. The interpreter's compatible load factor is only
1.056×[0.923,1.332], winning 3/5. WPO adds substantial artifact-build cost and does
not consistently beat the ordinary bundled app at load or execution.

Preserving metadata leaves considerable symbolic load work: 17 collections and
about 147 MB allocation for native interpreter load, 38 collections and about 319 MB
for native parser load. Source inspection explains a concrete candidate:
[`native-raw-compiletime-form`](../../.work/chez-first/baseline/source/src/native-source.shen)
retains datatype/defmacro/synonym forms as calls to Shen `eval`, and
[`native-compiletime-metadata-forms`](../../.work/chez-first/baseline/source/src/native-codegen.shen)
replays those forms at load.
This is a **mechanism-based hypothesis**, not an isolated attribution of every
millisecond. A useful follow-up feature would serialize/replay the resulting
compiletime environment without re-expanding declarations, while retaining
macro/datatype/redefinition behavior. Simply omitting compiletime metadata would
change the contract and is not an acceptable performance result.

## Process startup and host limits

Launch-to-READY includes the runtime **and this source-loaded harness/config**;
it is not a bare-runtime bootstrap benchmark. Median CPU / wall milliseconds
for the dynamic run processes are 198.134/278.772 (interpreter),
183.072/283.364 (parser),199.810/330.035 (SOR). Across all run modes, per-cell
bootstrap medians span 170.953–222.988ms CPU and 243.824–389.652ms wall. Common
bootstrap allocates about 427.22 MB. This is kept separate from application load,
not hidden inside request time or attributed wholly to the runtime.

The before/after load averages are 42.26/55.57/51.59 and 28.48/46.03/48.34.
Defender, OrbStack and unrelated compilation/process work remain visible. The
five modes rotate through all five order positions; application order also
rotates. Cooperating measurement agents were paused, but there is no OS CPU,
thermal or filesystem-cache isolation. Wall inflation and substantial CPU
variation rule out a precise backend ranking. Artifacts are fresh misses, not
claims of cold OS caches. First-call microsecond results are retained separately;
the shortest batches cannot justify sweeping latency claims.

The subprocesses consumed 61.21 seconds of summed observed wall time. Each
process had a 120-second cap, further reduced by the remaining 180-second
cohort deadline. A harness limit remains: final identity/artifact hashing does
not check that deadline. The recorded start-to-final-metadata interval is
206.03 seconds, so the intended 180-second **whole-command** budget was missed
by bookkeeping. No failed timing or hash check is silently discarded.

## Decision and evidence

Keep compatible native artifacts as a practical opt-in deployment/cache path.
Use sealed application graphs when their intentional binding semantics fit the
program. Treat WPO as an optional measured deployment choice, not a default
speedup. Prioritize a checked numeric representation path for the unchanged
SOR allocation issue and investigate compiletime-environment restoration for
symbolic load cost. Both require correctness evidence beyond this study.

Raw evidence is in
[final](../../.work/chez-first/modes/final/):
[all.csv](../../.work/chez-first/modes/final/all.csv),
[metadata.json](../../.work/chez-first/modes/final/metadata.json),
[processes.json](../../.work/chez-first/modes/final/processes.json),
[paired-summary.json](../../.work/chez-first/modes/final/paired-summary.json),
per-cell logs, objects, module graphs, fixture/source hashes, the exact measured
11-file source snapshot and serialized WPO
results. The summary's optional additive cost model sums artifact-build, load,
first and normalized repeated stages; it **excludes both process bootstraps**
and is not a newly timed end-to-end request-count experiment. Source and exact
commands are in [README.md](README.md), [run.py](run.py), [driver.ss](driver.ss)
and the post-cohort analysis in [analyse.py](analyse.py). Rejected preparation
runs are preserved beside the final cohort. Only this native arm64 host was
executed; other architectures remain unqualified.

The independent final audit passes: all 285 timing rows, 75 cells and 135
process receipts; 250 measured identity hashes; all 1,300 metadata-bound raw
artifact hashes; and 630 summary/paired/additive checks. Its receipt is
[modes-final-audit.json](../../.work/chez-first/review/modes-final-audit.json).
The final [SHA256SUMS.json](SHA256SUMS.json) binds this report, analysis, exact
measured-source snapshot manifest and final evidence/audit receipts.
