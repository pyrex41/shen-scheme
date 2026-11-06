# This fork

This is [tizoc/shen-scheme](https://github.com/tizoc/shen-scheme) `master` plus the commits
below, and it follows upstream. When upstream takes one of them, it is dropped here.

| Commit | Change | Why |
|---|---|---|
| Exit the REPL cleanly on stdin EOF | The REPL exits 0 when stdin runs out | Upstream loops forever printing `empty stream` |
| `*hush*` gates only standard output | `pr` to a file still writes under `-q` | Upstream follows the kernel's `pr`, so `eval -q` writes empty files |
| Optional Nix development environment | `flake.nix`, `.envrc` | Local convenience |

The fork's earlier history, on kernels up to 43.2 with its own byte-string changes, is
on the branch `archive/fork-master-20261106`.
