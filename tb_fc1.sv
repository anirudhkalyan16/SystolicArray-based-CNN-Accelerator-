module tb_fc1;
    logic clk;
    logic rst;
    logic start;
    logic signed [31:0] pool_mem [0:8];
    logic signed [31:0] fc1_out [0:7];
    logic done;
    fc1 dut(
        .pool_mem(pool_mem),
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .fc1_out(fc1_out)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    initial begin
        rst = 1;
        start = 0;
        pool_mem[0] = 436;
        pool_mem[1] = 224;
        pool_mem[2] = 0;
        pool_mem[3] = 218;
        pool_mem[4] = 514;
        pool_mem[5] = 0;
        pool_mem[6] = 604;
        pool_mem[7] = 512;
        pool_mem[8] = 0;

        // Hold reset for two rising edges
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        // Start on a negative edge so it is stable
        // before the next positive edge
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;
        wait(done);
        @(posedge clk);
        $display("\nFC1 OUTPUTS");
        for (int i = 0; i < 8; i++) begin
            $display(
                "fc1_out[%0d] = %0d",
                i,
                fc1_out[i]
            );
        end
        $finish;
    end
    // Debug
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
    // Prevent infinite simulation
    initial begin
        #1000;
        $display("ERROR: Simulation timed out");
        $finish;
    end
endmodule