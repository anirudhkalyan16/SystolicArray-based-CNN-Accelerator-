module tb_fc2;

    logic clk;
    logic rst;
    logic start;
    logic signed [31:0] fc1_out [0:7];
    logic signed [31:0] fc2_out [0:3];
    logic done;

    fc2 dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .fc1_in(fc1_out),
        .fc2_out(fc2_out),
        .done(done)
    );

    initial begin
        clk = 0;
    end

    always #5 clk = ~clk;

    initial begin
        rst = 1;
        start = 0;

        fc1_out[0] = 12;
        fc1_out[1] = 7;
        fc1_out[2] = 19;
        fc1_out[3] = 4;
        fc1_out[4] = 15;
        fc1_out[5] = 9;
        fc1_out[6] = 21;
        fc1_out[7] = 6;

        #10;
        rst = 0;

        #10;
        start = 1;

        #10;
        start = 0;

        wait(done);

        for (int i = 0; i < 4; i++) begin
            $display("fc2_out[%0d] = %0d", i, fc2_out[i]);
        end

        $finish;
    end

endmodule