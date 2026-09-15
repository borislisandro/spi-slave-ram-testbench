import spi_pkg::*;

class environment;

  string name = "environment";

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

  task run();
    if (verb(VERB_HIGH)) $display("t:%0t [%s]Starting", $time, name);
    connect();

    drv.run();
    in_mon.run();
    ram_mon.run();
    sb.run();
  endtask: run

  task connect();
    drv.vif  = dut_vif;
    drv.mbx  = drv_mbx;
    drv.done = drv_done;

    in_mon.vif = dut_vif;
    in_mon.mbx = input_mon_mbx;

    ram_mon.vif = ram_vif;
    ram_mon.mbx = ram_mon_mbx;

    sb.input_mbx = input_mon_mbx;
    sb.ram_mbx   = ram_mon_mbx;
  endtask: connect

  task send(transaction trns);
    drv_mbx.put(trns);
    @(drv_done);
  endtask: send

  // Re-assert reset mid test. Safe to call from a sequence: the driver's own
  // process is parked on its mailbox between frames, so nothing else is
  // touching the pins.
  task reset();
    drv.drive_rst();
  endtask: reset

  function void report();
    sb.report();
  endfunction: report

endclass: environment
