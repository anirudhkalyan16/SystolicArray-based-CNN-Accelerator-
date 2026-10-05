module tb_fc1;
    logic clk;
    logic rst;
    logic start;
    logic signed [31:0] pool_mem [0:8];
    logic signed [31:0] fc1_out [0:7];
    logic done;

    fc1 dut(
        .pool_mem(pool_mem), .clk(clk),.rst(rst), .start(start), .done(done), .fc1_out(fc1_out)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    initial begin
        rst = 1;
        start = 0;
        pool_mem[0] = 8;
        pool_mem[1] = 8;
        pool_mem[2] = 8;
        pool_mem[3] = 8;
        pool_mem[4] = 8;
        pool_mem[5] = 8;
        pool_mem[6] = 8;
        pool_mem[7] = 8;
        pool_mem[8] = 8;
        #5;
        rst = 0;
        start = 1;
        #10;
        start = 0;
        wait (done);
        for (int i = 0; i < 8; i++) begin
        $display("fc1_out[%0d] = %0d", i, fc1_out[i]);
        $finish;
        end
    end

endmodule
