TOP := tb_top
FILELIST := files.f
SOURCES := $(shell sed '/^[[:space:]]*\(#\|$$\)/d' $(FILELIST))

# UVM testbench (tb_uvm/). Verilator only learned to elaborate UVM in 5.052,
# so these targets use the locally built one and leave the distro Verilator
# alone for the plain tb/ flow.
UVM_TOP := tb_top_uvm
UVM_FILELIST := files_uvm.f
UVM_SOURCES := $(shell sed '/^[[:space:]]*\(#\|+\|$$\)/d' $(UVM_FILELIST))
UVM_VERILATOR_PREFIX := /opt/verilator-5.052
UVM_VERILATOR := $(UVM_VERILATOR_PREFIX)/bin/verilator
UVM_TEST ?= spi_base_test
UVM_VERBOSITY ?= UVM_MEDIUM
# The generated model is one very large translation unit per UVM chunk and
# each g++ takes a couple of gigabytes. A default WSL VM has 8 GB, so building
# with one job per core swaps itself to a halt. Raise it if you have the RAM.
UVM_BUILD_JOBS ?= 2

RTL_DIR := third_party/spi_slave_ram
RTL_PATCH := patches/spi_slave_ram.patch
RTL_PATCH_ABS := $(abspath $(RTL_PATCH))

VERBOSITY ?= 2

BUILD_DIR := build
WAVE_DIR := $(BUILD_DIR)/waves
COVERAGE_DIR := $(BUILD_DIR)/coverage

# Verilator's generated makefile refuses to build in a path containing spaces,
# so the C++ object tree lives outside the repository.
OBJ_DIR := $(HOME)/.cache/spi-tb/sim
COVERAGE_OBJ_DIR := $(HOME)/.cache/spi-tb/coverage
UVM_OBJ_DIR := $(HOME)/.cache/spi-tb/sim-uvm

SIM_BINARY := $(OBJ_DIR)/$(TOP)
COVERAGE_BINARY := $(COVERAGE_OBJ_DIR)/$(TOP)
WAVE_FILE := $(WAVE_DIR)/$(TOP).fst
COVERAGE_DATA := $(COVERAGE_DIR)/coverage.dat
COVERAGE_ANNOTATED := $(COVERAGE_DIR)/annotated
COVERAGE_REPORT := $(COVERAGE_DIR)/coverage.txt
UVM_SIM_BINARY := $(UVM_OBJ_DIR)/$(UVM_TOP)
UVM_WAVE_FILE := $(WAVE_DIR)/$(UVM_TOP).fst

VERILATOR_FLAGS := --binary --timing -j 0 -Wno-fatal --top-module $(TOP) -f $(FILELIST)
UVM_VERILATOR_FLAGS := --binary --timing --verilate-jobs 0 --build-jobs $(UVM_BUILD_JOBS) \
	-Wno-fatal --top-module $(UVM_TOP) -f $(UVM_FILELIST)
GTKWAVE_OPTIONS := -4 'initial_window_x 1400' -4 'initial_window_y 900' \
	-4 'initial_window_xpos 50' -4 'initial_window_ypos 50' \
	-4 'do_initial_zoom_fit on'

.DEFAULT_GOAL := help

.PHONY: help setup patch-rtl compile simulate waves kill-waves lint coverage coverage-open check clean \
	compile-uvm simulate-uvm waves-uvm lint-uvm check-uvm

help:
	@echo "make setup          Install/check WSL tools and fetch RTL"
	@echo "make patch-rtl      Re-apply the local fixes to the vendor RTL"
	@echo "make compile        Build the simulator with Verilator"
	@echo "make simulate       Run self-checking testbench and create FST"
	@echo "                    VERBOSITY=0..4 sets how much it prints (default 2)"
	@echo "make waves          Simulate, then open GTKWave"
	@echo "make kill-waves     Close every GTKWave window in WSL"
	@echo "make lint           Lint RTL and testbench with Verilator"
	@echo "make coverage       Generate line/toggle coverage and annotated sources"
	@echo "make coverage-open  Generate coverage and open the text report"
	@echo "make check          Run lint, simulation, and coverage"
	@echo "make clean          Remove generated build files"
	@echo ""
	@echo "UVM testbench in tb_uvm/, needs the Verilator that make setup builds:"
	@echo "make compile-uvm    Build the UVM simulator"
	@echo "make simulate-uvm   Run the UVM testbench and create FST"
	@echo "                    UVM_TEST=<name> picks the test (default spi_base_test)"
	@echo "                    UVM_VERBOSITY=UVM_NONE..UVM_DEBUG (default UVM_MEDIUM)"
	@echo "make waves-uvm      Simulate the UVM testbench, then open GTKWave"
	@echo "make lint-uvm       Lint the UVM testbench"
	@echo "make check-uvm      Run lint-uvm and simulate-uvm"

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
	$(SIM_BINARY) +DUMPFILE=$(WAVE_FILE) +VERBOSITY=$(VERBOSITY)

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

$(UVM_SIM_BINARY): $(UVM_FILELIST) $(UVM_SOURCES)
	@test -x $(UVM_VERILATOR) || { \
		echo "$(UVM_VERILATOR) not found. Run 'make setup' to build it."; exit 1; }
	@mkdir -p $(WAVE_DIR) $(UVM_OBJ_DIR)
	$(UVM_VERILATOR) $(UVM_VERILATOR_FLAGS) --trace-fst --Mdir $(UVM_OBJ_DIR) -o $(UVM_TOP)

compile-uvm: $(UVM_SIM_BINARY)

simulate-uvm: $(UVM_SIM_BINARY)
	@mkdir -p $(WAVE_DIR)
	$(UVM_SIM_BINARY) +DUMPFILE=$(UVM_WAVE_FILE) \
		+UVM_TESTNAME=$(UVM_TEST) +UVM_VERBOSITY=$(UVM_VERBOSITY)

waves-uvm:
	@$(MAKE) --no-print-directory kill-waves
	@$(MAKE) --no-print-directory simulate-uvm
	@test -f $(UVM_WAVE_FILE)
	@command -v gtkwave.exe >/dev/null || { \
		echo "gtkwave.exe not on the Windows PATH."; \
		echo "Install GTKWave for Windows and add its bin\\ directory to PATH:"; \
		echo "  https://sourceforge.net/projects/gtkwave/files/"; \
		exit 1; }
	gtkwave.exe $(GTKWAVE_OPTIONS) "$$(wslpath -w $(UVM_WAVE_FILE))"

# -Wall is not usable here: the UVM library itself trips dozens of Verilator
# style warnings that are not ours to fix.
lint-uvm:
	@test -x $(UVM_VERILATOR) || { \
		echo "$(UVM_VERILATOR) not found. Run 'make setup' to build it."; exit 1; }
	$(UVM_VERILATOR) --lint-only --timing -Wno-fatal \
		--top-module $(UVM_TOP) -f $(UVM_FILELIST)

check-uvm: lint-uvm simulate-uvm

clean:
	rm -rf $(BUILD_DIR) $(OBJ_DIR) $(COVERAGE_OBJ_DIR) $(UVM_OBJ_DIR)
