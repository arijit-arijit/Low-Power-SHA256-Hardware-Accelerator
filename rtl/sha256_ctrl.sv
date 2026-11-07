// sha256_ctrl.sv
// Controller FSM for the iterative SHA-256 core: IDLE -> ROUNDS -> DONE.
//
// Pure control: it contains no SHA-256 data. It sequences one block through
//   1 load cycle + 64 round cycles + 1 final-add cycle, then pulses `done`.
// The datapath (added later in sha256_core.sv) does what these outputs say:
//   load      : initialise working variables from h_in and load the scheduler
//   round_en  : perform round `round_cnt[5:0]` and advance the scheduler
//   final_add : digest <= h_in + working variables
//
// Interface
//   clk, rst_n : rising-edge clock, synchronous active-low reset
//   start      : request to process one block. Sampled only in IDLE. Keep it high
//                for exactly one cycle; a start while busy or in DONE is ignored.
//                Do not assert it during reset (see Reset).
//   busy       : high while the block is being processed (state ROUNDS)
//   done       : high for exactly one cycle (state DONE) when the digest is valid
//   load       : high in the cycle that start is accepted (IDLE && start).
//                This output depends combinationally on `start`.
//   round_en   : high in the 64 round cycles (round_cnt = 0..63)
//   final_add  : high in the single cycle after round 63 (round_cnt = 64)
//   round_cnt  : 7-bit counter. 0 in IDLE and DONE; 0..63 are rounds, 64 is the
//                final-add cycle. The K ROM index is round_cnt[5:0].
//
// Timing (cycle 0 = the cycle in which `start` is high in IDLE)
//   cycle 0        IDLE    load=1                         cnt = 0
//   cycles 1..64   ROUNDS  busy=1 round_en=1              cnt = 0..63
//   cycle 65       ROUNDS  busy=1 final_add=1             cnt = 64
//   cycle 66       DONE    done=1  (digest valid)         cnt = 0
//   cycle 67       IDLE    (a new start may be given here)
// So `done` is seen 66 cycles after `start`. busy is low in the start cycle
// (outputs are decoded from the state register) and low again when done is high.
//
// Reset: synchronous. While rst_n is low the FSM goes to IDLE with cnt = 0 at the
// next clock edge, aborting any block in progress (no `done` pulse). `start` is
// ignored during reset, but `load` is not gated by rst_n, so it can pulse if
// start is held high in IDLE during reset; keep start low then.
//
// Unreachable state encoding 2'b11 returns to IDLE.
module sha256_ctrl (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    output logic       busy,
    output logic       done,
    output logic       load,
    output logic       round_en,
    output logic       final_add,
    output logic [6:0] round_cnt
);

    typedef enum logic [1:0] {
        S_IDLE   = 2'd0,
        S_ROUNDS = 2'd1,
        S_DONE   = 2'd2
    } state_t;

    // cnt value of the final-add cycle: rounds are 0..63, then 64
    localparam logic [6:0] FINAL_ADD_CNT = 7'd64;

    state_t     state, state_n;
    logic [6:0] cnt, cnt_n;

    // ---- next-state and counter logic ----
    always_comb begin
        state_n = state;
        cnt_n   = cnt;
        case (state)
            S_IDLE: begin
                if (start) state_n = S_ROUNDS;      // cnt is already 0
            end
            S_ROUNDS: begin
                if (cnt == FINAL_ADD_CNT) begin
                    state_n = S_DONE;
                    cnt_n   = 7'd0;                 // leave the counter ready for next block
                end else begin
                    cnt_n = cnt + 7'd1;
                end
            end
            S_DONE: begin
                state_n = S_IDLE;
            end
            default: begin
                state_n = S_IDLE;
                cnt_n   = 7'd0;
            end
        endcase
    end

    // ---- state registers: synchronous active-low reset ----
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cnt   <= 7'd0;
        end else begin
            state <= state_n;
            cnt   <= cnt_n;
        end
    end

    // ---- outputs ----
    assign busy      = (state == S_ROUNDS);
    assign done      = (state == S_DONE);
    assign load      = (state == S_IDLE) && start;
    assign round_en  = busy && !cnt[6];     // cnt 0..63
    assign final_add = busy &&  cnt[6];     // cnt == 64 (only value >= 64 in ROUNDS)
    assign round_cnt = cnt;

endmodule
