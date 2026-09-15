import spi_pkg::*;

class ram_monitor;
  string name = "ram_monitor";
  virtual ram_if vif;
  mailbox #(transaction) mbx;

  task run();
    $display("t:%0t [%s]Starting", $time, name);
    fork
      monitor_ram();
    join_none
  endtask: run

  task monitor_ram();
    transaction trns;
    $display("t:%0t [%s]Starting SPI ram_monitor", $time, name);
    forever begin
      //wait until ss is low
      trns = new();
      monitor_cmd(trns);
      //Send to SB
      mbx.put(trns);
    end
  endtask: monitor_ram

  task monitor_cmd(transaction trns);
    bit [7:0] data;
    bit [1:0] opcode;

    @(posedge vif.rx_valid);
    opcode = vif.rx_data[9:8];
    data   = vif.rx_data[7:0];

    trns.opcode = cmd_type'(opcode);
    if (opcode != RDATA_TRNS) begin
      if (opcode != WDATA_TRNS) trns.addr = data;
      else                      trns.data = data;
    end else begin
      repeat(2) @(posedge vif.clk);
      trns.data = vif.tx_data;
    end
  endtask: monitor_cmd
endclass: ram_monitor
