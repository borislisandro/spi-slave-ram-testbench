class spi_transaction extends uvm_sequence_item;

  rand bit [ADDR_WIDTH-1:0] addr;
  rand bit [DATA_WIDTH-1:0] data;
  rand cmd_type             opcode;

  // Set by the sequence to ask the driver for a reset pulse instead of a
  // frame, and set by the input monitor to tell the scoreboard it saw one.
  // No RAM side frame pairs with either.
  bit do_reset;
  bit mon_rst_flag;

  `uvm_object_utils_begin(spi_transaction)
    `uvm_field_int (addr,         UVM_DEFAULT | UVM_HEX)
    `uvm_field_int (data,         UVM_DEFAULT | UVM_HEX)
    `uvm_field_enum(cmd_type, opcode, UVM_DEFAULT)
    `uvm_field_int (do_reset,     UVM_DEFAULT)
    `uvm_field_int (mon_rst_flag, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "spi_transaction");
    super.new(name);
  endfunction: new

  constraint addr_prob        { addr dist {8'h0 := 5, 8'hff := 5, [8'h1:8'hfd] :/ 90}; }
  constraint rdata_trans_data { (opcode == RDATA_TRNS) -> (data == 8'h0); }
  constraint rdata_wdata_addr { ((opcode == RDATA_TRNS) && (opcode == WDATA_TRNS)) -> (addr == 8'h0); }

  virtual function string convert2string();
    if (do_reset) return "reset";
    case (opcode)
      WADDR_TRNS, RADDR_TRNS: return $sformatf("%0s addr=0x%02h", opcode.name(), addr);
      WDATA_TRNS:             return $sformatf("%0s data=0x%02h", opcode.name(), data);
      default:                return $sformatf("%0s", opcode.name());
    endcase
  endfunction: convert2string

endclass: spi_transaction
