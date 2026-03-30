.PHONY: test lint check

test:
	bats tests/

lint:
	shellcheck -x -s bash ralph.sh

check: lint test
