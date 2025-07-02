`include "define.svh"

module post_quant(
    input signed [`DATA_BITS-1:0] data_in,
    input [5:0] scaling_factor,
    output logic [7:0] data_out
);

    logic [`DATA_BITS-1:0] shift_data;

    always @(*) begin
        shift_data = data_in >>> scaling_factor;
        if(~shift_data[`DATA_BITS-1] && (|shift_data[`DATA_BITS-2:7]))
            // shift_data > 127, data_out > 255
            data_out = 8'd255;
        else if(shift_data[`DATA_BITS-1] && !(&shift_data[`DATA_BITS-2:7]))
            // shift_data < -128, data_out < 0
            data_out = 8'd0;
        else
            data_out = {~shift_data[7],shift_data[6:0]};
    end

endmodule