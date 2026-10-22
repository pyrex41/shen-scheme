# Compatible native module using managed arrays

`arrays.shenmod` compiles an ordinary typechecked Shen caller of the optional
managed-array API. Run the checked example from the repository root:

```sh
sh scripts/check-performance-native.sh ./_build/bin/shen-scheme
```

The script initializes `lib/performance` explicitly before compilation and in a
separate fresh process before loading the object. The module creates, copies,
reads and closes managed arrays. Neither the object nor its type metadata
serializes Scheme owner records or loads the helper library automatically.

For an application, load `lib/performance/load.ss` once and call
`performance-load` with the explicit library directory in both build and run
processes. Then use the normal compatible `compile-module` / `load-compiled`
workflow. The generic loader restores the caller's typechecking state.

This example qualifies compatible modules. Sealed graphs, WPO, compiler-free
Petite deployment and automatic package discovery are outside this example's
contract. In particular, helper loading compiles Scheme at runtime and needs
full Chez. The SOR example is loaded separately and is not part of this module.
