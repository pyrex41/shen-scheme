# Chez-first performance work

Historical plan and outcome for the pre-rebase experiment. Current integration
is described in [the integration report](chez-first-integration.md).

Worktree: `work/chez-first-performance`, based on fork commit `680e2e95ed9dd0ca6d2f688453efca2a37e50021`. The fork already selects the unmodified upstream ec16a9f Shen kernel. Existing Shen-LuaChez experiments remain read-only historical evidence.

## Intended result

Deliver a concrete Chez-first improvement with an application-facing interface, semantic qualification and paired performance evidence. Use existing native compilation facilities before adding new machinery. C and Julia remain possible later numerical backends; this work requires neither.

## Sequence

1. Freeze and qualify the unchanged fork runtime on Chez 10.3.0, including source/kernel/toolchain provenance and kernel/native checks.
2. Compare ordinary loading, compatible AOT, sealed AOT, application bundles and WPO on actual symbolic programs and a numerical application. Separate build, initialization/loading and repeated execution. Preserve release-safe settings as the primary comparison.
3. Implement explicit typed numerical storage and a substantial operation callable from ordinary Shen. Prefer managed Chez storage where practical. Validate representation, shape, index, mutation and failure contracts before optimized code executes. Type `number` is not sufficient evidence for binary64 specialization.
4. Select a small compatible-path compiler/tooling improvement from source review and measurements. Implement in this isolated fork, with effect ordering, currying, redefinition and errors covered where relevant. If no compiler change is justified, ship the useful numerical package/tooling and record that decision.
5. Verify the final diff, focused semantic tests, application results and required kernel/port checks. Produce a standalone report with measured benefits, negative results and remaining gates.

## Measurement and scope

- Builders may prepare concurrently; the parent grants serial CPU windows for accepted measurements. Unrelated host activity is recorded, and a failed quiet-host gate is not described as isolation.
- Preserve immutable baseline sources and artifacts, all failed receipts and consumed source snapshots. Bind exact kernel, runtime, compiler flags, workloads and artifacts.
- Use fresh serial processes and paired per-process summaries. Include allocations/GC as well as CPU/wall. Bound child processes and aggregate work.
- Correctness precedes timing. Do not infer whole-application gains from kernel-only timings or unsafe assumptions.
- Keep default Shen semantics, except at explicitly documented sealed or typed-region boundaries. Do not change global optimization settings to make a benchmark win.
- No upstream posts, pushes or publication are authorized. Work remains on the local fork branch; preserve sibling worktrees and existing evidence.

## Ownership

| Area | Owner | Status |
| --- | --- | --- |
| Immutable baseline build/qualification | shen_baseline | Complete: pinned artifacts, 154/0 kernel, focused port checks |
| Native-mode application comparison | c_lua_bridge | Complete: 75 cells, 285 rows, 135 fresh processes |
| Typed numerical package and application | regression_kernels | Complete: 68 checks, 45 validated whole requests |
| Read-only compiler/API review | application_runner | Independent raw-data and source audits retained |
| Integration, compatible compiler/tooling change, final evidence | parent | Complete: full port suite and 154/0 kernel; compiler candidate rejected and restored |

## Outcome

The explicit managed numerical package is the accepted implementation. Existing
native modes mainly shift source work into artifact builds on these workloads.
The small compiler candidate did not demonstrate a real-application benefit and
is preserved as a rejected experiment. Timings are exploratory on the busy host.
See [the final report](chez-first-performance.md) for results and limits. No
commit, push, upstream write or release was performed.
