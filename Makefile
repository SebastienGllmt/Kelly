# Settings
# --------

build_dir:=$(CURDIR)/.build
defn_dir:=$(build_dir)/defn
k_submodule:=$(build_dir)/k
pandoc_tangle_submodule:=$(build_dir)/pandoc-tangle
k_bin:=$(k_submodule)/k-distribution/target/release/k/bin
tangler:=$(pandoc_tangle_submodule)/tangle.lua

LUA_PATH=$(pandoc_tangle_submodule)/?.lua;;
export LUA_PATH

.PHONY: deps ocaml-deps \
        build build-kelly build-test \
        defn defn-kelly defn-test \
        test test-simple \
        media

all: build

clean:
	rm -rf $(build_dir)

# Build Dependencies (K Submodule)
# --------------------------------

deps: $(k_submodule)/make.timestamp $(pandoc_tangle_submodule)/make.timestamp ocaml-deps

$(k_submodule)/make.timestamp:
	git submodule update --init -- $(k_submodule)
	cd $(k_submodule) \
		&& mvn package -q -DskipTests
	touch $(k_submodule)/make.timestamp

$(pandoc_tangle_submodule)/make.timestamp:
	git submodule update --init -- $(pandoc_tangle_submodule)
	touch $(pandoc_tangle_submodule)/make.timestamp

ocaml-deps:
	opam init --quiet --no-setup
	opam repository add k "$(k_submodule)/k-distribution/target/release/k/lib/opam" \
		|| opam repository set-url k "$(k_submodule)/k-distribution/target/release/k/lib/opam"
	opam update
	opam switch 4.03.0+k
	eval $$(opam config env) \
	opam install --yes mlgmp zarith uuidm

# Building Definition
# -------------------

# Tangle definition from *.md files

defn: defn-kelly defn-test

kelly_dir:=$(defn_dir)/kelly
kelly_files:=kelly.k data.k
defn_kelly_files:=$(patsubst %, $(kelly_dir)/%, $(kelly_files))
defn-kelly: $(defn_kelly_files)
$(kelly_dir)/%.k: %.md
	@echo "==  tangle: $@"
	mkdir -p $(dir $@)
	pandoc --from markdown --to $(tangler) --metadata=code:.k $< > $@

test_dir:=$(defn_dir)/test
test_files:=test.k $(kelly_files)
defn_test_files:=$(patsubst %, $(test_dir)/%, $(test_files))
defn-test: $(defn_test_files)
$(test_dir)/%.k: %.md
	@echo "==  tangle: $@"
	mkdir -p $(dir $@)
	pandoc --from markdown --to $(tangler) --metadata=code:.k $< > $@

# OCAML Backend

build: build-kelly build-test

build-kelly: $(kelly_dir)/kelly-kompiled/interpreter
$(kelly_dir)/kelly-kompiled/interpreter: $(defn_kelly_files)
	@echo "== kompile: $@"
	eval $$(opam config env) \
	$(k_bin)/kompile --debug --gen-ml-only -O3 --non-strict \
					 --main-module KELLY --syntax-module KELLY $< --directory $(kelly_dir) \
		&& ocamlfind opt -c $(kelly_dir)/kelly-kompiled/constants.ml -package gmp -package zarith \
		&& ocamlfind opt -c -I $(kelly_dir)/kelly-kompiled \
		&& ocamlfind opt -a -o $(kelly_dir)/semantics.cmxa \
		&& $(k_bin)/kompile --debug -O3 --non-strict \
					 --main-module KELLY --syntax-module KELLY $< --directory $(kelly_dir) \
		&& cd $(kelly_dir)/kelly-kompiled \
		&& ocamlfind opt -o interpreter \
				-package gmp -package dynlink -package zarith -package str -package uuidm -package unix \
				-linkpkg -inline 20 -nodynlink -O3 -linkall \
				constants.cmx prelude.cmx plugin.cmx parser.cmx lexer.cmx run.cmx interpreter.ml

build-test: $(test_dir)/test-kompiled/interpreter
$(test_dir)/test-kompiled/interpreter: $(defn_test_files)
	@echo "== kompile: $@"
	eval $$(opam config env) \
	$(k_bin)/kompile --debug --gen-ml-only -O3 --non-strict \
					 --main-module KELLY-TEST --syntax-module KELLY-TEST $< --directory $(test_dir) \
		&& ocamlfind opt -c $(test_dir)/test-kompiled/constants.ml -package gmp -package zarith \
		&& ocamlfind opt -c -I $(test_dir)/test-kompiled \
		&& ocamlfind opt -a -o $(test_dir)/semantics.cmxa \
		&& $(k_bin)/kompile --debug -O3 --non-strict \
					 --main-module KELLY-TEST --syntax-module KELLY-TEST $< --directory $(test_dir) \
		&& cd $(test_dir)/test-kompiled \
		&& ocamlfind opt -o interpreter \
				-package gmp -package dynlink -package zarith -package str -package uuidm -package unix \
				-linkpkg -inline 20 -nodynlink -O3 -linkall \
				constants.cmx prelude.cmx plugin.cmx parser.cmx lexer.cmx run.cmx interpreter.ml

# Testing
# -------

TEST=./kelly test

tests/%.test: tests/%
	$(TEST) $<

test: test-simple

### Simple Tests

simple_tests:=$(wildcard tests/simple/*.wast)

test-simple: $(simple_tests:=.test)
