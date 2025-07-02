#include "hardware_cpu.h"
#include <stdio.h>

void conv_maxpooling(uint32_t input_C, uint32_t input_H, uint32_t input_W,
                     uint8_t* activation, uint32_t filter_N, uint32_t filter_C,
                     uint32_t filter_H, uint32_t filter_W, int8_t* filter,
                     int32_t* bias, uint32_t padding, uint8_t* output,
                     uint32_t scale) {

    /*! <<<========= Implement here =========>>>*/
    int8_t ifmap_pad[input_C][input_H + 2][input_W + 2];
    int32_t opsum[input_H * input_W * filter_N];
    uint8_t opsum_quant[input_H * input_W * filter_N];
    // padding
    for(int c = 0; c < input_C; c++){
        for(int h = 0; h < input_H + 2; h++){
            for(int w = 0; w < input_W + 2; w++){
                if(h == 0 || h == input_H + 1 || w == 0 || w == input_W + 1){
                    ifmap_pad[c][h][w] = 0;
                }
                else    
                    ifmap_pad[c][h][w] = activation[c * input_H * input_W + (h - 1) * input_W + (w - 1)] - 128;
            }
        }
    }

    // initialize opsum with ipsum
    for(int i = 0; i < input_H * input_W * filter_N; i++){
        opsum[i] = bias[i / (input_H * input_W)];
    }

    // convolution
    for(int m = 0; m < filter_N; m++){
        for(int h = 0; h < input_H; h++){
            for(int w = 0; w < input_W; w++){
                for(int c = 0; c < input_C; c++){
                    for(int r = 0; r < filter_H; r++){
                        for(int s = 0; s < filter_W; s++){
                            opsum[(m * input_H * input_W) + (h * input_W) + w] 
                            += filter[(m * filter_H * filter_W * input_C) + (c * filter_H * filter_W) + (r * filter_W) + s]
                            * ifmap_pad[c][h + r][w + s];
                        }
                    }
                }
            }
        }
        //printf("opsum[%d]: %d\n", m, opsum[m]);
    }
    
    // post-quant
    quantize(opsum, opsum_quant, input_H * input_W * filter_N, scale);

    // relu
    for(int m = 0; m < input_H * input_W * filter_N; m++){
        if(opsum_quant[m] < 128)
            opsum_quant[m] = 128;
        else 
            opsum_quant[m] = opsum_quant[m];
        //printf("opsum_quant[%d]: %d\n", m, opsum_quant[m]);
    }

    // maxpooling
    for (int m = 0; m < filter_N; m++) {
        for (int h = 0; h < input_H/2; h++) {
            for (int w = 0; w < input_W/2; w++) {
                int max_value = opsum_quant[(m * input_H * input_W) + (h * 2 *input_W) + w * 2];

                // Perform maxpooling over the 2x2 region
                for (int ph = 0; ph < 2; ph++) {
                    for (int pw = 0; pw < 2; pw++) {
                        int idx = (m * input_H * input_W) + ((h * 2 + ph) * input_W) + (w * 2 + pw);
                        if(opsum_quant[idx] > max_value)
                            max_value = opsum_quant[idx];
                    }
                }

                // Save the max-pooling result back to opsum
                output[(m * input_H / 2 * input_W / 2) + (h * input_W / 2) + w] = max_value;
                //printf("output[%d] = %d\n", (m * input_H / 2 * input_W / 2) + (h * input_W / 2) + w, output[(m * input_H / 2 * input_W / 2) + (h * input_W / 2) + w]);
            }
        }
    }
};

