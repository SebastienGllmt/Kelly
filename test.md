Kelly Testing
=============

For testing, we augment the semantics with some helpers.

```k
require "kelly.k"

module KELLY-TEST
    imports KELLY
```

Assertions
----------

These assertions will check the supplied property, and then clear that state from the configuration.
In this way, tests can be written as a serious of setup, execute, assert cycles which leaves the configuration empty on success.

### Trap Assertion

This asserts that a `trap` was just thrown.

```k
    syntax Instr ::= "#assertTrap" String

endmodule
```
