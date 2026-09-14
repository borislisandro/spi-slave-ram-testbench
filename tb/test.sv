import spi_pkg::*;

class test;
  virtual spi_if dut_if;
  driver drv;
  monitor mon;
  mailbox #(transaction) drv_mbx;
  mailbox #(transaction) mon_mbx;
  event drv_done;

  function new();
    drv = new();
    mon = new();
    drv_mbx = new();
    mon_mbx = new();
  endfunction: new

  virtual task run();
    drv.dut_if = dut_if;
    drv.drv_mbx = drv_mbx;
    drv.drv_done = drv_done;

    mon.dut_if = dut_if;
    mon.mon_mbx = mon_mbx;

    //fork join_none in driver
    drv.run();
    mon.run();
    get_monitor_mbx_put();

    simple_wr_rd_seq();
  endtask: run

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

  task get_monitor_mbx_put();
    fork
      forever begin
        transaction trns;

        mon_mbx.get(trns);
        $display("t:%0t [MONITOR OUTPUT] addr:%0b op_code:%0s data: %0b", $time, trns.addr, trns.opcode.name(), trns.data);
      end
    join_none
  endtask: get_monitor_mbx_put

endclass: test