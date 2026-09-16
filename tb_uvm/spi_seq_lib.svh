// One sequence per scenario from tb/test.sv, plus spi_full_seq which runs
// them in the same order. finish_item() returning is the driver's item_done,
// so every frame is complete on the pins before the next one is built.

virtual class spi_base_seq extends uvm_sequence #(spi_transaction);

  function new(string name = "spi_base_seq");
    super.new(name);
  endfunction: new

  task banner(string text);
    `uvm_info(get_type_name(), $sformatf("--- %0s ---", text), UVM_LOW)
  endtask: banner

  task send_frame(cmd_type opcode, bit [ADDR_WIDTH-1:0] addr, bit [DATA_WIDTH-1:0] data);
    spi_transaction trns;
    trns = spi_transaction::type_id::create("trns");
    start_item(trns);
    trns.opcode = opcode;
    trns.addr   = addr;
    trns.data   = data;
    finish_item(trns);
  endtask: send_frame

  task write_byte(bit [ADDR_WIDTH-1:0] addr, bit [DATA_WIDTH-1:0] data);
    send_frame(WADDR_TRNS, addr, '0);
    send_frame(WDATA_TRNS, '0, data);
  endtask: write_byte

  task read_byte(bit [ADDR_WIDTH-1:0] addr);
    send_frame(RADDR_TRNS, addr, '0);
    send_frame(RDATA_TRNS, '0, '0);
  endtask: read_byte

  // Re-assert reset mid test. The driver is parked on the sequencer between
  // frames, so nothing else is touching the pins when this lands.
  task do_reset();
    spi_transaction trns;
    trns = spi_transaction::type_id::create("rst");
    start_item(trns);
    trns.do_reset = 1'b1;
    finish_item(trns);
  endtask: do_reset

endclass: spi_base_seq


// one write, one read back.
class simple_wr_rd_seq extends spi_base_seq;
  `uvm_object_utils(simple_wr_rd_seq)
  function new(string name = "simple_wr_rd_seq"); super.new(name); endfunction

  task body();
    banner("simple_wr_rd_seq");
    write_byte(8'hf0, 8'h55);
    read_byte(8'hf0);
  endtask: body
endclass: simple_wr_rd_seq


// Both directions are 8-bit shift registers, so a stuck bit or an
// off-by-one shift only shows up on patterns that are not symmetric.
// 0x55/0xaa catch adjacent-bit coupling, the walking one catches a bit
// that never moves, 0x00/0xff catch a line stuck at the other rail.
class data_pattern_seq extends spi_base_seq;
  `uvm_object_utils(data_pattern_seq)
  function new(string name = "data_pattern_seq"); super.new(name); endfunction

  task body();
    bit [DATA_WIDTH-1:0] patterns [8] = '{8'h00, 8'hff, 8'h55, 8'haa,
                                          8'h01, 8'h80, 8'h0f, 8'hf0};
    banner("data_pattern_seq");
    foreach (patterns[i]) begin
      write_byte(8'h20, patterns[i]);
      read_byte(8'h20);
    end
  endtask: body
endclass: data_pattern_seq


// Writes spread across the address range, then reads them back in reverse.
class addr_boundary_seq extends spi_base_seq;
  `uvm_object_utils(addr_boundary_seq)
  function new(string name = "addr_boundary_seq"); super.new(name); endfunction

  task body();
    bit [ADDR_WIDTH-1:0] addrs [5] = '{8'h00, 8'h01, 8'h7f, 8'h80, 8'hff};
    banner("addr_boundary_seq");
    foreach (addrs[i]) write_byte(addrs[i], addrs[i] ^ 8'h5a);
    for (int i = $size(addrs) - 1; i >= 0; i--) read_byte(addrs[i]);
  endtask: body
endclass: addr_boundary_seq


// w_addr is a register inside the RAM, so a second WDATA frame with no
// WADDR in front of it has to land at the same address and overwrite.
class overwrite_seq extends spi_base_seq;
  `uvm_object_utils(overwrite_seq)
  function new(string name = "overwrite_seq"); super.new(name); endfunction

  task body();
    banner("overwrite_seq");
    send_frame(WADDR_TRNS, 8'h40, '0);
    send_frame(WDATA_TRNS, '0, 8'h11);
    send_frame(WDATA_TRNS, '0, 8'h22);
    read_byte(8'h40);
  endtask: body
endclass: overwrite_seq


// Mirror of the above on the read side, and the only stimulus that
// exercises the read_trans latch.
class repeated_read_seq extends spi_base_seq;
  `uvm_object_utils(repeated_read_seq)
  function new(string name = "repeated_read_seq"); super.new(name); endfunction

  task body();
    banner("repeated_read_seq");
    write_byte(8'h50, 8'h3c);
    send_frame(RADDR_TRNS, 8'h50, '0);
    send_frame(RDATA_TRNS, '0, '0);
    send_frame(RDATA_TRNS, '0, '0);
  endtask: body
endclass: repeated_read_seq


// Negative control. The RAM array powers up unwritten, so the scoreboard
// has nothing to compare against and must say so instead of failing.
class read_unwritten_seq extends spi_base_seq;
  `uvm_object_utils(read_unwritten_seq)
  function new(string name = "read_unwritten_seq"); super.new(name); endfunction

  task body();
    banner("read_unwritten_seq");
    read_byte(8'h3c);
  endtask: body
endclass: read_unwritten_seq


// Reset clears dout and tx_valid in the RAM and the shift state in the SPI
// block, but the RAM array and its w_addr / r_addr registers have no reset.
class reset_survival_seq extends spi_base_seq;
  `uvm_object_utils(reset_survival_seq)
  function new(string name = "reset_survival_seq"); super.new(name); endfunction

  task body();
    banner("reset_survival_seq");
    write_byte(8'h60, 8'h7e);
    read_byte(8'h60);

    do_reset();

    read_byte(8'h60);
    send_frame(RDATA_TRNS, '0, '0);
  endtask: body
endclass: reset_survival_seq


// Broad sweep. addr picks up the dist constraint in spi_transaction, which
// weights the 0x00 and 0xff ends of the range.
class random_seq extends spi_base_seq;
  `uvm_object_utils(random_seq)
  function new(string name = "random_seq"); super.new(name); endfunction

  int unsigned count = 150;

  task body();
    spi_transaction trns;
    banner("random_seq");
    for (int unsigned i = 0; i < count; i++) begin
      trns = spi_transaction::type_id::create("rand_trns");
      if (!trns.randomize()) `uvm_fatal(get_type_name(), "randomize failed")
      write_byte(trns.addr, trns.data);
      read_byte(trns.addr);
    end
  endtask: body
endclass: random_seq


// The whole regression, in the order tb/test.sv ran it.
class spi_full_seq extends spi_base_seq;
  `uvm_object_utils(spi_full_seq)
  function new(string name = "spi_full_seq"); super.new(name); endfunction

  task body();
    simple_wr_rd_seq   s0;
    data_pattern_seq   s1;
    addr_boundary_seq  s2;
    overwrite_seq      s3;
    repeated_read_seq  s4;
    read_unwritten_seq s5;
    reset_survival_seq s6;
    random_seq         s7;

    s0 = simple_wr_rd_seq::type_id::create("s0");     s0.start(m_sequencer, this);
    s1 = data_pattern_seq::type_id::create("s1");     s1.start(m_sequencer, this);
    s2 = addr_boundary_seq::type_id::create("s2");    s2.start(m_sequencer, this);
    s3 = overwrite_seq::type_id::create("s3");        s3.start(m_sequencer, this);
    s4 = repeated_read_seq::type_id::create("s4");    s4.start(m_sequencer, this);
    // has to run before anything that might write 0x3c
    s5 = read_unwritten_seq::type_id::create("s5");   s5.start(m_sequencer, this);
    s6 = reset_survival_seq::type_id::create("s6");   s6.start(m_sequencer, this);
    s7 = random_seq::type_id::create("s7");           s7.start(m_sequencer, this);
  endtask: body
endclass: spi_full_seq
