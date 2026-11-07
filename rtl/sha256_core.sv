// sha256_core.sv
// Iterative SHA-256 compression core: one round per clock, one padded block per run.
//
//   digest = H(h_in, block):  h_out[i] = h_in[i] + working_variable[i]  after 64 rounds
//
// The module only wires together the verified building blocks and holds the three
// 256-bit registers of the datapath:
//   sha256_ctrl      sequencing (load / round_en / final_add / busy / done, round_cnt)
//   sha256_msg_sched W[t] from a 16-word rolling window
//   sha256_k_rom     K[t]
//   sha256_round     one round, combinational
//   vars             working variables {a,b,c,d,e,f,g,h}
//   h_saved          copy of h_in kept for the final addition
//   digest           result register
//
// Interface
//   clk, rst_n : rising-edge clock, synchronous active-low reset (controller only)
//   start      : one-cycle pulse; accepted only when idle. block and h_in are sampled
//                in the cycle start is high and need NOT be held afterwards.
//   block      : ONE already-padded 512-bit message block, word 0 in block[511:480]
//   h_in       : 256-bit chaining state {H0..H7}, H0 in h_in[255:224]. For the first
//                (or only) block of a message use the SHA-256 initial hash values;
//                for each further block use the digest of the previous block.
//   busy       : high for the 65 cycles after start (64 rounds + final add)
//   done       : one-cycle pulse, 66 cycles after the start cycle; digest is valid
//   digest     : h_in + working variables after 64 rounds. Written only in the
//                final-add cycle, so it keeps its value from one done pulse to the
//                next result. Undefined (X in simulation) until the first block completes.
//
// Scope: this is a block-level compression engine. It does NOT pad messages and does
// NOT sequence multi-block messages; the caller supplies padded blocks and feeds each
// digest back as the next h_in. That is why it is not described as a complete
// arbitrary-length SHA-256 hasher.
//
// Timing (cycle 0 = start high). See docs/CONTROLLER.md for the controller side.
//   cycle 0       load: vars <= h_in, h_saved <= h_in, scheduler window <= block
//   cycles 1..64  round t = cycle-1: vars <= round(vars, K[t], W[t])
//   cycle 65      final add: digest <= h_saved + vars
//   cycle 66      done = 1, digest valid
//
// No reset on the datapath registers (the controller guarantees load precedes use).
module sha256_core (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [511:0] block,
    input  logic [255:0] h_in,
    output logic         busy,
    output logic         done,
    output logic [255:0] digest
);

    // ---- controller ----
    logic       load;
    logic       round_en;
    logic       final_add;
    logic [6:0] round_cnt;

    sha256_ctrl u_ctrl (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .busy      (busy),
        .done      (done),
        .load      (load),
        .round_en  (round_en),
        .final_add (final_add),
        .round_cnt (round_cnt)
    );

    // ---- message schedule and constants ----
    logic [31:0] w;
    logic [31:0] k;

    sha256_msg_sched u_sched (
        .clk     (clk),
        .load    (load),
        .block   (block),
        .advance (round_en),
        .w       (w)
    );

    // round_cnt counts 0..64; only the low 6 bits address the ROM (64 is the final-add cycle)
    sha256_k_rom u_k (
        .idx (round_cnt[5:0]),
        .k   (k)
    );

    // ---- round datapath ----
    logic [255:0] vars;         // working variables {a,b,c,d,e,f,g,h}
    logic [255:0] vars_next;
    logic [255:0] h_saved;      // h_in kept for the final addition
    logic [255:0] sum;          // h_saved + vars, word by word

    sha256_round u_round (
        .state_in  (vars),
        .k         (k),
        .w         (w),
        .state_out (vars_next)
    );

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_final_add
            prefix_add32 u_acc_add (
                .a   (h_saved[32*i +: 32]),
                .b   (vars[32*i +: 32]),
                .sum (sum[32*i +: 32])
            );
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (load) begin
            vars    <= h_in;
            h_saved <= h_in;
        end else if (round_en) begin
            vars <= vars_next;
        end

        if (final_add)
            digest <= sum;
    end

    // round_cnt[6] is intentionally unused (name matches Verilator's unused-signal pattern)
    logic unused_ok;
    assign unused_ok = &{1'b0, round_cnt[6]};

endmodule
