module top_fc (
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic signed [31:0] pool_mem [0:8],
    output logic signed [31:0] fc2_out [0:2],
    output logic done
);
    logic fc1_start, fc1_done;
    logic fc2_start, fc2_done;
    logic signed [31:0] fc1_out [0:7];
    typedef enum logic [2:0] {
        IDLE,
        FC1_START,
        FC1_WAIT,
        FC2_START,
        FC2_WAIT,
        DONE
    } state_t;
    state_t state;
    assign fc1_start = (state == FC1_START);
    assign fc2_start = (state == FC2_START);

    fc1 layer1 (
        .clk(clk),
        .rst(rst),
        .start(fc1_start),
        .pool_mem(pool_mem),
        .fc1_out(fc1_out),
        .done(fc1_done)
    );

    fc2 layer2 (
        .clk(clk),
        .rst(rst),
        .start(fc2_start),
        .fc1_in(fc1_out),
        .fc2_out(fc2_out),
        .done(fc2_done)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        done  <= 1'b0;
                        state <= FC1_START;
                    end
                end
                FC1_START: begin
                    state <= FC1_WAIT;
                end
                FC1_WAIT: begin
                    if (fc1_done)
                        state <= FC2_START;
                end
                FC2_START: begin
                    state <= FC2_WAIT;
                end
                FC2_WAIT: begin
                    if (fc2_done)
                        state <= DONE;
                end
                DONE: begin
                    done <= 1'b1;
                    if (!start)
                        state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    done  <= 1'b0;
                end
            endcase
        end
    end
endmodule