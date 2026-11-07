// tb_sha256_ctrl.sv
// Self-checking test for sha256_ctrl (IDLE -> ROUNDS -> DONE).
//
// Every output is compared on every cycle against an explicit expected sequence
// (see the timing table in rtl/sha256_ctrl.sv). Covered:
//   1. Reset: power-up reset (with start held high, which must be ignored),
//      then idle behaviour; reset in the middle of a block; reset in the
//      final-add cycle (must NOT produce a done pulse)
//   2. Idle: no activity without start
//   3. Starting a block: load pulses in the start cycle only
//   4. All 64 rounds: round_en high and round_cnt = 0..63 in order, then the
//      final-add cycle (cnt = 64), then a one-cycle done pulse
//   5. Completion: done exactly once, busy low when done is high, 66 cycles
//      from start cycle to done cycle
//   6. Restart: back-to-back blocks (1 idle cycle apart), after idle gaps,
//      and after an aborted block
//   7. Ignored starts: start pulses during rounds, during the final-add
//      cycle, and during the done cycle must not change anything
//
// A VCD waveform is written to build/tb_sha256_ctrl.vcd (open with gtkwave).
// Run from the project root:  make sim_ctrl
`timescale 1ns/1ps

module tb_sha256_ctrl;

    logic       clk   = 1'b0;
    logic       rst_n = 1'b0;
    logic       start = 1'b0;
    logic       busy, done, load, round_en, final_add;
    logic [6:0] round_cnt;

    int errors = 0;
    int checks = 0;

    sha256_ctrl dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .busy(busy), .done(done), .load(load),
        .round_en(round_en), .final_add(final_add), .round_cnt(round_cnt)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/tb_sha256_ctrl.vcd");
        $dumpvars(0, tb_sha256_ctrl);
    end

    // ---- pulse counters and latency measurement (sampled just before each edge) ----
    int cyc = 0;
    int n_load = 0, n_round_en = 0, n_final_add = 0, n_done = 0;
    int t_load = -1, t_done = -1;

    always @(posedge clk) begin
        if (load === 1'b1)      begin n_load++;      t_load = cyc; end
        if (round_en === 1'b1)  n_round_en++;
        if (final_add === 1'b1) n_final_add++;
        if (done === 1'b1)      begin n_done++;      t_done = cyc; end
        cyc++;
    end

    task automatic clear_counts;
        n_load = 0; n_round_en = 0; n_final_add = 0; n_done = 0;
        t_load = -1; t_done = -1;
    endtask

    // ---- helpers: stimulus and checks happen 1 ns after a rising edge ----
    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    // Release start and let the combinational outputs (load) settle before any check.
    // Without the delay a check made in the same instant would still see the old load.
    task automatic drop_start;
        start = 1'b0;
        #1;
    endtask

    task automatic expect_out(input string name,
                              input bit e_busy, input bit e_done, input bit e_load,
                              input bit e_re,   input bit e_fa,   input logic [6:0] e_cnt);
        checks++;
        if (busy !== e_busy || done !== e_done || load !== e_load ||
            round_en !== e_re || final_add !== e_fa || round_cnt !== e_cnt) begin
            errors++;
            $display("FAIL %s\n  got      busy=%b done=%b load=%b round_en=%b final_add=%b cnt=%0d\n  expected busy=%b done=%b load=%b round_en=%b final_add=%b cnt=%0d",
                     name, busy, done, load, round_en, final_add, round_cnt,
                     e_busy, e_done, e_load, e_re, e_fa, e_cnt);
        end
    endtask

    task automatic expect_idle(input string name);
        expect_out(name, 0, 0, 0, 0, 0, 7'd0);
    endtask

    task automatic expect_count(input string name, input int got, input int want);
        checks++;
        if (got != want) begin
            errors++;
            $display("FAIL %s: got %0d expected %0d", name, got, want);
        end
    endtask

    // Advance n idle cycles, checking every one
    task automatic idle_cycles(input string name, input int n);
        for (int i = 0; i < n; i++) begin
            expect_idle(name);
            tick();
        end
    endtask

    // Run one complete block from an idle cycle and check every cycle.
    // inject = 0: none; 1: extra start pulses during rounds and the final-add
    // cycle; 2: extra start pulse in the done cycle (must not start a new block).
    // Leaves the testbench in an idle cycle (or after 6 idle cycles for inject = 2).
    task automatic run_block(input string tag, input int inject);
        int lat;
        clear_counts();

        // cycle 0: start accepted, load pulses
        start = 1'b1;
        #1;
        expect_out({tag, ": start cycle"}, 0, 0, 1, 0, 0, 7'd0);
        tick();
        drop_start();

        // cycles 1..64: rounds 0..63
        for (int k = 0; k < 64; k++) begin
            if (inject == 1 && (k == 0 || k == 31 || k == 63)) begin
                start = 1'b1;   // must be ignored
                #1;
            end
            expect_out($sformatf("%s: round %0d", tag, k), 1, 0, 0, 1, 0, k[6:0]);
            tick();
            drop_start();
        end

        // cycle 65: final add
        if (inject == 1) begin
            start = 1'b1;
            #1;
        end
        expect_out({tag, ": final add"}, 1, 0, 0, 0, 1, 7'd64);
        tick();
        drop_start();

        // cycle 66: done pulse
        if (inject == 2) begin
            start = 1'b1;       // must be ignored in the done cycle
            #1;
        end
        expect_out({tag, ": done"}, 0, 1, 0, 0, 0, 7'd0);
        tick();
        drop_start();

        // cycle 67: back to idle
        expect_idle({tag, ": idle after done"});
        if (inject == 2) begin
            tick();
            idle_cycles({tag, ": still idle (ignored start in done)"}, 6);
        end

        // totals for the whole block
        lat = t_done - t_load;
        expect_count({tag, ": load pulses"},       n_load,      1);
        expect_count({tag, ": round_en cycles"},   n_round_en,  64);
        expect_count({tag, ": final_add pulses"},  n_final_add, 1);
        expect_count({tag, ": done pulses"},       n_done,      1);
        expect_count({tag, ": start-to-done cycles"}, lat,      66);
    endtask

    // Start a block and run n round cycles (checked), leaving us in cycle n+1
    task automatic start_and_run(input string tag, input int n);
        start = 1'b1;
        #1;
        expect_out({tag, ": start cycle"}, 0, 0, 1, 0, 0, 7'd0);
        tick();
        drop_start();
        for (int k = 0; k < n; k++) begin
            expect_out($sformatf("%s: round %0d", tag, k), 1, 0, 0, 1, 0, k[6:0]);
            tick();
        end
    endtask

    initial begin
        // ================= 1. reset =================
        // Power-up reset with start held high: must be ignored
        rst_n = 1'b0;
        start = 1'b1;
        tick(); tick();
        drop_start();
        tick();
        expect_idle("reset: idle after power-up reset");
        rst_n = 1'b1;
        clear_counts();
        idle_cycles("reset: idle after release", 4);
        expect_count("reset: no load after start-in-reset", n_load, 0);
        expect_count("reset: no done after start-in-reset", n_done, 0);

        // ================= 2. idle =================
        idle_cycles("idle without start", 10);
        expect_count("idle: no round_en", n_round_en, 0);

        // ================= 3-5. one full block =================
        run_block("block 1", 0);

        // ================= 6. restarts =================
        run_block("block 2 (back-to-back)", 0);
        idle_cycles("gap before block 3", 5);
        run_block("block 3 (after idle gap)", 0);

        // ================= 7. ignored starts =================
        run_block("block 4 (starts injected in rounds/final add)", 1);
        run_block("block 5 (back-to-back after injection)", 0);
        run_block("block 6 (start injected in done cycle)", 2);
        run_block("block 7 (after ignored start in done)", 0);

        // ================= 1b. reset in the middle of a block =================
        clear_counts();
        start_and_run("abort mid-run", 10);
        rst_n = 1'b0;                       // asserted during round 10's cycle
        tick();
        expect_idle("abort mid-run: idle right after reset edge");
        tick();
        expect_idle("abort mid-run: idle while reset held");
        rst_n = 1'b1;
        idle_cycles("abort mid-run: stays idle after release", 4);
        expect_count("abort mid-run: no final_add", n_final_add, 0);
        expect_count("abort mid-run: no done pulse", n_done, 0);
        run_block("block 8 (after aborted block)", 0);

        // ================= 1c. reset in the final-add cycle =================
        clear_counts();
        start_and_run("abort at final add", 64);
        expect_out("abort at final add: final-add cycle", 1, 0, 0, 0, 1, 7'd64);
        rst_n = 1'b0;
        tick();
        expect_idle("abort at final add: idle, no done pulse");
        rst_n = 1'b1;
        idle_cycles("abort at final add: stays idle", 4);
        expect_count("abort at final add: no done pulse", n_done, 0);
        run_block("block 9 (after abort at final add)", 0);

        $display("checks run: %0d", checks);
        if (errors == 0) $display("TB_RESULT: PASS (all checks)");
        else             $display("TB_RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
