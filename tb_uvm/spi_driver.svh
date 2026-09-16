class spi_driver extends uvm_driver #(spi_transaction);

  `uvm_component_utils(spi_driver)

  virtual spi_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual spi_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "no virtual spi_if set in config db")
  endfunction: build_phase

  task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "starting", UVM_HIGH)

    if (uvm_report_enabled(UVM_DEBUG)) fork monitor_signals(); join_none

    `uvm_info(get_type_name(), "resetting dut", UVM_HIGH)
    drive_rst();

    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info(get_type_name(), $sformatf("driving %0s", req.convert2string()), UVM_HIGH)

      if (req.do_reset) drive_rst();
      else              drive_trns(req);

      seq_item_port.item_done();
    end
  endtask: run_phase

  task drive_rst();
    @(posedge vif.clk);
    vif.drv_rst_n <= 1'b0;
    vif.drv_mosi  <= 1'b0;
    vif.drv_ss_n  <= 1'b1;
    @(posedge vif.clk);

    vif.drv_rst_n <= 1'b1;
    repeat (5) @(posedge vif.clk);
  endtask: drive_rst

  task drive_trns(spi_transaction trns);
    @(posedge vif.clk);

    vif.drv_ss_n <= 1'b0;
    vif.drv_mosi <= (trns.opcode == WADDR_TRNS) || (trns.opcode == WDATA_TRNS) ? 1'b0 : 1'b1;
    repeat (2) @(posedge vif.clk);

    if ((trns.opcode == WADDR_TRNS) || (trns.opcode == RADDR_TRNS)) begin
      for (int i = 0; i < ADDR_WIDTH; i++) begin
        vif.drv_mosi <= trns.addr[i];
        @(posedge vif.clk);
      end
    end else begin
      for (int i = 0; i < DATA_WIDTH; i++) begin
        vif.drv_mosi <= trns.data[i];
        @(posedge vif.clk);
      end
    end

    for (int i = 0; i < 2; i++) begin
      vif.drv_mosi <= trns.opcode[i];
      @(posedge vif.clk);
    end

    if (trns.opcode == RDATA_TRNS) repeat (DATA_WIDTH + 2) @(posedge vif.clk);

    vif.drv_ss_n <= 1'b1;
    @(posedge vif.clk);
  endtask: drive_trns

  task monitor_signals();
    forever begin
      `uvm_info(get_type_name(), $sformatf("rst_n:%0d ss_n:%0d mosi:%0d miso:%0d",
                                           vif.rst_n, vif.ss_n, vif.mosi, vif.miso), UVM_DEBUG)
      @(posedge vif.clk);
    end
  endtask: monitor_signals

endclass: spi_driver
