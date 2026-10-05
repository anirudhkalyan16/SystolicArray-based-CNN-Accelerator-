module fc2(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic signed [31:0] fc1_in [0:7],
    output logic signed [31:0] fc2_out [0:3],
    output logic done
);

logic signed [7:0]  weights [0:31];
logic signed [31:0] bias [0:3];
logic signed [39:0] prod [0:7];
logic signed [47:0] sum;

logic busy;
logic [2:0] neuron_index;

initial begin
    $readmemh("fc2_weights.hex", weights);
end

initial begin
    $readmemh("fc2_bias.hex", bias);
end

always_ff @(posedge clk) begin
    if (rst) begin
        neuron_index <= 0;
        busy <= 0;
        done <= 0;

        for (int j = 0; j < 4; j++) begin
            fc2_out[j] <= 0;
        end
    end

    else if (start && !busy) begin
        neuron_index <= 0;
        busy <= 1;
        done <= 0;
    end

    else if (busy) begin
        fc2_out[neuron_index] <= sum[31:0];

        if (neuron_index == 3) begin
            busy <= 0;
            done <= 1;
        end
        else begin
            neuron_index <= neuron_index + 1;
        end
    end
end

always_comb begin
    for (int i = 0; i <= 7; i++) begin
        prod[i] = fc1_in[i] *
                  weights[(neuron_index * 8) + i];
    end

    sum = prod[0] + prod[1] + prod[2] + prod[3]+ prod[4] + prod[5] + prod[6] + prod[7]+ bias[neuron_index];
end

endmodule