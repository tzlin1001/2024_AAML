/* Copyright 2020 The TensorFlow Authors. All Rights Reserved.

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

#include "tensorflow/lite/micro/kernels/conv_test.h"

#include "tensorflow/lite/c/builtin_op_data.h"
#include "tensorflow/lite/c/common.h"
#include "tensorflow/lite/micro/kernels/kernel_runner.h"
#include "tensorflow/lite/micro/kernels/testdata/conv_test_data.h"
#include "tensorflow/lite/micro/micro_utils.h"
#include "tensorflow/lite/micro/test_helpers.h"
#include "tensorflow/lite/micro/testing/micro_test.h"

namespace tflite {
namespace testing {
namespace {
// Common inputs and outputs.
// constexpr int kInputElements = 16;
// static int kInputShape[] = {4, 2, 2, 4, 1};
// static const float kInputData[kInputElements] = {1, 1, 1, 1, 2, 2, 2, 2,
//                                                  1, 2, 3, 4, 1, 2, 3, 4};

// constexpr int kFilterElements = 12;
// static int kFilterShape[] = {4, 3, 2, 2, 1};
// static const float kFilterData[kFilterElements] = {1,  2, 3,  4,  -1, 1,
//                                                    -1, 1, -1, -1, 1,  1};

// constexpr int kBiasElements = 3;
// static int kBiasShape[] = {1, 3};
// static const float kBiasData[kBiasElements] = {1, 2, 3};

// constexpr int kOutputElements = 12;
// static int kOutputShape[] = {4, 2, 1, 2, 3};
// static const float kGoldenData[kOutputElements] = {18, 2, 5, 18, 2, 5,
//                                                    17, 4, 3, 37, 4, 3};

constexpr int kInputElements = 8;
static int kInputShape[] = {4, 1, 2, 4, 1};
static const float kInputData[kInputElements] = {1, 1, 1, 1, 2, 2, 2, 2};

constexpr int kFilterElements = 12;
static int kFilterShape[] = {4, 3, 2, 2, 1};
static const float kFilterData[kFilterElements] = {1,  2, 3,  4,  -1, 1,
                                                   -1, 1, -1, -1, 1,  1};

constexpr int kBiasElements = 3;
static int kBiasShape[] = {1, 3};
static const float kBiasData[kBiasElements] = {1, 2, 3};

constexpr int kOutputElements = 6;
static int kOutputShape[] = {4, 1, 1, 2, 3};
static const float kGoldenData[kOutputElements] = {18, 2, 5, 18, 2, 5};

static TfLiteConvParams common_conv_params = {
    kTfLitePaddingValid,  // padding
    2,                    // stride_width
    2,                    // stride_height
    kTfLiteActNone,       // activation
    1,                    // dilation_width_factor
    1,                    // dilation_height_factor
};

}  // namespace
}  // namespace testing
}  // namespace tflite

TF_LITE_MICRO_TESTS_BEGIN

TF_LITE_MICRO_TEST(SimpleTestQuantized4bitPerChannel) {
  const int output_dims_count = 6;
  int8_t output_data[output_dims_count];

  const float input_scale = 0.5f;
  const float output_scale = 1.0f;
  const int input_zero_point = 0;
  const int output_zero_point = 0;

  int8_t input_quantized[tflite::testing::kInputElements];
  int8_t filter_quantized[tflite::testing::kFilterElements];
  int32_t bias_quantized[tflite::testing::kBiasElements];
  int8_t golden_quantized[tflite::testing::kOutputElements];
  int zero_points[tflite::testing::kBiasElements + 1];
  float scales[tflite::testing::kBiasElements + 1];

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk,
      tflite::testing::TestConvQuantizedPerChannel(
          tflite::testing::kInputShape, tflite::testing::kInputData,
          input_quantized, input_scale, input_zero_point,
          tflite::testing::kFilterShape, tflite::testing::kFilterData,
          filter_quantized, tflite::testing::kBiasShape,
          tflite::testing::kBiasData, bias_quantized, scales, zero_points,
          tflite::testing::kOutputShape, tflite::testing::kGoldenData,
          golden_quantized, output_scale, output_zero_point,
          &tflite::testing::common_conv_params, tflite::Register_CONV_2D(),
          output_data, kTfLiteInt4));
}
#if !defined(XTENSA)  // TODO(b/170321206): xtensa kernels are less general than
                      // reference kernels and we ifdef out test cases that are
                      // currently known to fail.


TF_LITE_MICRO_TEST(SimpleTestQuantizedPerChannel) {
  const int output_dims_count = 6;
  int8_t output_data[output_dims_count];

  const float input_scale = 0.5f;
  const float output_scale = 1.0f;
  const int input_zero_point = 0;
  const int output_zero_point = 0;

  int8_t input_quantized[tflite::testing::kInputElements];
  int8_t filter_quantized[tflite::testing::kFilterElements];
  int32_t bias_quantized[tflite::testing::kBiasElements];
  int8_t golden_quantized[tflite::testing::kOutputElements];
  int zero_points[tflite::testing::kBiasElements + 1];
  float scales[tflite::testing::kBiasElements + 1];

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk,
      tflite::testing::TestConvQuantizedPerChannel(
          tflite::testing::kInputShape, tflite::testing::kInputData,
          input_quantized, input_scale, input_zero_point,
          tflite::testing::kFilterShape, tflite::testing::kFilterData,
          filter_quantized, tflite::testing::kBiasShape,
          tflite::testing::kBiasData, bias_quantized, scales, zero_points,
          tflite::testing::kOutputShape, tflite::testing::kGoldenData,
          golden_quantized, output_scale, output_zero_point,
          &tflite::testing::common_conv_params, tflite::Register_CONV_2D(),
          output_data));
}

TF_LITE_MICRO_TEST(SimpleTestDilatedQuantizedPerChannel) {
  const int output_dims_count = 12;
  int8_t output_data[output_dims_count];

  const float input_scale = 0.5f;
  const float output_scale = 1.0f;
  const int input_zero_point = 0;
  const int output_zero_point = 0;

  const int input_elements = 24;
  int input_shape[] = {4, 1, 4, 6, 1};
  const float input_data[] = {
      // b = 0
      1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4};
  const int output_elements = 12;
  int output_shape[] = {4, 1, 2, 2, 3};
  const float golden_data[] = {25, 2, 7, 25, 2, 7, 10, 2, -3, 10, 2, -3};

  int8_t input_quantized[input_elements];
  int8_t filter_quantized[tflite::testing::kFilterElements];
  int32_t bias_quantized[tflite::testing::kBiasElements];
  int8_t golden_quantized[output_elements];
  int zero_points[tflite::testing::kBiasElements + 1];
  float scales[tflite::testing::kBiasElements + 1];

  TfLiteConvParams conv_params{tflite::testing::common_conv_params};
  conv_params.dilation_width_factor = 3;
  conv_params.dilation_height_factor = 2;

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk,
      tflite::testing::TestConvQuantizedPerChannel(
          input_shape, input_data, input_quantized, input_scale,
          input_zero_point, tflite::testing::kFilterShape,
          tflite::testing::kFilterData, filter_quantized,
          tflite::testing::kBiasShape, tflite::testing::kBiasData,
          bias_quantized, scales, zero_points, output_shape, golden_data,
          golden_quantized, output_scale, output_zero_point, &conv_params,
          tflite::Register_CONV_2D(), output_data));
}

TF_LITE_MICRO_TEST(SimpleTestQuantizedPerChannelRelu6) {
  const int output_dims_count = 6;
  int8_t output_data[output_dims_count];

  const float bias_values[] = {1, 2, -3};
  const float golden_data[] = {6, 2, 0, 6, 2, 0, 6, 4, 0, 6, 4, 0};

  const float input_scale = 0.023529f;
  const float output_scale = 0.023529f;
  const int input_zero_point = -128;
  const int output_zero_point = -128;

  int8_t input_quantized[tflite::testing::kInputElements];
  int8_t filter_quantized[tflite::testing::kFilterElements];
  int32_t bias_quantized[tflite::testing::kBiasElements];
  int8_t golden_quantized[tflite::testing::kOutputElements];
  int zero_points[tflite::testing::kBiasElements + 1];
  float scales[tflite::testing::kBiasElements + 1];

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk,
      tflite::testing::TestConvQuantizedPerChannel(
          tflite::testing::kInputShape, tflite::testing::kInputData,
          input_quantized, input_scale, input_zero_point,
          tflite::testing::kFilterShape, tflite::testing::kFilterData,
          filter_quantized, tflite::testing::kBiasShape, bias_values,
          bias_quantized, scales, zero_points, tflite::testing::kOutputShape,
          golden_data, golden_quantized, output_scale, output_zero_point,
          &tflite::testing::common_conv_params, tflite::Register_CONV_2D(),
          output_data));
}

#if !defined(CMSIS_NN)
TF_LITE_MICRO_TEST(SimpleTestQuantized16x8PerChannelRelu632bBias) {
  const int output_dims_count = 6;
  int16_t output_data[output_dims_count];

  const float bias_values[] = {1, 2, -3};
  const float golden_data[] = {6, 2, 0, 6, 2, 0, 6, 4, 0, 6, 4, 0};

  const float input_scale = 0.023529f;
  const float output_scale = 0.023529f;
  const int input_zero_point = 0;
  const int output_zero_point = 0;

  int16_t input_quantized[tflite::testing::kInputElements];
  int8_t filter_quantized[tflite::testing::kFilterElements];
  int32_t bias_quantized[tflite::testing::kBiasElements];
  int16_t golden_quantized[tflite::testing::kOutputElements];
  int zero_points[tflite::testing::kBiasElements + 1];
  float scales[tflite::testing::kBiasElements + 1];

  TfLiteConvParams conv_params{tflite::testing::common_conv_params};
  conv_params.activation = kTfLiteActRelu6;
  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk,
      tflite::testing::TestConvQuantizedPerChannel(
          tflite::testing::kInputShape, tflite::testing::kInputData,
          input_quantized, input_scale, input_zero_point,
          tflite::testing::kFilterShape, tflite::testing::kFilterData,
          filter_quantized, tflite::testing::kBiasShape, bias_values,
          bias_quantized, scales, zero_points, tflite::testing::kOutputShape,
          golden_data, golden_quantized, output_scale, output_zero_point,
          &conv_params, tflite::Register_CONV_2D(), output_data));
}
#endif

TF_LITE_MICRO_TEST(Kernel1x1QuantizedPerChannel) {
  // conv params:
  // padding, stride_<width,height>, activation, dilation_<width, height>
  TfLiteConvParams conv_params = {kTfLitePaddingValid, 1, 1,
                                  kTfLiteActNone,      1, 1};

  int input_shape[] = {4, 1, 2, 2, 4};  // [len,N,H,W,C]
  constexpr int input_elements =
      1 * 2 * 2 *
      4;  // input_shape[1] * input_shape[2] * input_shape[3] * input_shape[4];
  constexpr float input_data[input_elements] = {1, 1, 1, 1, 2, 2, 2, 2,
                                                1, 2, 3, 4, 1, 2, 3, 4};

  int filter_shape[] = {4, 3, 1, 1, 4};
  constexpr int filter_elements =
      3 * 1 * 1 * 4;  //      filter_shape[1] * filter_shape[2] *
                      //      filter_shape[3] * filter_shape[4];
  const float filter_data[filter_elements] = {1,  2, 3,  4,  -1, 1,
                                              -1, 1, -1, -1, 1,  1};

  constexpr int bias_elements = 3;  // filter_shape[1];
  int bias_shape[] = {1, bias_elements};
  constexpr float bias_data[bias_elements] = {1, 2, 3};

  int output_shape[] = {4, 1, 2, 2, bias_elements};
  constexpr int output_elements = 4 * 3;
  int8_t output_data[output_elements];

  const float golden_data[output_elements] = {11, 2, 3, 21, 2, 3,
                                              31, 4, 7, 31, 4, 7};

  const float input_scale = 0.5f;
  const float output_scale = 1.0f;
  const int input_zero_point = 0;
  const int output_zero_point = 0;

  int8_t input_quantized[input_elements];
  int8_t filter_quantized[filter_elements];
  int32_t bias_quantized[bias_elements];
  int8_t golden_quantized[output_elements];
  int zero_points[bias_elements + 1];
  float scales[bias_elements + 1];

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk, tflite::testing::TestConvQuantizedPerChannel(
                     input_shape, input_data, input_quantized, input_scale,
                     input_zero_point, filter_shape, filter_data,
                     filter_quantized, bias_shape, bias_data, bias_quantized,
                     scales, zero_points, output_shape, golden_data,
                     golden_quantized, output_scale, output_zero_point,
                     &conv_params, tflite::Register_CONV_2D(), output_data));
}

TF_LITE_MICRO_TEST(Kernel1x1QuantizedPerChannelRelu6) {
  // conv params:
  // padding, stride_<width,height>, activation, dilation_<width, height>
  TfLiteConvParams conv_params = {kTfLitePaddingValid, 1, 1,
                                  kTfLiteActRelu6,     1, 1};

  int input_shape[] = {4, 1, 2, 2, 4};  // [len,N,H,W,C]
  constexpr int input_elements =
      1 * 2 * 2 *
      4;  // input_shape[1] * input_shape[2] * input_shape[3] * input_shape[4];
  constexpr float input_data[input_elements] = {1, 1, 1, 1, 2, 2, 2, 2,
                                                1, 2, 3, 4, 1, 2, 3, 4};

  int filter_shape[] = {4, 3, 1, 1, 4};
  constexpr int filter_elements =
      3 * 1 * 1 * 4;  //      filter_shape[1] * filter_shape[2] *
                      //      filter_shape[3] * filter_shape[4];
  const float filter_data[filter_elements] = {1,  2, 3,  4,  -1, 1,
                                              -1, 1, -1, -1, 1,  1};

  constexpr int bias_elements = 3;  // filter_shape[1];
  int bias_shape[] = {1, bias_elements};
  constexpr float bias_data[bias_elements] = {1, 2, -3};

  int output_shape[] = {4, 1, 2, 2, bias_elements};
  constexpr int output_elements = 4 * 3;
  int8_t output_data[output_elements];

  const float golden_data[output_elements] = {6, 2, 0, 6, 2, 0,
                                              6, 4, 1, 6, 4, 1};

  const float input_scale = 0.023529f;
  const float output_scale = 0.023529f;
  const int input_zero_point = -128;
  const int output_zero_point = -128;

  int8_t input_quantized[input_elements];
  int8_t filter_quantized[filter_elements];
  int32_t bias_quantized[bias_elements];
  int8_t golden_quantized[output_elements];
  int zero_points[bias_elements + 1];
  float scales[bias_elements + 1];

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk, tflite::testing::TestConvQuantizedPerChannel(
                     input_shape, input_data, input_quantized, input_scale,
                     input_zero_point, filter_shape, filter_data,
                     filter_quantized, bias_shape, bias_data, bias_quantized,
                     scales, zero_points, output_shape, golden_data,
                     golden_quantized, output_scale, output_zero_point,
                     &conv_params, tflite::Register_CONV_2D(), output_data));
}

TF_LITE_MICRO_TEST(BroadcastPerLayerQuantizationToPerChannelShouldMatchGolden) {
  const int output_dims_count = 6;
  int8_t output_data[output_dims_count];

  const float input_scale = 1.0f;
  const float filter_scale = 1.0f;
  const float output_scale = 1.0f;

  int8_t input_quantized[tflite::testing::kInputElements];
  int8_t filter_quantized[tflite::testing::kFilterElements];
  int32_t bias_quantized[tflite::testing::kBiasElements];
  int8_t golden_quantized[tflite::testing::kOutputElements];

  TfLiteIntArray* input_dims =
      tflite::testing::IntArrayFromInts(tflite::testing::kInputShape);
  TfLiteIntArray* filter_dims =
      tflite::testing::IntArrayFromInts(tflite::testing::kFilterShape);
  TfLiteIntArray* bias_dims =
      tflite::testing::IntArrayFromInts(tflite::testing::kBiasShape);
  TfLiteIntArray* output_dims =
      tflite::testing::IntArrayFromInts(tflite::testing::kOutputShape);

  // Create per-layer quantized int8_t input tensor.
  TfLiteTensor input_tensor = tflite::testing::CreateQuantizedTensor(
      tflite::testing::kInputData, input_quantized, input_dims, input_scale, 0);
  int input_zero_points[2] = {1, 0};
  float input_scales[2] = {1, input_scale};
  TfLiteAffineQuantization input_quant = {
      tflite::testing::FloatArrayFromFloats(input_scales),
      tflite::testing::IntArrayFromInts(input_zero_points), 0};
  input_tensor.quantization = {kTfLiteAffineQuantization, &input_quant};

  // Create per-layer quantized int8_t filter tensor.
  TfLiteTensor filter_tensor = tflite::testing::CreateQuantizedTensor(
      tflite::testing::kFilterData, filter_quantized, filter_dims, filter_scale,
      0);
  int filter_zero_points[2] = {1, 0};
  float filter_scales[2] = {1, filter_scale};
  TfLiteAffineQuantization filter_quant = {
      tflite::testing::FloatArrayFromFloats(filter_scales),
      tflite::testing::IntArrayFromInts(filter_zero_points), 0};
  filter_tensor.quantization = {kTfLiteAffineQuantization, &filter_quant};

  // Create per-layer quantized int32_t bias tensor.
  tflite::SymmetricQuantize(tflite::testing::kBiasData, bias_quantized,
                            tflite::testing::kBiasElements,
                            input_scale * output_scale);
  TfLiteTensor bias_tensor =
      tflite::testing::CreateTensor(bias_quantized, bias_dims);

  int bias_zero_points[2] = {1, 0};
  float bias_scales[2] = {1, input_scale * filter_scale};
  TfLiteAffineQuantization bias_quant = {
      tflite::testing::FloatArrayFromFloats(bias_scales),
      tflite::testing::IntArrayFromInts(bias_zero_points), 0};
  bias_tensor.quantization = {kTfLiteAffineQuantization, &bias_quant};

  // Create per-layer quantized int8_t output tensor.
  TfLiteTensor output_tensor = tflite::testing::CreateQuantizedTensor(
      output_data, output_dims, output_scale, 0 /* quantized dimension */);
  int output_zero_points[2] = {1, 0};
  float output_scales[2] = {1, output_scale};
  TfLiteAffineQuantization output_quant = {
      tflite::testing::FloatArrayFromFloats(output_scales),
      tflite::testing::IntArrayFromInts(output_zero_points), 0};
  output_tensor.quantization = {kTfLiteAffineQuantization, &output_quant};

  constexpr int inputs_size = 3;
  constexpr int outputs_size = 1;
  constexpr int tensors_size = inputs_size + outputs_size;
  TfLiteTensor tensors[tensors_size] = {
      input_tensor,
      filter_tensor,
      bias_tensor,
      output_tensor,
  };

  tflite::Quantize(tflite::testing::kGoldenData, golden_quantized,
                   output_dims_count, output_scale, 0);

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk, tflite::testing::ValidateConvGoldens(
                     tensors, tensors_size, golden_quantized, output_dims_count,
                     &tflite::testing::common_conv_params,
                     tflite::Register_CONV_2D(), output_data));
}

