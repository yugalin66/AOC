`include "src/PE_array/PE.sv"
`include "src/PE_array/GIN/GIN.sv"
`include "src/PE_array/GON/GON.sv"
`include "define.svh"

module PE_array #(
    parameter NUMS_PE_ROW = `NUMS_PE_ROW,
    parameter NUMS_PE_COL = `NUMS_PE_COL,
    parameter XID_BITS = `XID_BITS,
    parameter YID_BITS = `YID_BITS,
    parameter DATA_SIZE = `DATA_BITS,
    parameter CONFIG_SIZE = `CONFIG_SIZE
)(
    input clk,
    input rst,

    /* Scan Chain */
    input set_XID,
    input [`XID_BITS-1:0] ifmap_XID_scan_in,
    input [`XID_BITS-1:0] filter_XID_scan_in,
    input [`XID_BITS-1:0] ipsum_XID_scan_in,
    input [`XID_BITS-1:0] opsum_XID_scan_in,
    // output [XID_BITS-1:0] XID_scan_out,

    input set_YID,
    input [`YID_BITS-1:0] ifmap_YID_scan_in,
    input [`YID_BITS-1:0] filter_YID_scan_in,
    input [`YID_BITS-1:0] ipsum_YID_scan_in,
    input [`YID_BITS-1:0] opsum_YID_scan_in,
    // output logic [YID_BITS-1:0] YID_scan_out,

    input set_LN,
    input [`NUMS_PE_ROW-2:0] LN_config_in,

    /* Controller */
    input [`NUMS_PE_ROW*`NUMS_PE_COL-1:0] PE_en,
    input [`CONFIG_SIZE-1:0] PE_config,
    input [`XID_BITS-1:0] ifmap_tag_X,
    input [`YID_BITS-1:0] ifmap_tag_Y,
    input [`XID_BITS-1:0] filter_tag_X,
    input [`YID_BITS-1:0] filter_tag_Y,
    input [`XID_BITS-1:0] ipsum_tag_X,
    input [`YID_BITS-1:0] ipsum_tag_Y,
    input [`XID_BITS-1:0] opsum_tag_X,
    input [`YID_BITS-1:0] opsum_tag_Y,

    /* GLB */
    input GLB_ifmap_valid,
    output logic GLB_ifmap_ready,
    input GLB_filter_valid,
    output logic GLB_filter_ready,
    input GLB_ipsum_valid,
    output logic GLB_ipsum_ready,
    input [DATA_SIZE-1:0] GLB_data_in,

    output logic GLB_opsum_valid,
    input GLB_opsum_ready,
    output logic [DATA_SIZE-1:0] GLB_data_out
);

    /*
    testbench :
        1. send config : LN_config -> XID,YID
        2. send data : PE_en, PE_config -> send filter -> send ifmap -> send ipsum -> recieve opsum
    */

    // GIN wires
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GIN_PE_ifmap_ready_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GIN_PE_filter_ready_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GIN_PE_ipsum_ready_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GIN_PE_ifmap_valid_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GIN_PE_filter_valid_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GIN_PE_ipsum_valid_;
    logic [DATA_SIZE - 1 : 0] GIN_PE_ifmap_;
    logic [DATA_SIZE - 1 : 0] GIN_PE_filter_;
    logic [DATA_SIZE - 1 : 0] GIN_PE_ipsum_;

    // GON wires
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GON_PE_opsum_valid_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] GON_PE_opsum_ready_;
    logic [DATA_SIZE * NUMS_PE_ROW * NUMS_PE_COL - 1:0] GON_PE_opsum_;

    // PE wires
    // input 
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_ifmap_ready_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_filter_ready_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_ipsum_ready_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_opsum_valid_;
    logic [DATA_SIZE - 1 : 0] PE_ifmap_;
    logic [DATA_SIZE - 1 : 0] PE_filter_;
    logic [DATA_SIZE - 1 : 0] PE_ipsum_ [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0];
    // output
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_ifmap_valid_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_filter_valid_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_ipsum_valid_;
    logic [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0] PE_opsum_ready_;
    logic [DATA_SIZE - 1 : 0] PE_opsum_ [NUMS_PE_ROW * NUMS_PE_COL - 1 : 0];

    // Local Network
    logic [NUMS_PE_ROW-2:0] LN_config;

    // index
    integer i, j;

    // set LN_config, send a col in 1 cycle, every col is the same
    always @(posedge clk) begin
        if(rst)
            LN_config <= {(NUMS_PE_ROW-1){1'b0}};
        else if(set_LN)
            LN_config <= LN_config_in;
        else 
            LN_config <= LN_config;
    end

    // instantiat ifmap GIN
    GIN GIN_ifmap(
        .clk(clk),
        .rst(rst),
        .GIN_valid(GLB_ifmap_valid),
        .GIN_ready(GLB_ifmap_ready),
        .GIN_data(GLB_data_in),
        .tag_X(ifmap_tag_X),
        .tag_Y(ifmap_tag_Y),
        .set_XID(set_XID),
        .XID_scan_in(ifmap_XID_scan_in),
        .set_YID(set_YID),
        .YID_scan_in(ifmap_YID_scan_in),
        .PE_ready(GIN_PE_ifmap_ready_),
        .PE_valid(GIN_PE_ifmap_valid_),
        .PE_data(GIN_PE_ifmap_)
    );

    // instantiate filter GIN
    GIN GIN_filter(
        .clk(clk),
        .rst(rst),
        .GIN_valid(GLB_filter_valid),
        .GIN_ready(GLB_filter_ready),
        .GIN_data(GLB_data_in),
        .tag_X(filter_tag_X),
        .tag_Y(filter_tag_Y),
        .set_XID(set_XID),
        .XID_scan_in(filter_XID_scan_in),
        .set_YID(set_YID),
        .YID_scan_in(filter_YID_scan_in),
        .PE_ready(GIN_PE_filter_ready_),
        .PE_valid(GIN_PE_filter_valid_),
        .PE_data(GIN_PE_filter_)
    );

    // instantiate ipsum GIN
    GIN GIN_ipsum(
        .clk(clk),
        .rst(rst),
        .GIN_valid(GLB_ipsum_valid),
        .GIN_ready(GLB_ipsum_ready),
        .GIN_data(GLB_data_in),
        .tag_X(ipsum_tag_X),
        .tag_Y(ipsum_tag_Y),
        .set_XID(set_XID),
        .XID_scan_in(ipsum_XID_scan_in),
        .set_YID(set_YID),
        .YID_scan_in(ipsum_YID_scan_in),
        .PE_ready(GIN_PE_ipsum_ready_),
        .PE_valid(GIN_PE_ipsum_valid_),
        .PE_data(GIN_PE_ipsum_)
    );

    // instantiate opsum GON
    GON GON_opsum(
        .clk(clk),
        .rst(rst),
        .GON_valid(GLB_opsum_valid),
        .GON_ready(GLB_opsum_ready),
        .GON_data(GLB_data_out),
        .tag_X(opsum_tag_X),
        .tag_Y(opsum_tag_Y),
        .set_XID(set_XID),
        .XID_scan_in(opsum_XID_scan_in),
        .set_YID(set_YID),
        .YID_scan_in(opsum_YID_scan_in),
        .PE_valid(GON_PE_opsum_valid_),
        .PE_ready(GON_PE_opsum_ready_),
        .PE_data(GON_PE_opsum_)
    );

    // instantiate PEs
    genvar pe_idx;
    generate
        for(pe_idx = 0; pe_idx < NUMS_PE_ROW * NUMS_PE_COL; pe_idx = pe_idx + 1) begin : gen_pe
            PE pe(
                .clk(clk),
                .rst(rst),
                .PE_en(PE_en[pe_idx]),
                .i_config(PE_config),
                .ifmap(PE_ifmap_),
                .filter(PE_filter_),
                .ipsum(PE_ipsum_[pe_idx]),
                .ifmap_valid(PE_ifmap_valid_[pe_idx]),
                .filter_valid(PE_filter_valid_[pe_idx]),
                .ipsum_valid(PE_ipsum_valid_[pe_idx]),
                .opsum_ready(PE_opsum_ready_[pe_idx]),
                .opsum(PE_opsum_[pe_idx]),
                .ifmap_ready(PE_ifmap_ready_[pe_idx]),
                .filter_ready(PE_filter_ready_[pe_idx]),
                .ipsum_ready(PE_ipsum_ready_[pe_idx]),
                .opsum_valid(PE_opsum_valid_[pe_idx])
                
                //.PE_en(PE_en[0]),
                //.i_config(PE_config),
                //.ifmap(GIN_PE_ifmap_),
                //.filter(GIN_PE_filter_),
                //.ipsum(GIN_PE_ipsum_),
                //.ifmap_valid(GIN_PE_ifmap_valid_[0]),
                //.filter_valid(GIN_PE_filter_valid_[0]),
                //.ipsum_valid(GIN_PE_ipsum_valid_[0]),
                //.opsum_ready(GON_PE_opsum_ready_[0]),
                //.opsum(GON_PE_opsum_[31:0]),
                //.ifmap_ready(GIN_PE_ifmap_ready_[0]),
                //.filter_ready(GIN_PE_filter_ready_[0]),
                //.ipsum_ready(GIN_PE_ipsum_ready_[0]),
                //.opsum_valid(GON_PE_opsum_valid_[0])
            );
        end
    endgenerate

    // connect GIN and PE
    always @(*) begin
        // PE <- GIN
        PE_ifmap_valid_ = GIN_PE_ifmap_valid_;
        PE_filter_valid_ = GIN_PE_filter_valid_;
        PE_ifmap_ = GIN_PE_ifmap_;
        PE_filter_ = GIN_PE_filter_;

        // GIN <- PE
        GIN_PE_ifmap_ready_ = PE_ifmap_ready_;
        GIN_PE_filter_ready_ = PE_filter_ready_;
        GIN_PE_ipsum_ready_ = PE_ipsum_ready_;

        // GON <- PE
        GON_PE_opsum_valid_ = PE_opsum_valid_;
    end

    // connect GON and PE
    // decide whether ipsum comes from GLB or the opsum of upper PE
    // LN_config = 0 : from GLB
    // LN_config = 1 : from opsum of upper PE
    always @(*) begin
        for(i = 0; i < NUMS_PE_COL * NUMS_PE_ROW; i = i + 1) begin
            if(i < NUMS_PE_COL * (NUMS_PE_ROW - 1)) begin
                if(LN_config[(i >> 3)])  begin
                    // lower PE ipsum valid <- upper PE opsum valid
                    PE_ipsum_valid_[i] = PE_opsum_valid_[i + NUMS_PE_COL];
                    PE_ipsum_[i] = PE_opsum_[i + NUMS_PE_COL];  
                    //PE_opsum_ready_[i + NUMS_PE_COL] = PE_ipsum_ready_[i];                  
                end
                else begin
                    // PE <- GIN
                    PE_ipsum_valid_[i] = GIN_PE_ipsum_valid_[i];
                    PE_ipsum_[i] = GIN_PE_ipsum_;
                    //PE_opsum_ready_[i + NUMS_PE_COL] = GON_PE_opsum_ready_[i + NUMS_PE_COL];
                end
            end
            else begin
                // top row
                PE_ipsum_valid_[i] = GIN_PE_ipsum_valid_[i];
                PE_ipsum_[i] = GIN_PE_ipsum_;
                //PE_opsum_ready_[i] = GON_PE_opsum_ready_[i];
            end
        end
    end

    always @(*) begin
        for(i = 0; i < NUMS_PE_COL * NUMS_PE_ROW; i = i + 1) begin
            if(i >= NUMS_PE_COL) begin
                if(LN_config[(i >> 3)-1]) begin
                    // upper PE ipsum ready <- lower PE opsum ready 
                    PE_opsum_ready_[i] = PE_ipsum_ready_[i - NUMS_PE_COL];
                end
                else begin
                    // PE <- GON
                    PE_opsum_ready_[i] = GON_PE_opsum_ready_[i];
                end
            end
            else begin        
                // buttom row        
                PE_opsum_ready_[i] = GON_PE_opsum_ready_[i];
            end
        end
    end

    // concatenate all opsum
    always @(*) begin
        for(i = 0; i < NUMS_PE_COL * NUMS_PE_ROW; i = i + 1) begin
            GON_PE_opsum_[DATA_SIZE * (i + 1) - 1 -: DATA_SIZE] = PE_opsum_[i];
        end
    end

    // ======= debug =======
    logic [DATA_SIZE - 1:0] PE_ifmap_debug [0:NUMS_PE_ROW * NUMS_PE_COL - 1];
    logic [DATA_SIZE - 1:0] PE_filter_debug [0:NUMS_PE_ROW * NUMS_PE_COL - 1];
    logic [DATA_SIZE - 1:0] PE_ipsum_debug [0:NUMS_PE_ROW * NUMS_PE_COL - 1];
    logic [DATA_SIZE - 1:0] PE_opsum_debug [0:NUMS_PE_ROW * NUMS_PE_COL - 1];
   
    always @(*) begin
        for(i = 0; i < NUMS_PE_ROW * NUMS_PE_COL; i = i + 1) begin
            PE_ifmap_debug[i] = PE_ifmap_;
            PE_filter_debug[i] = PE_filter_;
            PE_ipsum_debug[i] = PE_ipsum_[i];
            PE_opsum_debug[i] = PE_opsum_[i];
        end
    end
    // ====================

endmodule