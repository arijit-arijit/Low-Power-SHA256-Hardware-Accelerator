// tb_sha256_core.sv
// End-to-end self-checking test of sha256_core: complete SHA-256 digests.
//
// Expected values come from three sources:
//   * build/core_vectors.txt, written by the C reference (`sha256_ref -c`): for 6
//     messages (9 padded blocks) the block, chaining state in, state out. The C digests
//     are cross-checked against coreutils sha256sum by `make check_ref`.
//   * NIST digests of "abc", the empty message and the 56-byte two-block message,
//     typed in below (published FIPS 180 / NIST example values).
//   * The SHA-256 initial hash values typed in below.
//
// What is checked
//   - every block of every message, with MULTI-BLOCK CHAINING DONE BY THE HARDWARE:
//     the digest the core produced for block n is fed back as h_in for block n+1
//   - the inputs block/h_in are scrambled right after the start cycle (the core must
//     have captured them) and extra start pulses with different data are injected
//     while busy and in the done cycle (must be ignored)
//   - protocol on every run: done exactly 66 cycles after the start cycle, busy for
//     exactly 65 cycles, a single done pulse, busy and done never together
//   - digest holds its value until the next result (checked during the next run and
//     during idle gaps)
//   - reset in the middle of a block aborts it (no done), and the core then computes
//     a correct digest
//
// A VCD waveform is written to build/tb_sha256_core.vcd (open with gtkwave).
// Run from the project root:  make sim_core
`timescale 1ns/1ps

module tb_sha256_core;

    localparam string VEC_FILE        = "build/core_vectors.txt";
    localparam int    EXPECTED_BLOCKS = 9;
    localparam int    MAXV            = 16;

    localparam logic [255:0] H_INIT = {32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
                                       32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19};

    // Published SHA-256 digests (NIST)
    localparam logic [255:0] NIST_ABC   = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;
    localparam logic [255:0] NIST_EMPTY = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;
    localparam logic [255:0] NIST_448   = 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1;

    logic         clk     = 1'b0;
    logic         rst_n   = 1'b0;
    logic         start   = 1'b0;
    logic [511:0] blk_drv = '0;
    logic [255:0] hin_drv = '0;
    logic         busy, done;
    logic [255:0] digest;

    int errors = 0;
    int checks = 0;

    sha256_core dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .block(blk_drv), .h_in(hin_drv),
        .busy(busy), .done(done), .digest(digest)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/tb_sha256_core.vcd");
        $dumpvars(0, tb_sha256_core);
    end

    // ---- monitors, sampled just before every rising edge ----
    int n_done = 0;
    always @(posedge clk) begin
        if (done === 1'b1) n_done++;
        if (busy === 1'b1 && done === 1'b1) begin
            errors++;
            $display("FAIL busy and done high together");
        end
    end

    // ---- helpers: all stimulus and checks happen 1 ns after a rising edge ----
    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    // Release start and let combinational outputs settle before any check
    task automatic drop_start;
        start = 1'b0;
        #1;
    endtask

    task automatic fail(input string msg);
        errors++;
        $display("FAIL %s", msg);
    endtask

    task automatic check_eq256(input string name, input logic [255:0] got, input logic [255:0] want);
        checks++;
        if (got !== want) begin
            errors++;
            $display("FAIL %s\n  got      %h\n  expected %h", name, got, want);
        end
    endtask

    task automatic check_bit(input string name, input logic got, input logic want);
        checks++;
        if (got !== want) begin
            errors++;
            $display("FAIL %s: got %b expected %b", name, got, want);
        end
    endtask

    task automatic check_int(input string name, input int got, input int want);
        checks++;
        if (got != want) begin
            errors++;
            $display("FAIL %s: got %0d expected %0d", name, got, want);
        end
    endtask

    // Idle cycles with the digest required to hold a known value
    task automatic idle_hold(input string name, input int n, input logic [255:0] want);
        for (int i = 0; i < n; i++) begin
            check_bit({name, ": busy low"}, busy, 1'b0);
            check_bit({name, ": done low"}, done, 1'b0);
            check_eq256({name, ": digest held"}, digest, want);
            tick();
        end
    endtask

    // Process one block, starting from an idle cycle; leaves us in the next idle cycle.
    //   mode 0: start once.  mode 1: also inject start pulses with different data in
    //   rounds (k=5, k=40), the final-add cycle (k=65) and the done cycle (k=66).
    //   prev_valid: digest must equal prev_dig until this run's result appears.
    task automatic run_block(input string tag, input logic [511:0] blk, input logic [255:0] hin,
                             input logic [255:0] want, input int mode,
                             input logic [255:0] prev_dig, input bit prev_valid,
                             output logic [255:0] got);
        int k, busy_cycles, lat;
        bit finished;
        logic [511:0] scr_blk;
        logic [255:0] scr_hin;

        scr_blk = ~blk ^ {16{32'hA5C30F1E}};
        scr_hin = ~hin ^ {8{32'h5A3CE1B7}};
        got = 'x;
        n_done = 0;
        busy_cycles = 0;
        lat = 0;
        finished = 1'b0;

        // cycle 0: start with the real data
        blk_drv = blk;
        hin_drv = hin;
        start   = 1'b1;
        #1;
        check_bit({tag, ": busy low in start cycle"}, busy, 1'b0);
        check_bit({tag, ": done low in start cycle"}, done, 1'b0);
        tick();
        // The core must have captured block/h_in; from here the inputs carry garbage
        blk_drv = scr_blk;
        hin_drv = scr_hin;
        drop_start();

        k = 1;
        while (!finished && k <= 80) begin
            if (mode == 1 && (k == 5 || k == 40 || k == 65 || k == 66)) begin
                blk_drv = ~scr_blk;
                hin_drv = ~scr_hin;
                start   = 1'b1;          // must be ignored
                #1;
            end
            if (busy === 1'b1) busy_cycles++;
            if (prev_valid && k <= 65) begin
                checks++;
                if (digest !== prev_dig) begin
                    errors++;
                    $display("FAIL %s: digest changed before the result at cycle %0d", tag, k);
                end
            end
            if (done === 1'b1) begin
                finished = 1'b1;
                lat = k;
                got = digest;
            end
            tick();
            drop_start();
            k++;
        end

        if (!finished) begin
            fail({tag, ": timeout, done never asserted"});
        end else begin
            check_int({tag, ": start-to-done cycles"}, lat, 66);
            check_int({tag, ": busy cycles"}, busy_cycles, 65);
            check_int({tag, ": done pulses"}, n_done, 1);
            check_eq256({tag, ": digest"}, got, want);
            // now in the idle cycle after done
            check_bit({tag, ": busy low after done"}, busy, 1'b0);
            check_bit({tag, ": done is one cycle"}, done, 1'b0);
            check_eq256({tag, ": digest held after done"}, digest, want);
        end
    endtask

    // ---- vector storage ----
    int           v_id   [0:MAXV-1];
    int           v_idx  [0:MAXV-1];
    int           v_len  [0:MAXV-1];
    logic [511:0] v_blk  [0:MAXV-1];
    logic [255:0] v_hin  [0:MAXV-1];
    logic [255:0] v_exp  [0:MAXV-1];
    int           nvec = 0;

    initial begin
        int fd, r, rr, msg_err0, t_id, t_idx, t_len;
        bit more, last_of_msg;
        logic [511:0] t_blk;
        logic [255:0] t_hin, t_exp;
        logic [255:0] hin, got, prev;
        bit prev_valid;
        string tag, unit;

        // ================= load vectors from the C reference =================
        fd = $fopen(VEC_FILE, "r");
        if (fd == 0) begin
            fail($sformatf("cannot open %s (run via `make sim_core`)", VEC_FILE));
        end else begin
            more = 1'b1;
            while (more && nvec < MAXV) begin
                r = $fscanf(fd, " %d %d %d %h %h %h", t_id, t_idx, t_len, t_blk, t_hin, t_exp);
                if (r != 6) begin
                    more = 1'b0;
                end else begin
                    v_id[nvec] = t_id;   v_idx[nvec] = t_idx; v_len[nvec] = t_len;
                    v_blk[nvec] = t_blk; v_hin[nvec] = t_hin; v_exp[nvec] = t_exp;
                    nvec++;
                end
            end
            $fclose(fd);
        end
        check_int("vectors read", nvec, EXPECTED_BLOCKS);
        for (int i = 0; i < nvec; i++)
            if (v_idx[i] == 0) check_eq256($sformatf("vector %0d starts from H_INIT", i), v_hin[i], H_INIT);

        // ================= reset =================
        rst_n = 1'b0;
        tick(); tick(); tick();
        check_bit("reset: busy low", busy, 1'b0);
        check_bit("reset: done low", done, 1'b0);
        rst_n = 1'b1;
        tick();
        check_bit("after reset: busy low", busy, 1'b0);
        check_bit("after reset: done low", done, 1'b0);
        tick(); tick();

        // ================= every block of every message, hardware chaining =================
        prev_valid = 1'b0;
        prev = 'x;
        got  = 'x;
        msg_err0 = errors;
        for (int i = 0; i < nvec; i++) begin
            if (v_idx[i] == 0) begin
                hin = H_INIT;               // first block: initial hash values
                msg_err0 = errors;
            end else begin
                hin = got;                  // continuation: the DUT's own previous digest
            end
            tag = $sformatf("msg %0d block %0d", v_id[i], v_idx[i]);
            run_block(tag, v_blk[i], hin, v_exp[i], 0, prev, prev_valid, got);
            prev = got;
            prev_valid = 1'b1;

            last_of_msg = (i == nvec - 1) ? 1'b1 : (v_idx[i+1] == 0);
            if (last_of_msg) begin
                if (v_id[i] == 0) check_eq256("msg 0 \"abc\" vs NIST",       got, NIST_ABC);
                if (v_id[i] == 1) check_eq256("msg 1 empty vs NIST",         got, NIST_EMPTY);
                if (v_id[i] == 2) check_eq256("msg 2 56-byte vs NIST",       got, NIST_448);
                if (errors == msg_err0) begin
                    unit = (v_idx[i] == 0) ? "block" : "blocks";
                    $display("PASS msg %0d (%0d bytes, %0d %s): %h", v_id[i], v_len[i],
                             v_idx[i] + 1, unit, got);
                end
            end
            // alternate between back-to-back starts and a short idle gap
            if (i % 2 == 1) begin
                idle_hold($sformatf("gap after block %0d", i), 3, got);
            end
        end

        // ================= ignored starts: "abc" with garbage start pulses =================
        msg_err0 = errors;
        run_block("abc with ignored starts", v_blk[0], H_INIT, v_exp[0], 1, prev, prev_valid, got);
        if (errors == msg_err0) $display("PASS start pulses while busy / in done cycle are ignored");

        // ================= reset in the middle of a block =================
        msg_err0 = errors;
        n_done = 0;
        blk_drv = v_blk[2]; hin_drv = H_INIT; start = 1'b1; #1;
        tick();
        drop_start();
        repeat (30) tick();
        check_bit("abort: still busy before reset", busy, 1'b1);
        rst_n = 1'b0;
        tick();
        check_bit("abort: busy low after reset", busy, 1'b0);
        check_bit("abort: done low after reset", done, 1'b0);
        tick();
        rst_n = 1'b1;
        repeat (6) begin
            check_bit("abort: stays idle", busy, 1'b0);
            check_bit("abort: no done pulse", done, 1'b0);
            tick();
        end
        check_int("abort: no done pulses at all", n_done, 0);
        run_block("block after abort", v_blk[0], H_INIT, v_exp[0], 0, prev, 1'b0, got);
        check_eq256("block after abort vs NIST abc", got, NIST_ABC);
        if (errors == msg_err0) $display("PASS reset aborts a block; core then computes a correct digest");

        $display("checks run: %0d", checks);
        if (errors == 0) $display("TB_RESULT: PASS (all checks)");
        else             $display("TB_RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
