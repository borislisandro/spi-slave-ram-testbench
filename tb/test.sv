import spi_pkg::*;

class test;
  virtual spi_if dut_if;
  driver drv;
  mailbox #(transaction) drv_mbx;
  event drv_done;

  function new();
    drv = new();
    drv_mbx = new();
  endfunction: new

  virtual task run();
    drv.dut_if = this.dut_if;
    drv.drv_mbx = this.drv_mbx;
    drv.drv_done = this.drv_done;

    //fork join_none in driver
    drv.run();

    simple_wr_rd_seq();
  endtask: run

  task simple_wr_rd_seq();
    transaction trns;
    trns = new();

    if (!trns.randomize() with {addr == 8'b11000011; opcode == 2'b00;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);

    if (!trns.randomize() with {opcode == 2'b01;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);

    if (!trns.randomize() with {addr == 8'b11000011; opcode == 2'b10;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);

    if (!trns.randomize() with {opcode == 2'b11;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);
  endtask: simple_wr_rd_seq
endclass: test