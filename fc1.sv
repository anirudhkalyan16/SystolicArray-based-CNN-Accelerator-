module fc1(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic signed [31:0] pool_mem [0:8],
    output logic signed [31:0] fc1_out [0:7],
    output logic done
);

logic signed [7:0]  weights [0:71];
logic signed [31:0] bias [0:7];
logic signed [39:0] prod [0:8];
logic signed [47:0] sum;
logic busy;
logic [2:0] neuron_index;


initial begin
    $readmemh("fc1_weights.hex", weights);
end
initial begin
    $readmemh("fc1_bias.hex", bias);
end
always_ff @(posedge clk) begin
    if (rst) begin
        neuron_index <= 0;
        busy         <= 0;
        done         <= 0;

        for (int j = 0; j < 8; j++) begin
            fc1_out[j] <= 0;
        end
    end
    else if (start && !busy) begin
        neuron_index <= 0;
        busy         <= 1;
        done         <= 0;
    end
    else if (busy) begin

        if (sum > 0)
            fc1_out[neuron_index] <= sum[31:0];
        else
            fc1_out[neuron_index] <= 0;
        if (neuron_index == 7) begin
            busy <= 0;
            done <= 1;
        end
        else begin
            neuron_index <= neuron_index + 1;
        end
    end
end

always_comb begin
    for (int i = 0; i <= 8; i++) begin
        prod[i] = pool_mem[i] *
                  weights[(neuron_index * 9) + i];
    end
    sum = prod[0] + prod[1] + prod[2] + prod[3] + prod[4] + prod[5] + prod[6] + prod[7] + prod[8] + bias[neuron_index];

end

endmodule