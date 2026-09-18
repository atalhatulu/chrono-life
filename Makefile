GODOT ?= godot

.PHONY: check-engine test simulate shock batch life

check-engine:
	@test "$$($(GODOT) --version | cut -d. -f1-3)" = "$$(cat .godot-version)" || \
		(echo "Expected Godot $$(cat .godot-version). Set GODOT=/path/to/pinned/godot."; exit 1)

test: check-engine
	$(GODOT) --headless --path . --script tests/run_tests.gd
	$(GODOT) --headless --path . --script tests/run_life_tests.gd
	$(GODOT) --headless --path . --script tests/run_storylet_tests.gd
	$(GODOT) --headless --path . --script tests/run_family_tests.gd

simulate: check-engine
	$(GODOT) --headless --path . --script cli/simulate.gd -- --seed 42 --years 12

shock: check-engine
	$(GODOT) --headless --path . --script cli/simulate.gd -- --seed 42 --years 12 --shock-year 1858

batch: check-engine
	$(GODOT) --headless --path . --script cli/simulate.gd -- --seed 0 --life --count 100

life: check-engine
	$(GODOT) --headless --path . --script cli/simulate.gd -- --seed 42 --life
