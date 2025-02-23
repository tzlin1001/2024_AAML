// Copyright 2021 The CFU-Playground Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "cfuop_simd.v"
`include "cfuop_add.v"
`include "cfuop_sa.v"

`define NUM_CFUOP 3
`define CFUOP_ADD  1
`define CFUOP_SIMD 2
`define CFUOP_SA   0

module Cfu (
  input             cmd_valid,
  output reg        cmd_ready,
  input      [9:0]  cmd_payload_function_id,
  input      [31:0] cmd_payload_inputs_0,
  input      [31:0] cmd_payload_inputs_1,
  output reg        rsp_valid,
  input             rsp_ready,
  output reg [31:0] rsp_payload_outputs_0,
  input             reset,
  input             clk
);
  // Wire & Reg
  wire [2:0]  funct3, sel;
  wire [6:0]  funct7;
  reg  [2:0]  funct3_reg;
  reg  busy;
  wire [`NUM_CFUOP-1:0] w_fu_enable;
  wire [`NUM_CFUOP-1:0] w_cmd_valid;
  wire [`NUM_CFUOP-1:0] w_cmd_ready;
  wire [`NUM_CFUOP-1:0] w_rsp_valid;
  wire [31:0] w_rsp_output[0:`NUM_CFUOP-1];

  // Dataflow & Control
  assign funct3 = cmd_payload_function_id[2:0];
  assign funct7 = cmd_payload_function_id[9:3];

  generate
    genvar idx;
    for (idx = 0; idx < `NUM_CFUOP; idx = idx + 1) begin
      assign w_fu_enable[idx] = funct3 == idx;
      assign w_cmd_valid[idx] = w_fu_enable[idx] & cmd_valid;
    end
  endgenerate

  always @(posedge clk or posedge reset) begin
    if (reset) busy <= 1'b0;
    else begin
      if (~busy) busy <= cmd_ready & cmd_valid;
      else       busy <= ~(rsp_ready & rsp_valid);
    end
  end

  always @(posedge clk or posedge reset) begin
    if (reset)
      funct3_reg <= 'd0;
    else if (cmd_ready & cmd_valid)
      funct3_reg <= funct3;
  end

  // Functional Units
`ifdef CFUOP_SIMD
  cfuop_simd fu_simd(
    .cmd_valid              (w_cmd_valid[`CFUOP_SIMD]),
    .cmd_ready              (w_cmd_ready[`CFUOP_SIMD]),
    .cmd_payload_function_id(cmd_payload_function_id),
    .cmd_payload_inputs_0   (cmd_payload_inputs_0),
    .cmd_payload_inputs_1   (cmd_payload_inputs_1),
    .rsp_valid              (w_rsp_valid[`CFUOP_SIMD]),
    .rsp_ready              (rsp_ready),
    .rsp_payload_outputs_0  (w_rsp_output[`CFUOP_SIMD]),
    .reset                  (reset),
    .clk                    (clk)
  );
`endif
`ifdef CFUOP_ADD
  cfuop_add fu_add(
    .cmd_valid              (w_cmd_valid[`CFUOP_ADD]),
    .cmd_ready              (w_cmd_ready[`CFUOP_ADD]),
    .cmd_payload_function_id(cmd_payload_function_id),
    .cmd_payload_inputs_0   (cmd_payload_inputs_0),
    .cmd_payload_inputs_1   (cmd_payload_inputs_1),
    .rsp_valid              (w_rsp_valid[`CFUOP_ADD]),
    .rsp_ready              (rsp_ready),
    .rsp_payload_outputs_0  (w_rsp_output[`CFUOP_ADD]),
    .reset                  (reset),
    .clk                    (clk)
  );
`endif
`ifdef CFUOP_SA
  cfuop_sa fu_sa(
    .cmd_valid              (w_cmd_valid[`CFUOP_SA]),
    .cmd_ready              (w_cmd_ready[`CFUOP_SA]),
    .cmd_payload_function_id(cmd_payload_function_id),
    .cmd_payload_inputs_0   (cmd_payload_inputs_0),
    .cmd_payload_inputs_1   (cmd_payload_inputs_1),
    .rsp_valid              (w_rsp_valid[`CFUOP_SA]),
    .rsp_ready              (rsp_ready),
    .rsp_payload_outputs_0  (w_rsp_output[`CFUOP_SA]),
    .reset                  (reset),
    .clk                    (clk)
  );
`endif

  // Output
  assign sel = busy ? funct3_reg : funct3;
  always @(*) begin
    case (sel)
`ifdef CFUOP_ADD
      `CFUOP_ADD: begin
        cmd_ready = w_cmd_ready[`CFUOP_ADD];
        rsp_valid = w_rsp_valid[`CFUOP_ADD];
        rsp_payload_outputs_0 = w_rsp_output[`CFUOP_ADD];
      end
`endif
`ifdef CFUOP_SIMD
      `CFUOP_SIMD: begin
        cmd_ready = w_cmd_ready[`CFUOP_SIMD];
        rsp_valid = w_rsp_valid[`CFUOP_SIMD];
        rsp_payload_outputs_0 = w_rsp_output[`CFUOP_SIMD];
      end
`endif
`ifdef CFUOP_SA
      `CFUOP_SA: begin
        cmd_ready = w_cmd_ready[`CFUOP_SA];
        rsp_valid = w_rsp_valid[`CFUOP_SA];
        rsp_payload_outputs_0 = w_rsp_output[`CFUOP_SA];
      end
`endif
      default: begin
        cmd_ready = 1'b0;
        rsp_valid = 1'b0;
        rsp_payload_outputs_0 = 'd0;
      end
    endcase
  end

endmodule
