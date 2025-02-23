/* Copyright 2019 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/
#ifndef TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_CONV_H_
#define TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_CONV_H_

#include <algorithm>
#include <stdio.h>
#include <perf.h>
#include <cmath>

#include "tensorflow/lite/kernels/internal/common.h"
#include "tensorflow/lite/kernels/internal/portable_tensor_utils.h"
#include "cfu.h"

// #define SHOW_PARAMS
#define USE_GEMM
#define CFU_GEMM_BUFF_SIZE 256

#define FUNC7_GEMM_WRITE_CONFIG 0x40
#define FUNC7_GEMM_READ_CONFIG  0x00
#define FUNC7_GEMM_WRITE_BUFF_A 0x50
#define FUNC7_GEMM_READ_BUFF_A  0x10
#define FUNC7_GEMM_WRITE_BUFF_B 0x60
#define FUNC7_GEMM_READ_BUFF_B  0x20
#define FUNC7_GEMM_WRITE_BUFF_C 0x70
#define FUNC7_GEMM_READ_BUFF_C  0x30
#define FUNC7_GEMM_COMPUTE      0x01

namespace tflite {
namespace reference_integer_ops {

// Matrix multiplication with tiling
inline void Int8GemmWithTilingCfu(
    const int& k, const int& m, const int& n, const int32_t& input_offset,
    const int8_t* mat_a, const int8_t* mat_b, int32_t* mat_c, int tile_size) {
  // Initialize
  int cnt = 0;
  for (int i = 0; i < m; ++i) {
    for (int j = 0; j < n; ++j) {
      mat_c[cnt++] = 0;
    }
  }
  // Tiling
  int8_t wdata[4];
  cfu_op0(FUNC7_GEMM_WRITE_CONFIG, input_offset, 3); // write config - offset
  for (int k_start = 0; k_start < k; k_start += tile_size) {
    int k_tile = std::min(tile_size, k - k_start);
    cfu_op0(FUNC7_GEMM_WRITE_CONFIG, k_tile, 0); // write config - k
    for (int n_start = 0; n_start < n; n_start += tile_size) {
      int n_tile = std::min(tile_size, n - n_start);
      cfu_op0(FUNC7_GEMM_WRITE_CONFIG, n_tile, 2); // write config - n
      const int8_t* mat_b_head = mat_b+(k_start*n+n_start);
      // write weight
      cnt = 0;
      int col_tile = std::ceil(n_tile / 4.0);
      for (int cnt_tile = 0; cnt_tile < col_tile; ++cnt_tile) {
        for (int row = 0; row < k_tile; ++row) {
          for (int byte_offset = 0; byte_offset < 4; ++byte_offset) {
            int col = 4 * cnt_tile + byte_offset;
            wdata[3 - byte_offset] = (col < n_tile) ? mat_b_head[row * n + col] : 0;
            // mat_cfumem[cnt++] = (col < width) ? mat[row * width + col] : 0;
          }
          // printf("%8lx: [%4d, %4d, %4d, %4d]\n", *((int32_t*)wdata), (int)wdata[3], (int)wdata[2], (int)wdata[1], (int)wdata[0]);
          cfu_op0(FUNC7_GEMM_WRITE_BUFF_B, *((int32_t*)wdata), cnt++);
        }
      }
      for (int m_start = 0; m_start < m; m_start += tile_size) {
        int m_tile = std::min(tile_size, m - m_start);
        cfu_op0(FUNC7_GEMM_WRITE_CONFIG, m_tile, 1); // write config - m
        // Tile GEMM
        // A[m_start:m_end][k_start:k_end] * B[k_start:k_end][n_start:n_end]
        const int8_t* mat_a_head = mat_a+(m_start*k+k_start);
        int32_t* mat_c_head = mat_c+(m_start*n+n_start);
        // CFU GEMM
        // write input
        cnt = 0;
        int row_tile = std::ceil(m_tile / 4.0);
        for (int cnt_tile = 0; cnt_tile < row_tile; ++cnt_tile) {
          for (int col = 0; col < k_tile; ++col) {
            for (int byte_offset = 0; byte_offset < 4; ++byte_offset) {
              int row = 4 * cnt_tile + byte_offset;
              wdata[3 - byte_offset] = (row < m_tile) ? mat_a_head[row * k + col] : 0;
              // mat_cfumem[cnt++] = (row < height) ? mat[row * width +col] : 0;
            }
            // printf("%8lx: [%4d, %4d, %4d, %4d]\n", *((int32_t*)wdata), (int)wdata[3], (int)wdata[2], (int)wdata[1], (int)wdata[0]);
            cfu_op0(FUNC7_GEMM_WRITE_BUFF_A, *((int32_t*)wdata), cnt++);
          }
        }
        // compute
        cfu_op0(FUNC7_GEMM_COMPUTE, 0, 0);
        // read result
        cnt = 0;
        int32_t rdata;
        for (int cnt_tile = 0; cnt_tile < col_tile; ++cnt_tile) {
          for (int row = 0; row < m_tile; ++row) {
            for (int byte_offset = 0; byte_offset < 4; ++byte_offset) {
              int col = 4 * cnt_tile + byte_offset;
              rdata = cfu_op0(FUNC7_GEMM_READ_BUFF_C, byte_offset, cnt);
              // printf("%ld ", rdata);
              if (col < n_tile) {
                mat_c_head[row * n + col] += rdata;
              }
            }
            ++cnt;
          }
        }
      }
    }
  }
}

// Im2col
inline void Im2col(
    const int& batches, const int& filters_per_group,
    const int& input_height, const int& input_width, const int& input_depth, const int32_t& input_offset,
    const int& output_height, const int& output_width, const int& output_depth,
    const int& filter_num, const int& filter_height, const int& filter_width, const int& filter_depth,
    const int& dilation_height, const int& dilation_width, const int& pad_height, const int& pad_width,
    const int& stride_height, const int& stride_width,
    const int8_t* input_data, const RuntimeShape& input_shape, int8_t* input_data_2D,
    const int8_t* filter_data, const RuntimeShape& filter_shape, int8_t* filter_data_2D) {
  // Kernel
  int cnt = 0;
  for (int filter_channel = 0; filter_channel < filter_depth; ++filter_channel) {
    for (int filter_row = 0; filter_row < filter_height; ++filter_row) {
      for (int filter_col = 0; filter_col < filter_width; ++filter_col) {
        for (int output_channel = 0; output_channel < filter_num; ++output_channel) {
          filter_data_2D[cnt++] = filter_data[Offset(filter_shape, output_channel, filter_row, filter_col, filter_channel)];
        }
      }   
    }  
  }
  // Input
  cnt = 0;
  for (int batch = 0; batch < batches; ++batch) {
    for (int out_y = 0; out_y < output_height; ++out_y) {
      const int in_y_origin = (out_y * stride_height) - pad_height;
      for (int out_x = 0; out_x < output_width; ++out_x) {
        const int in_x_origin = (out_x * stride_width) - pad_width;
        for (int in_channel = 0; in_channel < filter_depth; ++in_channel) {
          for (int filter_row = 0; filter_row < filter_height; ++filter_row) {
            const int in_y = in_y_origin + dilation_height * filter_row;
            for (int filter_col = 0; filter_col < filter_width; ++filter_col) {
              const int in_x = in_x_origin + dilation_width * filter_col;

              const bool is_point_inside_image =
                  (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                  (in_y < input_height);
              
              input_data_2D[cnt++] = is_point_inside_image ? input_data[Offset(input_shape, batch, in_y, in_x, in_channel)] : (int8_t)(-input_offset);
            }   
          }  
        }
      }
    }
  }
}

inline void Im2col_reverse_and_post(
    const int& batches,
    const int& output_height, const int& output_width, const int& output_depth,
    int8_t* output_data, const RuntimeShape& output_shape, int32_t* output_data_2D,
    const int32_t* output_multiplier, const int32_t* output_shift,
    const int32_t& output_offset, const int32_t& output_activation_min, const int32_t& output_activation_max,
    const RuntimeShape& bias_shape, const int32_t* bias_data) {
  int cnt = 0;
  cnt = 0;
  for (int batch = 0; batch < batches; ++batch) {
    for (int out_y = 0; out_y < output_height; ++out_y) {
      for (int out_x = 0; out_x < output_width; ++out_x) {
        for (int out_channel = 0; out_channel < output_depth; ++out_channel) {
          int32_t acc = output_data_2D[cnt];
          //
          // if (bias_data) {
          //   acc += bias_data[out_channel];
          // }
          // acc = MultiplyByQuantizedMultiplier(
          //     acc, output_multiplier[out_channel], output_shift[out_channel]);

          // acc += output_offset;
          // acc = std::max(acc, output_activation_min);
          // acc = std::min(acc, output_activation_max);
          //
          cfu_op2(4, acc, 0);
          acc = cfu_op2(2, bias_data[out_channel], output_offset);
          acc = cfu_op2(3, output_multiplier[out_channel], output_shift[out_channel]);
          //

          output_data[Offset(output_shape, batch, out_y, out_x, out_channel)] = static_cast<int8_t>(acc);
          ++cnt;
        }
      }
    }
  }
}

// Fixed-point per-channel-quantization convolution reference kernel.
inline void ConvPerChannel(
    const ConvParams& params, const int32_t* output_multiplier,
    const int32_t* output_shift, const RuntimeShape& input_shape,
    const int8_t* input_data, const RuntimeShape& filter_shape,
    const int8_t* filter_data, const RuntimeShape& bias_shape,
    const int32_t* bias_data, const RuntimeShape& output_shape,
    int8_t* output_data) {
  perf_enable_counter(6);
  // Get parameters.
  const int32_t input_offset = params.input_offset;  // r = s(q - Z)
  const int stride_width = params.stride_width;
  const int stride_height = params.stride_height;
  const int dilation_width_factor = params.dilation_width_factor;
  const int dilation_height_factor = params.dilation_height_factor;
  const int pad_width = params.padding_values.width;
  const int pad_height = params.padding_values.height;
  const int32_t output_offset = params.output_offset;

  // Set min and max value of the output.
  const int32_t output_activation_min = params.quantized_activation_min;
  const int32_t output_activation_max = params.quantized_activation_max;

  // Consistency check.
  TFLITE_DCHECK_LE(output_activation_min, output_activation_max);
  TFLITE_DCHECK_EQ(input_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(filter_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(output_shape.DimensionsCount(), 4);
  const int batches = MatchingDim(input_shape, 0, output_shape, 0);
  const int input_depth = input_shape.Dims(3);
  const int output_depth = MatchingDim(filter_shape, 0, output_shape, 3);
  if (bias_data) {
    TFLITE_DCHECK_EQ(bias_shape.FlatSize(), output_depth);
  }

  // Check dimensions of the tensors.
  const int input_height = input_shape.Dims(1);
  const int input_width = input_shape.Dims(2);
  const int filter_height = filter_shape.Dims(1);
  const int filter_width = filter_shape.Dims(2);
  const int filter_input_depth = filter_shape.Dims(3);
  const int groups = input_depth / filter_input_depth;
  TFLITE_DCHECK_EQ(input_depth % filter_input_depth, 0);
  const int filters_per_group = output_depth / groups;
  const int output_height = output_shape.Dims(1);
  const int output_width = output_shape.Dims(2);

  // Show params
#ifdef SHOW_PARAMS
  printf("Batches = %d\n", batches);
  
  printf("Input Height = %d, ", input_height);
  printf("Input Width = %d, ", input_width);
  printf("Input Depth = %d\n", input_depth);

  printf("Filter Num = %d, ", output_depth);
  printf("Filter groups = %d, ", groups);
  printf("Filter Height = %d, ", filter_height);
  printf("Filter Width = %d, ", filter_width);
  printf("Filter Depth = %d\n", filter_input_depth);
  
  printf("Stride Height = %d, ", stride_height);
  printf("Stride Width = %d, ", stride_width);
  printf("Dilation Height = %d, ", dilation_height_factor);
  printf("Dilation Width = %d, ", dilation_width_factor);
  printf("Padding Height = %d, ", pad_height);
  printf("Padding Width = %d\n", pad_width);
  
  printf("Output Height = %d, ", output_height);
  printf("Output Width = %d, ", output_width);
  printf("Output Depth = %d\n", output_depth);
#endif

#ifdef USE_GEMM
  int8_t input_data_2D[206400];
  int8_t filter_data_2D[90000];
  int32_t result_data_2D[300000];
  Im2col(batches, filters_per_group,
    input_height, input_width, input_depth, input_offset,
    output_height, output_width, output_depth,
    output_depth, filter_height, filter_width, filter_input_depth,
    dilation_height_factor, dilation_width_factor, pad_height, pad_width,
    stride_height, stride_width,
    input_data, input_shape, input_data_2D,
    filter_data, filter_shape, filter_data_2D);
  int k = filter_height * filter_width * filter_input_depth;
  int m = batches * output_height * output_width;
  int n = output_depth;
  Int8GemmWithTilingCfu(k, m, n, input_offset, input_data_2D, filter_data_2D, result_data_2D, 64);
  Im2col_reverse_and_post(batches,
    output_height, output_width, output_depth,
    output_data, output_shape, result_data_2D,
    output_multiplier, output_shift,
    output_offset, output_activation_min, output_activation_max,
    bias_shape, bias_data);
#else
  for (int batch = 0; batch < batches; ++batch) {
    for (int out_y = 0; out_y < output_height; ++out_y) {
      const int in_y_origin = (out_y * stride_height) - pad_height;
      for (int out_x = 0; out_x < output_width; ++out_x) {
        const int in_x_origin = (out_x * stride_width) - pad_width;
        for (int out_channel = 0; out_channel < output_depth; ++out_channel) {
          auto group = out_channel / filters_per_group;
          int32_t acc = 0;
          for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
            const int in_y = in_y_origin + dilation_height_factor * filter_y;
            for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
              const int in_x = in_x_origin + dilation_width_factor * filter_x;

              // Zero padding by omitting the areas outside the image.
              const bool is_point_inside_image =
                  (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                  (in_y < input_height);

              if (!is_point_inside_image) {
                continue;
              }

              for (int in_channel = 0; in_channel < filter_input_depth;
                   ++in_channel) {
                int32_t input_val =
                    input_data[Offset(input_shape, batch, in_y, in_x,
                                      in_channel + group * filter_input_depth)];
                int32_t filter_val = filter_data[Offset(
                    filter_shape, out_channel, filter_y, filter_x, in_channel)];
                // Accumulate with 32 bits accumulator.
                // In the nudging process during model quantization, we force
                // real value of 0.0 be represented by a quantized value. This
                // guarantees that the input_offset is a int8_t, even though
                // it is represented using int32_t. int32_t += int8_t *
                // (int8_t - int8_t) so the highest value we can get from each
                // accumulation is [-127, 127] * ([-128, 127] -
                // [-128, 127]), which is [-32512, 32512]. log2(32512)
                // = 14.98, which means we can accumulate at least 2^16
                // multiplications without overflow. The accumulator is
                // applied to a filter so the accumulation logic will hold as
                // long as the filter size (filter_y * filter_x * in_channel)
                // does not exceed 2^16, which is the case in all the models
                // we have seen so far.
                // TODO(b/174275578): Add a check to make sure the
                // accumulator depth is smaller than 2^16.
                // printf("[acc += (%4ld) * (%4ld)]\n", input_val + input_offset, filter_val);
                acc += filter_val * (input_val + input_offset);
              }
            }
          }
          // printf("%4ld", acc);
          if (bias_data) {
            acc += bias_data[out_channel];
          }
          acc = MultiplyByQuantizedMultiplier(
              acc, output_multiplier[out_channel], output_shift[out_channel]);
          acc += output_offset;
          acc = std::max(acc, output_activation_min);
          acc = std::min(acc, output_activation_max);
          // output_data[Offset(output_shape, batch, out_y, out_x, out_channel)] =
          //     static_cast<int8_t>(acc);
          // if (static_cast<int8_t>(acc) != output_data[Offset(output_shape, batch, out_y, out_x, out_channel)]) {
          //   printf("error at output[%d, %d, %d, %d] = %d, expect = %ld\n", batch, out_y, out_x, out_channel, (int)output_data[Offset(output_shape, batch, out_y, out_x, out_channel)], acc);
          // } else {
          //   printf("correct at output[%d, %d, %d, %d] = %d\n", batch, out_y, out_x, out_channel, (int)output_data[Offset(output_shape, batch, out_y, out_x, out_channel)]);
          // }
          // printf("(%4ld) \n", acc);
        }
      }
    }
  }
#endif
  perf_disable_counter(6);
}

inline void ConvPerChannelWithPackedInt4Weights(
    const ConvParams& params, const int32_t* output_multiplier,
    const int32_t* output_shift, const RuntimeShape& input_shape,
    const int8_t* input_data, const RuntimeShape& filter_shape,
    const int8_t* filter_input, int8_t* unpacked_filter_data,
    const RuntimeShape& bias_shape, const int32_t* bias_data,
    const RuntimeShape& output_shape, int8_t* output_data) {
  TFLITE_DCHECK(unpacked_filter_data != nullptr);
  tflite::tensor_utils::UnpackDenseInt4IntoInt8(
      filter_input, filter_shape.FlatSize(), unpacked_filter_data);
  ConvPerChannel(params, output_multiplier, output_shift, input_shape,
                 input_data, filter_shape, unpacked_filter_data, bias_shape,
                 bias_data, output_shape, output_data);
}

// Fixed-point per-channel-quantization convolution reference kernel.
// 16-bit data and 8-bit filter
template <typename AccumScalar>
inline void ConvPerChannel(
    const ConvParams& params, const int32_t* output_multiplier,
    const int32_t* output_shift, const RuntimeShape& input_shape,
    const int16_t* input_data, const RuntimeShape& filter_shape,
    const int8_t* filter_data, const RuntimeShape& bias_shape,
    const AccumScalar* bias_data, const RuntimeShape& output_shape,
    int16_t* output_data) {
  // Get parameters.
  const int stride_width = params.stride_width;
  const int stride_height = params.stride_height;
  const int dilation_width_factor = params.dilation_width_factor;
  const int dilation_height_factor = params.dilation_height_factor;
  const int pad_width = params.padding_values.width;
  const int pad_height = params.padding_values.height;

  // Set min and max value of the output.
  const int32_t output_activation_min = params.quantized_activation_min;
  const int32_t output_activation_max = params.quantized_activation_max;

  // Consistency check.
  TFLITE_DCHECK_LE(output_activation_min, output_activation_max);
  TFLITE_DCHECK_EQ(input_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(filter_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(output_shape.DimensionsCount(), 4);
  const int batches = MatchingDim(input_shape, 0, output_shape, 0);
  const int input_depth = input_shape.Dims(3);
  const int output_depth = MatchingDim(filter_shape, 0, output_shape, 3);
  if (bias_data) {
    TFLITE_DCHECK_EQ(bias_shape.FlatSize(), output_depth);
  }

  // Check dimensions of the tensors.
  const int input_height = input_shape.Dims(1);
  const int input_width = input_shape.Dims(2);
  const int filter_height = filter_shape.Dims(1);
  const int filter_width = filter_shape.Dims(2);
  const int filter_input_depth = filter_shape.Dims(3);
  const int groups = input_depth / filter_input_depth;
  TFLITE_DCHECK_EQ(input_depth % filter_input_depth, 0);
  const int filters_per_group = output_depth / groups;
  const int output_height = output_shape.Dims(1);
  const int output_width = output_shape.Dims(2);
  for (int batch = 0; batch < batches; ++batch) {
    for (int out_y = 0; out_y < output_height; ++out_y) {
      const int in_y_origin = (out_y * stride_height) - pad_height;
      for (int out_x = 0; out_x < output_width; ++out_x) {
        const int in_x_origin = (out_x * stride_width) - pad_width;
        for (int out_channel = 0; out_channel < output_depth; ++out_channel) {
          auto group = out_channel / filters_per_group;
          AccumScalar acc = 0;
          for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
            const int in_y = in_y_origin + dilation_height_factor * filter_y;
            for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
              const int in_x = in_x_origin + dilation_width_factor * filter_x;

              // Zero padding by omitting the areas outside the image.
              const bool is_point_inside_image =
                  (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                  (in_y < input_height);

              if (!is_point_inside_image) {
                continue;
              }

              for (int in_channel = 0; in_channel < filter_input_depth;
                   ++in_channel) {
                int32_t input_val =
                    input_data[Offset(input_shape, batch, in_y, in_x,
                                      in_channel + group * filter_input_depth)];
                int32_t filter_val = filter_data[Offset(
                    filter_shape, out_channel, filter_y, filter_x, in_channel)];
                // Accumulate with 64 bits accumulator.
                // int64_t += int8_t * int16_t so the highest value we can
                // get from each accumulation is [-127, 127] * ([-32768,
                // 32767] -
                // [-32768, 32767]), which is [-8322945, 8322945].
                // log2(8322945) = 22.99.
                acc += filter_val * input_val;
              }
            }
          }
          if (bias_data) {
            acc += bias_data[out_channel];
          }
          int32_t scaled_acc = MultiplyByQuantizedMultiplier(
              acc, output_multiplier[out_channel], output_shift[out_channel]);
          scaled_acc = std::max(scaled_acc, output_activation_min);
          scaled_acc = std::min(scaled_acc, output_activation_max);
          output_data[Offset(output_shape, batch, out_y, out_x, out_channel)] =
              static_cast<int16_t>(scaled_acc);
        }
      }
    }
  }
}

}  // namespace reference_integer_ops
}  // namespace tflite

#endif  // TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_CONV_H_
