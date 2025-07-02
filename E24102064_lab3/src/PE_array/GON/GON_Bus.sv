module GON_Bus #(
    parameter NUMS_MASTER = `NUMS_PE_COL,
    parameter ID_SIZE = `XID_BITS
) (
    input clk,
    input rst,
    input [ID_SIZE - 1:0] tag,

    input [NUMS_MASTER - 1:0] master_valid,     // PE valid
    input [NUMS_MASTER * `DATA_BITS - 1:0] master_data,
    output logic [NUMS_MASTER - 1:0] master_ready,  // Bus is ready for master(PE or X Bus) after MC

    output logic slave_valid,   // Bus valid after MC, to GON
    input slave_ready,          // Bus ready, from GON
    output logic [`DATA_BITS - 1:0] slave_data,

    // Config
    input set_id,
    input [ID_SIZE - 1:0] ID_scan_in,
    output logic [ID_SIZE - 1 :0] ID_scan_out
 );

    // store IDs of each slave
    logic [ID_SIZE-1:0] ids [0:NUMS_MASTER];     // only use [1:NUMS_SLAVE]
    
    // store valid signal of each MC
    logic [NUMS_MASTER-1:0] mc_valid;
    
    // generate MCs
    genvar mc_idx;
    generate
        for(mc_idx = 0; mc_idx < NUMS_MASTER; mc_idx = mc_idx + 1) begin : GON_MC
            GON_MulticastController #(
                .ID_SIZE(ID_SIZE)
            ) mc(
                .clk(clk),
                .rst(rst),
                .set_id(set_id),
                .id_in(ids[mc_idx]),
                .id(ids[mc_idx+1]),
                .tag(tag),
                .valid_in(master_valid[mc_idx]),
                .valid_out(mc_valid[mc_idx]),
                .ready_in(slave_ready),
                .ready_out(master_ready[mc_idx])
            );
        end
    endgenerate
     
    always @(*) begin
        ids[0] = ID_scan_in;
        ID_scan_out = ids[NUMS_MASTER];
        // BUs is valid if any MC is valid;
        slave_valid = |mc_valid;
    end

    integer i;
    always @(*) begin
        slave_data = `DATA_BITS'd0;
        for(i = 0; i < NUMS_MASTER; i = i + 1) begin
            if(mc_valid[i])
                slave_data = master_data[`DATA_BITS * i +: `DATA_BITS];
        end
    end

endmodule
