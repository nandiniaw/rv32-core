SIM ?= verilator
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(CURDIR)/counter.sv
COCOTB_TOPLEVEL = counter
COCOTB_TEST_MODULES = test_counter
include $(shell cocotb-config --makefiles)/Makefile.sim
