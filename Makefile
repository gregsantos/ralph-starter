.PHONY: test lint check

test:
	bats tests/

lint:
	shellcheck -x -s bash ralph.sh plugin/scripts/ralph-evidence.sh

check: lint test
