# Existing Chez-native mode qualification

Use the immutable fork runtime from `.work/chez-first/baseline/manifest.json`.
No port feature is added in this lane. Release optimize2/debug0 is primary.

1. Preserve unchanged bundled interpreter and c-minus parser sources. Add
   deterministic meaningful entry requests and a pure Shen SOR convergence
   solver. Same sources and effects across dynamic/compatible/sealed/app/WPO.
2. Use existing compile-module and build-module-app commands with runtime and
   compiletime metadata replay. Sealed/application binding is deliberate;
   dynamic and compatible must observe ordinary helper redefinition.
3. Check full parsed ASTs, evaluator results, effects, solver output and stopping
   decisions before performance; establish READY then obtain CPU grant.
4. Record fresh artifact build, process bootstrap/load, repeated execution CPU,
   wall, true Chez allocation and GC. Five serial fresh samples with balanced
   mode order, per-process120s and aggregate180s. Preserve failures.
5. Bind exact sources, runtime/artifact hashes, profiles and boundaries. Report
   practical native gains/misses and the concrete bottleneck motivating followup.

Own only benchmarks/chez-first/ and .work/chez-first/modes/. No commits or
external writes. Kernel/compiler feature work belongs to other lanes.
