# Shen kernel provenance

shen-scheme builds from Mark Tarver's **S41.2 "2026-07-11 refresh"** of the Shen
kernel. This is the *same* `41.2` version number as before, but a **restructured
kernel** — a different lineage from the community `ShenOSKernel-41.2` that
shen-scheme previously used.

## Source of record

- **Canonical mirror (tracked):** `pyrex41/shen-s41.1`
  (private GitHub mirror of Tarver's uploads)
  - tag `s41.2-pristine-20260711` (pristine import; import commit `11fc51b`)
  - `KLambda/*.kl` there are byte-identical to the primary download below.
- **Primary download:** <https://www.shenlanguage.org/Download/S41.2.zip>
  - `Last-Modified: 2026-07-11`
  - `sha256 = 51becbfd60fa8c93c3f8ae5b20b948eaa84c4b1d14ad2f5d2a056002a53ee836`

`make fetch-kernel` downloads the primary zip, verifies the sha256, and copies
the 15 kernel KLambda files into `kl/`.

## What changed upstream (refresh vs community 41.2)

The refresh ships **15** KLambda files:

```
backend core declarations load macros prolog reader sequent
sys t-star toplevel track types writer yacc
```

Relative to the community `ShenOSKernel-41.2`:

- **Removed `dict.kl`.** The property store is no longer a dict. `put`/`get`/
  `unput` are ordinary kernel defuns over a plain absvector (`*property-vector*`,
  a hash-indexed vector of association lists) via `shen.change-pointer-value` /
  `shen.remove-pointer` (both in `sys.kl`).
- **Removed `init.kl`.** There is no longer a `shen.initialise` function.
  Initialisation is now top-level forms in `declarations.kl` (property vector,
  arity table via `shen.initialise-arity-table`, lambda table via
  `shen.build-lambda-table`) and the ~160 `(declare ...)` forms in `types.kl`.
- **Removed `stlib.kl`.** The standard library now ships as lazy `.shen`
  sources under `Lib/StLib`, loaded at run time rather than compiled into the
  kernel.
- **Removed `compiler.kl` and the `extension-*.kl` files** (community additions).
- **Added `backend.kl`** — an inert `cl.*` KLambda→Common Lisp backend, harmless
  under Scheme but part of upstream's boot list (`Sources/make.shen`).
- `hush` → `shen.hush`; `input+` → `shen.input-h+`/`shen.process-input+`;
  `shen.initialise-lambda-forms` → `shen.initialise-lambda-tables`; no
  `shen.set-lambda-form-entry`.

## Standard library: generated from Tarver's `Lib/StLib` sources

shen-scheme compiles the standard library into the boot image. Tarver's refresh
ships it as lazy `.shen` sources under `Lib/StLib`, so `make gen-stlib`
regenerates `kl/stlib.kl` from those sources; the community `ShenOSKernel-41.2`
`stlib.kl` is **no longer used**.

Generation (`scripts/gen-stlib-driver.shen` + `scripts/gen-stlib-lib.shen`) runs
in a throwaway **kernel-only stage-1** shen-scheme (`scripts/do-build-stage1.shen`,
built with `_scm.*build-stage1*` dropping stlib) so that registering StLib's own
macros can't collide with an existing standard library. It **intercepts `eval-kl`
during a genuine `install.shen` load** — the approach ShenScript's generator uses:

- `kl:eval-kl` is wrapped (via the REPL's `(foreign scm.)` escape — hence the
  generator is piped to the REPL, not run with `script`) to record every compiled
  `defun` as `install.shen` loads the sources through the kernel's own loader.
  Because the real loader runs, macros, datatypes, and types register as genuine
  side effects, and function bodies are fully macroexpanded.
- After the load, the registrations the community `stlib.initialise-*` baked are
  reconstructed from the post-load environment: **macros** from a `*macros*` diff
  → `(shen.record-macro …)`; **arities** for every captured defun (externals *and*
  the internal macro-expansion helpers, which also need an arity to be applied)
  → `(update-lambda-table …)`; **systemf** for every stlib external; and `set` /
  `declare` forms harvested from the sources (these do not pass through eval-kl).
- `install.shen` is loaded **hushed** (`*hush*`), since shen-scheme's `pr` override
  otherwise corrupts the output path for later eval (a cross-port `pr`/`*hush*`
  hazard).

This closes the reader-macro / datatype-typing regression: `(sqrt 2)`, `for`-loops,
string sugar, and datatype typechecks (`(tc +) (rational? (r# 3 4))`) all work.

Two behavioural notes vs the community `stlib.kl`: (1) exported stdlib functions
**are** marked as system functions (the `install.shen` `systemf` tail is
reproduced), so a user `(define filter …)` is refused, matching upstream;
non-exported functions are package-namespaced (`reduce` → `list.reduce`). (2) The
`(datatype …)` `name#type` recognisers (`print#type`, `maths#type`, …) are
**excluded** from the baked defuns (`g2-hashtype?`) so a persisted `print#type`
can't shadow a user/kernel `print` datatype (the shen-julia hazard). Datatype
types still check through the emitted `declare`s; the `(datatype …)` inference
*rules* for the two stlib datatypes (`maths`, `print`) are not re-emitted, which
matters only under `(tc +)` for those two datatypes.

The command-line front end **`extension-launcher.kl`** is still retained from
community `ShenOSKernel-41.2` (`shen.x.launcher.launch-shen`, driven by
`shen-scheme.run-shen`); it is compatible with the refresh (its only `hush`
reference is the `*hush*` variable, not the removed `hush` function).
`extension-features.kl` is **dropped**: it calls `shen.set-lambda-form-entry`,
which the refresh removed.

## Build adaptations (see `scripts/build.shen`, `src/compiler.shen`)

- `*shen-files*`: dropped `dict`, `init`; added `backend`; kept `extension-launcher`.
  `stlib` is compiled from the generated `kl/stlib.kl` (above), or dropped
  entirely under `_scm.*build-stage1*` for the generator host.
- Removed the seeded `(shen.initialise)` init call (the function no longer
  exists; the kernel self-initialises via its top-level forms).
- **Init ordering.** Non-defun top-level forms are collected into `*init-code*`
  in file-compilation order and run at start-up in that order. The refresh has
  cross dependencies, so the compile order is now: `overrides.kl`, then
  `compiler.kl` (its `(set _scm.*compiling-function* ...)` must precede the
  kernel's `types.kl` `declare`s, which drive the runtime compiler), then the
  kernel (`declarations.kl` sets up the property vector / arity / lambda table
  before `types.kl`), then `shen-scheme-extensions.kl` (its `update-lambda-table`
  calls need that kernel state).
- **`get` de-optimisation.** The `(trap-error (get ...) ...)` → `scm.get/or`
  shortcut assumed dict-backed storage and is removed; `get` now goes through
  the standard guarded path and calls the kernel `get` defun over the property
  vector. (`tests/compiler-tests.shen` updated to match.)
- **`hash` 0-guard.** `src/overrides.shen` overrides `hash` (replacing the
  kernel defun). The refresh now buckets the property vector with
  `(hash key (limit V))`, where bucket 0 is reserved (address 0 holds the
  vector length). The kernel `hash` returns 1 instead of 0; the override now
  does the same. Without this, a key hashing to 0 corrupts the store — the same
  hazard other ports hit when overriding `hash`.

## Remaining work

- Re-emit the `(datatype …)` inference *rules* for the two stlib datatypes
  (`maths`, `print`) so they type-check under `(tc +)` (their `name#type`
  recognisers are deliberately not baked, to avoid shadowing). Every other stdlib
  function, macro, and declared type — including the `rational`/`complex`/`numeral`
  types — is reproduced.
- The `shen.dict*` overrides in `src/overrides.shen` are now dead code (the
  kernel no longer defines a dict type). They are kept, self-contained over
  Scheme hashtables, so `(shen.dict ...)` still works as a shen-scheme
  superset; drop them if strict upstream parity is preferred.
