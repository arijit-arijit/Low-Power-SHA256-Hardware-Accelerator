// tb_sha256_round.sv
// Self-checking unit test for the combinational round.
// Expected values: FIPS 180-4 worked example for "abc" (rounds t=0 and t=1),
// cross-checked against `ref/sha256_ref -t` (C reference model).
`timescale 1ns/1ps

module tb_sha256_round;

    logic [255:0] state_in, state_out;
    logic [31:0]  k, w;
    int           errors = 0;

    sha256_round dut (.state_in(state_in), .k(k), .w(w), .state_out(state_out));

    // Compare and report one check
    task automatic check(input string name, input logic [255:0] expected);
        #1; // let combinational logic settle
        if (state_out !== expected) begin
            errors++;
            $display("FAIL %s\n  got      %h\n  expected %h", name, state_out, expected);
        end else begin
            $display("PASS %s", name);
        end
    endtask

    localparam logic [255:0] H_INIT = {32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
                                       32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19};

    localparam logic [255:0] ABC_R0 = {32'h5d6aebcd, 32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372,
                                       32'hfa2a4622, 32'h510e527f, 32'h9b05688c, 32'h1f83d9ab};

    localparam logic [255:0] ABC_R1 = {32'h5a6ad9ad, 32'h5d6aebcd, 32'h6a09e667, 32'hbb67ae85,
                                       32'h78ce7989, 32'hfa2a4622, 32'h510e527f, 32'h9b05688c};

    initial begin
        // Round 0 of "abc": H_INIT, K[0], W[0] = "abc" + 0x80 padding byte
        state_in = H_INIT; k = 32'h428a2f98; w = 32'h61626380;
        check("abc round 0", ABC_R0);

        // Round 1: feed round 0's expected output forward, K[1], W[1] = 0
        state_in = ABC_R0; k = 32'h71374491; w = 32'h00000000;
        check("abc round 1", ABC_R1);

        // Pure combinational: no hidden state, repeating round 0 must repeat the result
        state_in = H_INIT; k = 32'h428a2f98; w = 32'h61626380;
        check("abc round 0 repeated", ABC_R0);

        if (errors == 0) $display("TB_RESULT: PASS (all checks)");
        else             $display("TB_RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
