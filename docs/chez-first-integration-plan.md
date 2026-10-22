# Chez-first fork integration

User scope: integrate the optional Chez-first extension on the user's fork,
rebasing onto current tizoc/shen-scheme first. Keep Shen-Lua recommendations
separate from changes to that runtime.

1. Preserve the qualified prototype as a local checkpoint commit and retain the
   immutable pre-rebase runtime/evidence under ignored `.work/` paths.
2. Rebase the fork commits and prototype onto current upstream master. Resolve
   overlapping OS/string-boundary work using upstream behavior plus qualified
   fork-specific contracts. Preserve failed/conflict receipts and original refs.
3. Keep reusable managed binary64 storage as an optional port library. Put the
   restricted SOR operation in a separately loaded example; test ownership,
   initialization, typechecking and application equivalence. Do not add a general
   region language or modify the default compiler.
4. Make initialization/use explicit, document native-module support accurately,
   and keep package/test/example documentation discoverable from the fork.
5. Build the rebased runtime and run the full port suite, authenticated community
   kernel tests and numerical correctness. Bind final source/runtime/upstream
   hashes. Existing timing results remain historical; they are not automatically
   current after the rebase.
6. Review the actual Shen-Lua source and write separate, prioritized learnings
   with measured-versus-hypothesized benefits and concrete qualification gates.

No changes or public writes to tizoc upstream. Preserve all sibling worktrees.
