# Shen kernel provenance

This fork of shen-scheme builds from the community **ShenOSKernel 43.1**
release of the Shen kernel, adopted **wholesale and byte-identical**. It is the
same community kernel release used by current Shen ports, and the fork's
runtime is the existing Scheme port plus the fork-only changes
listed below.

## Source of record

- **Repository:** [Shen-Language/shen-sources](https://github.com/Shen-Language/shen-sources)
- **Tag:** `shen-43.1`
- **Commit:** `715824a52b55e9c81a9501df8548ff3edd8411f5`
- **Release asset:** `ShenOSKernel-43.1.tar.gz`
  (<https://github.com/Shen-Language/shen-sources/releases/download/shen-43.1/ShenOSKernel-43.1.tar.gz>)
  - `sha256 = 900eedef44f440af78f9395ed06e689ce1604546fc309f5bc7c8bc84cc651920`
    (pinned as `kernel_sha256_43.1` in the `Makefile`)
- **`(version)`:** `"43.1"` (set by the kernel's `init.kl`)

`make fetch-kernel` downloads the release asset, verifies the SHA-256 with
`scripts/verify-sha256.sh` (the build refuses to extract on a mismatch), and
copies every file from `ShenOSKernel-43.1/klambda/*.kl` into `kl/` unmodified:

```
compiler core declarations dict init load macros prolog reader sequent stlib sys
t-star toplevel track types writer yacc
extension-expand-dynamic extension-features extension-launcher
extension-namespaces extension-programmable-pattern-matching
extension-type-annotations
```

The kernel files are not committed to this repository (`kl/` and `compiled/`
are build outputs).

## Lineage decision

Until this release the fork vendored **Mark Tarver's S41.2 / S42.0** kernel
(`S42.zip` from shenlanguage.org, 2026-08-25), a structurally different
lineage: no `init.kl`/`dict.kl`, a plain-absvector property store, and the
standard library shipped as lazy `Lib/StLib` sources that the fork compiled
into `stlib.kl` with its own generator.

Kernels 42.1, 42.2, and 43.1 are releases of the **community** `shen-sources` line.
Per pyrex41/shen-scheme#8 (umbrella pyrex41/bifrost#26, pyrex41/yggdrasil#32),
the fork now adopts ShenOSKernel 43.1 wholesale, replacing the
Tarver S42.0 lineage, so that this fork runs the
same kernel byte for byte. This deliberately undoes the Tarver-lineage loader
work. The following fork machinery was removed because it only applied to the
Tarver kernel:

- the `S42.zip` fetch in `make fetch-kernel` and the mixed community/Tarver
  file set;
- `make gen-stlib` and its scripts (`scripts/gen-stlib-driver.shen`,
  `scripts/gen-stlib-lib.shen`, `scripts/do-build-stage1.shen`); the community
  `stlib.kl` is used as shipped;
- the `scripts/build.shen` init-ordering and file-list changes (`backend.kl`,
  no `dict`/`init`, no `extension-features`);
- the `hash` bucket-0 guard and the removal of the
  `(trap-error (get ...) ...)` -> `scm.get/or` optimisation. Both were needed
  only because Tarver's kernel kept properties in a plain absvector. The
  community kernel uses `dict`, which shen-scheme overrides with Chez
  hashtables, so upstream's `hash` and `get` handling apply again.

## Fork-only changes on top of the existing Scheme port

- **Pattern-factorisation scaffolding removed** (`src/factorize-patterns.shen`,
  `shen.push-factorised-branch` / `shen.eval-factorised-branch`,
  `compile-factorised-branches`, the `shen.x.factorise-defun.*` build setup).
  ShenOSKernel 43.1 does not ship `extension-factorise-defun.kl`, so this code
  was unreachable. The kernel's own `(factorise +)` is unaffected.
- **`*hush*` gates only standard output** (`pr` in `src/overrides.shen`): an
  explicit `pr` to a file stream is written even under `*hush*`.
- **REPL exits cleanly on stdin EOF** (`shen.my-read-byte` / `shen.repl` in
  `src/overrides.shen`) instead of looping on `error: empty stream`. This is
  scoped to REPL command input; a program's own `(read-byte (stinput))` still
  returns `-1`.
- Optional Nix development environment (`flake.nix`, `flake.lock`, `.envrc`).

## 43.1 port-upgrade audit

From `doc/port-upgrades.md` in shen-sources:

- **42.0, `update-lambda-table` invalidation:** handled by upstream 0.47+.
- **42.1, source-form handlers / `shen.macroexpand-h` / `shen.try-parse`:**
  this fork overrides neither the reader nor `macroexpand`. Upstream 0.49+
  handles source-form expansion in native compilation. The only reader-adjacent
  override is the fork's `shen.my-read-byte`. It still lets the reader process
  input that ends at EOF without a trailing newline: the first EOF after
  pending input is passed through as `-1`, and the REPL exits only when nothing
  is pending. For example, `printf '(+ 1 2)' | shen-scheme` prints `3` and
  exits 0. It does not affect how expansions are consumed.
- **43.1, new kernel extensions:** `extension-expand-dynamic.kl` and
  `extension-type-annotations.kl` are compiled from the release tarball. The
  port exposes public `char-stream?`, `read-unit-string`, and `write-string`
  through Chez textual ports while retaining the fork's REPL EOF and `*hush*`
  behavior.
