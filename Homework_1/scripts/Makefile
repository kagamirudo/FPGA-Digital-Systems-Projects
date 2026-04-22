LATEX   ?= pdflatex
PYTHON  ?= python3
PLOTTER  = read_vcd_signals.py

VHDL_SRC = output_limiter.vhd \
           palindrome_synch_ckt.vhd \
           c_accum_0.vhd \
           accumulator_top.vhd

VHDL_TB  = tb_output_limiter.vhd \
           tb_palindrome_synch_ckt.vhd \
           tb_accumulator_top.vhd

SNAPS    = sim_limiter sim_pal sim_acc
VCDS     = waves_limiter.vcd waves_palindrome.vcd waves_accumulator.vcd
WAVES    = waveform_limiter.png waveform_palindrome.png waveform_accumulator.png

.PHONY: all compile elab sim waves pdf clean

all: pdf

# ---------- compile ----------
compile: .stamp_compile
.stamp_compile: $(VHDL_SRC) $(VHDL_TB)
	xvhdl output_limiter.vhd
	xvhdl tb_output_limiter.vhd
	xvhdl palindrome_synch_ckt.vhd
	xvhdl tb_palindrome_synch_ckt.vhd
	xvhdl c_accum_0.vhd
	xvhdl accumulator_top.vhd
	xvhdl tb_accumulator_top.vhd
	@touch $@

# ---------- elaborate ----------
elab: .stamp_elab
.stamp_elab: .stamp_compile
	xelab tb_output_limiter      -s sim_limiter -debug typical
	xelab tb_palindrome_synch_ckt -s sim_pal     -debug typical
	xelab tb_accumulator_top      -s sim_acc     -debug typical
	@touch $@

# ---------- simulate ----------
sim: $(VCDS)

waves_limiter.vcd: .stamp_elab run_vcd_limiter.tcl
	xsim sim_limiter -tclbatch run_vcd_limiter.tcl -onfinish quit

waves_palindrome.vcd: .stamp_elab run_vcd_palindrome.tcl
	xsim sim_pal -tclbatch run_vcd_palindrome.tcl -onfinish quit

waves_accumulator.vcd: .stamp_elab run_vcd_accumulator.tcl
	xsim sim_acc -tclbatch run_vcd_accumulator.tcl -onfinish quit

# ---------- waveform PNGs ----------
waves: $(WAVES)

waveform_limiter.png: waves_limiter.vcd $(PLOTTER)
	$(PYTHON) $(PLOTTER) $< \
	  -s tb_output_limiter.x -s tb_output_limiter.z \
	  -o $@ --title "Part 2.6.12 — Output Limiter"

waveform_palindrome.png: waves_palindrome.vcd $(PLOTTER)
	$(PYTHON) $(PLOTTER) $< \
	  -s tb_palindrome_synch_ckt.ck \
	  -s tb_palindrome_synch_ckt.reset \
	  -s tb_palindrome_synch_ckt.x \
	  -s tb_palindrome_synch_ckt.y \
	  -s tb_palindrome_synch_ckt.z \
	  -o $@ --title "Part 3.5.11 — Palindrome Checker"

waveform_accumulator.png: waves_accumulator.vcd $(PLOTTER)
	$(PYTHON) $(PLOTTER) $< \
	  -s tb_accumulator_top.ck \
	  -s tb_accumulator_top.sclr \
	  -s tb_accumulator_top.x \
	  -s tb_accumulator_top.q \
	  --signed -o $@ --title "Part 7.5.3 — Accumulator"

# ---------- PDF report ----------
pdf: REPORT.pdf

REPORT.pdf: REPORT.tex $(WAVES)
	$(LATEX) -interaction=nonstopmode REPORT.tex
	$(LATEX) -interaction=nonstopmode REPORT.tex

# ---------- clean ----------
clean:
	rm -rf xsim.dir xsim.jou xsim.log xelab.log xelab.pb xvhdl.log xvhdl.pb
	rm -rf vivado.log vivado.jou
	rm -f .stamp_compile .stamp_elab
	rm -f $(VCDS) $(WAVES)
	rm -f REPORT.aux REPORT.log REPORT.out REPORT.pdf REPORT.toc
	rm -f hs_err_*.log xsim_*.backup.*
