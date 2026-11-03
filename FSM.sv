module accelerator_fsm (
    input logic clk,
    input logic rst,
    input logic start,
    output logic done,
    output logic signed [31:0] pool_mem [0:8]
);

    logic [3:0] state;
    localparam IDLE=4'd0;
    localparam CLEAR=4'd1;
    localparam COMPUTE1=4'd2;
    localparam COMPUTE2=4'd3;
    localparam COMPUTE3=4'd4;
    localparam STORE=4'd5;
    localparam NEXT=4'd6;
    localparam POOL=4'd7;
    localparam DONE=4'd8;

    logic [2:0] row,col;
    logic [5:0] out_index;
    logic [2:0] pool_row,pool_col;
    logic [3:0] pool_index;
    logic [5:0] base;
    logic signed [31:0] sum;
    logic signed [31:0] output_mem [0:35];
    logic signed [31:0] A,B,C,D;
    logic signed [31:0] max1,max2,pool_max;
    logic signed [7:0] w1,w2,w3,w4,w5,w6,w7,w8,w9;
    logic clear;

    assign clear=(state==CLEAR);

    assign w1=-8'sd1;
    assign w2=8'sd0;
    assign w3=8'sd1;
    assign w4=-8'sd2;
    assign w5=8'sd0;
    assign w6=8'sd2;
    assign w7=-8'sd1;
    assign w8=8'sd0;
    assign w9=8'sd1;

    top_convol datapath (
        .row(row),
        .col(col),
        .w1(w1),.w2(w2),.w3(w3),
        .w4(w4),.w5(w5),.w6(w6),
        .w7(w7),.w8(w8),.w9(w9),
        .clk(clk),
        .rst(rst),
        .sum(sum)
    );

    always_comb begin
        base=pool_row*6+pool_col;
        A=output_mem[base];
        B=output_mem[base+1];
        C=output_mem[base+6];
        D=output_mem[base+7];
        max1=(A>B)?A:B;
        max2=(C>D)?C:D;
        pool_max=(max1>max2)?max1:max2;
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=IDLE;
            row<=3'd0;
            col<=3'd0;
            out_index<=6'd0;
            pool_row<=3'd0;
            pool_col<=3'd0;
            pool_index<=4'd0;
            done<=1'b0;
            for(int i=0;i<36;i++)
                output_mem[i]<=32'sd0;
            for(int i=0;i<9;i++)
                pool_mem[i]<=32'sd0;
        end
        else begin
            case(state)
                IDLE: begin
                    row<=3'd0;
                    col<=3'd0;
                    out_index<=6'd0;
                    pool_row<=3'd0;
                    pool_col<=3'd0;
                    pool_index<=4'd0;
                    done<=1'b0;
                    if(start)
                        state<=CLEAR;
                    else
                        state<=IDLE;
                end

                CLEAR: begin
                    state<=COMPUTE1;
                end

                COMPUTE1: begin
                    state<=COMPUTE2;
                end

                COMPUTE2: begin
                    state<=COMPUTE3;
                end

                COMPUTE3: begin
                    state<=STORE;
                end

                STORE: begin
                    if(sum>0)
                        output_mem[out_index]<=sum;
                    else
                        output_mem[out_index]<=32'sd0;
                    state<=NEXT;
                end

                NEXT: begin
                    if(out_index==6'd35)
                        state<=POOL;
                    else begin
                        out_index<=out_index+1;
                        if(col==3'd5) begin
                            col<=3'd0;
                            row<=row+1;
                        end
                        else
                            col<=col+1;
                        state<=CLEAR;
                    end
                end

                POOL: begin
                    pool_mem[pool_index]<=pool_max;
                    if(pool_index==4'd8) begin
                        done<=1'b1;
                        state<=DONE;
                    end
                    else begin
                        pool_index<=pool_index+1;
                        if(pool_col==3'd4) begin
                            pool_col<=3'd0;
                            pool_row<=pool_row+2;
                        end
                        else
                            pool_col<=pool_col+2;
                        state<=POOL;
                    end
                end

                DONE: begin
                    done<=1'b1;
                    if(!start)
                        state<=IDLE;
                    else
                        state<=DONE;
                end

                default: begin
                    state<=IDLE;
                end
            endcase
        end
    end

endmodule