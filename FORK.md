# pyrex41/shen-scheme: what the fork changes

This fork is upstream [tizoc/shen-scheme](https://github.com/tizoc/shen-scheme)
`master` plus a few fork-specific commits.

- **Base:** `fa07173`, "Prepare Shen Scheme 0.52 release". It runs kernel S43.1, the community [ShenOSKernel 43.1](https://github.com/Shen-Language/shen-sources/releases/tag/shen-43.1), fetched and checksum-verified by `make fetch-kernel` exactly as upstream does.
- **No kernel or build changes:** the fork changes nothing in the kernel or in upstream's build recipe.
- **Syncing:** to sync with upstream, rebase these commits onto the new upstream `master`.

## Fork commits on top of upstream

| Change | Why upstream's behaviour was not kept | Test |
|---|---|---|
| The REPL exits cleanly on stdin EOF | v0.52 loops on `error: empty stream` when its stdin runs out (33 MB of output in 8 s). The fix still evaluates a final line without a trailing newline. | `make test-repl-eof` |
| `*hush*` gates only standard output | Under `eval -q`, v0.52's `pr` also silences explicit file writes, so `(write-to-file ...)` writes an empty file. | `make test-hush` |
| Dead pattern-factorisation scaffolding removed | It targeted `extension-factorise-defun.kl`, which the kernel no longer ships. Nothing in kernel 43.1 reaches it. | builds and `make test` |
| Optional Nix environment (`flake.nix`, `.envrc`) | Convenience for Bifrost; Nix is never required. | `nix develop` |

`make test` runs the upstream suites plus `test-repl-eof` and `test-hush`.

## History

Before 2026-10-20 the fork carried its own kernel lineage: Mark Tarver's S41.2 and S42.0, with a generated `stlib.kl` and absvector property-store workarounds. It later took its own ShenOSKernel 42.2 and 43.1 upgrades.

- **The old history** is kept at tag [`archive/master-pre-upstream-rebase`](https://github.com/pyrex41/shen-scheme/tree/archive/master-pre-upstream-rebase) (`4dc9cc2`).
- **Rebased.** On 2026-10-20 the fork was rebased onto upstream v0.52, keeping only the changes above.

Dropped in that rebase:

- **Kernel upgrades (42.2, 43.1) and version bumps.** Superseded: upstream ships 43.1 itself.
- **The fork's character-stream hooks** (`char-stream?` on textual ports). Superseded by upstream's 43.1 hooks: byte streams only, with character operations reported as unsupported.
- **`extension-expand-dynamic` and `extension-type-annotations` in the build's kernel file list.** Upstream 0.52 compiles without them and its suite passes, so this fork follows upstream.
- **The Tarver-lineage loader, `make gen-stlib`, and the `hash` bucket-0 and `get` workarounds.** Already removed in the fork's 42.2 merge: they only applied to Tarver's kernel.
- **The kernel-provenance document.** Upstream's `make fetch-kernel` pins and verifies the kernel release, so it is the provenance.
