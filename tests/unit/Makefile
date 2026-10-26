SIM ?= verilator
TOPLEVEL_LANG ?= verilog
TOP ?= regfile
VERILOG_SOURCES += $(CURDIR)/../../rtl/rv32_pkg.sv $(CURDIR)/../../rtl/$(TOP).sv $(EXTRA_SRC)
COCOTB_TOPLEVEL = $(TOP)
COCOTB_TEST_MODULES = test_$(TOP)
include $(shell cocotb-config --makefiles)/Makefile.sim
