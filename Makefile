ALR      ?= alr
ALR_CLEAN = $(ALR) clean -- -p
ALR_BUILD = $(ALR) build --development --profiles="*=development"

.PHONY: build clean prove prove-check tests check-readme coverage \
        trust trust-check docs docs-check docs-deps docs-placement help

build: ## Build the library and the tools crate
	cd json && $(ALR_BUILD)
	cd tools && $(ALR_BUILD)

clean: ## Remove build, proof, doc and coverage artifacts
	-cd json && alr exec -- gnatprove --clean -P json_prove.gpr
	cd json && $(ALR_CLEAN)
	cd tests && $(ALR_CLEAN)
	rm -rf json/build tests/build tools/build tests/TEST-*.xml
	rm -rf docs/api gnatdoc-run.txt

prove: ## Prove the library to SPARK Silver -- AoRTE (--level=2)
	cd json && $(ALR) exec -- gnatprove -P json_prove.gpr -j0 --level=2 --warnings=error --output=oneline --output-header

prove-check: ## `prove` as a gate: drift from scripts/proof-xfail.txt => exit 1
	ALR="$(ALR)" ./scripts/check-proof.sh

check-readme: ## Compile the README example against the library
	ALR="$(ALR)" ./scripts/check-readme-example.sh

# GNATdoc. The same report/gate split as prove/prove-check, and for the same
# underlying reason: `gnatdoc --warnings` lists every undocumented entity and
# then exits 0 regardless, so a bare gnatdoc run cannot fail a build.
# scripts/check-docs.sh reads the report and sets the exit status; it also drives
# every project root and is the durable record of the --style=gnat and
# --generate=private choices, which no GPR attribute can express.
#
# Needs gnatdoc on PATH: `alr -n install gnatdoc_bin=26.0.0`. The script says so
# and stops if it is missing; it installs nothing itself.
docs: docs-deps ## Generate the API docs into docs/api + report undocumented entities
	./scripts/check-docs.sh --no-gate

# The placement lint runs after check-docs.sh, and needs no toolchain of its own.
# It catches what the gnatdoc gate structurally cannot: --warnings is per entity,
# not per declaration, so a block on the wrong side of a declaration either reads
# as a missing comment on the entity below or silently satisfies the one above.
docs-check: docs-deps ## `docs` as a gate: undocumented entity or misplaced block => exit 1
	./scripts/check-docs.sh
	./scripts/check-doc-placement.sh

# What gnatdoc needs on disk that a bare checkout does not have, WITHOUT
# building anything:
#
#   1. config/*_config.gpr for all three crates, which every root withs. Each
#      crate has its own Alire solution, so each needs its own generation pass;
#      the tests pass also syncs the AUnit sources the tests root reads.
#      --stop-after=generation stops before compilation.
#   2. tools/build/readme/example.adb, the only source of the readme_example
#      root, extracted from README.md.
#
# The object and library directories the roots name are created by
# check-docs.sh, because their absence is a .gpr warning the gate deliberately
# does not filter. Nothing here compiles or links, so `make docs` works on a
# fresh checkout with no built library.
#
# No profile flags below, deliberately, and it is load-bearing. Alire keys a
# dependency's build directory by build profile, and check-docs.sh drives gnatdoc
# through a bare `alr exec`, which resolves the DEFAULT profile. Provisioning with
# --profiles="*=development" syncs aunit under one hash while `alr exec` looks
# under another, so tests/json_tests.gpr fails to load with
# `imported project file "aunit.gpr" not found`. That only bites on a fresh
# checkout -- a dev machine already has every profile's hash on disk -- so it
# reproduces in CI and not locally. The two must agree, and the default is the
# one `alr exec` picks.
docs-deps: ## Provision what gnatdoc reads (config GPRs + README example), no build
	cd json && $(ALR) build --stop-after=generation
	cd tests && $(ALR) build --stop-after=generation
	cd tools && $(ALR) build --stop-after=generation
	ALR="$(ALR)" ./scripts/check-readme-example.sh --extract-only

tests: ## Build + run the AUnit drivers, instrumented for coverage
	cd tests && ADAFLAGS="--coverage -gnata" $(ALR_BUILD)
	cd tests && alr run -s

coverage: ## Render the coverage report from the last `tests` run
	mkdir -p tests/build/cov
	gcovr --exclude test --html-nested tests/build/cov/coverage.html

# grep over `git ls-files`, so these need no toolchain and run on a bare
# checkout. That is what lets CI gate on the trust surface before anything
# compiles.
trust: ## List the derived trust surface, in manifest form
	./scripts/check-trust-surface.sh --list

trust-check: ## `trust` as a gate: any drift from scripts/trust-surface.txt => exit 1
	./scripts/check-trust-surface.sh

# awk over `git ls-files`, so like the trust targets this one needs no toolchain
# and runs on a bare checkout, before anything is built. The script itself gates
# (and docs-check runs it that way); this target only reports.
docs-placement: ## Report doc blocks attributed to the wrong declaration
	./scripts/check-doc-placement.sh --no-gate

# `[a-z-]`, not `[a-z]`: with the latter the hyphenated targets (prove-check,
# check-readme, docs-check, docs-placement, trust-check) are silently absent
# from this listing.
help: ## List targets
	@grep -hE '^[a-z-]+:.*?##' $(MAKEFILE_LIST) \
	  | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-15s\033[0m %s\n",$$1,$$2}'
