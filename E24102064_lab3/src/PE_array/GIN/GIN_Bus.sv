 module GIN_Bus #(
    parameter NUMS_SLAVE = `NUMS_PE_COL,    // depends on Y-bus or X-bus 
    parameter ID_SIZE = `XID_BITS           // ID size of each slave
) (
    input clk,
    input rst,

   // Master I/O
    input [ID_SIZE-1:0] tag,                
    input master_valid,                     // GIN valid
    input [`DATA_BITS-1:0] master_data,     // from GIN
    output logic master_ready,              // Bus ready after MC

   // Slave I/O
    input [NUMS_SLAVE-1:0] slave_ready,         // PE ready or XBus ready, from GIN
    output logic [NUMS_SLAVE-1:0] slave_valid,  // Bus is valid for slave(PE or X Bus) after MC
    output logic [`DATA_BITS-1:0] slave_data,   // to PE or Xbus

    // Config
    input set_id,
    input [ID_SIZE-1:0] ID_scan_in,
    output logic [ID_SIZE-1:0] ID_scan_out
 );
    
    // store IDs of each slave
    logic [ID_SIZE-1:0] ids [0:NUMS_SLAVE];     // only use [1:NUMS_SLAVE]
    
    // MC ready for Bus
    logic [NUMS_SLAVE-1:0] mc_ready;
    
    // generate MCs
    genvar mc_idx;
    generate
        for(mc_idx = 0; mc_idx < NUMS_SLAVE; mc_idx = mc_idx + 1) begin : GIN_MC
            GIN_MulticastController #(
                .ID_SIZE(ID_SIZE)
            ) mc (
                .clk(clk),
                .rst(rst),
                .set_id(set_id),
                .id_in(ids[mc_idx]),
                .id(ids[mc_idx + 1]),   // shift ID to the next MC
                .tag(tag),
                .valid_in(master_valid),
                .valid_out(slave_valid[mc_idx]),
                .ready_in(slave_ready[mc_idx]),
                .ready_out(mc_ready[mc_idx])
            );
        end
    endgenerate

    always @(*) begin
        ids[0] = ID_scan_in;            // push first
        ID_scan_out = ids[NUMS_SLAVE];  // pop last
        master_ready = |mc_ready;       // bus is ready when all the MCs are ready
        slave_data = master_data;
    end

endmodule
