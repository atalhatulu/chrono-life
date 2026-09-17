GODOT ?= godot

.PHONY: check-engine test simulate shock batch

check-engine:
	@test "$$($(GODOT) --version | cut -d. -f1-3)" = "$$(cat .godot-version)" || \
		(echo "Expected Godot $$(cat .godot-version). Set GODOT=/path/to/pinned/godot."; exit 1)

test: check-engine
	$(GODOT) --headless --path . --script tests/run_tests.gd

simulate: check-engine
	$(GODOT) --headless --path . --script cli/simulate.gd -- --seed 42 --years 12

shock: check-engine
	$(GODOT) --headless --path . --script cli/simulate.gd -- --seed 42 --years 12 --shock-year 1858

batch: check-engine
	$(GODOT) --headless --path . --script cli/simulate.gd -- --seed 0 --years 20 --count 100 --shock-year 1858