#endif  // !defined(XTENSA)

TF_LITE_MICRO_TEST(Int8Filter1x3x3x1ShouldMatchGoldenEvenInputPaddingSame) {
  using tflite::ElementCount;
  using tflite::kConvFilter1x3x3x1;
  using tflite::kConvGoldenOutput4x4InputPaddingSame2x2;
  using tflite::kConvInput1x4x4x1;
  using tflite::kConvZeroBias;
  using tflite::testing::CreateTensor;
  using tflite::testing::FloatArrayFromFloats;
  using tflite::testing::IntArrayFromInts;
  using tflite::testing::ValidateConvGoldens;

  constexpr int kInDepth = 1;
  constexpr int kOutDepth = 1;

  // Input quantization parameters: same scale and zero point for all input
  // elements.
  constexpr float kInputScale = 0.00392120517f;
  constexpr int kInputZeroPoint = -128;
  float input_scales[] = {1, kInputScale};
  int input_zero_points[] = {1, kInputZeroPoint};
  TfLiteAffineQuantization input_quant = {FloatArrayFromFloats(input_scales),
                                          IntArrayFromInts(input_zero_points),
                                          0};
  // Create input tensor of size 1x4x4x1.
  int input_shape[] = {4, 1, 4, 4, kInDepth};
  TfLiteIntArray* input_dims = IntArrayFromInts(input_shape);
  TfLiteTensor input_tensor = CreateTensor(kConvInput1x4x4x1, input_dims);
  input_tensor.params = {kInputScale, kInputZeroPoint};
  input_tensor.quantization = {kTfLiteAffineQuantization, &input_quant};

  // Filter quantization parameters.
  int filter_zero_points[kOutDepth + 1] = {kOutDepth, 0};
  float filter_scales[kOutDepth + 1] = {kOutDepth, 0.00448552053f};
  TfLiteAffineQuantization filter_quant;
  filter_quant.scale = FloatArrayFromFloats(filter_scales);
  filter_quant.zero_point = IntArrayFromInts(filter_zero_points);
  filter_quant.quantized_dimension = 0;

  // Create filter tensor of size 1x3x3x1.
  int filter_shape[] = {4, kOutDepth, 3, 3, kInDepth};
  TfLiteIntArray* filter_dims = IntArrayFromInts(filter_shape);
  TfLiteTensor filter_tensor = CreateTensor(kConvFilter1x3x3x1, filter_dims);
  filter_tensor.quantization = {kTfLiteAffineQuantization, &filter_quant};

  // Bias quantization parameters: same zero point, but different scale per
  // output channel.
  int bias_zero_points[kOutDepth + 1] = {kOutDepth, 0};
  float bias_scales[kOutDepth + 1] = {kOutDepth, 0.00001758864f};
  TfLiteAffineQuantization bias_quant;
  bias_quant.scale = FloatArrayFromFloats(bias_scales);
  bias_quant.zero_point = IntArrayFromInts(bias_zero_points);
  bias_quant.quantized_dimension = 0;

  // Create size 1 zero bias tensor.
  int bias_shape[] = {1, kOutDepth};
  TfLiteIntArray* bias_dims = IntArrayFromInts(bias_shape);
  TfLiteTensor bias_tensor = CreateTensor(kConvZeroBias, bias_dims);
  bias_tensor.quantization = {kTfLiteAffineQuantization, &bias_quant};

  // Output quantization parameters: same zero point and scale for all elements.
  const float output_scale = 0.00627814838f;
  const int output_zero_point = -7;
  float output_scales[] = {1, output_scale};
  int output_zero_points[] = {1, output_zero_point};
  TfLiteAffineQuantization output_quant = {FloatArrayFromFloats(output_scales),
                                           IntArrayFromInts(output_zero_points),
                                           0};

  // Create output tensor of 1x2x2x1.
  int8_t output_data[4 * 2 * 2 * kOutDepth];
  int output_shape[] = {4, 1, 2, 2, kOutDepth};
  TfLiteIntArray* output_dims = IntArrayFromInts(output_shape);
  const int output_dims_count = ElementCount(*output_dims);
  TfLiteTensor output_tensor = CreateTensor(output_data, output_dims);
  output_tensor.params = {output_scale, output_zero_point};
  output_tensor.quantization = {kTfLiteAffineQuantization, &output_quant};

  // The 3 inputs include the input, filter and bias tensors.
  constexpr int inputs_size = 3;
  constexpr int outputs_size = 1;
  constexpr int tensors_size = inputs_size + outputs_size;
  TfLiteTensor tensors[tensors_size] = {
      input_tensor,
      filter_tensor,
      bias_tensor,
      output_tensor,
  };

  TfLiteConvParams conv_params{tflite::testing::common_conv_params};
  conv_params.padding = kTfLitePaddingSame;

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk, ValidateConvGoldens(tensors, tensors_size,
                                     kConvGoldenOutput4x4InputPaddingSame2x2,
                                     output_dims_count, &conv_params,
                                     tflite::Register_CONV_2D(), output_data,
                                     1.0 /* tolerance */));
}

