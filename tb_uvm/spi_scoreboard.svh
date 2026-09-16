class spi_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(spi_scoreboard)

  // Analysis fifos rather than imps: the check is order sensitive across two
  // streams, so it wants a blocking get on each, not two write callbacks.
  uvm_tlm_analysis_fifo #(spi_transaction) input_fifo;
  uvm_tlm_analysis_fifo #(spi_transaction) ram_fifo;

  bit [DATA_WIDTH-1:0] mem       [2**ADDR_WIDTH];
  bit                  mem_valid [2**ADDR_WIDTH];

  bit [ADDR_WIDTH-1:0] w_addr;
  bit [ADDR_WIDTH-1:0] r_addr;
  bit                  w_addr_set;
  bit                  r_addr_set;

  int frames;
  int errors;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    input_fifo = new("input_fifo", this);
    ram_fifo   = new("ram_fifo", this);
  endfunction: new

  task run_phase(uvm_phase phase);
    spi_transaction in_trns;
    spi_transaction ram_trns;

    `uvm_info(get_type_name(), "starting", UVM_HIGH)

    forever begin
      input_fifo.get(in_trns);
      if (in_trns.mon_rst_flag) begin
        reset_model();
        continue;
      end

      ram_fifo.get(ram_trns);
      frames++;

      check_monitors_agree(in_trns, ram_trns);
      check_and_update_model(in_trns);
    end
  endtask: run_phase

  function void check_monitors_agree(spi_transaction in_trns, spi_transaction ram_trns);
    if (in_trns.opcode !== ram_trns.opcode) begin
      report_error($sformatf("opcode mismatch: pins saw %0s, ram interface saw %0s",
                             in_trns.opcode.name(), ram_trns.opcode.name()));
      return;
    end

    case (in_trns.opcode)
      WADDR_TRNS, RADDR_TRNS:
        if (in_trns.addr !== ram_trns.addr)
          report_error($sformatf("%0s address mismatch: pins saw 0x%02h, ram interface saw 0x%02h",
                                 in_trns.opcode.name(), in_trns.addr, ram_trns.addr));
      WDATA_TRNS, RDATA_TRNS:
        if (in_trns.data !== ram_trns.data)
          report_error($sformatf("%0s data mismatch: pins saw 0x%02h, ram interface saw 0x%02h",
                                 in_trns.opcode.name(), in_trns.data, ram_trns.data));
    endcase
  endfunction: check_monitors_agree

  // Replays the frame against the reference memory. The read-after-write check
  // lives in the RDATA branch: whatever the last write put at this address is
  // what the read has to return.
  function void check_and_update_model(spi_transaction trns);
    case (trns.opcode)
      WADDR_TRNS: begin
        w_addr     = trns.addr;
        w_addr_set = 1'b1;
        `uvm_info(get_type_name(), $sformatf("WADDR  addr=0x%02h", trns.addr), UVM_MEDIUM)
      end

      WDATA_TRNS: begin
        if (!w_addr_set) begin
          report_error("WDATA frame with no WADDR frame before it");
        end else begin
          mem[w_addr]       = trns.data;
          mem_valid[w_addr] = 1'b1;
          `uvm_info(get_type_name(), $sformatf("WDATA  mem[0x%02h] <= 0x%02h", w_addr, trns.data), UVM_MEDIUM)
        end
      end

      RADDR_TRNS: begin
        r_addr     = trns.addr;
        r_addr_set = 1'b1;
        `uvm_info(get_type_name(), $sformatf("RADDR  addr=0x%02h", trns.addr), UVM_MEDIUM)
      end

      RDATA_TRNS: begin
        if (!r_addr_set) begin
          report_error("RDATA frame with no RADDR frame before it");
        end else if (!mem_valid[r_addr]) begin
          `uvm_info(get_type_name(), $sformatf("RDATA  mem[0x%02h] never written, read 0x%02h, not checked",
                                               r_addr, trns.data), UVM_MEDIUM)
        end else if (trns.data !== mem[r_addr]) begin
          report_error($sformatf("read-after-write mismatch at 0x%02h: wrote 0x%02h, read back 0x%02h",
                                 r_addr, mem[r_addr], trns.data));
        end else begin
          `uvm_info(get_type_name(), $sformatf("RDATA  mem[0x%02h] => 0x%02h  MATCH",
                                               r_addr, trns.data), UVM_MEDIUM)
        end
      end
    endcase
  endfunction: check_and_update_model

  // Nothing the model tracks is cleared by reset. In the RAM only dout and
  // tx_valid have a reset branch: the memory array and the w_addr / r_addr
  // registers have none, so contents and both address latches survive. The
  // SPI block does clear its shift state and its read_trans latch, but that
  // only changes which state a read command walks through, not what the RAM
  // decodes from the command bits.
  function void reset_model();
    `uvm_info(get_type_name(), "reset seen, reference memory kept", UVM_MEDIUM)
  endfunction: reset_model

  function void report_error(string message);
    errors++;
    `uvm_error(get_type_name(), message)
  endfunction: report_error

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf("%0d frames checked, %0d errors", frames, errors), UVM_NONE)
    if (errors == 0) `uvm_info(get_type_name(), "TEST PASSED", UVM_NONE)
    else             `uvm_info(get_type_name(), "TEST FAILED", UVM_NONE)
  endfunction: report_phase

endclass: spi_scoreboard
