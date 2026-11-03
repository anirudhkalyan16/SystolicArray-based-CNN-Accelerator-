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

//systollic array code starts here
module systollic_array (
    input  logic clk,
    input  logic reset,
    input logic clear,
    input  logic [7:0] p1,p2,p3,p4,p5,p6,p7,p8,p9,
    input  logic signed [7:0] w1,w2,w3,w4,w5,w6,w7,w8,w9,

    output logic signed [31:0] sum
);

    logic signed [31:0] psum1, psum2, psum3;
    logic signed [31:0] psum4, psum5, psum6;
    logic signed [31:0] psum7, psum8, psum9;

    pe pe1(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p1),
        .in_w(w1),
        .psum_in(32'd0),
        .psum_out(psum1)
    );

    pe pe2(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p2),
        .in_w(w2),
        .psum_in(psum1),
        .psum_out(psum2)
    );

    pe pe3(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p3),
        .in_w(w3),
        .psum_in(psum2),
        .psum_out(psum3)
    );

    pe pe4(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p4),
        .in_w(w4),
        .psum_in(32'd0),
        .psum_out(psum4)
    );

    pe pe5(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p5),
        .in_w(w5),
        .psum_in(psum4),
        .psum_out(psum5)
    );

    pe pe6(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p6),
        .in_w(w6),
        .psum_in(psum5),
        .psum_out(psum6)
    );

    pe pe7(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p7),
        .in_w(w7),
        .psum_in(32'd0),
        .psum_out(psum7)
    );

    pe pe8(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p8),
        .in_w(w8),
        .psum_in(psum7),
        .psum_out(psum8)
    );

    pe pe9(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .in_p(p9),
        .in_w(w9),
        .psum_in(psum8),
        .psum_out(psum9)
    );

    assign sum = psum3 + psum6 + psum9;

endmodule

module pe(
    input  logic clk,
    input  logic reset,
    input logic clear,
    input  logic [7:0] in_p,
    input  logic signed [7:0] in_w,

    input  logic signed [31:0] psum_in,

    output logic signed [31:0] psum_out
);

    logic signed [15:0] product;

    assign product = $signed({1'b0, in_p}) * in_w;

    always_ff @(posedge clk) begin
        if (reset || clear)
            psum_out <= 32'd0;
        else
            psum_out <= psum_in + product;
    end

endmodule
//systollic array code ends here

module top_convol (
    input  logic [2:0] row,
    input  logic [2:0] col,

    input  logic signed [7:0] w1, w2, w3,
    input  logic signed [7:0] w4, w5, w6,
    input  logic signed [7:0] w7, w8, w9,

    input  logic clk,
    input  logic rst,
    input logic clear,

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

    systollic_array systollic (
        .p1(p1), .p2(p2), .p3(p3),
        .p4(p4), .p5(p5), .p6(p6),
        .p7(p7), .p8(p8), .p9(p9),

        .w1(w1), .w2(w2), .w3(w3),
        .w4(w4), .w5(w5), .w6(w6),
        .w7(w7), .w8(w8), .w9(w9),

        .clk(clk),
        .reset(rst),
        .clear(clear),
        .sum(sum)
    );

endmodule