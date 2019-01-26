Semantics of Cardano Shelley Ledger-Spec (Kelly) in K
====================================

This repository presents a prototype formal semantics of Shelley for Cardano.

This is NOT an official project. Just a fun project I spend some time on to learn more about K. IT is far from complete (in fact, all it does is parse transactions right now to maintain UTXO state).

See the `tests` folder for example input and output.

Semantics
========

See [kelly.md](kelly.md) for the semantics.

Building
========

System Dependencies
-------------------

The following are needed for building/running Kelly:

-   [Pandoc >= 1.17](https://pandoc.org) is used to generate the `*.k` files from the `*.md` files.
-   GNU [Bison](https://www.gnu.org/software/bison/), [Flex](https://github.com/westes/flex), and [Autoconf](http://www.gnu.org/software/autoconf/).
-   GNU [libmpfr](http://www.mpfr.org/) and [libtool](https://www.gnu.org/software/libtool/).
-   Java 8 JDK (eg. [OpenJDK](http://openjdk.java.net/))
-   [Opam](https://opam.ocaml.org/doc/Install.html), **important**: Ubuntu users prior to 15.04 **must** build from source, as the Ubuntu install for 14.10 and prior is broken.
    `opam repository` also requires `rsync`.

On Ubuntu >= 15.04 (for example):

```sh
sudo apt-get install make gcc maven openjdk-8-jdk flex opam pkg-config libmpfr-dev autoconf libtool pandoc zlib1g-dev
```

To run proofs, you will also need [Z3](https://github.com/Z3Prover/z3) prover; on Ubuntu:

```sh
sudo apt-get install z3
```

Installing/Building
-------------------

After installing the above dependencies, the following command will build submodule dependencies and then Kelly:

```sh
make deps
make build
```

Testing
-------

Run tests:
```sh
./kelly run tests/ledger.kelly
```

Step-through: 
```sh
./kelly debug tests/ledger.kelly
```
