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
(`scripts/gen-stlib.shen`) regenerates `kl/stlib.kl` from those sources; the
community `ShenOSKernel-41.2` `stlib.kl` is **no longer used**.

Generation runs in a throwaway **kernel-only stage-1** shen-scheme
(`scripts/do-build-stage1.shen`, built with `_scm.*build-stage1*` dropping
stlib) so that registering StLib's own macros can't collide with an existing
standard library. It processes the sources in upstream `install.shen` order;
`read-file` package-expands and macroexpands each form (macro/`.dtype` files are
evaluated first so dependents expand), and it emits: `define` → defun (arity
recorded), `declare` → type declaration, `set` → global initialiser, plus a
trailing `(shen.initialise-arity-table …)` — shen-scheme does not derive arity
from a bare defun (this is the `(fn filter)` / `arity = -1` quirk other ports hit
on render/compile paths), so explicit registration is required.

Two behavioural notes vs the community `stlib.kl`: (1) exported stdlib functions
are **not** marked as system functions — the `install.shen` `systemf` tail is not
applied — so a user `(define sq …)` is still accepted (upstream would refuse it);
non-exported functions are package-namespaced (`reduce` → `list.reduce`) via the
package expansion. (2) The `(datatype …)` `name#type` recognisers (e.g.
`print#type`, `maths#type`) are **excluded by construction** — the generator only
emits explicit `define`/`declare`/`set`, never datatype forms — so they cannot
shadow a kernel/user datatype of the same name (a hazard for generators that
capture defuns from an `install.shen` *load*).

The command-line front end **`extension-launcher.kl`** is still retained from
community `ShenOSKernel-41.2` (`shen.x.launcher.launch-shen`, driven by
`shen-scheme.run-shen`); it is compatible with the refresh (its only `hush`
reference is the `*hush*` variable, not the removed `hush` function).
`extension-features.kl` is **dropped**: it calls `shen.set-lambda-form-entry`,
which the refresh removed.

### Not yet reproduced from `Lib/StLib` (see "Remaining work")

- User-facing **reader macros** (`Maths/Strings/Vectors` `macros.shen`): implicit
  optional args — `(sqrt N)` for `(sqrt N (tolerance))`, `for`-loops, string
  `s-op` sugar. Stdlib functions are fully macroexpanded and callable; only the
  call-site sugar is absent (so `(expt 2 10 (tolerance))` works, `(expt 2 10)`
  does not). The community `stlib.kl` registered these via
  `stlib.initialise-macros`; matching that is follow-up.
- `(datatype …)` **typechecker rules** (e.g. `maths`): skipped — they matter only
  under `(tc +)`, and the build/tests run untyped.
- `systemf` external declarations and synonyms from `install.shen`'s tail.

The macro expanders and datatype functions are defined as a side effect of
`read-file`/`eval` but are not returned by `read-file`, and shen-scheme has no
`ps`/source-retrieval to dump them. The robust way to capture them (and match
the community `stlib.initialise-{macros,datatypes}` via `shen.record-macro` /
`shen.process-datatype`) is to intercept `eval-kl` while genuinely loading
`install.shen`, recording every compiled defun — the approach ShenScript's
generator uses. That is the recommended follow-up to close this gap.

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

- Register the StLib **reader macros** and `(datatype …)`/`systemf` metadata so
  the standard library matches the community `stlib.kl` at call-site sugar and
  under `(tc +)` (see "Not yet reproduced" above). Stdlib functions are all
  present and callable today; this is optional-argument sugar and typing.
- The `shen.dict*` overrides in `src/overrides.shen` are now dead code (the
  kernel no longer defines a dict type). They are kept, self-contained over
  Scheme hashtables, so `(shen.dict ...)` still works as a shen-scheme
  superset; drop them if strict upstream parity is preferred.
