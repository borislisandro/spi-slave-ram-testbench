class spi_env extends uvm_env;

  `uvm_component_utils(spi_env)

  spi_agent      agent;
  ram_monitor    ram_mon;   // passive probe only, no agent worth wrapping it in
  spi_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent   = spi_agent::type_id::create("agent", this);
    ram_mon = ram_monitor::type_id::create("ram_mon", this);
    sb      = spi_scoreboard::type_id::create("sb", this);
  endfunction: build_phase

  function void connect_phase(uvm_phase phase);
    agent.mon.ap.connect(sb.input_fifo.analysis_export);
    ram_mon.ap.connect(sb.ram_fifo.analysis_export);
  endfunction: connect_phase

endclass: spi_env
