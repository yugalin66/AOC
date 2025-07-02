module GON_MulticastController #(
    parameter ID_SIZE = `XID_BITS
)(
    input clk,
    input rst,

    // config id
    input set_id,
    input [ID_SIZE - 1:0] id_in,
    output logic [ID_SIZE - 1:0] id,

    // tag
    input [ID_SIZE - 1:0] tag,

    input valid_in,
    output logic valid_out,
    input ready_in,
    output logic ready_out
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
