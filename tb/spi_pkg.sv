package spi_pkg;

  parameter int ADDR_WIDTH = 8;
  parameter int DATA_WIDTH = 8;

  typedef enum bit [1:0] {
    WADDR_TRNS = 0,
    WDATA_TRNS = 1,
    RADDR_TRNS = 2,
    RDATA_TRNS = 3
  } cmd_type;

endpackage: spi_pkg