TF_LITE_MICRO_TEST(Int8Filter1x3x3x1ShouldMatchGoldenOddInputPaddingSame) {
  using tflite::ElementCount;
  using tflite::kConvFilter1x3x3x1;
  using tflite::kConvGoldenOutput5x5InputPaddingSame3x3;
  using tflite::kConvInput1x5x5x1;
  using tflite::kConvZeroBias;
  using tflite::testing::CreateTensor;
  using tflite::testing::FloatArrayFromFloats;
  using tflite::testing::IntArrayFromInts;
  using tflite::testing::ValidateConvGoldens;

  constexpr int kInDepth = 1;
  constexpr int kOutDepth = 1;

  // Input quantization parameters: same scale and zero point for all input
  // elements.
  constexpr float kInputScale = 0.00392120517f;
  constexpr int kInputZeroPoint = -128;
  float input_scales[] = {1, kInputScale};
  int input_zero_points[] = {1, kInputZeroPoint};
  TfLiteAffineQuantization input_quant = {FloatArrayFromFloats(input_scales),
                                          IntArrayFromInts(input_zero_points),
                                          0};
  // Create input tensor of size 1x5x5x1.
  int input_shape[] = {4, 1, 5, 5, kInDepth};
  TfLiteIntArray* input_dims = IntArrayFromInts(input_shape);
  TfLiteTensor input_tensor = CreateTensor(kConvInput1x5x5x1, input_dims);
  input_tensor.params = {kInputScale, kInputZeroPoint};
  input_tensor.quantization = {kTfLiteAffineQuantization, &input_quant};

  // Filter quantization parameters.
  int filter_zero_points[kOutDepth + 1] = {kOutDepth, 0};
  float filter_scales[kOutDepth + 1] = {kOutDepth, 0.00448552053f};
  TfLiteAffineQuantization filter_quant;
  filter_quant.scale = FloatArrayFromFloats(filter_scales);
  filter_quant.zero_point = IntArrayFromInts(filter_zero_points);
  filter_quant.quantized_dimension = 0;

  // Create filter tensor of size 1x3x3x1.
  int filter_shape[] = {4, kOutDepth, 3, 3, kInDepth};
  TfLiteIntArray* filter_dims = IntArrayFromInts(filter_shape);
  TfLiteTensor filter_tensor = CreateTensor(kConvFilter1x3x3x1, filter_dims);
  filter_tensor.quantization = {kTfLiteAffineQuantization, &filter_quant};

  // Bias quantization parameters: same zero point, but different scale per
  // output channel.
  int bias_zero_points[kOutDepth + 1] = {kOutDepth, 0};
  float bias_scales[kOutDepth + 1] = {kOutDepth, 0.00001758864f};
  TfLiteAffineQuantization bias_quant;
  bias_quant.scale = FloatArrayFromFloats(bias_scales);
  bias_quant.zero_point = IntArrayFromInts(bias_zero_points);
  bias_quant.quantized_dimension = 0;

  // Create size 1 zero bias tensor.
  int bias_shape[] = {1, kOutDepth};
  TfLiteIntArray* bias_dims = IntArrayFromInts(bias_shape);
  TfLiteTensor bias_tensor = CreateTensor(kConvZeroBias, bias_dims);
  bias_tensor.quantization = {kTfLiteAffineQuantization, &bias_quant};

  // Output quantization parameters: same zero point and scale for all elements.
  const float output_scale = 0.00627814838f;
  const int output_zero_point = -7;
  float output_scales[] = {1, output_scale};
  int output_zero_points[] = {1, output_zero_point};
  TfLiteAffineQuantization output_quant = {FloatArrayFromFloats(output_scales),
                                           IntArrayFromInts(output_zero_points),
                                           0};

  // Create output tensor.
  int8_t output_data[4 * 3 * 3 * kOutDepth];
  int output_shape[] = {4, 1, 3, 3, kOutDepth};
  TfLiteIntArray* output_dims = IntArrayFromInts(output_shape);
  const int output_dims_count = ElementCount(*output_dims);
  TfLiteTensor output_tensor = CreateTensor(output_data, output_dims);
  output_tensor.params = {output_scale, output_zero_point};
  output_tensor.quantization = {kTfLiteAffineQuantization, &output_quant};

  // The 3 inputs include the input, filter and bias tensors.
  constexpr int inputs_size = 3;
  constexpr int outputs_size = 1;
  constexpr int tensors_size = inputs_size + outputs_size;
  TfLiteTensor tensors[tensors_size] = {
      input_tensor,
      filter_tensor,
      bias_tensor,
      output_tensor,
  };

  TfLiteConvParams conv_params{tflite::testing::common_conv_params};
  conv_params.padding = kTfLitePaddingSame;

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk, ValidateConvGoldens(tensors, tensors_size,
                                     kConvGoldenOutput5x5InputPaddingSame3x3,
                                     output_dims_count, &conv_params,
                                     tflite::Register_CONV_2D(), output_data,
                                     1.0 /* tolerance */));
}

