# Run inside Ubuntu (WSL2 on Windows 11). Needs: make gcc iverilog verilator
# Targets:
#   make ref         build the C reference model (ref/sha256_ref)
#   make kat         print reference digests (compare with NIST values in README)
#   make lint        Verilator lint (-Wall) of every file in rtl/, one file at a time
#   make sim         round unit test (Icarus Verilog)
#   make sim_k_rom   K-constant ROM test: all 64 constants vs the C reference
#   make sim_msg_sched  message scheduler test: W[0..63] of 4 blocks vs the C reference
#   make sim_ctrl    controller FSM test (writes build/tb_sha256_ctrl.vcd for gtkwave)
#   make check_ref   C reference digests vs coreutils sha256sum (several message lengths)
#   make sim_core    end-to-end: complete SHA-256 digests through sha256_core vs the C reference
#   make test        kat + lint + all simulations; fails if any test reports FAIL
#   make clean
#
# Testbench targets exit non-zero unless the log contains "TB_RESULT: PASS".

RTL := rtl/sha256_round.sv
TB  := tb/tb_sha256_round.sv

K_ROM_RTL := rtl/sha256_k_rom.sv
K_ROM_TB  := tb/tb_sha256_k_rom.sv

MSG_SCHED_RTL := rtl/sha256_msg_sched.sv
MSG_SCHED_TB  := tb/tb_sha256_msg_sched.sv

CTRL_RTL := rtl/sha256_ctrl.sv
CTRL_TB  := tb/tb_sha256_ctrl.sv

# The core instantiates the four modules above; list its sources leaf-first
CORE_RTL := rtl/sha256_round.sv rtl/sha256_k_rom.sv rtl/sha256_msg_sched.sv \
            rtl/sha256_ctrl.sv rtl/prefix_add32.sv rtl/sha256_core.sv
CORE_TB  := tb/tb_sha256_core.sv

.PHONY: ref kat check_ref lint sim sim_k_rom sim_msg_sched sim_ctrl sim_core sim_prefix test clean

ref: ref/sha256_ref

ref/sha256_ref: ref/sha256_ref.c
	gcc -std=c99 -Wall -Wextra -O2 -o $@ $< -lm

kat: ref
	./ref/sha256_ref

# Expected K constants for tb_sha256_k_rom, written by the C reference
# (which first checks them against the cube-root definition).
build/k_expected.hex: ref/sha256_ref
	mkdir -p build
	./ref/sha256_ref -k > $@

# Independent check of the C reference: its digests must equal coreutils sha256sum
# for messages of several lengths (including the 1-block/2-block padding boundaries)
check_ref: ref
	@set -e; \
	for m in abc "" "hello world" \
	         abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq \
	         $$(head -c 55 /dev/zero | tr '\0' a) \
	         $$(head -c 64 /dev/zero | tr '\0' a) \
	         $$(head -c 119 /dev/zero | tr '\0' a); do \
		want=$$(printf '%s' "$$m" | sha256sum | cut -d' ' -f1); \
		got=$$(./ref/sha256_ref -s "$$m" | sed -n 's/^digest = //p'); \
		if [ "$$want" = "$$got" ]; then echo "check_ref PASS len=$${#m}"; \
		else echo "check_ref FAIL len=$${#m}: sha256sum $$want, reference $$got"; exit 1; fi; \
	done

# Lint: leaf modules one at a time; the core together with everything it instantiates
lint:
	@for f in $(filter-out rtl/sha256_core.sv,$(wildcard rtl/*.sv)); do \
		echo "verilator --lint-only -Wall $$f"; \
	        if [ "$$f" = "rtl/sha256_round.sv" ]; then \
        verilator --lint-only -Wall rtl/prefix_add32.sv "$$f" || exit 1; \
        else \
        verilator --lint-only -Wall "$$f" || exit 1; \
        fi; \
	done
	@echo "verilator --lint-only -Wall --top-module sha256_core $(CORE_RTL)"
	@verilator --lint-only -Wall --top-module sha256_core $(CORE_RTL)

sim:
	mkdir -p build
	iverilog -g2012 -Wall -Wno-timescale -o build/tb_sha256_round.vvp rtl/prefix_add32.sv $(RTL) $(TB)
	vvp build/tb_sha256_round.vvp | tee build/tb_sha256_round.log
	@grep -q "TB_RESULT: PASS" build/tb_sha256_round.log

sim_k_rom: build/k_expected.hex
	iverilog -g2012 -Wall -Wno-timescale -o build/tb_sha256_k_rom.vvp $(K_ROM_RTL) $(K_ROM_TB)
	vvp build/tb_sha256_k_rom.vvp | tee build/tb_sha256_k_rom.log
	@grep -q "TB_RESULT: PASS" build/tb_sha256_k_rom.log

# Padded blocks and W[0..63] for tb_sha256_msg_sched, written by the C reference
build/sched_vectors.txt: ref/sha256_ref
	mkdir -p build
	./ref/sha256_ref -w > $@

sim_msg_sched: build/sched_vectors.txt
	iverilog -g2012 -Wall -Wno-timescale -o build/tb_sha256_msg_sched.vvp $(MSG_SCHED_RTL) $(MSG_SCHED_TB)
	vvp build/tb_sha256_msg_sched.vvp | tee build/tb_sha256_msg_sched.log
	@grep -q "TB_RESULT: PASS" build/tb_sha256_msg_sched.log

sim_ctrl:
	mkdir -p build
	iverilog -g2012 -Wall -Wno-timescale -o build/tb_sha256_ctrl.vvp $(CTRL_RTL) $(CTRL_TB)
	vvp build/tb_sha256_ctrl.vvp | tee build/tb_sha256_ctrl.log
	@grep -q "TB_RESULT: PASS" build/tb_sha256_ctrl.log

# Per-block records (block, state in, state out) for tb_sha256_core, written by the C reference
build/core_vectors.txt: ref/sha256_ref
	mkdir -p build
	./ref/sha256_ref -c > $@

sim_core: build/core_vectors.txt
	mkdir -p build
	iverilog -g2012 -Wall -Wno-timescale -o build/tb_sha256_core.vvp $(CORE_RTL) $(CORE_TB)
	vvp build/tb_sha256_core.vvp | tee build/tb_sha256_core.log
	@grep -q "TB_RESULT: PASS" build/tb_sha256_core.log

sim_prefix:
	mkdir -p build
	iverilog -g2012 -Wall -Wno-timescale -o build/tb_prefix_add32.vvp rtl/prefix_add32.sv tb/tb_prefix_add32.sv
	vvp build/tb_prefix_add32.vvp | tee build/tb_prefix_add32.log
	@grep -q "PASS: prefix_add32" build/tb_prefix_add32.log

test: kat check_ref lint sim sim_k_rom sim_msg_sched sim_ctrl sim_core sim_prefix

clean:
	rm -rf build ref/sha256_ref

include synth/synth.mk
