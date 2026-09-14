`timescale 1ns/1ps

interface spi_if(input clk);

  // Pins seen by the DUT.
  logic rst_n;
  logic ss_n;
  logic mosi;
  logic miso;

  // What the driver class asks for. The interface registers it onto the pins
  // on the falling edge, so the pins are driven by ordinary module-scope RTL
  // and the DUT sees a request made on one rising edge at the next one, every
  // time, whatever order the testbench processes happen to run in.
  //
  // Driving the pins straight from the class instead costs two things. The
  // driver analysis in Verilator cannot see writes made through a virtual
  // interface handle, so the pins are reported undriven and get no trace
  // change-detection (flat lines in the FST), and combinational logic reading
  // them does not re-settle until the following clock edge, which puts an
  // extra cycle between SS_n falling and the DUT leaving IDLE.
  bit drv_rst_n = 1'b1;
  bit drv_ss_n  = 1'b1;
  bit drv_mosi  = 1'b0;

  always @(negedge clk) begin
    rst_n <= drv_rst_n;
    ss_n  <= drv_ss_n;
    mosi  <= drv_mosi;
  end

endinterface: spi_if
