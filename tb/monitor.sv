import spi_pkg::*;

class monitor;
  string name = "Monitor";
  virtual spi_if dut_if;
  mailbox #(transaction) mon_mbx;

  //aux vars
  bit [7:0] data;
  bit [1:0] opcode;

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
      monitor_cmd(trns);
      @(posedge dut_if.ss_n);
      //Send to SB
      mon_mbx.put(trns);
    end
  endtask: monitor_spi

  task monitor_cmd(transaction trns);
    repeat(3)@(posedge dut_if.clk);
    
    //get addr/data
    for(int i = 0; i < ADDR_WIDTH; i++) begin
      data[i] <= dut_if.mosi;
      @(posedge dut_if.clk);
    end

    //get opcode
    for(int i = 0; i < 2; i++) begin
      opcode[i] <= dut_if.mosi;
      @(posedge dut_if.clk);
    end

    trns.opcode <= cmd_type'(this.opcode);
    if(opcode != RDATA_TRNS) begin
      if(opcode != WDATA_TRNS) trns.addr <= this.data;
      else                     trns.data <= this.data;
    end else begin
      //get data from RDATA_TRNS
      @(posedge dut_if.clk);

      for(int i = 0; i < DATA_WIDTH; i++) begin
        data[i] <= dut_if.miso;
        @(posedge dut_if.clk);
      end
    end


  endtask: monitor_cmd
endclass: monitor