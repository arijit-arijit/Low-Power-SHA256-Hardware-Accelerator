`timescale 1ns/1ps

module tb_prefix_add32;

    logic [31:0] a;
    logic [31:0] b;
    logic [31:0] sum;

    logic [31:0] expected;
    integer errors;
    integer n;

    prefix_add32 dut (
        .a(a),
        .b(b),
        .sum(sum)
    );

    task automatic check_add(
        input logic [31:0] x,
        input logic [31:0] y
    );
        begin
            a = x;
            b = y;
            expected = x + y;
            #1;

            if (sum !== expected) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display(
                        "FAIL: a=%h b=%h got=%h expected=%h",
                        x, y, sum, expected
                    );
            end
        end
    endtask

    initial begin
        errors = 0;
        a = 0;
        b = 0;

        // Directed corner cases
        check_add(32'h00000000, 32'h00000000);
        check_add(32'hFFFFFFFF, 32'h00000001);
        check_add(32'hFFFFFFFF, 32'hFFFFFFFF);
        check_add(32'h80000000, 32'h80000000);
        check_add(32'h7FFFFFFF, 32'h00000001);
        check_add(32'hAAAAAAAA, 32'h55555555);

        // Randomized comparisons against the built-in addition operator
        for (n = 0; n < 200000; n = n + 1) begin
            check_add($urandom, $urandom);
        end

        if (errors == 0)
            $display("PASS: prefix_add32, 200000 random vectors plus directed cases");
        else
            $display("FAIL: prefix_add32, errors=%0d", errors);

        $finish;
    end

endmodule
