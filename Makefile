TOP := tb_instantiation
FILELIST := files.f
SOURCES := $(shell sed '/^[[:space:]]*\(#\|$$\)/d' $(FILELIST))
RTL_SOURCES := $(filter %.v,$(SOURCES))

BUILD_DIR := build
SIM_DIR := $(BUILD_DIR)/sim
WAVE_DIR := $(BUILD_DIR)/waves
COVERAGE_DIR := $(BUILD_DIR)/coverage
SIM_BINARY := $(SIM_DIR)/$(TOP).vvp
WAVE_FILE := $(WAVE_DIR)/$(TOP).fst
COVERAGE_VCD := $(COVERAGE_DIR)/$(TOP).vcd
COVERAGE_DATABASE := $(COVERAGE_DIR)/coverage.cdd
COVERAGE_REPORT := $(COVERAGE_DIR)/coverage.txt

.DEFAULT_GOAL := help

.PHONY: help setup compile simulate waves lint coverage coverage-open coverage-gui check clean

help:
	@echo "make setup          Install/check WSL tools and fetch RTL"
	@echo "make compile        Compile with Icarus Verilog"
	@echo "make simulate       Run self-checking testbench and create FST"
	@echo "make waves          Simulate, then open GTKWave"
	@echo "make lint           Lint RTL and testbench with Verilator"
	@echo "make coverage       Generate RTL coverage database and text report"
	@echo "make coverage-open  Generate coverage and open text report"
	@echo "make coverage-gui   Generate coverage and open Covered GUI"
	@echo "make check          Run lint, simulation, and coverage"
	@echo "make clean          Remove generated build files"

setup:
	@./scripts/setup-wsl.sh

compile: $(SIM_BINARY)

$(SIM_BINARY): $(FILELIST) $(SOURCES)
	@mkdir -p $(SIM_DIR) $(WAVE_DIR)
	iverilog -g2012 -Wall -s $(TOP) -o $@ -c $(FILELIST)

simulate: $(SIM_BINARY)
	@mkdir -p $(WAVE_DIR)
	vvp -N $(SIM_BINARY) -fst +DUMPFILE=$(WAVE_FILE)

waves: simulate
	@test -f $(WAVE_FILE)
	@gtkwave $(WAVE_FILE) >/dev/null 2>&1 &
	@echo "Opened $(WAVE_FILE)"

lint:
	verilator --lint-only --timing -Wall -Wno-fatal -Wno-BLKANDNBLK \
		--top-module $(TOP) -f $(FILELIST)

coverage: $(SIM_BINARY)
	@mkdir -p $(COVERAGE_DIR)
	@rm -f $(COVERAGE_VCD) $(COVERAGE_DATABASE) $(COVERAGE_REPORT)
	vvp -N $(SIM_BINARY) +DUMPFILE=$(COVERAGE_VCD)
	@sed -i '/^$$comment /d' $(COVERAGE_VCD)
	covered score -t instantiation -i tb_instantiation.dut -g 3 \
		$(addprefix -v ,$(RTL_SOURCES)) -vcd $(COVERAGE_VCD) \
		-o $(COVERAGE_DATABASE) -rI=SPI
	covered report -d v -m ltcf -o $(COVERAGE_REPORT) $(COVERAGE_DATABASE)
	@echo "Coverage report: $(COVERAGE_REPORT)"

coverage-open: coverage
	@explorer.exe "$$(wslpath -w "$$(realpath $(COVERAGE_REPORT))")"

coverage-gui: coverage
	@covered report -view $(COVERAGE_DATABASE) >/dev/null 2>&1 &

check: lint simulate coverage

clean:
	rm -rf $(BUILD_DIR)
