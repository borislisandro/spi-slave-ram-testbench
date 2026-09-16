package spi_uvm_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;

  parameter int ADDR_WIDTH = 8;
  parameter int DATA_WIDTH = 8;

  typedef enum bit [1:0] {
    WADDR_TRNS = 0,
    WDATA_TRNS = 1,
    RADDR_TRNS = 2,
    RDATA_TRNS = 3
  } cmd_type;

  `include "spi_transaction.svh"
  `include "spi_driver.svh"
  `include "spi_input_monitor.svh"
  `include "ram_monitor.svh"
  `include "spi_scoreboard.svh"
  `include "spi_agent.svh"
  `include "spi_env.svh"
  `include "spi_seq_lib.svh"
  `include "spi_test.svh"

endpackage: spi_uvm_pkg
