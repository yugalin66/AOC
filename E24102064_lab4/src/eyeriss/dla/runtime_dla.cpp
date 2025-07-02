#include <stdio.h>
#include <stdlib.h>

#include "hardware_dla.h"
#include "runtime.h"

/*  //////////      NOTICE      //////////
    all parameter used to set DLA are send in by function argument
*/

void dla_stop() {
    // set disable
    reg_write(DLA_ENABLE_OFFSET, 0);
}

void dla_init() {
#ifdef DLA_INFO
    fprintf(stdout, "DLA runtime info logging enabled.\n");
    dla_reset_runtime_info();
    create_dla_info_to_csv(DLA_INFO_CSV);
#endif
    hal_init();
}

void dla_final() {
#ifdef DLA_INFO
    fprintf(stdout, "Creating dla info file: %s\n", DLA_INFO_CSV);
#endif
    hal_final();
}

void dla_reset_runtime_info() { reset_runtime_info(); }

void create_dla_info_to_csv(const char *filename) {
    fprintf(stdout, "Creating dla info file: %s\n", filename);
    FILE *file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "Create DLA info file failed.\n");
        return;
    }
    fprintf(file,
            "Operation,Cycles,Time(ns),Memory read,Memory "
            "write,m,e,p,q,r,t,PAD,U,R,S,C,M,W,H\n");
    fclose(file);
}

void dump_dla_info_to_csv(const char *filename, const char *operation_name,
                          // mapping parameter
                          uint32_t m, uint32_t e, uint32_t p, uint32_t q,
                          uint32_t r, uint32_t t,
                          // shape parameter
                          uint32_t PAD, uint32_t U, uint32_t R, uint32_t S,
                          uint32_t C, uint32_t M, uint32_t W, uint32_t H) {
    FILE *file = fopen(filename, "a");
    struct runtime_info info = get_runtime_info();
    fprintf(file, "%s,", operation_name);        // Operation
    fprintf(file, "%10d,", info.elapsed_cycle);  // Cycles
    fprintf(file, "%10d,", info.elapsed_time);   // Time (ns)
    fprintf(file, "%10d,", info.memory_read);    // Memory read
    fprintf(file, "%10d,", info.memory_write);   // Memory write
    fprintf(file, "%d,%d,%d,%d,%d,%d,", m, e, p, q, r, t);
    fprintf(file, "%d,%d,%d,%d,%d,%d,%d,%d\n", PAD, U, R, S, C, M, W, H);
    fclose(file);
}

int qconv2d_relu_maxpool(
    uint8_t *input_in_DRAM, int8_t *filter_in_DRAM, uint8_t *opsum_in_DRAM,
    int32_t *bias, uint32_t ofmap_len, uint32_t ifmap_len, uint32_t filter_len,
    // mapping parameter
    uint32_t m, uint32_t e, uint32_t p, uint32_t q, uint32_t r, uint32_t t,
    // shape parameter
    uint32_t PAD, uint32_t U, uint32_t R, uint32_t S, uint32_t C, uint32_t M,
    uint32_t W, uint32_t H,
    uint32_t scale) {  // int32_t scale_factor: merge ifmap and weight and ofmap
    // scale bit-shift

#ifdef DLA_INFO
    dla_reset_runtime_info();
#endif
    /*! <<<========= Implement here =========>>>*/
    // compute GLB opsum usage
    uint32_t GLB_SIZE = 64 * 1024;  // 64KB
    uint32_t glb_ifmap_usage = (q * r) * (U * (e - 1) + R) * W;
    uint32_t glb_filter_usage = (p * t) * (q * r) * (R * S);
    // glb_bias_usage = m * 4;
    // glb_opsum_usage = m * e * F * 4;
    uint32_t bias_opsum_available = GLB_SIZE - (glb_ifmap_usage + glb_filter_usage);
    uint32_t optimal_m = 1 << (uint32_t)(floor(log2(bias_opsum_available / (4 + e * W * 4))));
    if(optimal_m > M)
        optimal_m = M;
    uint32_t glb_bias_usage = optimal_m * 4;

    uint32_t glb_ifmap_addr = 0;
    uint32_t glb_filter_addr = glb_ifmap_addr + glb_ifmap_usage;
    uint32_t glb_bias_addr = glb_filter_addr + glb_filter_usage;
    uint32_t glb_opsum_addr = glb_bias_addr + glb_bias_usage;
    
    // call lower setting functions
    /*! <<<========= Implement here =========>>>*/
    
    // set shape and mapping parameters
    set_mapping_param(optimal_m, e, p, q, r, t);
    set_shape_param1(PAD, U, R, S, C, M);
    set_shape_param2(W, H, PAD);    
    // set address
    set_ifmap_addr(input_in_DRAM);
    set_filter_addr(filter_in_DRAM);
    set_bias_addr(bias);
    set_opsum_addr(opsum_in_DRAM);
    // set glb address
    set_glb_filter_addr(glb_filter_addr);
    set_glb_bias_addr(glb_bias_addr);
    set_glb_ofmap_addr(glb_opsum_addr);
    // set length
    set_input_activation_len(ifmap_len);
    set_output_activation_len(ofmap_len);
    // set enable
    set_enable(scale, true, true, false);   // maxpool, relu, conv

    wait_for_interrupt();
    dla_stop();
#ifdef DLA_INFO
    dump_dla_info_to_csv(DLA_INFO_CSV, "qconv2d_relu_maxpool", m, e, p, q, r, t,
                         PAD, U, R, S, C, M, W, H);
#endif
    return 0;
};

