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

## SPI-to-RAM interface

```text
rx_data[9:8] = command
rx_data[7:0] = address or data
rx_valid     = rx_data is ready

tx_data[7:0] = byte read from RAM
tx_valid     = tx_data is ready for MISO
```
