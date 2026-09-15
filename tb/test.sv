import spi_pkg::*;

class test;

  string name = "test";

  //vifs
  virtual spi_if dut_vif;
  virtual ram_if ram_vif;

  environment env;

  function new();
    env = new();
  endfunction: new

  virtual task run();
    if (verb(VERB_HIGH)) $display("t:%0t [%s]Starting", $time, name);
    env.dut_vif = dut_vif;
    env.ram_vif = ram_vif;

    //components fork join_none, so this returns once they are running
    env.run();

    simple_wr_rd_seq();
    data_pattern_seq();
    addr_boundary_seq();
    overwrite_seq();
    repeated_read_seq();
    // has to run before anything that might write 0x3c
    read_unwritten_seq();
    reset_survival_seq();
    random_seq(150);
  endtask: run

  // Called from tb_top once the sequence has drained.
  function void report();
    env.report();
  endfunction: report


  task send_frame(cmd_type opcode, bit [ADDR_WIDTH-1:0] addr, bit [DATA_WIDTH-1:0] data);
    transaction trns;
    trns = new();
    trns.opcode = opcode;
    trns.addr   = addr;
    trns.data   = data;
    env.send(trns);
  endtask: send_frame

  task write_byte(bit [ADDR_WIDTH-1:0] addr, bit [DATA_WIDTH-1:0] data);
    send_frame(WADDR_TRNS, addr, '0);
    send_frame(WDATA_TRNS, '0, data);
  endtask: write_byte

  task read_byte(bit [ADDR_WIDTH-1:0] addr);
    send_frame(RADDR_TRNS, addr, '0);
    send_frame(RDATA_TRNS, '0, '0);
  endtask: read_byte

  // one write, one read back.
  task simple_wr_rd_seq();
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- simple_wr_rd_seq ---", $time, name);
    write_byte(8'hf0, 8'h55);
    read_byte(8'hf0);
  endtask: simple_wr_rd_seq

  // Both directions are 8-bit shift registers, so a stuck bit or an
  // off-by-one shift only shows up on patterns that are not symmetric.
  // 0x55/0xaa catch adjacent-bit coupling, the walking one catches a bit
  // that never moves, 0x00/0xff catch a line stuck at the other rail.
  task data_pattern_seq();
    bit [DATA_WIDTH-1:0] patterns [8] = '{8'h00, 8'hff, 8'h55, 8'haa,
                                          8'h01, 8'h80, 8'h0f, 8'hf0};
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- data_pattern_seq ---", $time, name);
    foreach (patterns[i]) begin
      write_byte(8'h20, patterns[i]);
      read_byte(8'h20);
    end
  endtask: data_pattern_seq

  // Writes spread across the address range, then reads them back in reverse.
  task addr_boundary_seq();
    bit [ADDR_WIDTH-1:0] addrs [5] = '{8'h00, 8'h01, 8'h7f, 8'h80, 8'hff};
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- addr_boundary_seq ---", $time, name);
    foreach (addrs[i]) write_byte(addrs[i], addrs[i] ^ 8'h5a);
    for (int i = $size(addrs) - 1; i >= 0; i--) read_byte(addrs[i]);
  endtask: addr_boundary_seq

  // w_addr is a register inside the RAM, so a second WDATA frame with no
  // WADDR in front of it has to land at the same address and overwrite.
  task overwrite_seq();
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- overwrite_seq ---", $time, name);
    send_frame(WADDR_TRNS, 8'h40, '0);
    send_frame(WDATA_TRNS, '0, 8'h11);
    send_frame(WDATA_TRNS, '0, 8'h22);
    read_byte(8'h40);
  endtask: overwrite_seq

  // Mirror of the above on the read side, and the only stimulus that
  // exercises the read_trans latch.
  task repeated_read_seq();
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- repeated_read_seq ---", $time, name);
    write_byte(8'h50, 8'h3c);
    send_frame(RADDR_TRNS, 8'h50, '0);
    send_frame(RDATA_TRNS, '0, '0);
    send_frame(RDATA_TRNS, '0, '0);
  endtask: repeated_read_seq

  // Negative control. The RAM array powers up unwritten, so the scoreboard
  // has nothing to compare against and must say so instead of failing.
  task read_unwritten_seq();
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- read_unwritten_seq ---", $time, name);
    read_byte(8'h3c);
  endtask: read_unwritten_seq

  // Reset clears dout and tx_valid in the RAM and the shift state in the SPI
  // block, but the RAM array and its w_addr / r_addr registers have no reset.
  task reset_survival_seq();
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- reset_survival_seq ---", $time, name);
    write_byte(8'h60, 8'h7e);
    read_byte(8'h60);

    env.reset();

    read_byte(8'h60);
    send_frame(RDATA_TRNS, '0, '0);
  endtask: reset_survival_seq

  // Broad sweep. addr picks up the dist constraint in transaction, which
  // weights the 0x00 and 0xff ends of the range.
  task random_seq(int unsigned count);
    transaction trns;
    if (verb(VERB_LOW)) $display("t:%0t [%s] --- random_seq ---", $time, name);
    for (int unsigned i = 0; i < count; i++) begin
      trns = new();
      if (trns.randomize() == 0) $fatal(1, "randomize failed");
      write_byte(trns.addr, trns.data);
      read_byte(trns.addr);
    end
  endtask: random_seq

endclass: test
