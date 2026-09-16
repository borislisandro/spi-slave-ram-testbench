# Compile order for the UVM testbench (tb_uvm/). Needs Verilator 5.052 or
# newer -- that is the first release that can elaborate UVM. `make setup`
# builds it into /opt/verilator-5.052 if the distro one is older.

# UVM library. No DPI: the pure SystemVerilog fallbacks are enough for this
# testbench and it saves compiling uvm_dpi.cc into the model.
+define+UVM_NO_DPI
+incdir+third_party/uvm-core/src
third_party/uvm-core/src/uvm_pkg.sv

# DUT
third_party/spi_slave_ram/Codes/RTL/RAM.v
third_party/spi_slave_ram/Codes/RTL/SPI.v
third_party/spi_slave_ram/Codes/RTL/instantiation.v

# Testbench. The two interfaces are shared with the non-UVM tb/.
+incdir+tb_uvm
tb/spi_if.sv
tb/ram_if.sv
tb_uvm/spi_uvm_pkg.sv
tb_uvm/tb_top_uvm.sv
