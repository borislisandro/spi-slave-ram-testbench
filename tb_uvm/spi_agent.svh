typedef uvm_sequencer #(spi_transaction) spi_sequencer;

class spi_agent extends uvm_agent;

  `uvm_component_utils(spi_agent)

  spi_driver        drv;
  spi_sequencer     sqr;
  spi_input_monitor mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = spi_input_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = spi_driver::type_id::create("drv", this);
      sqr = spi_sequencer::type_id::create("sqr", this);
    end
  endfunction: build_phase

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction: connect_phase

endclass: spi_agent
