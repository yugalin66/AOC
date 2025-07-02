#include "hardware_cpu.h"
#include <stdio.h>

void conv_maxpooling(uint32_t input_C, uint32_t input_H, uint32_t input_W,
                     uint8_t* activation, uint32_t filter_N, uint32_t filter_C,
                     uint32_t filter_H, uint32_t filter_W, int8_t* filter,
                     int32_t* bias, uint32_t padding, uint8_t* output,
                     uint32_t scale) {

    /*! <<<========= Implement here =========>>>*/

    size_t in_plane   = (size_t)input_H * input_W;
    size_t filt_plane = (size_t)filter_H * filter_W;
    uint32_t pool_H = input_H / 2;
    uint32_t pool_W = input_W / 2;
    size_t pool_plane = (size_t)pool_H * pool_W;

    uint8_t* conv_out = malloc((size_t)filter_N * in_plane * sizeof(uint8_t));
    int32_t* accu = malloc((size_t)filter_N * in_plane * sizeof(int32_t));

    // load bias
    for (uint32_t m = 0; m < filter_N; m++) {
        int32_t b = bias[m];
        int32_t* dst = accu + (size_t)m * in_plane;
        for (size_t i = 0; i < in_plane; i++) {
            dst[i] = b;
        }
    }

    // conv
    for (uint32_t m = 0; m < filter_N; m++) {
        int8_t* filt_m = filter + (size_t)m * filter_C * filt_plane;
        int32_t* dst_m = accu   + (size_t)m * in_plane;
        for (uint32_t c = 0; c < filter_C; c++) {
            uint8_t* act_c = activation + (size_t)c * in_plane;
            int8_t* filt_c = filt_m     + (size_t)c * filt_plane;
            for (uint32_t r = 0; r < filter_H; r++) {
                // count legal h range
                int h_start = padding > r ? padding - r : 0;
                int h_end   = (int)input_H + padding - r;
                if (h_end > (int)input_H) h_end = input_H;
                for (uint32_t s = 0; s < filter_W; s++) {
                    int8_t wgt = filt_c[r * filter_W + s];
                    // count legal w range
                    int w_start = padding > s ? padding - s : 0;
                    int w_end   = (int)input_W + padding - s;
                    if (w_end > (int)input_W) w_end = input_W;
                    for (int h = h_start; h < h_end; h++) {
                        int ih = h + (int)r - (int)padding;
                        int32_t* out_row = dst_m + (size_t)h * input_W;
                        uint8_t* act_row = act_c + (size_t)ih * input_W;
                        for (int w = w_start; w < w_end; w++) {
                            int iw = w + (int)s - (int)padding;
                            int32_t a = (int32_t)act_row[iw] - 128;
                            out_row[w] += (int32_t)wgt * a;
                        }
                    }
                }
            }
        }
    }

    // quant and relu
    for (uint32_t m = 0; m < filter_N; m++) {
        int32_t* src = accu + (size_t)m * in_plane;
        uint8_t* dst = conv_out + (size_t)m * in_plane;
        for (size_t i = 0; i < in_plane; i++) {
            int32_t v = src[i];
            if (v < 0) v = 0;
            v >>= scale;  
            if (v > 127) v = 127;
            dst[i] = (uint8_t)(v + 128);
        }
    }

    free(accu);

    // maxpooling
    for (uint32_t m = 0; m < filter_N; m++) {
        uint8_t* src_m = conv_out + (size_t)m * in_plane;
        uint8_t* dst_m = output  + (size_t)m * pool_plane;
        for (uint32_t ph = 0; ph < pool_H; ph++) {
            for (uint32_t pw = 0; pw < pool_W; pw++) {
                size_t base_h = (size_t)ph * 2;
                size_t base_w = (size_t)pw * 2;
                uint8_t m0 = src_m[base_h       * input_W + base_w      ];
                uint8_t m1 = src_m[base_h       * input_W + base_w + 1  ];
                uint8_t m2 = src_m[(base_h + 1) * input_W + base_w      ];
                uint8_t m3 = src_m[(base_h + 1) * input_W + base_w + 1  ];
                // find max
                uint8_t mm = m0;
                if (m1 > mm) mm = m1;
                if (m2 > mm) mm = m2;
                if (m3 > mm) mm = m3;
                dst_m[(size_t)ph * pool_W + pw] = mm;
            }
        }
    }

    free(conv_out);
};

