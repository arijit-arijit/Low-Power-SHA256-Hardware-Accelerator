// tb_sha256_msg_sched.sv
// Self-checking test for sha256_msg_sched.
//
// Vectors come from the C reference (`ref/sha256_ref -w`, written to
// build/sched_vectors.txt by `make`): for each padded block, one line with the
// 512-bit block followed by 64 lines W[0]..W[63]. Four blocks: "abc", empty
// message, and the two blocks of the 56-byte message.
//
// Per block the test:
//   - loads the block, then checks w == W[t] for all t = 0..63 while advancing
//     one round per clock (this is how the core will use it)
//   - inserts idle cycles (advance = 0) and checks the window holds
// Extra directed tests: load beats advance; reload in the middle of a block
// restarts at W[0]; the "abc" block from the file equals a block built by hand here.
//
// Run from the project root (the vector path is relative to the working directory):
//   make sim_msg_sched
`timescale 1ns/1ps

module tb_sha256_msg_sched;

    localparam string VEC_FILE         = "build/sched_vectors.txt";
    localparam int    EXPECTED_VECTORS = 4;
    localparam int    MAXV             = 8;

    // "abc" padded by hand: 0x61626380, zeros, 64-bit message length = 24 bits = 0x18
    localparam logic [511:0] ABC_BLOCK = {32'h61626380, 416'd0, 64'h0000000000000018};

    logic         clk = 1'b0;
    logic         load = 1'b0;
    logic         advance = 1'b0;
    logic [511:0] block_in = '0;
    logic [31:0]  w;

    logic [511:0] blk  [0:MAXV-1];
    logic [31:0]  wexp [0:MAXV-1][0:63];
    int           nvec   = 0;
    int           errors = 0;
    int           checks = 0;

    sha256_msg_sched dut (.clk(clk), .load(load), .block(block_in), .advance(advance), .w(w));

    always #5 clk = ~clk;

    // All stimulus is applied 1 ns after a rising edge and checked at the same point,
    // i.e. after the flops have updated, so there are no clock/stimulus races.
    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    task automatic check_w(input string what, input int v, input int t);
        checks++;
        if (w !== wexp[v][t]) begin
            errors++;
            $display("FAIL %s vector %0d W[%0d]: got %h expected %h", what, v, t, w, wexp[v][t]);
        end
    endtask

    task automatic do_load(input logic [511:0] b);
        block_in = b;
        load     = 1'b1;
        advance  = 1'b0;
        tick();
        load     = 1'b0;
    endtask

    // Full 64-round walk of one vector, with idle cycles sprinkled in
    task automatic run_vector(input int v);
        int err0 = errors;
        do_load(blk[v]);
        for (int t = 0; t < 64; t++) begin
            check_w("walk", v, t);
            if (t % 9 == 4) begin          // idle: window must hold
                advance = 1'b0;
                repeat (3) begin
                    tick();
                    check_w("hold", v, t);
                end
            end
            advance = 1'b1;
            tick();
            advance = 1'b0;
        end
        if (errors == err0) $display("PASS vector %0d: W[0..63] all match", v);
    endtask

    initial begin
        int fd, r, err0;
        bit more;
        logic [31:0] wtmp;

        // ---- load vectors written by the C reference ----
        fd = $fopen(VEC_FILE, "r");
        if (fd == 0) begin
            errors++;
            $display("FAIL cannot open %s (run via `make sim_msg_sched`)", VEC_FILE);
        end else begin
            more = 1'b1;
            while (more && nvec < MAXV) begin
                r = $fscanf(fd, " %h", blk[nvec]);
                if (r != 1) begin
                    more = 1'b0;           // end of file: no further block line
                end else begin
                    for (int t = 0; t < 64; t++) begin
                        r = $fscanf(fd, " %h", wtmp);
                        wexp[nvec][t] = wtmp;
                        if (r != 1) begin
                            errors++;
                            $display("FAIL vector %0d truncated at W[%0d]", nvec, t);
                        end
                    end
                    nvec++;
                end
            end
            $fclose(fd);
        end
        if (nvec != EXPECTED_VECTORS) begin
            errors++;
            $display("FAIL expected %0d vectors, read %0d", EXPECTED_VECTORS, nvec);
        end

        // ---- the file's "abc" block must equal the block constructed by hand ----
        checks++;
        if (blk[0] !== ABC_BLOCK) begin
            errors++;
            $display("FAIL vector 0 block differs from hand-built padded abc\n  file %h\n  hand %h",
                     blk[0], ABC_BLOCK);
        end else $display("PASS vector 0 block equals hand-built padded \"abc\"");

        // ---- main: every vector, all 64 words ----
        for (int v = 0; v < nvec; v++) run_vector(v);

        // ---- load has priority over advance ----
        err0 = errors;
        do_load(blk[0]);
        advance = 1'b1; tick(); tick(); advance = 1'b0;      // now at W[2]
        block_in = blk[1]; load = 1'b1; advance = 1'b1;       // both high
        tick();
        load = 1'b0; advance = 1'b0;
        check_w("load-over-advance", 1, 0);
        if (errors == err0) $display("PASS load beats advance when both are high");

        // ---- reload in the middle of a block restarts at W[0] ----
        err0 = errors;
        do_load(blk[0]);
        advance = 1'b1; repeat (30) tick(); advance = 1'b0;   // mid-block
        do_load(blk[0]);
        for (int t = 0; t < 64; t++) begin
            check_w("reload", 0, t);
            advance = 1'b1; tick(); advance = 1'b0;
        end
        if (errors == err0) $display("PASS reload mid-block restarts at W[0]");

        $display("checks run: %0d", checks);
        if (errors == 0) $display("TB_RESULT: PASS (all checks)");
        else             $display("TB_RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
