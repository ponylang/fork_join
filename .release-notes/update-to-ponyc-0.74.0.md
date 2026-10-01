## Update to work with ponyc 0.74.0

Ponyc 0.74.0 added a `Generator` class to the `pony_test` package, which clashes with fork_join's own `Generator` interface when both are imported in the same package without aliasing. Test files now alias `pony_test` to avoid the collision.

If you use fork_join's `Generator` and `pony_test` in the same package, alias one of them:

```pony
use pt = "pony_test"
use "fork_join"

class iso MyTest is pt.UnitTest
  fun name(): String => "my test"

  fun apply(h: pt.TestHelper) =>
    // Generator here refers to fork_join's Generator, not pony_test's
    None
```
