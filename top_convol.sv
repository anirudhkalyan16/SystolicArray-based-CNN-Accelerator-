module window_extractor_8x8 (
    input  logic [2:0] row,
    input  logic [2:0] col,

    output logic [7:0] p1, p2, p3,
    output logic [7:0] p4, p5, p6,
    output logic [7:0] p7, p8, p9
);

    logic [7:0] image_mem [0:63];
    logic [5:0] base;

    initial begin
        $readmemh("C:/Pdf files/sem v/SystolicArray-based-CNN-Accelerator-/image.hex", image_mem);
    end

    always_comb begin
        base = row * 8 + col;

        p1 = image_mem[base];
        p2 = image_mem[base + 1];
        p3 = image_mem[base + 2];

        p4 = image_mem[base + 8];
        p5 = image_mem[base + 9];
        p6 = image_mem[base + 10];

        p7 = image_mem[base + 16];
        p8 = image_mem[base + 17];
        p9 = image_mem[base + 18];
    end

endmodule


module convol (
    input  logic [7:0] p1, p2, p3,
    input  logic [7:0] p4, p5, p6,
    input  logic [7:0] p7, p8, p9,

    input  logic signed [7:0] w1, w2, w3,
    input  logic signed [7:0] w4, w5, w6,
    input  logic signed [7:0] w7, w8, w9,

    input  logic clk,
    input  logic rst,

    output logic signed [31:0] sum
);

    logic signed [15:0] prod1, prod2, prod3;
    logic signed [15:0] prod4, prod5, prod6;
    logic signed [15:0] prod7, prod8, prod9;

    assign prod1 = $signed({1'b0, p1}) * w1;
    assign prod2 = $signed({1'b0, p2}) * w2;
    assign prod3 = $signed({1'b0, p3}) * w3;
    assign prod4 = $signed({1'b0, p4}) * w4;
    assign prod5 = $signed({1'b0, p5}) * w5;
    assign prod6 = $signed({1'b0, p6}) * w6;
    assign prod7 = $signed({1'b0, p7}) * w7;
    assign prod8 = $signed({1'b0, p8}) * w8;
    assign prod9 = $signed({1'b0, p9}) * w9;

    always_ff @(posedge clk) begin
        if (rst)
            sum <= 32'sd0;
        else
            sum <= prod1 + prod2 + prod3 +
                   prod4 + prod5 + prod6 +
                   prod7 + prod8 + prod9;
    end

endmodule


module top_convol (
    input  logic [2:0] row,
    input  logic [2:0] col,

    input  logic signed [7:0] w1, w2, w3,
    input  logic signed [7:0] w4, w5, w6,
    input  logic signed [7:0] w7, w8, w9,

    input  logic clk,
    input  logic rst,

    output logic signed [31:0] sum
);

    logic [7:0] p1,p2,p3,p4,p5,p6,p7,p8,p9;

    window_extractor_8x8 window (
        .row(row),
        .col(col),
        .p1(p1), .p2(p2), .p3(p3),
        .p4(p4), .p5(p5), .p6(p6),
        .p7(p7), .p8(p8), .p9(p9)
    );

    convol convolution (
        .p1(p1), .p2(p2), .p3(p3),
        .p4(p4), .p5(p5), .p6(p6),
        .p7(p7), .p8(p8), .p9(p9),

        .w1(w1), .w2(w2), .w3(w3),
        .w4(w4), .w5(w5), .w6(w6),
        .w7(w7), .w8(w8), .w9(w9),

        .clk(clk),
        .rst(rst),
        .sum(sum)
    );

endmodule