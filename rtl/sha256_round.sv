// sha256_round.sv
// One combinational SHA-256 compression round.
// Uses carry-save adders to reduce multioperand addition depth.

module sha256_round (
    input  logic [255:0] state_in,
    input  logic [31:0]  k,
    input  logic [31:0]  w,
    output logic [255:0] state_out
);

    function automatic logic [31:0] rotr(input logic [31:0] x, input integer n);
        rotr = (x >> n) | (x << (32 - n));
    endfunction

    function automatic logic [31:0] ch(input logic [31:0] x, y, z);
        ch = (x & y) ^ (~x & z);
    endfunction

    function automatic logic [31:0] maj(input logic [31:0] x, y, z);
        maj = (x & y) ^ (x & z) ^ (y & z);
    endfunction

    function automatic logic [31:0] big_sigma0(input logic [31:0] x);
        big_sigma0 = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
    endfunction

    function automatic logic [31:0] big_sigma1(input logic [31:0] x);
        big_sigma1 = rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
    endfunction

    // Carry-save compressor: x + y + z = sum + carry (modulo 2^32).
    function automatic logic [63:0] csa(
        input logic [31:0] x, y, z
    );
        logic [31:0] s, c;
        begin
            s = x ^ y ^ z;
            c = ((x & y) | (x & z) | (y & z)) << 1;
            csa = {s, c};
        end
    endfunction

    logic [31:0] a, b, c, d, e, f, g, h;

    logic [31:0] a_s1, a_c1, a_s2, a_c2;
    logic [31:0] a_s3, a_c3, a_s4, a_c4;
    logic [31:0] a_s5, a_c5;

    logic [31:0] e_s1, e_c1, e_s2, e_c2;
    logic [31:0] e_s3, e_c3, e_s4, e_c4;

    logic [31:0] a_next, e_next;

    assign {a, b, c, d, e, f, g, h} = state_in;

    // CSA tree for a_next.
assign {a_s1, a_c1} = csa(h, big_sigma1(e), ch(e, f, g));
assign {a_s2, a_c2} = csa(k, w, big_sigma0(a));
assign {a_s3, a_c3} = csa(a_s1, a_c1, a_s2);
assign {a_s4, a_c4} = csa(a_c2, a_s3, a_c3);
assign {a_s5, a_c5} = csa(a_s4, a_c4, maj(a, b, c));

prefix_add32 u_a_add (.a(a_s5), .b(a_c5), .sum(a_next));

// CSA tree for e_next.
assign {e_s1, e_c1} = csa(d, h, big_sigma1(e));
assign {e_s2, e_c2} = csa(ch(e, f, g), k, w);
assign {e_s3, e_c3} = csa(e_s1, e_c1, e_s2);
assign {e_s4, e_c4} = csa(e_c2, e_s3, e_c3);

prefix_add32 u_e_add (.a(e_s4), .b(e_c4), .sum(e_next));
assign state_out = {a_next, a, b, c, e_next, e, f, g};
endmodule
