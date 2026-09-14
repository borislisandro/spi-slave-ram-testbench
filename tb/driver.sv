import spi_pkg::*;

class driver;

  string name = "Driver";
  virtual spi_if dut_if;
  mailbox #(transaction) drv_mbx;
  event drv_done;


  task run();
    $display("t:%0t [%s]Starting", $time, name);
    fork 
      // monitor_signals();
      begin
        $display("t:%0t [%s]Reseting dut", $time, name);
        drive_rst();

        forever begin
          transaction trns;

          $display("t:%0t [%s]Waiting for transactions", $time, name);
          drv_mbx.get(trns);
          trns.print();

          drive_trns(trns);
          ->drv_done;
        end
      end 
    join_none
  endtask: run

  task drive_rst();
    $display("t:%0t [%s]Initilization reset", $time, name);
    @(posedge dut_if.clk);
    dut_if.drv_rst_n <= 1'b0;
    dut_if.drv_mosi <= 1'b0;
    dut_if.drv_ss_n <= 1'b1;
    @(posedge dut_if.clk);

    dut_if.drv_rst_n <= 1'b1;
    repeat(5) @(posedge dut_if.clk);
  endtask: drive_rst

  task drive_trns(transaction trns);
    @(posedge dut_if.clk);

    dut_if.drv_ss_n <= 1'b0;
    dut_if.drv_mosi <= (trns.opcode == WADDR_TRNS) || (trns.opcode == WDATA_TRNS) ? 1'b0 : 1'b1;
    repeat(2) @(posedge dut_if.clk);

    if ((trns.opcode == WADDR_TRNS) || (trns.opcode == RADDR_TRNS)) begin
      for(int i = 0; i < ADDR_WIDTH; i++) begin
        dut_if.drv_mosi <= trns.addr[i];
        @(posedge dut_if.clk);
      end
    end else begin
      for(int i = 0; i < DATA_WIDTH; i++) begin
        dut_if.drv_mosi <= trns.data[i];
        @(posedge dut_if.clk);
      end
    end

    for(int i = 0; i < 2; i++) begin
      dut_if.drv_mosi <= trns.opcode[i];
      @(posedge dut_if.clk);
    end

    if (trns.opcode == RDATA_TRNS) repeat(DATA_WIDTH + 2) @(posedge dut_if.clk);

    dut_if.drv_ss_n <= 1'b1;
    @(posedge dut_if.clk);
  endtask: drive_trns

endclass: driver
