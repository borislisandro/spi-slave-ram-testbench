interface ram_if(input clk);
  logic       tx_valid;
  logic [7:0] tx_data;
  logic       rx_valid;
  logic [9:0] rx_data;
endinterface: ram_if