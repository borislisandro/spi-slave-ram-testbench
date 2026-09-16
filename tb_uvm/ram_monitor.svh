class ram_monitor extends uvm_monitor;

  `uvm_component_utils(ram_monitor)

  virtual ram_if vif;
  uvm_analysis_port #(spi_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ram_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "no virtual ram_if set in config db")
  endfunction: build_phase

  task run_phase(uvm_phase phase);
    spi_transaction trns;
    `uvm_info(get_type_name(), "starting", UVM_HIGH)
    forever begin
      trns = spi_transaction::type_id::create("trns");
      monitor_cmd(trns);
      ap.write(trns);
    end
  endtask: run_phase

  task monitor_cmd(spi_transaction trns);
    bit [7:0] data;
    bit [1:0] opcode;

    @(posedge vif.rx_valid);
    opcode = vif.rx_data[9:8];
    data   = vif.rx_data[7:0];

    trns.opcode = cmd_type'(opcode);
    if (opcode != RDATA_TRNS) begin
      if (opcode != WDATA_TRNS) trns.addr = data;
      else                      trns.data = data;
    end else begin
      repeat (2) @(posedge vif.clk);
      trns.data = vif.tx_data;
    end
  endtask: monitor_cmd

endclass: ram_monitor
