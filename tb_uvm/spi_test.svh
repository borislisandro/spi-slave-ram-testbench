class spi_base_test extends uvm_test;

  `uvm_component_utils(spi_base_test)

  spi_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = spi_env::type_id::create("env", this);
  endfunction: build_phase

  task run_phase(uvm_phase phase);
    spi_full_seq seq;

    phase.raise_objection(this, "running spi scenarios");

    seq = spi_full_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    // Let the last RDATA frame finish walking through the ram monitor and
    // the scoreboard before the phase ends.
    #50;

    phase.drop_objection(this, "scenarios done");
  endtask: run_phase

endclass: spi_base_test


// Random traffic only, longer. `+UVM_TESTNAME=spi_random_test`.
class spi_random_test extends spi_base_test;

  `uvm_component_utils(spi_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new

  task run_phase(uvm_phase phase);
    random_seq seq;

    phase.raise_objection(this, "running random traffic");

    seq = random_seq::type_id::create("seq");
    seq.count = 1000;
    seq.start(env.agent.sqr);

    #50;

    phase.drop_objection(this, "random traffic done");
  endtask: run_phase

endclass: spi_random_test
