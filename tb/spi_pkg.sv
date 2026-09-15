package spi_pkg;

  parameter int ADDR_WIDTH = 8;
  parameter int DATA_WIDTH = 8;

  typedef enum bit [1:0] {
    WADDR_TRNS = 0,
    WDATA_TRNS = 1,
    RADDR_TRNS = 2,
    RDATA_TRNS = 3
  } cmd_type;

  // Message verbosity. tb_top sets this from +VERBOSITY=<n> before the test
  // starts, and nothing else writes it. Each level includes the ones above it.
  typedef enum int {
    VERB_NONE   = 0,  // final pass / fail report only
    VERB_LOW    = 1,  // + errors and scenario banners
    VERB_MEDIUM = 2,  // + one line per checked frame
    VERB_HIGH   = 3,  // + component startup and driven transactions
    VERB_DEBUG  = 4   // + per clock pin state
  } verbosity_e;

  verbosity_e verbosity = VERB_MEDIUM;

  // Guard for a $display: `if (verb(VERB_HIGH)) $display(...)`.
  function automatic bit verb(verbosity_e level);
    return (level <= verbosity);
  endfunction: verb

endpackage: spi_pkg
