# Existing Chez-native modes on actual Shen applications

This lane compares existing port features; it adds no compiler feature and uses
no second language runtime. Sources live here; generated descriptors/artifacts,
logs and receipts live only in `.work/chez-first/modes/`.

The immutable baseline is base680e2e95 with unmodified upstream kernel ec16a9f,
Shen43.1/Chez10.3.0, release optimize2/debug0. Its qualified runtime and source
maps are `.work/chez-first/baseline/manifest.json`. Active compiler changes in the
main worktree do not enter these measurements.

```sh
python3 benchmarks/chez-first/run.py validate --output .work/chez-first/modes/new-validation
# Only after the parent grants serial CPU:
python3 benchmarks/chez-first/run.py measure --cpu-granted --output .work/chez-first/modes/new-cohort
```

Every output directory must be new. The aggregate budget is180seconds and each
process120seconds, additionally bounded by remaining aggregate time. There are
five fresh samples per application/mode, balancing the five mode positions by
rotation. Each native artifact is built in a fresh process and loaded/invoked in
another fresh process. Ordinary load has no prebuilt artifact phase.

Applications:

- The bundled unchanged `shen-test-programs/interpreter.shen`, evaluating100
  nested `let`/successor expressions through its complete normal-form evaluator.
  The request constructs its expression inside the execution timer.
- The bundled unchanged `shen-test-programs/c-minus.shen`, parsing a complete
  program with a declaration,30assignments and return. Character tokenization is
  part of common process setup; the full parser and AST construction are timed.
  The entire AST is compared with an independent expected AST.
- A pure ordinary Shen harmonic SOR solver in `numeric-main.shen`:20×20 grid,
  initialization, in-place ascending sweeps in ten-sweep batches, full residual
  scan/stopping decision, complete grid output, residual and sweep count. It
  converges in60sweeps;400cells match the independent Python binary64 reference,
  and convergence plus analytical error gates reject capped/incorrect results.

All modes use the same application sources and request wrappers. Metadata is
explicitly `(runtime compiletime)` for all native descriptors. The bundled modes
use `build-module-app` so datatype/parser metadata replay remains part of their
load contract; raw `build-app` intentionally differs on compiletime metadata and
is not silently substituted.

- `dynamic`: ordinary Shen `load`; includes source reading, expansion, source
  checking setting, translation, code compilation/evaluation, metadata/effects.
- `compatible`: release compile-module retaining ordinary top-level rebinding.
- `sealed`: release compile-module with deliberate local binding inside the unit.
- `app`: release closed module graph, with static cross-module linkage.
- `app-wpo`: same graph, plus actual Chez compile-whole-program; remaining
  external libraries are preserved in the serialized build result. The runtime
  stays external, so this is not whole-runtime optimization.

`artifact-build`, `load`, `first`, `repeated` rows record CPU/wall, cumulative
Chez allocation, GC count and collector CPU. Build includes source analysis,
Shen expansion/lowering, Chez compilation and file output; it is not a parse-only
or checker-only cost. Compilation/evaluation happens within ordinary Shen
translation (`shen.shen->kl`); no misleading separate noop compilation timer is
introduced. Typechecking is disabled consistently for source loading; checking
performance is outside this lane.

Parent launch-to-READY wall and process CPU/total Chez allocation/GC at READY are
retained separately. They include common runtime and harness setup. Kernel entry
lookup is hoisted outside request timing. Every first/warm/recorded final result
is verified, and input/result construction within each application request stays
in the request timer. Repeated batches are100interpreter requests,20parser
requests and one complete SOR solve; each is an independently complete request.

One initializer effect must happen exactly once at load and never during native
build. All modes install a replacement public helper. Dynamic/compatible callers
must observe it; sealed/app/WPO callers must preserve their deliberately frozen
local helper. The semantic boundary is qualified, not presented as transparent
ordinary redefinition equivalence. No optimizer level3 control is mixed in.

Source/runtime/fixture/generated-object hashes are checked before and after;
build results and all sidecars are retained. Failures are never overwritten.
Shen's source reader maps literal0.3125 to0.31250000000000006 in this kernel, so
the solver uses the original SOR grouping `(* 1.25 0.25)` to obtain0.3125 rather
than assuming another language's decimal-reader behavior. This discovered
preparation mismatch and the corrected full-grid evidence remain retained.

The host is shared, without scheduling/thermal/cache isolation. Performance
cohorts require cooperating agents to pause, but unrelated jobs may remain.
Only the recorded native arm64 host is qualified by execution; other hosts and
architectures remain open.
