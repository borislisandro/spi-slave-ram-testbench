`timescale 1ns/1ps

module tb_instantiation;
  localparam logic WRITE_MODE = 1'b0;
  localparam logic READ_MODE = 1'b1;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic MOSI = 1'b0;
  logic SS_n = 1'b1;
  logic MISO;
  string dumpfile_name;

  instantiation dut (
      .clk  (clk),
      .rst_n(rst_n),
      .MOSI (MOSI),
      .SS_n (SS_n),
      .MISO (MISO)
  );

  always #1 clk = ~clk;

  task automatic reset_dut;
    begin
      rst_n = 1'b0;
      SS_n  = 1'b1;
      MOSI  = 1'b0;
      repeat (3) @(negedge clk);
      rst_n = 1'b1;
      @(negedge clk);
    end
  endtask

  task automatic send_frame(
      input logic mode,
      input logic [1:0] operation,
      input logic [7:0] payload
  );
    logic [9:0] frame;
    integer bit_index;
    begin
      frame = {operation, payload};
      SS_n = 1'b0;
      @(negedge clk);
      MOSI = mode;
      @(negedge clk);

      for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
        MOSI = frame[bit_index];
        @(negedge clk);
      end

      // The upstream SPI block clears rx_valid at count 11 while selected.
      repeat (2) @(negedge clk);
      SS_n = 1'b1;
      @(negedge clk);
    end
  endtask

  task automatic write_byte(input logic [7:0] address, input logic [7:0] data);
    begin
      send_frame(WRITE_MODE, 2'b00, address);
      send_frame(WRITE_MODE, 2'b01, data);
    end
  endtask

  task automatic read_byte(input logic [7:0] address, output logic [7:0] data);
    logic [9:0] frame;
    integer bit_index;
    begin
      send_frame(READ_MODE, 2'b10, address);

      frame = {2'b11, 8'h00};
      SS_n = 1'b0;
      @(negedge clk);
      MOSI = READ_MODE;
      @(negedge clk);

      for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
        MOSI = frame[bit_index];
        @(negedge clk);
      end

      @(negedge clk);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        @(negedge clk);
        data[bit_index] = MISO;
      end

      SS_n = 1'b1;
      @(negedge clk);
    end
  endtask

  task automatic check_byte(input logic [7:0] address, input logic [7:0] expected);
    logic [7:0] actual;
    begin
      read_byte(address, actual);
      if (actual !== expected) begin
        $fatal(1, "Address 0x%02h: expected 0x%02h, got 0x%02h", address, expected, actual);
      end
    end
  endtask

  initial begin
    if (!$test$plusargs("NO_WAVES")) begin
      if (!$value$plusargs("DUMPFILE=%s", dumpfile_name)) begin
        dumpfile_name = "build/waves/tb_instantiation.fst";
      end
      $dumpfile(dumpfile_name);
      $dumpvars(0, tb_instantiation);
    end

    reset_dut();

    write_byte(8'h00, 8'hA5);
    write_byte(8'h3C, 8'h5A);
    write_byte(8'hFF, 8'hC3);

    check_byte(8'h00, 8'hA5);
    check_byte(8'h3C, 8'h5A);
    check_byte(8'hFF, 8'hC3);

    $display("PASS: SPI write/read test completed");
    $finish;
  end

  initial begin
    repeat (2000) @(posedge clk);
    $fatal(1, "Simulation timeout");
  end
endmodule
