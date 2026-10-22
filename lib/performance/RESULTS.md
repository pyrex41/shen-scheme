> **Historical evidence only.** Every measurement below predates the rebase onto upstream8d26151 and the generic-array/SOR-example factorization. The current generic package installs no SOR operation; the example now allocates a reduction workspace per call instead of keeping it in an owner field. These figures are not current matched-runtime performance or allocation claims. Old raw receipts and source snapshots remain unchanged.

# Historical pre-rebase numerical-region measurements

The former combined prototype ran a complete harmonic SOR solve through an ordinary Shen-facing API while keeping numerical storage in Chez-managed flvectors. It has no C/Lua dependency. Explicit typed storage and a one-cell managed reduction state remove the previously observed per-residual-cell boxing pattern.

This is a restricted operation prototype, not automatic typed lowering for arbitrary Shen programs. The descriptor names one validated SOR/residual operation, and Shen `number` remains broader than binary64. [README.md](README.md) documents construction, ownership, numerical bounds, typechecking and compilation limitations.

## Qualification

The measured executable comes from the frozen fork baseline `680e2e95ed9dd0ca6d2f688453efca2a37e50021`, authenticated upstream kernel commit `ec16a9fa4fc2e87e2aa336fb1ae30e8ac2266394`, Shen43.1/Chez10.3.0. The runtime image SHA256 is `534374a34b76ace7b20b7899eae6ca465e7a4d73a4f1465d245e12dc2f9115f0`. The launcher, full runtime artifacts, generated Scheme and kernel KL hashes are checked before/after the cohort, together with every consumed package/test source and the runner. Source snapshots accompany the data.

The final correctness suite passes **68 checks**. It covers exact-vs-binary64 input, explicit bounded conversion, negative zero, NaN/Inf rejection, shape/index bounds, no-write argument rejection, distinct-owner copy, closed owners/aliases, standard Shen vector headers, idempotent package initialization, and caller typechecking-state preservation after success and deliberate load failure. Under tc+, a declared caller constructs and runs the operation; a string passed as its numeric initializer is rejected statically. An injected nonfinite execution result checks owner revocation; that fault control is separate from actual numerical correctness.

Actual ordinary Shen orchestration runs complete11x11 and100x100 solves through all three modes, comparing every output cell. The100x100 grid uses boundary `u=x+y`, zero interior, omega1.25, residual tolerance1e-5, cap20,000 and batches of10. All stop after**3,470 sweeps**, residual**9.885826612432425e-6**, checksum**9980.537779721863**, analytical RMSE**0.0024260170706671322** and max error**0.004901722560183841**. Boundaries and the analytical maximum-principle error bound are checked per request. The tolerance is for the unscaled discrete residual, not the mesh-scaled physical Laplacian.

## Exploratory measurements

Five fresh serial processes ran three requests per mode, rotating mode order: **45/45 validated requests**. A process is the statistical unit: summarize requests1/2 within a process, then summarize five processes. First requests are retained separately. GC stays enabled. Other collaborating benchmark agents paused, but the host was **extremely busy**, with starting load averages about80/68/53. These times are exploratory; they are not quiet-host qualification.

The request clock includes initialization, allocation/import into managed storage, checked operation calls, ordinary Shen convergence decisions, result export, checksum/error reductions and owner close. Independent full-grid comparison and raw logging follow the timer. The dynamic baseline uses ordinary Shen boxed SOR loops and the shared generic residual helper. The region calls the public ordinary Shen API. The direct typed control calls the exact same checked generated Chez implementation, measuring the wrapper boundary without selecting a weaker native algorithm; it is not an independent competing implementation.

Persistent complete-request results, process-hierarchical medians:

| Mode | CPU ms | Wall ms | Chez allocated bytes | GC collections |
|---|---:|---:|---:|---:|
| Ordinary dynamic baseline |796.903|961.289|3,520,987,824|419|
| Managed region via Shen API |87.024|92.954|1,025,608|0|
| Same checked typed control directly |80.121|82.501|1,025,608|0|

The region's paired CPU speedup over the dynamic baseline is**9.157x**, range8.110–9.927,5/5 wins. Its paired wall speedup is**9.725x**, range9.138–10.551,5/5 wins. These ratios describe this complete application on the recorded host, not general Shen acceleration.

The API/direct-control paired CPU ratio is**0.968x**, range0.807–1.058,2/5 wins; wall0.970x, range0.747–1.064. No performance advantage for the wrapper is claimed. The two paths use the same kernel and safety contract, and host/request-order variability is material.

Each process separately calls the resident residual-only kernel100 times on a100x100 managed grid. Every sample reports**1,760 allocated Chez bytes total**, about17.6bytes per scan over9,604 interior cells. This shows allocation is no longer proportional to residual-cell visits. The prior foreign-buffer prototype allocated roughly54MB per solve in its typed residual; that older number is historical context from a different cohort/runtime and is not a matched speedup denominator here.

The full public API includes pre/post typed scans, finite-result checks, bounded numerical input checks and output materialization; its roughly1.026MB whole-request allocation is measured with `sstats-bytes`, not a live-heap delta. Close revokes access while managed storage is reclaimed by GC. No unmanaged owner or second runtime is involved.

## Evidence

Raw files are retained under `.work/chez-first/numeric/measurement/`: identity, source snapshots, five stdout/stderr pairs, rows, runs, host observations, drift gate and process-paired analysis. Final correctness is `.work/chez-first/numeric/fork-correctness-api-v3.stdout`; earlier failures and preparation receipts remain separate. A prior `/tmp` working-directory smoke confirms loading with an explicit absolute package root.

This prototype is ready for further integration review. General region syntax, automatic representation inference, sealed/AOT packaging, compiler integration, concurrency, general arithmetic overflow rollback and other architectures are outside this qualification. The measured outcome supports pursuing explicit typed numerical storage and reductions in Chez before adding another runtime.

## Current factorization correctness

After the rebase and package/example split, the rebuilt runtime passes the fresh-process generic-only smoke (**12 checks**) and the full explicit-example suite (**73 checks**, preserving the original68 and adding5 example-loader controls). The100x100 application still agrees in every cell and stops after3,470 sweeps. A bounded allocation regression control performs100 checked residual calls, including each call's new one-cell managed workspace, and allocates32,160 Chez bytes. This is a focused correctness/allocation control, not a new matched speed cohort or a denominator for the historical timings above. Commands and before/after source/runtime hashes were captured with the integration receipts.
