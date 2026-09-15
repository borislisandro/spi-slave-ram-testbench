import spi_pkg::*;

class input_monitor;
  string name = "input_monitor";
  virtual spi_if vif;
  mailbox #(transaction) mbx;

  task run();
    if (verb(VERB_HIGH)) $display("t:%0t [%s]Starting", $time, name);
    fork
      monitor_rst();
      monitor_spi();
    join_none
  endtask: run

  task monitor_rst();
    transaction trns;
    if (verb(VERB_HIGH)) $display("t:%0t [%s]Starting rst input_monitor", $time, name);
    forever begin
      @(negedge vif.rst_n);
      trns = new();
      trns.mon_rst_flag = 1'b1;
      mbx.put(trns);
    end
  endtask: monitor_rst

  task monitor_spi();
    transaction trns;
    if (verb(VERB_HIGH)) $display("t:%0t [%s]Starting SPI input_monitor", $time, name);
    forever begin
      //wait until ss is low
      @(negedge vif.ss_n);
      trns = new();
      monitor_cmd(trns);
      //Send to SB
      mbx.put(trns);
    end
  endtask: monitor_spi

  task monitor_cmd(transaction trns);
    bit [7:0] data;
    bit [1:0] opcode;

    repeat(3)@(posedge vif.clk);

    //get addr/data
    for(int i = 0; i < ADDR_WIDTH; i++) begin
      data[i] = vif.mosi;
      @(posedge vif.clk);
    end

    //get opcode
    for(int i = 0; i < 2; i++) begin
      opcode[i] = vif.mosi;
      @(posedge vif.clk);
    end

    trns.opcode = cmd_type'(opcode);
    if(opcode != RDATA_TRNS) begin
      if(opcode != WDATA_TRNS) trns.addr = data;
      else                     trns.data = data;
    end else begin
      repeat(2) @(posedge vif.clk);

      for(int i = 0; i < DATA_WIDTH; i++) begin
        data[i] = vif.miso;
        @(posedge vif.clk);
      end

      trns.data = data;
    end
  endtask: monitor_cmd
endclass: input_monitor