int qconv2d_relu(uint8_t *input_in_DRAM, int8_t *filter_in_DRAM,
                 uint8_t *opsum_in_DRAM, int32_t *bias, uint32_t ofmap_len,
                 uint32_t ifmap_len, uint32_t filter_len,
                 // mapping parameter
                 uint32_t m, uint32_t e, uint32_t p, uint32_t q, uint32_t r,
                 uint32_t t,
                 // shape parameter
                 uint32_t PAD, uint32_t U, uint32_t R, uint32_t S, uint32_t C,
                 uint32_t M, uint32_t W, uint32_t H,
                 uint32_t scale) {  // int32_t scale_factor: merge ifmap and
                                    // ofmap scale bit-shift
#ifdef DLA_INFO
    dla_reset_runtime_info();
#endif
    /*! <<<========= Implement here =========>>>*/
  
    // compute GLB opsum usage
    uint32_t GLB_SIZE = 64 * 1024;  // 64KB
    uint32_t glb_ifmap_usage = (q * r) * (U * (e - 1) + R) * W;
    uint32_t glb_filter_usage = (p * t) * (q * r) * (R * S);
    // glb_bias_usage = m * 4;
    // glb_opsum_usage = m * e * F * 4;
    uint32_t bias_opsum_available = GLB_SIZE - (glb_ifmap_usage + glb_filter_usage);
    uint32_t optimal_m = 1U << (uint32_t)(floor(log2(bias_opsum_available / (4 + e * W * 4))));
    if(optimal_m > M)
        optimal_m = M;
    uint32_t glb_bias_usage = optimal_m * 4;

    uint32_t glb_ifmap_addr = 0;
    uint32_t glb_filter_addr = glb_ifmap_addr + glb_ifmap_usage;
    uint32_t glb_bias_addr = glb_filter_addr + glb_filter_usage;
    uint32_t glb_opsum_addr = glb_bias_addr + glb_bias_usage;
    
    // call lower setting functions
    /*! <<<========= Implement here =========>>>*/
    
    // set shape and mapping parameters
    set_mapping_param(optimal_m, e, p, q, r, t);
    set_shape_param1(PAD, U, R, S, C, M);
    set_shape_param2(W, H, PAD);    
    // set address
    set_ifmap_addr(input_in_DRAM);
    set_filter_addr(filter_in_DRAM);
    set_bias_addr(bias);
    set_opsum_addr(opsum_in_DRAM);
    // set glb address
    set_glb_filter_addr(glb_filter_addr);
    set_glb_bias_addr(glb_bias_addr);
    set_glb_ofmap_addr(glb_opsum_addr);
    // set length
    set_input_activation_len(ifmap_len);
    set_output_activation_len(ofmap_len);
    // set enable
    set_enable(scale, false, true, false);   // relu, conv
    
    wait_for_interrupt();
    dla_stop();
#ifdef DLA_INFO
    dump_dla_info_to_csv(DLA_INFO_CSV, "qconv2d_relu", m, e, p, q, r, t, PAD, U,
                         R, S, C, M, W, H);
#endif
    return 0;
};
