`include "define.svh"
module PE (
    input clk,
    input rst,
    input PE_en,
    input [`CONFIG_SIZE-1:0] i_config,
    input [`DATA_BITS-1:0] ifmap,
    input [`DATA_BITS-1:0] filter,
    input [`DATA_BITS-1:0] ipsum,
    input ifmap_valid,
    input filter_valid,
    input ipsum_valid,
    input opsum_ready,
    output logic [`DATA_BITS-1:0] opsum,
    output logic ifmap_ready,
    output logic filter_ready,
    output logic ipsum_ready,
    output logic opsum_valid
);

    // states
    typedef enum logic [2:0] {
        IDLE,
        READ_FILTER,
        READ_IFMAP,
        CONV,
        READ_IPSUM,
        WRITE_OPSUM,
        DONE
    } STATE;
    STATE ns, cs;

    // i_config
    logic mode;     // 0 for Conv, 1 for Fully Connected layer
    logic [2:0] p;  // number of filters processed by a PE set (# output channel)
    logic [2:0] q;  // number of channels processed by a PE set (# input channel)
    logic [4:0] f;  // ofmap width

    // registers
    logic [`IFMAP_SIZE-1:0] ifmap_spad [0:`IFMAP_SPAD_LEN-1];
    logic [`FILTER_SIZE-1:0] filter_spad [0:`FILTER_SPAD_LEN-1];
    logic [`PSUM_SIZE-1:0] ofmap_spad [0:`OFMAP_SPAD_LEN-1];

    // counter and index
    logic [5:0] counter;    // read filters up to 12 times
    logic [`FILTER_INDEX_BIT-1:0] filter_idx;   // 6 bit, up to 48 filters
    logic [`IFMAP_INDEX_BIT-1:0] ifmap_idx;     // 4 bit, up to 12 ifmaps
    logic [`OFMAP_INDEX_BIT-1:0] ipsum_idx;     // 2 bit, up to 4 ipsum
    logic [`OFMAP_INDEX_BIT-1:0] ofmap_idx;     // 2 bit, up to 4 ofmap
    logic [`IFMAP_INDEX_BIT-1:0] mul_ifmap_idx;     // 4 bit, up to 12 ifmaps
    logic [`OFMAP_INDEX_BIT-1:0] mul_ofmap_idx;     // 2 bit, up to 4 ofmaps/psum

    logic [5:0] filter_num;             // FILT_S * p * q
    logic [4:0] input_filter_times;     // FILT_S * p
    logic [1:0] input_ifmap_times;      // FILT_S
    logic [2:0] input_ipsum_times;      // p
    logic [4:0] ofmap_col_num;          // f
    logic [4:0] ofmap_col_count;    // count ofmap col

    // control signal
    logic first_read;

    // index
    integer i;

    always @(posedge clk) begin
        if(rst) begin
            mode <= 1'd0;
            p <= 3'd0;
            f <= 5'd0;
            q <= 3'd0;
        end
        else if(PE_en) begin
            begin
                mode <= i_config[`CONFIG_SIZE-1];                             // bit 9
                p <= {1'd0,i_config[`CONFIG_SIZE-2:`CONFIG_SIZE-3]} + 3'd1;   // bits 8~7 (p-1)
                f <= i_config[`CONFIG_SIZE-4:`CONFIG_SIZE-8];                 // bits 6~2 (f)
                q <= {1'd0,i_config[`CONFIG_SIZE-9:0]} + 3'd1;                // bits 1~0 (q-1)
            end 
        end
        else begin
                mode <= mode;
                p <= p;
                f <= f;
                q <= q;
            end
    end

    always @(posedge clk) begin
        if(rst) 
            first_read <= 1'd0;
        else if(PE_en)
            first_read <= 1'd1;
        else if(cs == CONV)
            first_read <= 1'd0; 
        else 
            first_read <= first_read;
    end

    always @(posedge clk) begin
        if(rst) begin
            // reset filter spad
            for(i = 0; i < `FILTER_SPAD_LEN; i = i + 1) begin
                filter_spad[i] <= `FILTER_SIZE'd0;
            end

            // reset ifmap spad
            for(i = 0; i < `IFMAP_SPAD_LEN; i = i + 1) begin
                ifmap_spad[i] <= `IFMAP_SIZE'd0;
            end

            // reset ofmap spad
            for(i = 0; i < `OFMAP_SPAD_LEN; i = i + 1) begin
                ofmap_spad[i] <= `PSUM_SIZE'd0;
            end
        end
        else begin
            case(cs) 
                READ_FILTER : begin
                    // ======== read input filter ========
                    // 32 bit : {q4, q3, q2, q1} of 1 column
                    // total cycle = 3 * p
                    // total # of filter = 3 * p * q
                    // filter spad : p1{col1[q1, q2, q3, q4]}, p1{col2[q1, q2, q3, q4]}, p1{col3[q1, q2, q3, q4]},
                    //               p2{col1[q1, q2, q3, q4]}, p2{col2[q1, q2, q3, q4]}, p2{col3[q1, q2, q3, q4]},
                    //               p3{col1[q1, q2, q3, q4]}, p3{col2[q1, q2, q3, q4]}, p3{col3[q1, q2, q3, q4]},
                    //               p4{col1[q1, q2, q3, q4]}, p4{col2[q1, q2, q3, q4]}, p4{col3[q1, q2, q3, q4]},
                    if(filter_valid) begin
                        filter_spad[{26'd0,filter_idx}] <= filter[7:0];
                        if(q >= 3'd2)
                            filter_spad[{26'd0, filter_idx} + 32'd1] <= filter[15:8];
                        else 
                            filter_spad[{26'd0, filter_idx} + 32'd1] <= filter_spad[{26'd0, filter_idx} + 32'd1];
                        if(q >= 3'd3)
                            filter_spad[{26'd0, filter_idx} + 32'd2] <= filter[23:16];
                        else 
                            filter_spad[{26'd0, filter_idx} + 32'd2] <= filter_spad[{26'd0, filter_idx} + 32'd2];
                        if(q >= 3'd4)
                            filter_spad[{26'd0, filter_idx} + 32'd3] <= filter[31:24];
                        else 
                            filter_spad[{26'd0, filter_idx} + 32'd3] <= filter_spad[{26'd0, filter_idx} + 32'd3];
                    end else begin
                        for(i = 0; i < `FILTER_SPAD_LEN; i = i + 1) begin
                            filter_spad[i] <= filter_spad[i];
                        end
                    end
                end

                READ_IFMAP : begin
                    // ======= read input ifmap ========
                    // 32 bit : {q4, q3, q2, q1}
                    // first cycle read 3 ifmap, the rest read 1 ifmap per cycle 
                    // total # of ifmap = 3 * q
                    // ifmap spad : col1[q1, q2, q3, q4], col2[q1, q2, q3, q4], col3[q1, q2, q3, q4]
                    if(ifmap_valid) begin
                        if(first_read) begin
                            ifmap_spad[{28'd0, ifmap_idx}] <= {~ifmap[7], ifmap[6:0]};
                            if(q >= 3'd2)
                                ifmap_spad[{28'd0, ifmap_idx} + 32'd1] <= {~ifmap[15], ifmap[14:8]};
                            else 
                                ifmap_spad[{28'd0, ifmap_idx} + 32'd1] <= ifmap_spad[{28'd0, ifmap_idx} + 32'd1];
                            if(q >= 3'd3)
                                ifmap_spad[{28'd0, ifmap_idx} + 32'd2] <= {~ifmap[23], ifmap[22:16]};
                            else 
                                ifmap_spad[{28'd0, ifmap_idx} + 32'd2] <= ifmap_spad[{28'd0, ifmap_idx} + 32'd2];
                            if(q >= 3'd4)
                                ifmap_spad[{28'd0, ifmap_idx} + 32'd3] <= {~ifmap[31], ifmap[30:24]};
                            else 
                                ifmap_spad[{28'd0, ifmap_idx} + 32'd3] <= ifmap_spad[{28'd0, ifmap_idx} + 32'd3];
                        end
                        else begin  // read 1 ifmap each cycle after 2nd read-ifmap-state
                            // shift col2, col3 to col1, col2
                            for(i = 0; i < 2 * q; i = i + 1) begin
                                ifmap_spad[i] <= ifmap_spad[i+{29'd0,q}];
                            end
                            // read new ifmap to col3
                            ifmap_spad[2 * q] <= {~ifmap[7], ifmap[6:0]};
                            ifmap_spad[2 * q + 1] <= {~ifmap[15], ifmap[14:8]};
                            ifmap_spad[2 * q + 2] <= {~ifmap[23], ifmap[22:16]};
                            ifmap_spad[2 * q + 3] <= {~ifmap[31], ifmap[30:24]};
                        end
                    end else begin
                        for(i = 0; i < `IFMAP_SPAD_LEN; i = i + 1) begin
                            ifmap_spad[i] <= ifmap_spad[i];
                        end
                    end
                end

                CONV : begin
                    ofmap_spad[mul_ofmap_idx] <= $signed(ofmap_spad[mul_ofmap_idx]) + $signed(filter_spad[counter]) * $signed(ifmap_spad[mul_ifmap_idx]);
                end

                READ_IPSUM : begin
                    // ======== read ipsum ==========
                    // 32 bit for each
                    // total cycle = p
                    // total # of ipsum = p
                    // ofmap_spad : [p1, p2, p3, p4]
                    if(ipsum_valid) begin
                        ofmap_spad[ipsum_idx] <= ofmap_spad[ipsum_idx] + ipsum;
                    end else begin
                        for(i = 0; i < `OFMAP_SPAD_LEN; i = i + 1) begin
                            ofmap_spad[i] <= ofmap_spad[i];
                        end
                    end
                end

                WRITE_OPSUM : begin
                    if((counter == {3'd0,p} - 1) && opsum_ready) begin
                        for(i = 0; i < p; i = i + 1) begin
                            ofmap_spad[i] <= `PSUM_SIZE'd0;
                        end
                    end
                    else begin
                        for(i = 0; i < p; i = i + 1) begin
                            ofmap_spad[i] <= ofmap_spad[i];
                        end
                    end
                end

                default : begin
                    for(i = 0; i < `FILTER_SPAD_LEN; i = i + 1) begin
                        filter_spad[i] <= filter_spad[i];
                    end
                    for(i = 0; i < `IFMAP_SPAD_LEN; i = i + 1) begin
                        ifmap_spad[i] <= ifmap_spad[i];
                    end
                    for(i = 0; i < `OFMAP_SPAD_LEN; i = i + 1) begin
                        ofmap_spad[i] <= ofmap_spad[i];
                    end
                end
            endcase
        end
    end

    // output opsum
    always @(*) begin
        if(cs == WRITE_OPSUM) begin
            if(opsum_ready) begin
                opsum = ofmap_spad[ofmap_idx];                        
            end
            else begin
                opsum = `DATA_BITS'd0;
            end
        end
        else 
            opsum = `DATA_BITS'd0;
    end

    // counter
    always @(posedge clk) begin
        if(rst) begin
            counter <= 6'd0;
        end
        else begin
            if(cs != ns) 
            counter <= 6'd0;
            else if ((cs == READ_FILTER) && filter_valid)
                counter <= counter + 6'd1;
            else if((cs == READ_IFMAP) && ifmap_valid)
                counter <= counter + 6'd1;
            else if(cs == CONV)
                counter <= counter + 6'd1;
            else if((cs == READ_IPSUM) && ipsum_valid)
                counter <= counter + 6'd1;
            else if((cs == WRITE_OPSUM) && opsum_ready) 
                counter <= counter + 6'd1;
            else 
                counter <= counter;
        end
    end

    // filter idx, used when reading filter
    always @(posedge clk) begin
        if(rst) 
            filter_idx <= 6'd0;
        else if((cs == READ_FILTER) && filter_valid) 
            filter_idx <= filter_idx + {3'd0, q};
        else 
            filter_idx <= filter_idx;
    end

    // ifmap idx, used when reading ifmap at the first time
    always @(posedge clk) begin
        if(rst) 
            ifmap_idx <= 4'd0;
        else if((cs == READ_IFMAP) && ifmap_valid) 
            ifmap_idx <= ifmap_idx + {1'd0, q};
        else 
            ifmap_idx <= ifmap_idx;
    end

    // convolution ifmap, ofmap index
    always @(posedge clk) begin
        if(rst) begin
            mul_ifmap_idx <= 4'd0;
            mul_ofmap_idx <= 2'd0;
        end
        else if(cs == CONV) begin
            mul_ifmap_idx <= ({1'b0,mul_ifmap_idx} == `FILT_S * q - 5'd1) ? 4'd0 : mul_ifmap_idx + 4'd1;
            mul_ofmap_idx <= ({1'b0,mul_ifmap_idx} == `FILT_S * q - 5'd1) ? mul_ofmap_idx + 2'd1 : mul_ofmap_idx;
        end
        else begin
            mul_ifmap_idx <= 4'd0;
            mul_ofmap_idx <= 2'd0;
        end
    end

    // ipsum idx, used when reading ipsum
    always @(posedge clk) begin
        if(rst) 
            ipsum_idx <= 2'd0;
        else if((cs == READ_IPSUM) && ipsum_valid)
            ipsum_idx <= ipsum_idx + 2'd1;
        else 
            ipsum_idx <= ipsum_idx;
    end

    // ofmap idx, used when writing ofmap, write p ofmaps then change ifmap
    always @(posedge clk) begin
        if(rst)
            ofmap_idx <= 2'd0;
        else if((cs == WRITE_OPSUM) && opsum_ready)
            if(ns != WRITE_OPSUM)
                ofmap_idx <= 2'd0;
            else 
                ofmap_idx <= ofmap_idx + 2'd1;
        else
            ofmap_idx <= ofmap_idx;
    end

    // count ofmap, PE done when output f ofmaps
    always @(posedge clk) begin
        if(rst) 
            ofmap_col_count <= 5'd0;
        else if((cs == READ_IPSUM) && (ns == WRITE_OPSUM))
            ofmap_col_count <= ofmap_col_count + 5'd1;
        else if((cs == WRITE_OPSUM) && opsum_ready) 
            if(counter == {3'd0,input_ipsum_times} - 6'd1) // finish calculating 1 ofmap col of p filters
                ofmap_col_count <= ofmap_col_count + 5'd1;
            else 
                ofmap_col_count <= ofmap_col_count;
        else 
            ofmap_col_count <= ofmap_col_count;
    end

    // ========= FSM =========
    always @(posedge clk) begin
        if(rst) 
            cs <= IDLE;
        else
            cs <= ns;
    end

    always @(*) begin
        filter_num = `FILT_S * p * q;
        input_filter_times = `FILT_S * p;
        input_ifmap_times = `FILT_S;
        input_ipsum_times = p;
        ofmap_col_num = f;
        case(cs) 
            IDLE : ns = (PE_en) ? READ_FILTER : IDLE;
            READ_FILTER : ns = ((counter == {1'd0, input_filter_times} - 6'd1) && filter_valid) ? READ_IFMAP : READ_FILTER;
            READ_IFMAP : ns = (first_read) ? ((counter == {4'd0, input_ifmap_times} - 6'd1) && ifmap_valid) ? CONV : READ_IFMAP : (counter == 6'd1) ? CONV : READ_IFMAP;
            CONV : ns = (counter == filter_num - 6'd1) ? READ_IPSUM : CONV;
            READ_IPSUM : ns = ((counter == {3'd0, input_ipsum_times} - 6'd1) && ipsum_valid) ? WRITE_OPSUM : READ_IPSUM;
            WRITE_OPSUM : ns = ((counter == {3'd0, input_ipsum_times} - 6'd1) && opsum_ready) ? ((ofmap_col_count == ofmap_col_num - 5'd1) && opsum_ready) ? DONE : READ_IFMAP : WRITE_OPSUM;
            DONE : ns = DONE;
            default : ns = IDLE;
        endcase
    end

    // ===== output handshake signal ======
    always @(*) begin
        filter_ready = (cs == READ_FILTER);
        ifmap_ready = (cs == READ_IFMAP);
        ipsum_ready = (cs == READ_IPSUM);
        opsum_valid = (cs == WRITE_OPSUM);
    end

    // ========== debug ===========
    logic [`FILTER_SIZE-1:0] mul_filter;
    logic [`IFMAP_SIZE-1:0] mul_ifmap;

    always @(*) begin
        mul_filter = $signed(filter_spad[counter]);
        mul_ifmap = $signed(ifmap_spad[mul_ifmap_idx]);
    end

endmodule