TF_LITE_MICRO_TEST(Int8Input32x1Filter32x32ShouldMatchGolden) {
  constexpr int kSampleSize = 32;
  constexpr int kNumFilters = 32;
  int input_shape[] = {4, 1, 1, 1, kSampleSize};
  int filter_shape[] = {4, kNumFilters, 1, 1, kSampleSize};
  int bias_shape[] = {1, kSampleSize};
  int output_shape[] = {4, 1, 1, 1, kSampleSize};
  float filter_values[kNumFilters * kSampleSize];
  float input_values[kSampleSize];
  float bias_values[kSampleSize];

  // Generated these outputs using the floating point reference conv kernel.
  // TODO(b/149942509): Do this comparison automatically on random inputs.
  float expected_output[kSampleSize] = {
      5168.000000,  3377.000000,  306.000000,   -4045.000000, -4556.000000,
      -1227.000000, 822.000000,   1591.000000,  5176.000000,  3385.000000,
      314.000000,   -4037.000000, -4548.000000, -1219.000000, 830.000000,
      1599.000000,  5184.000000,  3393.000000,  322.000000,   -4029.000000,
      -4540.000000, -1211.000000, 838.000000,   1607.000000,  5192.000000,
      3401.000000,  330.000000,   -4021.000000, -4532.000000, -1203.000000,
      846.000000,   1615.000000};

  for (int i = 0; i < kSampleSize; i++) {
    bias_values[i] = i;
    // Generate inputs from -16 to 15.
    input_values[i] = i - 16;
  }

  // Generate samples of varying values between -128 and 127.
  for (int i = 0; i < kNumFilters * kSampleSize; i++) {
    filter_values[i] = (i * 25) % 256 - 128;
  }

  TfLiteConvParams conv_params;
  conv_params.activation = kTfLiteActNone;
  conv_params.dilation_height_factor = 1;
  conv_params.dilation_width_factor = 1;
  conv_params.stride_height = 1;
  conv_params.stride_width = 1;
  conv_params.padding = kTfLitePaddingValid;

  TfLiteIntArray* input_dims = tflite::testing::IntArrayFromInts(input_shape);
  TfLiteIntArray* filter_dims = tflite::testing::IntArrayFromInts(filter_shape);
  TfLiteIntArray* bias_dims = tflite::testing::IntArrayFromInts(bias_shape);
  TfLiteIntArray* output_dims = tflite::testing::IntArrayFromInts(output_shape);
  const int output_dims_count = tflite::ElementCount(*output_dims);

  // Quantization Parameters.  All scales except output are 1.0, and all zero
  // points are 0. This direct-maps the values to floating point and makes it
  // easy to reson about them.
  int input_zero_point = 0;
  float input_scale = 1.0f;
  int filter_zero_point = 0;
  float filter_scale = 1.0f;
  int output_zero_point = 0;
  // Output scale of 50 is needed to accomodate a float range of [-6400, 6350]
  float output_scale = 50.0f;

  // Create per-tensor quantized int8_t input tensor.
  int8_t input_quantized[kSampleSize];
  TfLiteTensor input_tensor = tflite::testing::CreateQuantizedTensor(
      input_values, input_quantized, input_dims, input_scale, input_zero_point);
  // Set zero point and scale arrays with a single element for each.
  int input_zero_points[] = {1, input_zero_point};
  float input_scales[] = {1, input_scale};
  TfLiteAffineQuantization input_quant = {
      tflite::testing::FloatArrayFromFloats(input_scales),
      tflite::testing::IntArrayFromInts(input_zero_points), 0};
  input_tensor.quantization = {kTfLiteAffineQuantization, &input_quant};

  // Create per-tensor quantized int8_t filter tensor.
  int8_t filter_quantized[kNumFilters * kSampleSize];
  TfLiteTensor filter_tensor = tflite::testing::CreateQuantizedTensor(
      filter_values, filter_quantized, filter_dims, filter_scale,
      filter_zero_point);
  // Set zero point and scale arrays with a single element for each.
  int filter_zero_points[] = {1, filter_zero_point};
  float filter_scales[] = {1, filter_scale};
  TfLiteAffineQuantization filter_quant = {
      tflite::testing::FloatArrayFromFloats(filter_scales),
      tflite::testing::IntArrayFromInts(filter_zero_points), 0};
  filter_tensor.quantization = {kTfLiteAffineQuantization, &filter_quant};

  // Create per-tensor quantized int32_t bias tensor.
  int32_t bias_quantized[kSampleSize];
  tflite::SymmetricQuantize(bias_values, bias_quantized, kSampleSize,
                            input_scale * output_scale);
  TfLiteTensor bias_tensor =
      tflite::testing::CreateTensor(bias_quantized, bias_dims);

  // There is a single zero point of 0, and a single scale of
  // input_scale * filter_scale.
  int bias_zero_points[] = {1, 0};
  float bias_scales[] = {1, input_scale * filter_scale};
  TfLiteAffineQuantization bias_quant = {
      tflite::testing::FloatArrayFromFloats(bias_scales),
      tflite::testing::IntArrayFromInts(bias_zero_points), 0};
  bias_tensor.quantization = {kTfLiteAffineQuantization, &bias_quant};

  // Create per-tensor quantized int8_t output tensor.
  int8_t output_quantized[kSampleSize];
  TfLiteTensor output_tensor = tflite::testing::CreateQuantizedTensor(
      output_quantized, output_dims, output_scale, output_zero_point);
  // Set zero point and scale arrays with a single element for each.
  int output_zero_points[] = {1, output_zero_point};
  float output_scales[] = {1, output_scale};
  TfLiteAffineQuantization output_quant = {
      tflite::testing::FloatArrayFromFloats(output_scales),
      tflite::testing::IntArrayFromInts(output_zero_points), 0};
  output_tensor.quantization = {kTfLiteAffineQuantization, &output_quant};

  // The 3 inputs include the input, filter and bias tensors.
  constexpr int kInputsSize = 3;
  constexpr int kOutputsSize = 1;
  constexpr int kTensorsSize = kInputsSize + kOutputsSize;
  TfLiteTensor tensors[kTensorsSize] = {
      input_tensor,
      filter_tensor,
      bias_tensor,
      output_tensor,
  };

  int8_t golden_quantized[kSampleSize];
  tflite::Quantize(expected_output, golden_quantized, output_dims_count,
                   output_scale, output_zero_point);

  // Rounding errors due to quantization should not exceed 1.
  constexpr int kQuantizationTolerance = 1;

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk, tflite::testing::ValidateConvGoldens(
                     tensors, kTensorsSize, golden_quantized, output_dims_count,
                     &conv_params, tflite::Register_CONV_2D(), output_quantized,
                     kQuantizationTolerance));
}

