module GIN_MulticastController #(
    parameter ID_SIZE = `XID_BITS
    )(
    input clk,
    input rst,

    input set_id,
    input [ID_SIZE - 1:0] id_in,
    output reg [ID_SIZE - 1:0] id,

    input [ID_SIZE - 1:0] tag,

    input valid_in,             // from GIN_Bus, GIN valid
    output logic valid_out,     // GIN_Bus to PE
    
    input ready_in,             // from PE to GIN to BUS to MC
    output logic ready_out      // to GIN Bus
);

    always @(posedge clk) begin
        if(rst)
            id <= {ID_SIZE{1'b0}};
        else if(set_id)
            id <= id_in;
        else 
            id <= id;
    end

    // to check if id = tag, and if Bus valid and PE ready
    // only when id = tag propagate valid and ready between PE and MC,
    // and Bus propagate data to PE iff valid-ready handshake
    always @(*) begin
        valid_out = ((id == tag) & valid_in);
        ready_out = ((id == tag) & ready_in);
    end

endmodule
