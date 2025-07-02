`include "src/PE_array/GIN/GIN_Bus.sv"
`include "src/PE_array/GIN/GIN_MulticastController.sv"
`include "define.svh"

module GIN (
    input clk,
    input rst,

    // Slave SRAM <-> GIN
    input GIN_valid,                    // GLB valid
    output logic GIN_ready,             // Y Bus ready
    input [`DATA_BITS - 1:0] GIN_data,  // data to Y Bus

    /* Controller <-> GIN */
    input [`XID_BITS - 1:0] tag_X,
    input [`YID_BITS - 1:0] tag_Y,

    /* config */
    input set_XID,
    input [`XID_BITS - 1:0] XID_scan_in,
    input set_YID,
    input [`YID_BITS - 1:0] YID_scan_in,

    // Master GIN <-> PE
    input [`NUMS_PE_ROW * `NUMS_PE_COL - 1:0] PE_ready,         // from MC
    output logic [`NUMS_PE_ROW * `NUMS_PE_COL - 1:0] PE_valid,  // to PE
    output logic [`DATA_BITS - 1:0] PE_data
);

    
    logic [`NUMS_PE_ROW-1:0] x_ready_;              // X Bus ready for Y     
    logic [`DATA_SIZE-1:0] x_data_;                 // X Bus data    
    logic [`XID_BITS-1:0] x_ids [0:`NUMS_PE_ROW];    // X Bus ids   
    logic [`NUMS_PE_ROW-1:0] y_valid_;              // Y Bus valid for X Bus
    logic [`YID_BITS - 1 : 0] YID_scan_out;         // no use
    
    // Y Bus
    GIN_Bus #(
        .NUMS_SLAVE(`NUMS_PE_ROW),
        .ID_SIZE(`YID_BITS)
    ) y_bus(
        .clk(clk),
        .rst(rst),
        .tag(tag_Y),
        .master_valid(GIN_valid),
        .master_data(GIN_data),
        .master_ready(GIN_ready),
        .slave_ready(x_ready_),
        .slave_valid(y_valid_),
        .slave_data(x_data_),
        .set_id(set_YID),
        .ID_scan_in(YID_scan_in),
        .ID_scan_out(YID_scan_out)  // no use
    );

    // X Bus
    always @(*) begin
        x_ids[0] = XID_scan_in;
    end

    genvar x;
    generate
        for(x = 0; x < `NUMS_PE_ROW; x = x + 1) begin : GIN_X_Bus
            GIN_Bus #(
                .NUMS_SLAVE(`NUMS_PE_COL),
                .ID_SIZE(`XID_BITS)
            ) x_bus(
                .clk(clk),
                .rst(rst),
                .tag(tag_X),
                .master_valid(y_valid_[x]),
                .master_data(x_data_),
                .master_ready(x_ready_[x]),
                .slave_ready(PE_ready[`NUMS_PE_COL * (x + 1) - 1 : `NUMS_PE_COL * x]),
                .slave_valid(PE_valid[`NUMS_PE_COL * (x + 1) - 1 : `NUMS_PE_COL * x]),
                .slave_data(PE_data),
                .set_id(set_XID),
                .ID_scan_in(x_ids[x]),
                .ID_scan_out(x_ids[x+1])
            );
        end
    endgenerate

endmodule
