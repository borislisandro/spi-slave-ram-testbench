import spi_pkg::*;

class transaction;
  string name = "Transaction";
  rand bit [ADDR_WIDTH-1:0] addr;
  rand bit [DATA_WIDTH-1:0] data;
  rand cmd_type  opcode;
  bit mon_rst_flag;

  function void print();
    if       ((opcode == WADDR_TRNS) || (opcode == RADDR_TRNS)) $display("t:%0t [%s] addr:%0b op_code:%0s", $time, name, addr, opcode.name());
    else if  (opcode == WDATA_TRNS)                             $display("t:%0t [%s] op_code:%0s data:%0b", $time, name, opcode.name(), data);
    else                                                        $display("t:%0t [%s] op_code:%0s"         , $time, name, opcode.name());
  endfunction: print

  constraint addr_prob { addr dist {8'h0 := 5, 8'hff := 5, [8'h1:8'hfd] :/ 90};}
  constraint rdata_trans_data { (opcode == RDATA_TRNS) -> (data == 8'h0);}
  constraint rdata_wdata_addr { ((opcode == RDATA_TRNS) && (opcode == WDATA_TRNS)) -> (addr == 8'h0);}

endclass: transaction