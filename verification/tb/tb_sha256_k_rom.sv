// tb_sha256_k_rom.sv
// Self-checking test for sha256_k_rom: ALL 64 constants are compared.
//
// Expected values are NOT typed into this file. They are loaded from
// build/k_expected.hex, which `make` produces with `ref/sha256_ref -k`. That C
// program first verifies its table against the definition of K[t] (cube roots of
// the first 64 primes), so the oracle is independent of the RTL.
//
// Run from the project root (the hex path is relative to the working directory):
//   make sim_k_rom
`timescale 1ns/1ps

module tb_sha256_k_rom;

    localparam string EXPECTED_FILE = "build/k_expected.hex";

    logic [5:0]  idx;
    logic [31:0] k;
    logic [31:0] expected [0:63];
    int          errors = 0;
    int          checks = 0;
    int          seed;

    sha256_k_rom dut (.idx(idx), .k(k));

    // Apply one index and compare against the loaded expectation
    task automatic check_idx(input int i, input string pass_name);
        idx = i[5:0];
        #1; // let combinational logic settle
        checks++;
        if (k !== expected[i]) begin
            errors++;
            $display("FAIL %s idx=%0d got %h expected %h", pass_name, i, k, expected[i]);
        end
    endtask

    initial begin
        // Load expected table; fail loudly if the file is missing or short
        for (int i = 0; i < 64; i++) expected[i] = 32'hxxxxxxxx;
        $readmemh(EXPECTED_FILE, expected);
        for (int i = 0; i < 64; i++) begin
            if (^expected[i] === 1'bx) begin
                errors++;
                $display("FAIL expected table entry %0d not loaded from %s", i, EXPECTED_FILE);
            end
        end

        // Pass 1: ascending 0..63 (the order the core will use)
        for (int i = 0; i < 64; i++) check_idx(i, "ascending");
        if (errors == 0) $display("PASS all 64 constants, ascending order");

        // Pass 2: descending - a pure lookup must not depend on previous index
        for (int i = 63; i >= 0; i--) check_idx(i, "descending");
        if (errors == 0) $display("PASS all 64 constants, descending order");

        // Pass 3: pseudo-random order, fixed seed so the run is reproducible
        seed = 32'h5a17;
        for (int n = 0; n < 256; n++) check_idx($unsigned($random(seed)) % 64, "random");
        if (errors == 0) $display("PASS 256 random-order lookups");

        // Unknown index (simulation-only behaviour, documented in the RTL header):
        // output must be X, never a valid-looking constant.
        idx = 6'b0000x1;
        #1;
        checks++;
        if (^k !== 1'bx) begin
            errors++;
            $display("FAIL idx with X bit returned %h, expected X", k);
        end else begin
            $display("PASS X in idx gives X on k");
        end

        $display("checks run: %0d", checks);
        if (errors == 0) $display("TB_RESULT: PASS (all checks)");
        else             $display("TB_RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
