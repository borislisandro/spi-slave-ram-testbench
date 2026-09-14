import spi_pkg::*;

class monitor;
  string name = "Monitor";
  virtual spi_if dut_if;
  mailbox #(transaction) mon_mbx;

  task run();
    $display("t:%0t [%s]Starting", $time, name);
    fork
      monitor_rst();
      monitor_spi();
    join_none
  endtask: run

  task monitor_rst();
    transaction trns;
    $display("t:%0t [%s]Starting rst monitor", $time, name);
    forever begin
      @(negedge dut_if.rst_n);
      trns = new();
      trns.mon_rst_flag = 1'b1;
      mon_mbx.put(trns);
    end
  endtask: monitor_rst

  task monitor_spi();
    transaction trns;
    bit rdwr; // 0 - rd  1 - wr
    $display("t:%0t [%s]Starting SPI monitor", $time, name);
    forever begin
      //wait until ss is low
      @(negedge dut_if.ss_n);
      trns = new();
      // monitor_cmd already returns after the last edge of the frame, and SS_n
      // is high again by then. Waiting for its rising edge here blocks until
      // the *next* frame ends, which reports every frame one frame late and
      // loses the frame that starts while blocked.
      monitor_cmd(trns);
      //Send to SB
      mon_mbx.put(trns);
    end
  endtask: monitor_spi

  task monitor_cmd(transaction trns);
    bit [7:0] data;
    bit [1:0] opcode;

    // SS_n falls on a falling clock edge, so three rising edges land on the one
    // that samples the first payload bit: the first takes the DUT out of IDLE,
    // the second samples the mode bit.
    repeat(3)@(posedge dut_if.clk);

    //get addr/data
    for(int i = 0; i < ADDR_WIDTH; i++) begin
      data[i] = dut_if.mosi;
      @(posedge dut_if.clk);
    end

    //get opcode
    for(int i = 0; i < 2; i++) begin
      opcode[i] = dut_if.mosi;
      @(posedge dut_if.clk);
    end

    trns.opcode = cmd_type'(opcode);
    if(opcode != RDATA_TRNS) begin
      if(opcode != WDATA_TRNS) trns.addr = data;
      else                     trns.data = data;
    end else begin
      //get data from RDATA_TRNS
      // One edge hands rx_data to the RAM and the next puts the first bit on
      // MISO, so the first bit can only be sampled two edges on from here.
      repeat(2) @(posedge dut_if.clk);

      for(int i = 0; i < DATA_WIDTH; i++) begin
        data[i] = dut_if.miso;
        @(posedge dut_if.clk);
      end

      trns.data = data;
    end
  endtask: monitor_cmd
endclass: monitor
