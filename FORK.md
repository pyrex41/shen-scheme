# pyrex41/shen-scheme: what the fork changes

This fork is upstream [tizoc/shen-scheme](https://github.com/tizoc/shen-scheme) `master` plus a few fork-specific commits.

- **Base:** `05cf325`, "Merge pull request #44 … fix-byte-string-io-core", which is v0.52 plus upstream's byte-string fix.
- **Kernel:** ShenOSKernel **43.1.1** from [pyrex41/shen-sources release `shen-43.1.1`](https://github.com/pyrex41/shen-sources/releases/tag/shen-43.1.1). It is community 43.1 plus [Shen-Language/shen-sources#117](https://github.com/Shen-Language/shen-sources/pull/117), and it is not an official Shen-Language release. `make fetch-kernel` fetches it and checks its checksum (`kernel_sha256_43.1.1`, from the `kernel_repo_43.1.1` release) the same way upstream fetches 43.1.
- **Syncing:** to sync with upstream, rebase these commits onto the new upstream `master`.

## Fork commits on top of upstream

| Change | Why upstream's behaviour was not kept | Test |
|---|---|---|
| The REPL exits cleanly on stdin EOF | Upstream loops on `error: empty stream` when its stdin runs out (33 MB of output in 8 s). The fix still evaluates a final line without a trailing newline. | `make test-repl-eof` |
| `*hush*` gates only standard output | Under `eval -q`, upstream's `pr` also silences explicit file writes, so `(write-to-file ...)` writes an empty file. Upstream's `tests/byte-strings.ss` asserts that a hushed `pr` to any sink writes nothing; in the fork, that one check is two: nothing to `*stoutput*`, every byte to another sink. | `make test-hush`, `make test-byte-strings` |
| Byte strings at the OS boundary: file names, command-line arguments, native compile and load paths | Upstream's fix ([#44](https://github.com/tizoc/shen-scheme/pull/44)) makes `pr` and `read-file-as-string` byte-exact. A Shen string naming a non-ASCII file, or an `eval -e` argument, still reached the OS or the program unconverted. | `make test-byte-string-boundaries` |
| Kernel 43.1.1 instead of 43.1: the type checker dereferences the checked term once ([Shen-Language/shen-sources#117](https://github.com/Shen-Language/shen-sources/pull/117)) | In 43.1, `shen.search-user-datatypes` and `shen.by-hypothesis` re-dereferenced the same term on every iteration. The fix halves the instructions of a typecheck-heavy workload, with the same output. 43.1.1 changes only `t-star.kl` and the version string (`init.kl`); eleven other `.kl` files differ only in gensym numbering. Return to an official Shen-Language kernel once one contains #117. | `make test`; `tests/kernel-compatibility.shen` expects `(version)` = `"43.1.1"` |
| Dead pattern-factorisation scaffolding removed | It targeted `extension-factorise-defun.kl`, which the kernel no longer ships. Nothing in kernel 43.1 reaches it. | builds and `make test` |
| Optional Nix environment (`flake.nix`, `.envrc`) | Convenience for Bifrost; Nix is never required. | `nix develop` |

`make test` runs the upstream suites, including upstream's `test-byte-strings`, plus `test-byte-string-boundaries`, `test-repl-eof` and `test-hush`.

## History

Before 2026-10-20 the fork carried its own kernel lineage: Mark Tarver's S41.2 and S42.0, with a generated `stlib.kl` and absvector property-store workarounds. It later took its own ShenOSKernel 42.2 and 43.1 upgrades.

**Tags of earlier fork states:**
- [`archive/master-pre-upstream-rebase`](https://github.com/pyrex41/shen-scheme/tree/archive/master-pre-upstream-rebase) (`4dc9cc2`) is the master before the first rebase onto upstream.
- [`v0.52-pyrex41.1`](https://github.com/pyrex41/shen-scheme/releases/tag/v0.52-pyrex41.1) (`dce21e3`) is the master that was rebased onto v0.52, before upstream's own byte-string fix.

**Rebases:**
- On 2026-10-20 the fork was rebased onto upstream v0.52, keeping only the changes in the table.
- On 2026-10-21 it was rebased onto upstream `05cf325`.
  - The fork's own `pr` and `read-file-as-string` commits were dropped, since upstream's #44 supersedes them. One rule changed with them: a character at or above 256 now follows upstream, so `pr` writes nothing, where the fork had written UTF-8.
  - The fork's other boundary conversions were kept.
  - The kernel patch was added, then replaced on the same day by the 43.1.1 kernel release that carries the same fix. `v0.52-pyrex41.2` has the patch; `v0.52-pyrex41.3` has 43.1.1.

**Dropped in the first rebase:**
- **Kernel upgrades (42.2, 43.1) and version bumps.** Superseded: upstream ships 43.1 itself.
- **The fork's character-stream hooks.** Superseded by upstream's 43.1 hooks.
- **`extension-expand-dynamic` and `extension-type-annotations` in the build's kernel file list.** Upstream builds without them and its suite passes.
- **The Tarver-lineage loader, `make gen-stlib`, and the `hash`/`get` workarounds.** Already removed in the fork's 42.2 merge.
- **The kernel-provenance document.** Upstream's `make fetch-kernel` pins and verifies the kernel release, so it is the provenance.
