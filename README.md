# SPI slave RAM testbench

Reproducible SystemVerilog verification project for Abdelrahman1810's [SPI slave with single-port RAM](https://github.com/Abdelrahman1810/SPI_Slave_with_Single_Port_RAM). The upstream design is tracked as a Git submodule, so its history and ownership remain separate.

The flow uses Icarus Verilog for simulation, Verilator for lint, Covered for code coverage, GTKWave for FST waveforms, and Verible for editor formatting and language services. It is designed for Ubuntu on WSL 2 and VS Code's WSL extension.

## First-time setup

Open PowerShell in this project and run:

```powershell
.\scripts\wsl.ps1 setup
```

Then open the project in WSL-backed VS Code:

```powershell
wsl --cd "$PWD" code .
```

Accept the recommended extensions. In VS Code, use **Terminal > Run Task** for compile, simulation, waves, lint, coverage, or the full check.

## Commands

From a WSL terminal in the project:

```bash
make compile        # compile only
make simulate       # run testbench and write build/waves/tb_instantiation.fst
make waves          # simulate and open GTKWave through WSLg
make lint           # lint RTL and testbench
make coverage       # write a CDD database and detailed text report
make coverage-open  # generate and open coverage text in Windows
make coverage-gui   # generate and open Covered's WSLg GUI
make check          # lint, simulate, and generate coverage
make clean          # delete generated build files
```

The same targets work from PowerShell, for example:

```powershell
.\scripts\wsl.ps1 simulate
.\scripts\wsl.ps1 coverage-open
```

## Project layout

```text
tb/tb_instantiation.sv       Self-checking SystemVerilog testbench
third_party/spi_slave_ram/   Upstream RTL Git submodule
files.f                      Simulator source list
Makefile                     Compile, simulation, waveform, lint, and coverage flow
scripts/setup-wsl.sh         Idempotent WSL tool setup
scripts/wsl.ps1              PowerShell-to-WSL command wrapper
.vscode/                     Editor settings and one-click tasks
.github/workflows/           GitHub Actions verification
```

Generated files stay under `build/` and are ignored by Git. Coverage output is written to `build/coverage/coverage.txt` and `build/coverage/coverage.cdd`.

## Extending the testbench

Add scenarios to `tb/tb_instantiation.sv`. Keep checks self-verifying with `$fatal` so local runs and GitHub Actions fail reliably. Add any new RTL or testbench source to `files.f`.

The design protocol sends frames least-significant bit first. Each 10-bit frame contains a two-bit operation and eight-bit payload:

- `00`: latch write address
- `01`: write data
- `10`: latch read address
- `11`: request read data

The upstream repository currently has no declared software license. Review that repository's terms before redistributing or modifying its RTL.

## Known upstream RTL findings

Verilator reports width mismatches and mixed blocking/nonblocking assignments in `SPI.v`. The mixed assignments also make direct Verilator simulation unreliable, so this project uses Icarus for behavioral simulation and Covered to score the resulting VCD. Coverage uses Covered's `-rI=SPI` option to retain the SPI block despite its known race-prone coding style; treat those metrics as guidance until the RTL is repaired.

The SPI driver leaves `SS_n` asserted through internal count 11 because the current RTL only clears `rx_valid` at that count. Deasserting immediately after the tenth payload bit leaves `rx_valid` stuck high and can corrupt later commands.
