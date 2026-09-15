TOP := tb_top
FILELIST := files.f
SOURCES := $(shell sed '/^[[:space:]]*\(#\|$$\)/d' $(FILELIST))

RTL_DIR := third_party/spi_slave_ram
RTL_PATCH := patches/spi_slave_ram.patch
RTL_PATCH_ABS := $(abspath $(RTL_PATCH))

BUILD_DIR := build
WAVE_DIR := $(BUILD_DIR)/waves
COVERAGE_DIR := $(BUILD_DIR)/coverage

# Verilator's generated makefile refuses to build in a path containing spaces,
# so the C++ object tree lives outside the repository.
OBJ_DIR := $(HOME)/.cache/spi-tb/sim
COVERAGE_OBJ_DIR := $(HOME)/.cache/spi-tb/coverage

SIM_BINARY := $(OBJ_DIR)/$(TOP)
COVERAGE_BINARY := $(COVERAGE_OBJ_DIR)/$(TOP)
WAVE_FILE := $(WAVE_DIR)/$(TOP).fst
COVERAGE_DATA := $(COVERAGE_DIR)/coverage.dat
COVERAGE_ANNOTATED := $(COVERAGE_DIR)/annotated
COVERAGE_REPORT := $(COVERAGE_DIR)/coverage.txt

VERILATOR_FLAGS := --binary --timing -j 0 -Wno-fatal --top-module $(TOP) -f $(FILELIST)
GTKWAVE_OPTIONS := -4 'initial_window_x 1400' -4 'initial_window_y 900' \
	-4 'initial_window_xpos 50' -4 'initial_window_ypos 50' \
	-4 'do_initial_zoom_fit on'

.DEFAULT_GOAL := help

.PHONY: help setup patch-rtl compile simulate waves kill-waves lint coverage coverage-open check clean

help:
	@echo "make setup          Install/check WSL tools and fetch RTL"
	@echo "make patch-rtl      Re-apply the local fixes to the vendor RTL"
	@echo "make compile        Build the simulator with Verilator"
	@echo "make simulate       Run self-checking testbench and create FST"
	@echo "make waves          Simulate, then open GTKWave"
	@echo "make kill-waves     Close every GTKWave window in WSL"
	@echo "make lint           Lint RTL and testbench with Verilator"
	@echo "make coverage       Generate line/toggle coverage and annotated sources"
	@echo "make coverage-open  Generate coverage and open the text report"
	@echo "make check          Run lint, simulation, and coverage"
	@echo "make clean          Remove generated build files"

setup:
	@./scripts/setup-wsl.sh

# git submodule update resets the vendor RTL, which drops the timescale
# directives and the blocking-to-non-blocking fixes the simulation needs.
patch-rtl:
	@git -C "$(RTL_DIR)" apply --reverse --check "$(RTL_PATCH_ABS)" 2>/dev/null \
		&& echo "RTL patch already applied" \
		|| git -C "$(RTL_DIR)" apply "$(RTL_PATCH_ABS)"

compile: $(SIM_BINARY)

$(SIM_BINARY): $(FILELIST) $(SOURCES)
	@mkdir -p $(WAVE_DIR) $(OBJ_DIR)
	verilator $(VERILATOR_FLAGS) --trace-fst --Mdir $(OBJ_DIR) -o $(TOP)

simulate: $(SIM_BINARY)
	@mkdir -p $(WAVE_DIR)
	$(SIM_BINARY) +DUMPFILE=$(WAVE_FILE)

waves:
	@$(MAKE) --no-print-directory kill-waves
	@$(MAKE) --no-print-directory simulate
	@test -f $(WAVE_FILE)
	@command -v gtkwave.exe >/dev/null || { \
		echo "gtkwave.exe not on the Windows PATH."; \
		echo "Install GTKWave for Windows and add its bin\\ directory to PATH:"; \
		echo "  https://sourceforge.net/projects/gtkwave/files/"; \
		exit 1; }
	gtkwave.exe $(GTKWAVE_OPTIONS) "$$(wslpath -w $(WAVE_FILE))"

kill-waves:
	@taskkill.exe /IM gtkwave.exe /F >/dev/null 2>&1 || true
	@pkill -TERM -x gtkwave 2>/dev/null || true
	@sleep 0.2
	@pkill -KILL -x gtkwave 2>/dev/null || true

lint:
	verilator --lint-only --timing -Wall -Wno-fatal \
		--top-module $(TOP) -f $(FILELIST)

$(COVERAGE_BINARY): $(FILELIST) $(SOURCES)
	@mkdir -p $(COVERAGE_OBJ_DIR)
	verilator $(VERILATOR_FLAGS) --coverage-line --coverage-toggle \
		--Mdir $(COVERAGE_OBJ_DIR) -o $(TOP)

coverage: $(COVERAGE_BINARY)
	@mkdir -p $(COVERAGE_DIR)
	@rm -rf $(COVERAGE_DATA) $(COVERAGE_ANNOTATED) $(COVERAGE_REPORT)
	$(COVERAGE_BINARY) +verilator+coverage+file+$(COVERAGE_DATA)
	verilator_coverage --annotate $(COVERAGE_ANNOTATED) --annotate-all \
		$(COVERAGE_DATA) | tee $(COVERAGE_REPORT)
	@echo "Coverage report: $(COVERAGE_REPORT)"
	@echo "Annotated sources: $(COVERAGE_ANNOTATED)"

coverage-open: coverage
	@explorer.exe "$$(wslpath -w "$$(realpath $(COVERAGE_REPORT))")"

check: lint simulate coverage

clean:
	rm -rf $(BUILD_DIR) $(OBJ_DIR) $(COVERAGE_OBJ_DIR)
