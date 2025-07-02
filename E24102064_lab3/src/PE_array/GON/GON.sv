`include "src/PE_array/GON/GON_Bus.sv"
`include "src/PE_array/GON/GON_MulticastController.sv"
`include "define.svh"

module GON (
    input clk,
    input rst,

    /* Master GON <-> GLB */
    output logic GON_valid,
    input GON_ready,
    output logic [`DATA_BITS-1:0] GON_data,

    /* Controller <-> GON */
    input [`XID_BITS-1:0] tag_X,
    input [`YID_BITS-1:0] tag_Y,

    /* config */
    input set_XID,
    input [`XID_BITS - 1:0] XID_scan_in,

    input set_YID,
    input [`YID_BITS - 1:0] YID_scan_in,

    // Master PE <-> GON
    input [`NUMS_PE_ROW * `NUMS_PE_COL - 1:0] PE_valid,
    output logic [`NUMS_PE_ROW * `NUMS_PE_COL - 1:0] PE_ready,
    input [`DATA_BITS * `NUMS_PE_ROW * `NUMS_PE_COL - 1:0] PE_data

);
    
    logic [`NUMS_PE_ROW-1:0] x_valid_;                      // X Bus valid for Y Bus 
    logic [`NUMS_PE_ROW * `DATA_BITS - 1 : 0] x_data_;    // X Bus data
    logic [`XID_BITS-1:0] x_ids [0:`NUMS_PE_COL];       // X Bus IDs    
    logic [`NUMS_PE_ROW-1:0] y_ready_;                      // Y Bus ready for X Bus

    // Y Bus
    GON_Bus #(
        .NUMS_MASTER(`NUMS_PE_ROW),
        .ID_SIZE(`YID_BITS)
    ) y_bus(
        .clk(clk),
        .rst(rst),
        .tag(tag_Y),
        .master_valid(x_valid_),
        .master_data(x_data_),  
        .master_ready(y_ready_),
        .slave_valid(GON_valid),
        .slave_ready(GON_ready),
        .slave_data(GON_data),
        .set_id(set_YID),
        .ID_scan_in(YID_scan_in),
        .ID_scan_out()
    );

    // X Bus
    always @(*) begin
        x_ids[0] = XID_scan_in;
    end
    genvar x;
    generate
        for(x = 0; x < `NUMS_PE_ROW; x = x + 1) begin : GON_X_Bus
            GON_Bus #(
                .NUMS_MASTER(`NUMS_PE_COL),
                .ID_SIZE(`XID_BITS)
            ) x_bus(
                .clk(clk),
                .rst(rst),
                .tag(tag_X),
                .master_valid(PE_valid[`NUMS_PE_COL * (x + 1) - 1-:`NUMS_PE_COL]),
                .master_data(PE_data[`DATA_BITS * `NUMS_PE_COL * (x + 1) - 1-:`DATA_BITS * `NUMS_PE_COL]),
                .master_ready(PE_ready[`NUMS_PE_COL * (x + 1) - 1-:`NUMS_PE_COL]),
                .slave_valid(x_valid_[x]),
                .slave_ready(y_ready_[x]),
                .slave_data(x_data_[`DATA_BITS * (x + 1) - 1 -:`DATA_BITS]),
                .set_id(set_XID),
                .ID_scan_in(x_ids[x]),
                .ID_scan_out(x_ids[x+1])
            );
        end
    endgenerate

endmodule
