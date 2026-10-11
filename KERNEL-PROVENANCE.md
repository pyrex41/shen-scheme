# Shen kernel provenance

This fork of shen-scheme builds from the community **ShenOSKernel 42.2**
release of the Shen kernel, adopted **wholesale and byte-identical**. It is the
same kernel that upstream [tizoc/shen-scheme v0.50](https://github.com/tizoc/shen-scheme/tree/v0.50)
ships, and the fork's runtime is upstream v0.50 plus the fork-only changes
listed below.

## Source of record

- **Repository:** [Shen-Language/shen-sources](https://github.com/Shen-Language/shen-sources)
- **Tag:** `shen-42.2`
- **Commit:** `73507e069fe147aefb728d632c4ce40bc6a7b314`
- **Release asset:** `ShenOSKernel-42.2.tar.gz`
  (<https://github.com/Shen-Language/shen-sources/releases/download/shen-42.2/ShenOSKernel-42.2.tar.gz>)
  - `sha256 = 1d02273003654d34ec020ae67cb214ecec410dee3350419ff807d82b652678d8`
    (pinned as `kernel_sha256_42.2` in the `Makefile`)
- **`(version)`:** `"42.2"` (set by the kernel's `init.kl`)

`make fetch-kernel` downloads the release asset, verifies the SHA-256 with
`scripts/verify-sha256.sh` (the build refuses to extract on a mismatch), and
copies every file from `ShenOSKernel-42.2/klambda/*.kl` into `kl/` unmodified:

```
core declarations dict init load macros prolog reader sequent stlib sys
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

Kernels 42.1 and 42.2 are releases of the **community** `shen-sources` line.
Per pyrex41/shen-scheme#8 (umbrella pyrex41/bifrost#26, pyrex41/yggdrasil#32),
option **(a)** was chosen: adopt ShenOSKernel 42.2 wholesale, replacing the
Tarver S42.0 lineage, so that this fork and upstream shen-scheme 0.50 run the
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

## Fork-only changes on top of upstream v0.50

- **Pattern-factorisation scaffolding removed** (`src/factorize-patterns.shen`,
  `shen.push-factorised-branch` / `shen.eval-factorised-branch`,
  `compile-factorised-branches`, the `shen.x.factorise-defun.*` build setup).
  ShenOSKernel 42.2 does not ship `extension-factorise-defun.kl`, so this code
  was unreachable. The kernel's own `(factorise +)` is unaffected.
- **`*hush*` gates only standard output** (`pr` in `src/overrides.shen`): an
  explicit `pr` to a file stream is written even under `*hush*`.
- **REPL exits cleanly on stdin EOF** (`shen.my-read-byte` / `shen.repl` in
  `src/overrides.shen`) instead of looping on `error: empty stream`. This is
  scoped to REPL command input; a program's own `(read-byte (stinput))` still
  returns `-1`.
- Optional Nix development environment (`flake.nix`, `flake.lock`, `.envrc`).

## 42.1 / 42.2 port-upgrade audit

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
- **42.2, `extension-namespaces.kl` regenerated:** used as shipped in the 42.2
  tarball.