// This test is created based on
// https://github.com/tensorflow/tflite-micro/issues/329
// Input, output and filter are all 8 bits.
// Filter tensor is of dimension 8x3x3x3 with different scales per output
// channel. Some arbitrary parameters come from the above issue.
TF_LITE_MICRO_TEST(Int8Filter8x3x3x3PerChannelScaleRelu6ShouldMatchGolden) {
  using tflite::ElementCount;
  using tflite::kConvBiasQuantized8;
  using tflite::kConvFilter8x3x3x3;
  using tflite::kConvGoldenOutput1x16x16x8;
  using tflite::kConvInput1x32x32x3;
  using tflite::testing::CreateTensor;
  using tflite::testing::FloatArrayFromFloats;
  using tflite::testing::IntArrayFromInts;
  using tflite::testing::ValidateConvGoldens;

  constexpr int kInDepth = 3;
  constexpr int kOutDepth = 8;

  // Input quantization parameters: same scale and zero point for all input
  // elements.
  constexpr float kInputScale = 0.00784313772f;
  constexpr int kInputZeroPoint = -1;
  float input_scales[] = {1, kInputScale};
  int input_zero_points[] = {1, kInputZeroPoint};
  TfLiteAffineQuantization input_quant = {FloatArrayFromFloats(input_scales),
                                          IntArrayFromInts(input_zero_points),
                                          0};
  // Create input tensor of size 1x32x32x3.
  int input_shape[] = {4, 1, 32, 32, kInDepth};
  TfLiteIntArray* input_dims = IntArrayFromInts(input_shape);
  TfLiteTensor input_tensor = CreateTensor(kConvInput1x32x32x3, input_dims);
  input_tensor.params = {kInputScale, kInputZeroPoint};
  input_tensor.quantization = {kTfLiteAffineQuantization, &input_quant};

  // Filter quantization parameters: same zero point, but different scale per
  // output channel.
  int filter_zero_points[kOutDepth + 1] = {kOutDepth, 0, 0, 0, 0, 0, 0, 0, 0};
  float filter_scales[kOutDepth + 1] = {
      kOutDepth,      2.18926089e-05, 0.00453596329,
      0.000504297379, 0.00184638216,  0.00596635276,
      0.000199135626, 0.0047677448,   0.00193942268};
  TfLiteAffineQuantization filter_quant;
  filter_quant.scale = FloatArrayFromFloats(filter_scales);
  filter_quant.zero_point = IntArrayFromInts(filter_zero_points);
  filter_quant.quantized_dimension = 0;

  // Create filter tensor of size 8x3x3x3.
  int filter_shape[] = {4, kOutDepth, 3, 3, kInDepth};
  TfLiteIntArray* filter_dims = IntArrayFromInts(filter_shape);
  TfLiteTensor filter_tensor = CreateTensor(kConvFilter8x3x3x3, filter_dims);
  filter_tensor.quantization = {kTfLiteAffineQuantization, &filter_quant};

  // Bias quantization parameters: same zero point, but different scale per
  // output channel.
  int bias_zero_points[kOutDepth + 1] = {kOutDepth, 0, 0, 0, 0, 0, 0, 0, 0};
  float bias_scales[kOutDepth + 1] = {
      kOutDepth,      1.71706745e-07, 3.5576184e-05,
      3.95527377e-06, 1.44814294e-05, 4.67949249e-05,
      1.56184819e-06, 3.73940784e-05, 1.52111588e-05};
  TfLiteAffineQuantization bias_quant;
  bias_quant.scale = FloatArrayFromFloats(bias_scales);
  bias_quant.zero_point = IntArrayFromInts(bias_zero_points);
  bias_quant.quantized_dimension = 0;

  // Create per output channel bias of size 8
  int bias_shape[] = {1, kOutDepth};
  TfLiteIntArray* bias_dims = IntArrayFromInts(bias_shape);
  TfLiteTensor bias_tensor = CreateTensor(kConvBiasQuantized8, bias_dims);
  bias_tensor.quantization = {kTfLiteAffineQuantization, &bias_quant};

  // Output quantization parameters: same zero point and scale for all elements.
  const float output_scale = 0.0235294122f;
  const int output_zero_point = -128;
  float output_scales[] = {1, output_scale};
  int output_zero_points[] = {1, output_zero_point};
  TfLiteAffineQuantization output_quant = {FloatArrayFromFloats(output_scales),
                                           IntArrayFromInts(output_zero_points),
                                           0};

  // Create output tensor of 16x16x8
  int8_t output_data[1 * 16 * 16 * kOutDepth];
  int output_shape[] = {4, 1, 16, 16, kOutDepth};
  TfLiteIntArray* output_dims = IntArrayFromInts(output_shape);
  const int output_dims_count = ElementCount(*output_dims);
  TfLiteTensor output_tensor = CreateTensor(output_data, output_dims);
  output_tensor.params = {output_scale, output_zero_point};
  output_tensor.quantization = {kTfLiteAffineQuantization, &output_quant};

  // The 3 inputs include the input, filter and bias tensors.
  constexpr int inputs_size = 3;
  constexpr int outputs_size = 1;
  constexpr int tensors_size = inputs_size + outputs_size;
  TfLiteTensor tensors[tensors_size] = {
      input_tensor,
      filter_tensor,
      bias_tensor,
      output_tensor,
  };

  TfLiteConvParams conv_params{tflite::testing::common_conv_params};
  conv_params.activation = kTfLiteActRelu6;

  TF_LITE_MICRO_EXPECT_EQ(
      kTfLiteOk,
      ValidateConvGoldens(tensors, tensors_size, kConvGoldenOutput1x16x16x8,
                          output_dims_count, &conv_params,
                          tflite::Register_CONV_2D(), output_data,
                          1.0 /* tolerance */));
}

TF_LITE_MICRO_TESTS_END
