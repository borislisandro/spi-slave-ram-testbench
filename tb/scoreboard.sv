import spi_pkg::*;

class scoreboard;

  string name = "scoreboard";
  mailbox #(transaction) input_mbx;
  mailbox #(transaction) ram_mbx;

  bit [DATA_WIDTH-1:0] mem       [2**ADDR_WIDTH];
  bit                  mem_valid [2**ADDR_WIDTH];

  bit [ADDR_WIDTH-1:0] w_addr;
  bit [ADDR_WIDTH-1:0] r_addr;
  bit                  w_addr_set;
  bit                  r_addr_set;

  int frames;
  int errors;

  task run();
    $display("t:%0t [%s]Starting", $time, name);
    fork
      compare();
    join_none
  endtask: run

  task compare();
    transaction in_trns;
    transaction ram_trns;

    forever begin
      // The input monitor is the one that reports a reset, and no RAM-side
      // frame pairs with it, so handle it before reaching for the other
      // mailbox or the two streams drift apart by one.
      input_mbx.get(in_trns);
      if (in_trns.mon_rst_flag) begin
        reset_model();
        continue;
      end

      ram_mbx.get(ram_trns);
      frames++;

      check_monitors_agree(in_trns, ram_trns);
      check_and_update_model(in_trns);
    end
  endtask: compare

  function void check_monitors_agree(transaction in_trns, transaction ram_trns);
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
  function void check_and_update_model(transaction trns);
    case (trns.opcode)
      WADDR_TRNS: begin
        w_addr     = trns.addr;
        w_addr_set = 1'b1;
        $display("t:%0t [%s] WADDR  addr=0x%02h", $time, name, trns.addr);
      end

      WDATA_TRNS: begin
        if (!w_addr_set) begin
          report_error("WDATA frame with no WADDR frame before it");
        end else begin
          mem[w_addr]       = trns.data;
          mem_valid[w_addr] = 1'b1;
          $display("t:%0t [%s] WDATA  mem[0x%02h] <= 0x%02h", $time, name, w_addr, trns.data);
        end
      end

      RADDR_TRNS: begin
        r_addr     = trns.addr;
        r_addr_set = 1'b1;
        $display("t:%0t [%s] RADDR  addr=0x%02h", $time, name, trns.addr);
      end

      RDATA_TRNS: begin
        if (!r_addr_set) begin
          report_error("RDATA frame with no RADDR frame before it");
        end else if (!mem_valid[r_addr]) begin
          $display("t:%0t [%s] RDATA  mem[0x%02h] never written, read 0x%02h, not checked",
                   $time, name, r_addr, trns.data);
        end else if (trns.data !== mem[r_addr]) begin
          report_error($sformatf("read-after-write mismatch at 0x%02h: wrote 0x%02h, read back 0x%02h",
                                 r_addr, mem[r_addr], trns.data));
        end else begin
          $display("t:%0t [%s] RDATA  mem[0x%02h] => 0x%02h  MATCH", $time, name, r_addr, trns.data);
        end
      end
    endcase
  endfunction: check_and_update_model

  function void reset_model();
    foreach (mem_valid[i]) mem_valid[i] = 1'b0;
    w_addr_set = 1'b0;
    r_addr_set = 1'b0;
    $display("t:%0t [%s] reset, reference memory cleared", $time, name);
  endfunction: reset_model

  function void report_error(string message);
    errors++;
    $display("t:%0t [%s] ERROR: %0s", $time, name, message);
  endfunction: report_error

  function void report();
    $display("t:%0t [%s] %0d frames checked, %0d errors", $time, name, frames, errors);
    if (errors == 0) $display("t:%0t [%s] TEST PASSED", $time, name);
    else             $display("t:%0t [%s] TEST FAILED", $time, name);
  endfunction: report

endclass: scoreboard