void conv(uint32_t input_C, uint32_t input_H, uint32_t input_W,
          uint8_t* activation, uint32_t filter_N, uint32_t filter_C,
          uint32_t filter_H, uint32_t filter_W, int8_t* filter, int32_t* bias,
          uint32_t padding, uint8_t* output, uint32_t scale) {

    /*! <<<========= Implement here =========>>>*/
    
    size_t in_plane   = (size_t)input_H * input_W;
    size_t filt_plane = (size_t)filter_H * filter_W;
    int32_t* out_temp = malloc(filter_N * in_plane * sizeof(int32_t));

    // load bias
    for (uint32_t m = 0; m < filter_N; m++) {
        int32_t b = bias[m];
        int32_t* dst = out_temp + m * in_plane;
        for (size_t i = 0; i < in_plane; i++) {
            dst[i] = b;
        }
    }

    // conv in order of m -> c -> r -> s
    for (uint32_t m = 0; m < filter_N; m++) {
        int8_t* filt_m_base = filter + (size_t)m * filter_C * filt_plane;
        int32_t* dst_m      = out_temp + m * in_plane;
        for (uint32_t c = 0; c < filter_C; c++) {
            uint8_t* act_c_base = activation + (size_t)c * in_plane;
            int8_t* filt_c_base = filt_m_base + (size_t)c * filt_plane;
            for (uint32_t r = 0; r < filter_H; r++) {
                // count legal h range
                int h_start = padding > r ? (padding - r) : 0;
                int h_end   = (int)input_H + padding - r;
                if (h_end > (int)input_H) h_end = input_H;
                for (uint32_t s = 0; s < filter_W; s++) {
                    int8_t wgt = filt_c_base[r * filter_W + s];
                    // count legal w range
                    int w_start = padding > s ? (padding - s) : 0;
                    int w_end   = (int)input_W + padding - s;
                    if (w_end > (int)input_W) w_end = input_W;
                    for (int h = h_start; h < h_end; h++) {
                        int ih = h + (int)r - (int)padding;
                        int32_t* out_row = dst_m + (size_t)h * input_W;
                        uint8_t* act_row = act_c_base + (size_t)ih * input_W;
                        for (int w = w_start; w < w_end; w++) {
                            int iw = w + (int)s - (int)padding;
                            int32_t a = (int32_t)act_row[iw] - 128;
                            out_row[w] += (int32_t)wgt * a;
                        }
                    }
                }
            }
        }
    }

    // quant and relu
    for (uint32_t m = 0; m < filter_N; m++) {
        int32_t* src = out_temp + m * in_plane;
        uint8_t* dst = output  + m * in_plane;
        for (size_t i = 0; i < in_plane; i++) {
            int32_t v = src[i];
            if (v < 0) v = 0;    // ReLU
            v >>= scale;        // arithmetic shift
            if (v > 127) v = 127;
            dst[i] = (uint8_t)(v + 128);
        }
    }

    free(out_temp);
};  

void linear_relu(uint32_t input_size, uint32_t output_size, uint8_t* activation,
                 uint8_t* output, int8_t* filter, int32_t* bias,
                 uint32_t scale) {
    /*! <<<========= Implement here =========>>>*/
    int32_t* out_temp = malloc(output_size * sizeof(int32_t));

    // initialize with bias
    for (uint32_t o = 0; o < output_size; o++) {
        out_temp[o] = bias[o];
    }
    // linear
    for (uint32_t o = 0; o < output_size; o++) {
        int32_t acc = out_temp[o];
        int8_t*  filt_row = filter + o * input_size;
        for (uint32_t i = 0; i < input_size; i++) {
            acc += (int32_t)(activation[i] - 128) * filt_row[i];
        }
        out_temp[o] = acc;
    }

    // quant and relu
    for (uint32_t o = 0; o < output_size; o++) {
        int32_t v = out_temp[o] >> scale;   // arithmetic right shift
        v += 128;
        if (v < 128) v = 128;
        if (v > 255) v = 255;
        output[o] = (uint8_t)v;
    }

    free(out_temp);
};

void linear(uint32_t input_size, uint32_t output_size, uint8_t* activation,
            uint8_t* output, int8_t* filter, int32_t* bias, uint32_t scale) {
    /*! <<<========= Implement here =========>>>*/

    int32_t* out_temp = malloc(output_size * sizeof(int32_t));

    // initialize with bias
    for (uint32_t o = 0; o < output_size; o++) {
        out_temp[o] = bias[o];
    }
    // linear
    for (uint32_t o = 0; o < output_size; o++) {
        int32_t acc = out_temp[o];
        int8_t*  filt_row = filter + o * input_size;
        for (uint32_t i = 0; i < input_size; i++) {
            acc += (int32_t)(activation[i] - 128) * filt_row[i];
        }
        out_temp[o] = acc;
    }

    // quant
    for (uint32_t o = 0; o < output_size; o++) {
        int32_t v = out_temp[o] >> scale;   // arithmetic right shift
        v += 128;
        if (v < 0)   v = 0;
        if (v > 255) v = 255;
        output[o] = (uint8_t)v;
    }

    free(out_temp);
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
