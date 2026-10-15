SIM ?= verilator
TOPLEVEL_LANG ?= verilog
RTL := $(CURDIR)/../../rtl
VERILOG_SOURCES = $(RTL)/rv32_pkg.sv $(RTL)/alu.sv $(RTL)/imm_gen.sv $(RTL)/decoder.sv \
                  $(RTL)/branch_cmp.sv $(RTL)/lsu.sv $(RTL)/regfile.sv $(RTL)/core.sv \
                  $(CURDIR)/../../tb/tb_top.sv
COCOTB_TOPLEVEL = tb_top
COCOTB_TEST_MODULES = test_core_elf
include $(shell cocotb-config --makefiles)/Makefile.sim
