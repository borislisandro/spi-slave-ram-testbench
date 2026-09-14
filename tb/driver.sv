import spi_pkg::*;

class driver;

  string name = "Driver";
  virtual spi_if dut_if;
  mailbox #(transaction) drv_mbx;
  event drv_done;


  task run();
    fork 
      monitor_signals();
      begin
        $display("t:%0t [%s]Reseting dut", $time, name);
        drive_rst();

        $display("t:%0t [%s]Running", $time, name);
        @(posedge dut_if.clk);

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
    dut_if.rst_n <= 1'b0;
    dut_if.mosi <= 1'b0;
    dut_if.ss_n <= 1'b1;
    @(posedge dut_if.clk);

    dut_if.rst_n <= 1'b1;
    repeat(5) @(posedge dut_if.clk);
  endtask: drive_rst

  task drive_trns(transaction trns);
    //SS and mode
    dut_if.ss_n <= 1'b0;
    dut_if.mosi <= (trns.opcode == WADDR_TRNS) || (trns.opcode == WDATA_TRNS) ? 1'b0 : 1'b1;
    @(posedge dut_if.clk);

    if ((trns.opcode == WADDR_TRNS) || (trns.opcode == RADDR_TRNS)) begin
      // waddr or raddr cmd
      for(int i = 0; i < ADDR_WIDTH; i++) begin
        dut_if.mosi <= trns.addr[i];
        @(posedge dut_if.clk);
      end
    end else begin
      //wdata or rdata cmd
      for(int i = 0; i < DATA_WIDTH; i++) begin
        dut_if.mosi <= trns.data[i];
        @(posedge dut_if.clk);
      end
    end

    //opcode
    for(int i = 0; i < 2; i++) begin
      dut_if.mosi <= trns.opcode[i];
      @(posedge dut_if.clk);
    end
    
    //wait for dut to retrieve read data
    if(trns.opcode == RDATA_TRNS) repeat(DATA_WIDTH) @(posedge dut_if.clk);

    //assert SS
    dut_if.ss_n <= 1'b1;
    @(posedge dut_if.clk);
  endtask: drive_trns

  task monitor_signals();
    forever begin
      $display("rst_n:%0d ss_n:%0d mosi:%0d miso:%0d",dut_if.rst_n, dut_if.ss_n, dut_if.mosi, dut_if.miso);
      @(posedge dut_if.clk);
    end
  endtask: monitor_signals

endclass: driver