# Chez-first extension on the rebased fork

The extension belongs in the Shen/Scheme fork as an optional library. Generic
managed arrays live in `lib/performance`; the restricted SOR operation is a
separately loaded example. Default Shen values, generic arithmetic and normal
compiler behavior are unchanged by this extension.

## Upstream base and preserved fork behavior

This branch is rebased onto tizoc/shen-scheme
`8d261518db17fbfec32d1b268b40ed216b925c74`, verified against upstream master on
2026-10-22. That commit is an ancestor of the feature branch. The user's fork is
`pyrex41/shen-scheme`; the work branch is `work/chez-first-performance`.

Upstream #45 supersedes the fork's earlier byte-string/OS conversions. The rebase
keeps upstream's prelude, primitives and CLI/native boundary implementations,
preventing double conversion, while retaining the fork's additional regression
checks. The EOF, explicit-file-output under `*hush*`, optional Nix environment,
dead-factorisation cleanup and authenticated ec16a9f kernel remain. See
[FORK.md](../FORK.md) for the complete differences.

The pre-rebase prototype is preserved by local archive ref
`archive/chez-first-pre-upstream-20261022` (`bd881cc`). Rebase conflict/resolution
receipts and immutable original timing artifacts remain under ignored `.work/`.
No experimental compiler arity fast path is included.

## Library, example and native-module boundaries

| Area | Entry and contract |
| --- | --- |
| Generic managed storage | [lib/performance](../lib/performance/README.md): explicit binary64 conversion, checked allocation/indexing/copy, vector adapters, opaque types and owner revocation |
| Restricted operation example | [examples/performance/sor](../examples/performance/sor/README.md): explicit second loader, bounded SOR/residual descriptor and kernel |
| Compatible native caller | [examples/performance/native](../examples/performance/native/README.md): typechecked caller compiled in one process and loaded in another, with explicit library initialization in each |

The generic owner holds storage and length only. It contains no SOR workspace.
The example allocates a one-cell managed reduction workspace per checked call.
This is a representation change from the earlier prototype, so its old timings
and allocation totals are historical evidence, not current matched claims.

Both loaders preserve the caller's typechecking flag after success or failure
and are idempotent after successful initialization. Load each defining Scheme
file only once, then call its initializer with an explicit package directory.
The generic-only fresh-process test confirms that loading storage does not
install the SOR API, descriptor or kernel.

Compatible modules must initialize helpers in both build and run processes.
They do not embed owner records or discover/load the library automatically.
This feature requires full Chez with flvector primitives; sealed/WPO integration
and compiler-free Petite loading are outside its current contract. Binary
archives include `lib/performance` and `examples/performance`; ordinary `make
install` retains its existing runtime-only behavior, so library roots remain
explicit. There is no implicit package-discovery change.

## Reproduction

From a built source checkout:

```sh
make test-performance
make test
```

`test-performance` launches independent generic-only and example suites, an
allocation regression control and the compatible-module build/run smoke. The
full port suite includes this target. The module example script is also directly
runnable:

```sh
sh scripts/check-performance-native.sh ./_build/bin/shen-scheme
```

For direct Shen use, initialize both explicit roots before loading the example:

```sh
_build/bin/shen-scheme eval -q \
  -e '(eval-kl [scm.load "lib/performance/load.ss"])' \
  -e '(eval-kl [scm.performance-load "lib/performance"])' \
  -e '(eval-kl [scm.load "examples/performance/sor/load.ss"])' \
  -e '(eval-kl [scm.performance-sor-load "examples/performance/sor"])' \
  -e '(load "examples/performance/sor/usage.shen")' \
  -e '(if (= (sor-example.zero-residual 5) (perf.f64 0)) ok (error "SOR example differs"))'
```

Explicit binary64 results are compared with explicitly constructed binary64
values. The native smoke initially compared `2.0` with exact `2`, which this
port's structural equality distinguishes; its expected value now uses
`(perf.f64 2)`. This was a fixture correction, not an arithmetic/compiler change.

## Current qualification

Qualification passes on native macOS arm64 with Chez 10.3.0 and the authenticated
ec16a9f kernel. Final evidence is recorded separately from all pre-rebase timing
cohorts. Source-only review verifies upstream ancestry,
boundary-source equality and generic/example separation. Rebased runtime build
and upstream/fork byte-string, Unicode-boundary, hush and EOF checks pass.
Focused factorization checks pass: 12 generic-only checks, 73 example checks and
full-grid equality for complete harmonic solves. All 100×100 modes stop after
3,470 sweeps. The checked residual allocation control reports 32,160 bytes for
100 calls, including the new per-call workspace; it is not the old raw-kernel
probe or an accepted speed comparison.

| Final check | Result |
| --- | --- |
| Full port suite, `make test` | PASS, including the extension |
| Coherent self-precompile and runtime rebuild | PASS |
| Generic-only fresh process | 12 checks passed; no SOR installed |
| Example suite | 73 checks passed; complete output grids match |
| Checked allocation regression control | PASS, 32,160 bytes for 100 calls |
| Compatible native build/run in separate processes | PASS |
| Authenticated community kernel suite | 154 passed, zero failed |
| Binary archive including library and examples | PASS |
| Extracted archive initialized and executed from `/tmp` | PASS |

The first full-suite attempt timed out at 180 seconds without an assertion
failure; it is retained as incomplete. The bounded retry allowed 420 seconds and
passed in about 256 seconds. Later checks used individual 120-second bounds.
This is correctness and packaging qualification, not a new speed ranking. No
quiet-host timing or additional architecture qualification is claimed.

Receipts are kept under `.work/chez-first/integration/`: `rebased-build/`,
`factorization/`, the initial `qualification/` timeout and the passing
`qualification-v2/` commands, source/runtime identities and extracted package.
The preserved historical speed study is
[chez-first-performance.md](chez-first-performance.md).

## Next work

Use additional real applications to choose reusable numerical operations before
introducing a general region language. The existing native-mode study also
identifies compile-time environment restoration as a symbolic loading candidate;
that requires its own metadata/redefinition qualification and is not implemented
here. Optional C or Julia operations can later be compared through the same
explicit storage and complete-request contract.
