`include "define.svh"

module ReLU_Qint8(
    input signed [`DATA_BITS-1:0] data_in,
    input relu_en,
    output logic[`DATA_BITS-1:0] data_out
);

    always @(*) begin
        if(relu_en) 
            data_out = (data_in[`DATA_BITS-1]) ? `DATA_BITS'd0 : data_in;
        else 
            data_out = `DATA_BITS'dx;
    end

endmodule