void conv(uint32_t input_C, uint32_t input_H, uint32_t input_W,
          uint8_t* activation, uint32_t filter_N, uint32_t filter_C,
          uint32_t filter_H, uint32_t filter_W, int8_t* filter, int32_t* bias,
          uint32_t padding, uint8_t* output, uint32_t scale) {

    /*! <<<========= Implement here =========>>>*/
    int8_t ifmap_pad[input_C][input_H + 2][input_W + 2];
    int32_t opsum[input_H * input_W * filter_N];
    uint8_t opsum_quant[input_H * input_W * filter_N];
    // padding
    for(int c = 0; c < input_C; c++){
        for(int h = 0; h < input_H + 2; h++){
            for(int w = 0; w < input_W + 2; w++){
                if(h == 0 || h == input_H + 1 || w == 0 || w == input_W + 1){
                    ifmap_pad[c][h][w] = 0;
                }
                else    
                    ifmap_pad[c][h][w] = activation[c * input_H * input_W + (h - 1) * input_W + (w - 1)] - 128;
            }
        }
    }

    // initialize opsum with ipsum
    for(int i = 0; i < input_H * input_W * filter_N; i++){
        opsum[i] = bias[i / (input_H * input_W)];
    }

    // convolution
    for(int m = 0; m < filter_N; m++){
        for(int h = 0; h < input_H; h++){
            for(int w = 0; w < input_W; w++){
                for(int c = 0; c < input_C; c++){
                    for(int r = 0; r < filter_H; r++){
                        for(int s = 0; s < filter_W; s++){
                            opsum[(m * input_H * input_W) + (h * input_W) + w] 
                            += filter[(m * filter_H * filter_W * input_C) + (c * filter_H * filter_W) + (r * filter_W) + s]
                            * ifmap_pad[c][h + r][w + s];
                        }
                    }
                }
                //printf("opsum[%d] = %d\n", (m * input_H * input_W) + (h * input_W) + w, opsum[(m * input_H * input_W) + (h * input_W) + w]);
            }
        }
        //printf("opsum[%d]: %d\n", m, opsum[m]);
    }
    
    // post-quant
    quantize((opsum), opsum_quant, input_H * input_W * filter_N, scale);

    // relu
    for(int m = 0; m < input_H * input_W * filter_N; m++){
        if(opsum_quant[m] < 128)
            output[m] = 128;
        else 
            output[m] = opsum_quant[m];
        //printf("opsum_quant[%d]: %d\n", m, opsum_quant[m]);
    }
};  

void linear_relu(uint32_t input_size, uint32_t output_size, uint8_t* activation,
                 uint8_t* output, int8_t* filter, int32_t* bias,
                 uint32_t scale) {
    /*! <<<========= Implement here =========>>>*/
    int32_t out_temp[output_size];

    // FC
    for(int o_idx = 0; o_idx < output_size; o_idx++){
        out_temp[o_idx] = bias[o_idx];
    }
    for(int o_idx = 0; o_idx < output_size; o_idx++){
        for(int i_idx = 0; i_idx < input_size; i_idx++){
            out_temp[o_idx] += (activation[i_idx] - 128) * filter[o_idx * input_size + i_idx];
        }
        //printf("out temp[%d] = %d\n", o_idx, out_temp[o_idx]);
        quantize((out_temp), output, output_size, scale);
        //printf("out quant[%d] = %d\n", o_idx, output[o_idx]);
    }

    // relu
    for(int o_idx = 0; o_idx < output_size; o_idx++){
        if(output[o_idx] < 128)
            output[o_idx] = 128;
        else 
            output[o_idx] = output[o_idx];
        //printf("out relu[%d] = %d\n", o_idx, output[o_idx]);
    }
};

void linear(uint32_t input_size, uint32_t output_size, uint8_t* activation,
            uint8_t* output, int8_t* filter, int32_t* bias, uint32_t scale) {
    /*! <<<========= Implement here =========>>>*/
    int32_t out_temp[output_size];

    // FC
    for(int o_idx = 0; o_idx < output_size; o_idx++){
        out_temp[o_idx] = bias[o_idx];
    }
    for(int o_idx = 0; o_idx < output_size; o_idx++){
        for(int i_idx = 0; i_idx < input_size; i_idx++){
            out_temp[o_idx] += (activation[i_idx] - 128) * filter[o_idx * input_size + i_idx];
        }
        //printf("out temp[%d] = %d\n", o_idx, out_temp[o_idx]);
        quantize((out_temp), output, output_size, scale);
        //printf("out quant[%d] = %d\n", o_idx, output[o_idx]);
    }
};

void quantize(int32_t* input_in_DRAM, uint8_t* output_in_DRAM, uint32_t size,
              uint32_t scale) {
    float fp_scale = 1;
    for (uint32_t i = 0; i < scale; i++) {
        fp_scale *= 2;
    }
    for (uint32_t i = 0; i < size; i++) {
        //printf("quantize input[%d] = %d\n", i, input_in_DRAM[i]);
        float t = (float)input_in_DRAM[i] / fp_scale;
        int32_t temp = (int32_t)(t + 128);
        // clamp to 0 ~ 255
        if (temp < 0) {
            output_in_DRAM[i] = 0;
        } else if (temp > 255)
            output_in_DRAM[i] = 255;
        else
            output_in_DRAM[i] = (uint8_t)temp;
        //printf("quantize output[%d] = %d\n", i, output_in_DRAM[i]);
    }
};

void dequantize(uint8_t* input_in_DRAM, float* output_in_DRAM, uint32_t size,
                uint32_t scale) {
    float fp_scale = 1;
    for (uint32_t i = 0; i < scale; i++) {
        fp_scale *= 2;
    }
    for (uint32_t i = 0; i < size; i++) {
        float temp = *(input_in_DRAM + i) - 128;
        *(output_in_DRAM + i) = temp / fp_scale;
    }
};
