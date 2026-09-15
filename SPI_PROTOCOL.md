# SPI RAM Protocol

## Sizes

- Address: 8 bits
- Data: 8 bits
- Command: 2 bits
- MOSI frame: 1 mode bit followed by a 10-bit command frame
- MISO response: 8 bits

All multi-bit values are transferred least-significant bit first.

## MOSI frame

```text
mode, value[0], value[1], ... value[7], command[0], command[1]
```

The logical 10-bit command frame is:

```text
[9:8] command | [7:0] address, data, or ignored value
```

## Write one byte

1. Pull `SS_n` low.
2. Send mode `0`, command `00`, and the 8-bit write address.
3. Pull `SS_n` high.
4. Pull `SS_n` low again.
5. Send mode `0`, command `01`, and the 8-bit data.
6. Pull `SS_n` high. RAM writes the data at the saved address.

## Read one byte

1. Pull `SS_n` low.
2. Send mode `1`, command `10`, and the 8-bit read address.
3. Pull `SS_n` high.
4. Pull `SS_n` low again.
5. Send mode `1`, command `11`, and 8 ignored bits, normally zero.
6. Read 8 data bits from `MISO`, least-significant bit first.
7. Pull `SS_n` high.

`CHK_CMD` sends mode `1` to `READ_ADD` unless the DUT's internal `read_trans`
latch is already set, and only a read-address frame sets it. That choice of
state does not change what comes back: `READ_ADD`, `READ_DATA` and `WRITE` all
shift identically, and the RAM decodes the command from `rx_data[9:8]` rather
than from the state. So a read-data frame with no read-address frame in front
of it still returns `ram[r_addr]` — it just walks through `READ_ADD` on the
way, and `r_addr` keeps whatever the last read-address frame put there.

## Cycle timing

Everything is sampled and driven on the rising edge of `clk`. Edge 1 below is
the first rising edge with `SS_n` already low; `counter` is the DUT's internal
bit counter as it stands *before* that edge.

| Edge | State entering the edge | `counter` | MOSI sampled     | MISO after the edge |
| ---- | ----------------------- | --------- | ---------------- | ------------------- |
| 1    | `IDLE`                  | 0         | ignored          | held                |
| 2    | `CHK_CMD`               | 0         | **mode bit**     | held                |
| 3    | data state              | 0         | `value[0]`       | held                |
| 4    | data state              | 1         | `value[1]`       | held                |
| ...  | data state              | ...       | ...              | held                |
| 10   | data state              | 7         | `value[7]`       | held                |
| 11   | data state              | 8         | `command[0]`     | held                |
| 12   | data state              | 9         | `command[1]`     | held                |
| 13   | data state              | 10        | ignored          | held                |
| 14   | data state              | 11        | ignored          | `tx_data[0]`        |
| 15   | data state              | 12        | ignored          | `tx_data[1]`        |
| ...  | data state              | ...       | ignored          | ...                 |
| 21   | data state              | 18        | ignored          | `tx_data[7]`        |

Two edges are spent before any payload bit: edge 1 moves the DUT from `IDLE`
to `CHK_CMD`, edge 2 samples the mode bit and picks the write, read-address or
read-data state. A master that starts the 10-bit frame on edge 2 loses
`value[0]`, which shifts the whole frame and lands `command` as
`{command[1], command[1]}` — write-data then decodes as write-address and
read-address as read-data.

`rx_valid` asserts on edge 12, the RAM captures `rx_data` on edge 13, and
`tx_data` / `tx_valid` are ready for edge 14.

### How long `SS_n` must stay low

- Write address, write data, read address: through **edge 13**, so the RAM
  captures `rx_data`. `SS_n` may rise for edge 14.
- Read data: through **edge 21** to put the last bit on `MISO`, plus **edge
  22** for the master to sample it. `SS_n` may rise for edge 23.

Releasing `SS_n` earlier on a read-data frame is why `MISO` looks stuck: the
DUT never reaches the counter values that drive it.

## MISO

`MISO` is a register the DUT only writes while `tx_valid` is high, so:

- During write-address, write-data and read-address frames it is **not driven
  and holds its previous value**. It is `0` only because reset left it there.
- It carries real data on edges 14 to 21 of a read-data frame, least
  significant bit first. The master samples each bit on the following edge.
- `tx_valid` stays high after a read until the next write-address,
  write-data or read-address frame clears it.

## SPI-to-RAM interface

```text
rx_data[9:8] = command
rx_data[7:0] = address or data
rx_valid     = rx_data is ready

tx_data[7:0] = byte read from RAM
tx_valid     = tx_data is ready for MISO
```

## Local RTL fixes

The vendor RTL in `third_party/spi_slave_ram` mixes blocking and non-blocking
assignments on `counter`, `rx_data` and `rx_valid`. Verilator rejects that as
unsupported rather than as a style warning, and suppressing the error produces
a model where `counter` never resets between frames, so every frame after the
first decodes at the wrong bit offset. The local patch makes those signals
consistently non-blocking, which is also the timing the `counter == 11` MISO
decode was written for: one edge for `rx_valid` to reach the RAM, one for the
RAM to present `tx_data`.

`patches/spi_slave_ram.patch` holds those changes plus the `timescale`
directives. `git submodule update` resets the submodule and drops them, so
`make patch-rtl` re-applies them and `scripts/setup-wsl.sh` calls it after
updating submodules.
