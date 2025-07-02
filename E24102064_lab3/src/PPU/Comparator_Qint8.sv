`include "define.svh"

module Comparator_Qint8(
    input clk,
    input rst,
    input unsigned [7:0] data_in,
    input maxpool_en,
    input maxpool_init,
    output logic [7:0] data_out
);

    logic [7:0] max;
    logic [1:0] counter;
    logic start;

    always @(posedge clk) begin
        if(rst) begin
            start <= 1'd0;
            counter <= 2'd0;
            max <= 8'd0;
        end
        else if(maxpool_en) begin
            if(counter == 2'd3) begin
                start <= 1'd0;
                counter <= 2'd0;
            end
            else begin
                if(maxpool_init && !start) begin
                    max <= data_in;
                    start <= 1'd1;
                    counter <= 2'd0;
                end
                else begin
                    max <= (data_in > max) ? data_in : max;
                    counter <= counter + 2'd1;
                end
            end
        end
    end

    always @(*) begin
        if(counter == 2'd3)
            data_out = max;
        else
            data_out = 8'dx;
    end

endmodule