ALR      ?= alr
ALR_CLEAN = $(ALR) clean -- -p
ALR_BUILD = $(ALR) build --development --profiles="*=development"

.PHONY: build clean prove prove-check tests check-readme coverage

build:
	cd json && $(ALR_BUILD)
	cd tools && $(ALR_BUILD)

clean:
	-cd json && alr exec -- gnatprove --clean -P json_prove.gpr
	cd json && $(ALR_CLEAN)
	cd tests && $(ALR_CLEAN)
	rm -rf json/build tests/build tests/TEST-*.xml

prove:
	cd json && $(ALR) exec -- gnatprove -P json_prove.gpr -j0 --level=2 --output=oneline --output-header

prove-check:
	ALR="$(ALR)" ./scripts/check-proof.sh

check-readme:
	ALR="$(ALR)" ./scripts/check-readme-example.sh

tests:
	cd tests && ADAFLAGS="--coverage -gnata" $(ALR_BUILD)
	cd tests && alr run -s

coverage:
	mkdir -p tests/build/cov
	gcovr --exclude test --html-nested tests/build/cov/coverage.html
