// sha256_msg_sched.sv
// SHA-256 message schedule with a 16-word rolling window (FIPS 180-4, 6.2.2).
//
// SHA-256 needs W[0..63] for one block:
//   W[t] = block word t                                          t = 0..15
//   W[t] = sigma1(W[t-2]) + W[t-7] + sigma0(W[t-15]) + W[t-16]   t = 16..63
// Storing all 64 words would cost 2048 flops. Only the next 16 are ever needed, so
// this module keeps a window and shifts it one word per round.
//
// Window contents (look-ahead form): at round t the window holds W[t] .. W[t+15],
// stored in one flat 512-bit register laid out exactly like the input block:
//   win[511:480] = W[t]   (oldest, used now)
//   win[479:448] = W[t+1]
//   ...
//   win[31:0]    = W[t+15]
// so the word for the current round comes straight out of a register
// (w = win[511:480]): no adder sits between this module and the round datapath.
// On every advance the window shifts left by one word and appends
//   W[t+16] = sigma1(W[t+14]) + W[t+9] + sigma0(W[t+1]) + W[t]
//
// Interface
//   clk     : rising-edge clock
//   load    : synchronous. Window <= block; w becomes W[0] on the next cycle.
//             Has priority over `advance`.
//   block   : padded 512-bit message block. Word 0 (first 4 message bytes,
//             big-endian) is block[511:480]; word 15 is block[31:0].
//   advance : synchronous. Window shifts by one round (w becomes W[t+1]).
//             When neither load nor advance is high the window holds.
//   w       : W[t] for the current round.
//
// Expected use by the core: pulse `load` once with the block (same cycle the
// working variables are initialised), then hold `advance` high for the 64 round
// cycles; during round t, w = W[t]. Words computed after W[63] are never used.
//
// Reset: none, by design. The window is only meaningful after the first `load`;
// w is X in simulation before that. The controller FSM, not this datapath, owns
// reset and guarantees `load` happens before the first round.
module sha256_msg_sched (
    input  logic         clk,
    input  logic         load,
    input  logic [511:0] block,
    input  logic         advance,
    output logic [31:0]  w
);

    // Functions assign to their own name instead of using `return`, and the window
    // is a flat vector instead of a 2-D packed array: Yosys 0.33 (Ubuntu 24.04)
    // parses neither `return <expr>;` nor `logic [15:0][31:0]`.
    function automatic logic [31:0] rotr(input logic [31:0] x, input int n);
        rotr = (x >> n) | (x << (32 - n));
    endfunction

    function automatic logic [31:0] small_sigma0(input logic [31:0] x);
        small_sigma0 = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
    endfunction

    function automatic logic [31:0] small_sigma1(input logic [31:0] x);
        small_sigma1 = rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
    endfunction

    logic [511:0] win;      // W[t] in [511:480] ... W[t+15] in [31:0]
    logic [31:0]  w_t;      // W[t]
    logic [31:0]  w_t1;     // W[t+1]
    logic [31:0]  w_t9;     // W[t+9]
    logic [31:0]  w_t14;    // W[t+14]
    logic [31:0]  w_next;   // W[t+16]

    assign w_t    = win[511:480];
    assign w_t1   = win[479:448];
    assign w_t9   = win[223:192];
    assign w_t14  = win[63:32];
    assign w_next = small_sigma1(w_t14) + w_t9 + small_sigma0(w_t1) + w_t;

    assign w = w_t;

    always_ff @(posedge clk) begin
        if (load)
            win <= block;
        else if (advance)
            win <= {win[479:0], w_next};
    end

endmodule
