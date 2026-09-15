import spi_pkg::*;

class test;
  //vifs
  virtual spi_if dut_vif;
  virtual ram_if ram_vif;

  //tb components
  driver drv;
  input_monitor in_mon;
  ram_monitor ram_mon;
  scoreboard sb;

  //Mailboxes
  mailbox #(transaction) drv_mbx;
  mailbox #(transaction) input_mon_mbx;
  mailbox #(transaction) ram_mon_mbx;

  event drv_done;

  function new();
    drv = new();
    in_mon = new();
    ram_mon = new();
    sb = new();

    drv_mbx = new();
    input_mon_mbx = new();
    ram_mon_mbx = new();
  endfunction: new

  virtual task run();
    drv.vif = dut_vif;
    drv.mbx = drv_mbx;
    drv.done = drv_done;

    sb.input_mbx = input_mon_mbx;
    sb.ram_mbx = ram_mon_mbx;

    in_mon.vif = dut_vif;
    in_mon.mbx = input_mon_mbx;

    ram_mon.vif = ram_vif;
    ram_mon.mbx = ram_mon_mbx;

    //fork join_none in driver
    drv.run();
    in_mon.run();
    ram_mon.run();
    sb.run();

    simple_wr_rd_seq();
  endtask: run

  // Called from tb_top once the sequence has drained.
  function void report();
    sb.report();
  endfunction: report

  task simple_wr_rd_seq();
    transaction trns;
    trns = new();

    if (!trns.randomize() with {addr == 8'b11110000; opcode == 2'b00;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);

    if (!trns.randomize() with {opcode == 2'b01; data == 8'b01010101;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);

    if (!trns.randomize() with {addr == 8'b11110000; opcode == 2'b10;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);

    if (!trns.randomize() with {opcode == 2'b11;}) $fatal(1, "randomize failed");
    drv_mbx.put(trns); @(drv_done);
  endtask: simple_wr_rd_seq

endclass: test