`timescale 1ns/1ps

// Run with +UVM_TESTNAME=spi_base_test.
module tb_top_uvm;

  import uvm_pkg::*;
  import spi_uvm_pkg::*;
  `include "uvm_macros.svh"

  logic  clk = 1'b0;
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

  initial begin
    uvm_config_db #(virtual spi_if)::set(null, "uvm_test_top.env.agent.*", "vif", dut_vif);
    uvm_config_db #(virtual ram_if)::set(null, "uvm_test_top.env.ram_mon", "vif", ram_vif);

    run_test("spi_base_test");
  end

  // Simulator dependent system tasks that can be used to
  // dump simulation waves.
  initial begin
    if (!$value$plusargs("DUMPFILE=%s", dumpfile_name)) begin
      dumpfile_name = "build/waves/tb_top_uvm.fst";
    end
    $dumpfile(dumpfile_name);
    $dumpvars(0, tb_top_uvm);
  end

endmodule: tb_top_uvm
