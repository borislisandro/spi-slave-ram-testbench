`timescale 1ns/1ps

module tb_top;
  import spi_pkg::*;

  logic clk = 1'b0;
  string dumpfile_name;

  spi_if dut_vif(clk);
  ram_if ram_vif(clk);

  instantiation dut (
    .clk  (clk),
    .rst_n(dut_vif.rst_n),
    .MOSI (dut_vif.mosi),
    .SS_n (dut_vif.ss_n),
    .MISO (dut_vif.miso)
  );

  // probe ram signals
  always @(posedge clk) begin
    ram_vif.tx_valid <= dut.tx_valid;
    ram_vif.tx_data  <= dut.tx_data;
    ram_vif.rx_valid <= dut.rx_valid;
    ram_vif.rx_data  <= dut.rx_data;
  end

  always #1 clk = ~clk;

  //Main tb loop
  initial begin
    test t0 = new();
    int unsigned verbosity_arg;

    // Set before anything runs, so every component sees the same level.
    // 0 report only, 1 + errors and banners, 2 + per frame lines,
    // 3 + component startup and transactions, 4 + per clock pin state.
    if ($value$plusargs("VERBOSITY=%d", verbosity_arg))
      verbosity = verbosity_e'(verbosity_arg);

    t0.dut_vif = dut_vif;
    t0.ram_vif = ram_vif;

    if (verb(VERB_LOW))
      $display("t:%0t [TB_TOP]Running test scenarios, verbosity %0s", $time, verbosity.name());
    t0.run();

    #50;
    t0.report();
    $finish;
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
