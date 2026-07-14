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

## What shen-scheme retains from community 41.2, and why

Tarver's refresh unbundles the standard library, but shen-scheme has always
compiled it into the boot image. To preserve the standard library and the REPL
front end without a `Lib/StLib`-source build path (see "Remaining work"), two
files are taken from the community `ShenOSKernel-41.2` release:

- **`stlib.kl`** — the standard library (math, rationals, complex, lists,
  strings, vectors, tuples, IO). Verified to contain no dict references and no
  dependency on removed kernel functions.
- **`extension-launcher.kl`** — the command-line front end
  (`shen.x.launcher.launch-shen`) that `shen-scheme.run-shen` drives.
  Compatible with the refresh (its only `hush` reference is the `*hush*`
  variable, not the removed `hush` function).

`extension-features.kl` is **dropped**: it calls `shen.set-lambda-form-entry`,
which the refresh removed.

## Build adaptations (see `scripts/build.shen`, `src/compiler.shen`)

- `*shen-files*`: dropped `dict`, `init`; added `backend`; kept `stlib` and
  `extension-launcher`.
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

## Remaining work

- Build the standard library from Tarver's `Lib/StLib` `.shen` sources rather
  than retaining the community `stlib.kl`, to fully track the refresh.
- The `shen.dict*` overrides in `src/overrides.shen` are now dead code (the
  kernel no longer defines a dict type). They are kept, self-contained over
  Scheme hashtables, so `(shen.dict ...)` still works as a shen-scheme
  superset; drop them if strict upstream parity is preferred.
