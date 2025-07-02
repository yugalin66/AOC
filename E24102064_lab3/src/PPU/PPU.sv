`include "src/PPU/post_quant.sv"
`include "src/PPU/Comparator_Qint8.sv"
`include "src/PPU/ReLU_Qint8.sv"
`include "define.svh"

module PPU (
    input clk,
    input rst,
    input signed [`DATA_BITS-1:0] data_in,
    input [5:0] scaling_factor,
    input maxpool_en,
    input maxpool_init,
    input relu_sel,     // 0 for post_quant, 1 for maxpooling
    input relu_en,
    output logic [7:0] data_out
);

    logic [`DATA_BITS-1:0] relu_out, post_quant_in;
    logic [7:0] post_quant_out, maxpool_out;

    ReLU_Qint8 relu(
        .data_in(data_in), 
        .relu_en(relu_en), 
        .data_out(relu_out)
    );

    post_quant post_quant(
        .data_in(post_quant_in),
        .scaling_factor(scaling_factor),
        .data_out(post_quant_out)
    );

    Comparator_Qint8 maxpool(
        .clk(clk),
        .rst(rst),
        .data_in(post_quant_out),
        .maxpool_en(maxpool_en),
        .maxpool_init(maxpool_init),
        .data_out(maxpool_out)
    );

    always @(*) begin
        post_quant_in = (relu_en) ? relu_out : data_in;
        data_out = (relu_sel) ? maxpool_out : post_quant_out;
    end 

endmodule