`timescale 1ns/1ps
// Sustained-hashing activity testbench: NBLK chained blocks, back to back.
// Run 1 (RTL): writes build/power/golden.hex. Run 2 (+CHECK): compares against it.
// Plusargs: +CHECK  +HALF=<half period ns>  +VCD=<file>
module tb_sha256_power;
    localparam int NBLK = 20;
    localparam logic [255:0] H_INIT = {32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
                                       32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19};
    logic clk = 1'b0, rst_n = 1'b0, start = 1'b0;
    logic [511:0] blk = '0;
    logic [255:0] hin = '0;
    logic busy, done;
    logic [255:0] digest;
    sha256_core dut (.clk(clk), .rst_n(rst_n), .start(start), .block(blk), .h_in(hin),
                     .busy(busy), .done(done), .digest(digest));
    real half;
    initial begin
        if (!$value$plusargs("HALF=%f", half)) half = 6.6;
        forever #(half) clk = ~clk;
    end
    int cyc = 0;
    always @(posedge clk) cyc++;
    function automatic logic [31:0] xs(input logic [31:0] v);
        logic [31:0] t;
        t = v ^ (v << 13); t = t ^ (t >> 17); t = t ^ (t << 5);
        return t;
    endfunction
    logic [255:0] gold [0:NBLK-1];
    logic [255:0] got  [0:NBLK-1];
    int cs [0:NBLK-1];
    logic [31:0] s;
    int n, i, g, errors = 0, fd;
    bit chk;
    string vcdname;
    initial begin
        chk = $test$plusargs("CHECK");
        if ($value$plusargs("VCD=%s", vcdname)) begin
            $dumpfile(vcdname);
            $dumpvars(0, tb_sha256_power.dut);
        end
        if (chk) $readmemh("build/power/golden.hex", gold);
        s = 32'h1badb002;
        repeat (4) @(posedge clk);
        #1 rst_n = 1'b1;
        @(posedge clk); #1;
        for (n = 0; n < NBLK; n++) begin
            for (i = 0; i < 16; i++) begin s = xs(s); blk[32*i +: 32] = s; end
            hin = (n == 0) ? H_INIT : got[n-1];
            cs[n] = cyc;
            start = 1'b1;
            @(posedge clk); #1;
            start = 1'b0;
            g = 0;
            while (done !== 1'b1 && g < 200) begin @(posedge clk); #1; g++; end
            if (done !== 1'b1) begin errors++; $display("FAIL block %0d: no done", n); end
            got[n] = digest;
            if (chk && got[n] !== gold[n]) begin errors++; $display("FAIL block %0d digest mismatch", n); end
            @(posedge clk); #1;
        end
        if (!chk) begin
            fd = $fopen("build/power/golden.hex", "w");
            for (n = 0; n < NBLK; n++) $fdisplay(fd, "%064h", got[n]);
            $fclose(fd);
            $display("GOLDEN_WRITTEN blocks=%0d", NBLK);
        end
        $display("cycles per block (start to start) = %0d", (cs[NBLK-1] - cs[0]) / (NBLK - 1));
        if (chk) begin
            if (errors == 0) $display("TB_RESULT: PASS (%0d blocks match golden)", NBLK);
            else             $display("TB_RESULT: FAIL (%0d errors)", errors);
        end
        $finish;
    end
endmodule
