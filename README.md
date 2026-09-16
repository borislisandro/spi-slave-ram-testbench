# SPI slave RAM testbench

A class-based SystemVerilog testbench for an SPI slave with a single-port RAM,
running under Verilator.

The design under test is not mine. It is Abdelrahman1810's
[SPI_Slave_with_Single_Port_RAM](https://github.com/Abdelrahman1810/SPI_Slave_with_Single_Port_RAM),
tracked here as a Git submodule under `third_party/spi_slave_ram/` so its
history and ownership stay separate from this repository. That repository has
no declared software license; review its terms before redistributing or
modifying the RTL. Everything under `tb/` is this project's own work.

## What the DUT does

A 10-bit frame arrives on `MOSI`, least significant bit first, preceded by a
mode bit. The top two bits of the frame select the operation and the low eight
carry an address or a byte:

| Command | Meaning |
| ------- | ----------------------------- |
| `00`    | latch the write address |
| `01`    | write a byte at that address |
| `10`    | latch the read address |
| `11`    | return the byte on `MISO` |

Writes and reads each take two frames, so the design holds `w_addr` and
`r_addr` between frames. [SPI_PROTOCOL.md](SPI_PROTOCOL.md) has the
cycle-accurate timing: which clock edge samples which bit, when `MISO` is
valid, and how long `SS_n` has to stay low for each command.

## Testbench architecture

```text
tb_top ─ spi_if  (pins: rst_n, ss_n, mosi, miso)
       └ ram_if  (probe: rx_valid, rx_data, tx_valid, tx_data)
            │
          test ── environment ─┬─ driver          drives the pins
                               ├─ input_monitor   reconstructs frames from the pins
                               ├─ ram_monitor     reconstructs frames from the RAM interface
                               └─ scoreboard      pairs the two, checks against a memory model
```

`tb_top` builds the interfaces, instantiates the DUT, and runs one `test`.
`test` holds only the scenarios; `environment` owns the components, the
mailboxes and the wiring between them.

Two monitors rather than one is the point of the structure. `input_monitor`
sees what a real SPI master would see, `ram_monitor` sees what the design
handed its RAM, and the scoreboard pairs them frame by frame. A disagreement
means the design decoded something differently from what was sent, which is
distinct from the design decoding correctly but storing the wrong byte.

## What is checked

The scoreboard runs a reference memory alongside the DUT and checks three
things per frame:

- **The two monitors agree.** Same opcode, same payload, pins versus RAM
  interface.
- **Read-after-write.** Whatever the last write put at an address is what a
  read of that address has to return. This is the main functional check.
- **Frame ordering.** A write-data frame with no write-address frame in front
  of it, or a read-data frame with no read-address frame, is reported rather
  than silently modelled.

Reading a location the test never wrote is reported and not failed — the RAM
array powers up with no defined contents, so there is nothing to compare
against.

## Scenarios

All of them live in `tb/test.sv`.

| Scenario | What it goes after |
| ------------------- | ------------------------------------------------------- |
| `simple_wr_rd_seq` | baseline: one write, one read back |
| `data_pattern_seq` | `00 ff 55 aa 01 80 0f f0` — both directions are shift registers, so a stuck bit or an off-by-one shift only shows on asymmetric patterns |
| `addr_boundary_seq` | writes `00 01 7f 80 ff`, reads them back **in reverse** — catches a read that returns the last byte written instead of the addressed one |
| `overwrite_seq` | two write-data frames after one write-address frame: `w_addr` is sticky, the second write has to overwrite |
| `repeated_read_seq` | two read-data frames after one read-address frame — the only stimulus that moves the `read_trans` latch |
| `read_unwritten_seq` | negative control: the scoreboard must report, not fail |
| `reset_survival_seq` | reset mid-test, then read back |
| `random_seq(150)` | broad sweep; addresses pick up the distribution constraint in `transaction` |

Current run: 675 frames, 0 errors.

## Why there is no functional coverage

Verilator 5.032 does not implement SystemVerilog functional coverage. A
covergroup is rejected at elaboration:

```text
%Error-UNSUPPORTED: Unsupported: covergroup
%Error-UNSUPPORTED: Unsupported: cover point
%Error-UNSUPPORTED: Unsupported: cover bin specification
```

`covergroup`, `coverpoint`, `cross` and `bins` are all unsupported, so the
usual coverage model cannot be written. What is available instead is
Verilator's structural coverage — `make coverage` builds with
`--coverage-line --coverage-toggle` and writes annotated sources to
`build/coverage/`. That answers "was this line reached" and "did this signal
toggle", not "was this combination of stimulus exercised", so the scenario
table above is doing the job a coverage model normally would: each scenario
names the protocol state it is there to reach.

## Local RTL fixes

The upstream RTL mixes blocking and non-blocking assignments on `counter`,
`rx_data` and `rx_valid` in `SPI.v`. Verilator rejects that as *unsupported*
rather than warning about it:

```text
%Error-BLKANDNBLK: Unsupported: Blocked and non-blocking assignments to same
variable: 'tb_top.dut.spiBlock.counter'
```

Suppressing the error with `-Wno-BLKANDNBLK` produces a model where `counter`
never resets between frames, so every frame after the first decodes at the
wrong bit offset. The fix is to make those signals consistently non-blocking,
which is also the timing the `counter == 11` MISO decode was written for: one
edge for `rx_valid` to reach the RAM, one for the RAM to present `tx_data`.

Those changes plus the `timescale` directives live in
`patches/spi_slave_ram.patch`. `git submodule update` resets the submodule and
drops them, so `make patch-rtl` re-applies them and `scripts/setup-wsl.sh`
calls it after updating submodules. The target is idempotent.

## Commands

```bash
make setup          # install/check WSL tools and fetch the RTL submodule
make patch-rtl      # re-apply the local fixes to the vendor RTL
make compile        # build the simulator with Verilator
make simulate       # run the testbench and write build/waves/tb_top.fst
make waves          # simulate, then open GTKWave
make lint           # lint RTL and testbench
make coverage       # line and toggle coverage with annotated sources
make check          # lint, simulate, coverage
make clean          # remove generated files
```

`make simulate VERBOSITY=n` controls how much the run prints. Each level
includes the ones above it:

| n | Adds |
| - | ------------------------------------------- |
| 0 | final pass/fail report only |
| 1 | errors and scenario banners |
| 2 | one line per checked frame (default) |
| 3 | component startup and driven transactions |
| 4 | per-clock pin state |

Level 1 is the useful one for CI: eight scenario banners and the result.

### UVM testbench

`tb_uvm/` is the same testbench expressed in UVM: same DUT, same stimulus,
same checks. It has its own targets so the two flows never share a build
directory.

```bash
make compile-uvm    # build the UVM simulator
make simulate-uvm   # run it and write build/waves/tb_top_uvm.fst
make waves-uvm      # simulate, then open GTKWave
make lint-uvm       # lint the UVM testbench
make check-uvm      # lint-uvm, simulate-uvm
```

`UVM_TEST=` picks the test (`spi_base_test`, the default, is the full
regression; `spi_random_test` is 1000 random write/read pairs) and
`UVM_VERBOSITY=UVM_NONE|UVM_LOW|UVM_MEDIUM|UVM_HIGH|UVM_DEBUG` replaces the
`VERBOSITY=n` knob, one level for one level.

Verilator only learned to elaborate UVM in 5.052, which is newer than what
Debian and Ubuntu package. `make setup` builds that version into
`/opt/verilator-5.052` and only the UVM targets use it, so a broken build
there cannot take the `tb/` flow down with it. The CI job still runs `make
check` against the packaged Verilator; it does not build the UVM testbench.

## Layout

```text
tb/spi_pkg.sv         parameters, command enum, verbosity level
tb/transaction.sv     one frame: opcode, address, data
tb/spi_if.sv          pin interface; registers driver requests onto the pins
tb/ram_if.sv          probe interface for the SPI-to-RAM signals
tb/driver.sv          drives frames onto the pins
tb/input_monitor.sv   reconstructs frames from the pins
tb/ram_monitor.sv     reconstructs frames from the RAM interface
tb/scoreboard.sv      pairs both monitors, reference memory, read-after-write
tb/environment.sv     owns components, mailboxes, and the wiring
tb/test.sv            scenarios
tb/tb_top.sv          clock, DUT instance, RAM probe, verbosity plusarg
files.f               source list for Verilator
patches/              local fixes to the vendor RTL
third_party/          upstream RTL and UVM submodules

tb_uvm/spi_uvm_pkg.sv      package: parameters, command enum, includes
tb_uvm/spi_transaction.svh uvm_sequence_item
tb_uvm/spi_driver.svh      uvm_driver
tb_uvm/spi_input_monitor.svh, tb_uvm/ram_monitor.svh  uvm_monitor
tb_uvm/spi_scoreboard.svh  uvm_scoreboard, two analysis fifos
tb_uvm/spi_agent.svh       driver, sequencer, pin monitor
tb_uvm/spi_env.svh         agent, RAM monitor, scoreboard
tb_uvm/spi_seq_lib.svh     one sequence per scenario
tb_uvm/spi_test.svh        uvm_test
tb_uvm/tb_top_uvm.sv       clock, DUT instance, RAM probe, config_db
files_uvm.f                source list for the UVM build
```

`tb_uvm/` reuses `tb/spi_if.sv` and `tb/ram_if.sv` unchanged -- they are
plain RTL interfaces with nothing methodology-specific in them.

Generated files stay under `build/` and are ignored by Git.

## A note on driving the pins

`spi_if` does not let the driver class write the pins directly. The class
writes `drv_rst_n` / `drv_ss_n` / `drv_mosi` and the interface registers those
onto the real pins on the falling clock edge.

That indirection is there for two reasons, both specific to Verilator. Its
driver analysis cannot see writes made through a virtual interface handle, so
pins written that way are reported undriven and get no trace change-detection —
the FST keeps their time-0 value forever and the waveform looks dead even
though the DUT is being driven correctly. And combinational logic reading such
a pin does not re-settle until the following clock edge, which puts a phantom
extra cycle between `SS_n` falling and the DUT leaving `IDLE`. Driving the pins
from ordinary module-scope RTL inside the interface avoids both.
