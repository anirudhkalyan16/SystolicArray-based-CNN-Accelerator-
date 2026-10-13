module tb_fc2;
    logic clk;
    logic rst;
    logic start;
    logic signed [31:0] fc1_in [0:7];
    logic signed [31:0] fc2_out [0:2];
    logic done;
    fc2 dut(
        .clk(clk),
        .rst(rst),
        .start(start),
        .fc1_in(fc1_in),
        .fc2_out(fc2_out),
        .done(done)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    initial begin
        rst = 1;
        start = 0;
        // FC1 outputs already verified against Python
        fc1_in[0] = 51875;
        fc1_in[1] = 42540;
        fc1_in[2] = 0;
        fc1_in[3] = 23455;
        fc1_in[4] = 74676;
        fc1_in[5] = 0;
        fc1_in[6] = 51839;
        fc1_in[7] = 0;
        // Reset
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        // Start FC2
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;
        // Wait until FC2 finishes
        wait(done);
        @(posedge clk);
        $display("");
        $display("FC2 OUTPUTS");
        for (int i = 0; i < 3; i++) begin
            $display(
                "fc2_out[%0d] = %0d",
                i,
                fc2_out[i]
            );
        end
        $display("");
        $display("EXPECTED");
        $display("fc2_out[0] = -2001738");
        $display("fc2_out[1] = -6374125");
        $display("fc2_out[2] = 6273312");
        $finish;
    end
    // Debug information
    always @(posedge clk) begin
        $display(
            "time=%0t rst=%b start=%b busy=%b neuron=%0d done=%b sum=%0d",
            $time,
            rst,
            start,
            dut.busy,
            dut.neuron_index,
            done,
            dut.sum
        );

    end
    // Prevent simulation from hanging forever
    initial begin
        #1000;
        $display("ERROR: Simulation timed out");
        $finish;
    end

endmodule