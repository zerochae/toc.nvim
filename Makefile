.PHONY: test lint format format-check check

test:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

format:
	stylua lua/ plugin/ tests/

format-check:
	stylua --check lua/ plugin/ tests/

lint: format-check

check: lint test
