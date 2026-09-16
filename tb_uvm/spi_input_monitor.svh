class spi_input_monitor extends uvm_monitor;

  `uvm_component_utils(spi_input_monitor)

  virtual spi_if vif;
  uvm_analysis_port #(spi_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual spi_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "no virtual spi_if set in config db")
  endfunction: build_phase

  task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "starting", UVM_HIGH)
    fork
      monitor_rst();
      monitor_spi();
    join
  endtask: run_phase

  task monitor_rst();
    spi_transaction trns;
    forever begin
      @(negedge vif.rst_n);
      trns = spi_transaction::type_id::create("rst_trns");
      trns.mon_rst_flag = 1'b1;
      ap.write(trns);
    end
  endtask: monitor_rst

  task monitor_spi();
    spi_transaction trns;
    forever begin
      // wait until ss is low
      @(negedge vif.ss_n);
      trns = spi_transaction::type_id::create("trns");
      monitor_cmd(trns);
      ap.write(trns);
    end
  endtask: monitor_spi

  task monitor_cmd(spi_transaction trns);
    bit [7:0] data;
    bit [1:0] opcode;

    repeat (3) @(posedge vif.clk);

    // get addr/data
    for (int i = 0; i < ADDR_WIDTH; i++) begin
      data[i] = vif.mosi;
      @(posedge vif.clk);
    end

    // get opcode
    for (int i = 0; i < 2; i++) begin
      opcode[i] = vif.mosi;
      @(posedge vif.clk);
    end

    trns.opcode = cmd_type'(opcode);
    if (opcode != RDATA_TRNS) begin
      if (opcode != WDATA_TRNS) trns.addr = data;
      else                      trns.data = data;
    end else begin
      repeat (2) @(posedge vif.clk);

      for (int i = 0; i < DATA_WIDTH; i++) begin
        data[i] = vif.miso;
        @(posedge vif.clk);
      end

      trns.data = data;
    end
  endtask: monitor_cmd

endclass: spi_input_monitor
