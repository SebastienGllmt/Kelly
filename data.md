Kelly Data
=========

```k
require "domains.k"

module KELLY-DATA
    imports DOMAINS
```

Layout
------

Kelly allows for block comments using `(;` and `;)`, and line comments using `;;`.
Additionally, white-space is skipped/ignored.

```k
    syntax #Layout ::= r"(\\(;([^;]|(;+([^;\\)])))*;\\))"
                     | r"(;;[^\\n\\r]*)"
                     | r"([\\ \\n\\r\\t])"
 // --------------------------------------

endmodule
```
