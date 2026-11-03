`timescale 1ns/1ps
module tb_top_fc;
    logic clk = 0;
    logic rst = 1;
    logic conv_start = 0;
    logic fc_start = 0;
    wire conv_done;
    wire fc_done;
    wire signed [31:0] pool_mem [0:8];
    wire signed [31:0] fc2_out [0:2];
    accelerator_fsm frontend (
        .clk(clk),
        .rst(rst),
        .start(conv_start),
        .done(conv_done),
        .pool_mem(pool_mem)
    );
    top_fc dut (
        .clk(clk),
        .rst(rst),
        .start(fc_start),
        .pool_mem(pool_mem),
        .fc2_out(fc2_out),
        .done(fc_done)
    );
    always #5 clk = ~clk;
    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        conv_start = 1;
        @(negedge clk);
        conv_start = 0;
        wait (conv_done === 1'b1);
        @(negedge clk);

        for (int i = 0; i < 9; i++)
            $display("pool_mem[%0d] = %0d", i, pool_mem[i]);
        fc_start = 1;
        @(negedge clk);
        fc_start = 0;
        wait (fc_done === 1'b1);
        @(negedge clk);
        for (int i = 0; i < 3; i++) begin
            if ($isunknown(fc2_out[i]))
                $fatal(1, "Unknown score: check parameter files");
            $display("Class %0d score = %0d", i, fc2_out[i]);
        end
        $display("FULL IMAGE PROCESSING COMPLETE");
        $finish;
    end
endmodule