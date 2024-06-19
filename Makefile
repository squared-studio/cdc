TC = 10
T1 = 10
T2 = 11

SRC += ./sub/SystemVerilog/rtl/decoder.sv
SRC += ./sub/SystemVerilog/rtl/mux.sv
SRC += ./sub/SystemVerilog/rtl/demux.sv
SRC += ./sub/SystemVerilog/rtl/mem.sv
SRC += ./sub/SystemVerilog/rtl/bin_to_gray.sv
SRC += ./sub/SystemVerilog/rtl/gray_to_bin.sv
SRC += ./sub/SystemVerilog/rtl/register.sv
SRC += ./sub/SystemVerilog/rtl/register_dual_flop.sv
SRC += ./sub/SystemVerilog/rtl/cdc_fifo.sv

SRC += ./tb/cdc_fifo_tb.sv

TOP = cdc_fifo_tb

TPA += -testplusarg \"TC=${TC}\"
TPA += -testplusarg \"T1=${T1}\"
TPA += -testplusarg \"T2=${T2}\"

CT += *.jou
CT += *.log
CT += *.out
CT += *.pb
CT += *.vcd
CT += *.wdb
CT += .Xil
CT += work
CT += xsim.dir

.PHONY: vivado
vivado: clean
	@xvlog -sv ${SRC}
	@xelab ${TOP} -s top
	@xsim top -runall ${TPA}

.PHONY: questa
questa: clean
	@vlog ${SRC}
	@vsim work.${TOP} -voptargs=+acc -do 'run -all'

.PHONY: iverilog
iverilog: clean
	@iverilog -o ${TOP}.out -g2012 -s ${TOP} ${SRC}
	@vvp ${TOP}.out

.PHONY: clean
clean:
	@rm -rf ${CT}

