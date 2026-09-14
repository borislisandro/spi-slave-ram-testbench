`timescale 1ns/1ps

module tb_top;
  import spi_pkg::*;

  logic clk = 1'b0;
  string dumpfile_name;

  spi_if dut_if(clk);

  instantiation dut (
    .clk  (clk),
    .rst_n(dut_if.rst_n),
    .MOSI (dut_if.mosi),
    .SS_n (dut_if.ss_n),
    .MISO (dut_if.miso)
  );

  always #1 clk = ~clk;

  //Main tb loop
  initial begin
    test t0 = new();
    t0.dut_if = dut_if;

    $display("t:%0t [TB_TOP]Running test scenarios", $time);
    t0.run();

    #50; $finish;
  end

  // Simulator dependent system tasks that can be used to
  // dump simulation waves.
  initial begin
    if (!$value$plusargs("DUMPFILE=%s", dumpfile_name)) begin
      dumpfile_name = "build/waves/tb_top.fst";
    end
    $dumpfile(dumpfile_name);
    $dumpvars(0, tb_top);
  end

endmodule: tb_top
