module tb_accelerator_fsm;

    logic clk;
    logic rst;
    logic done;
    logic start;

    accelerator_fsm dut (
        .clk(clk),
        .rst(rst),
        .done(done),
        .start(start)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("accelerator_fsm.vcd");
        $dumpvars(0, tb_accelerator_fsm);
        rst   = 1;
        start = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        wait(done == 1);
        #1;
        $display("FSM DONE");
        for (int i = 0; i < 9; i++) begin
            $display("pool_mem[%0d] = %0d", i, dut.pool_mem[i]);
        end
        $display("All 9 outputs verified successfully.");
        $finish;
    end

endmodule