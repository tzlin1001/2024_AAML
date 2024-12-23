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



module Cfu (
  input               cmd_valid,
  output              cmd_ready,
  input      [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  output reg          rsp_valid,
  input               rsp_ready,
  output reg [31:0]   rsp_payload_outputs_0,
  input               reset,
  input               clk
);

  /******** state definition ********/
  reg [1:0] state, next_state;
  reg [2:0] exp_calc_state, exp_calc_nt_state;

  parameter WAIT_DATA_INPUT    = 2'd0;
  parameter DATA_EXP_CALC      = 2'd1;
  parameter DATA_OUTPUT        = 2'd2;

  parameter EXP_INIT = 3'd0;
  parameter EXP_MUT  = 3'd1;
  parameter EXP_DIV  = 3'd2;
  parameter EXP_ADD  = 3'd3;
  parameter EXP_DONE = 3'd4;


  /******** internal register ********/
  reg signed [31:0] input_value;
  reg signed [31:0] output_value;

  /******** exponent register ********/
  reg signed [31:0] term_32b, factorial;
  reg signed [63:0] term_64b, term_output;
  integer i;                                  // 計算項次

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      term_32b <= 32'h0;
      factorial <= 32'h0;
      i <= 0;
      state <= WAIT_DATA_INPUT;
      next_state <= WAIT_DATA_INPUT;
      exp_calc_state <= EXP_INIT;
      exp_calc_nt_state <= EXP_INIT;
    end else if (rsp_valid) rsp_valid <= 1'b0;
    else begin
      state = next_state;
      case (state)
        WAIT_DATA_INPUT: begin
          if (cmd_valid) begin
            input_value <= cmd_payload_inputs_0;
            next_state <= DATA_EXP_CALC;
            exp_calc_nt_state <= EXP_INIT;
            //rsp_payload_outputs_0 <= 32'd1;   // 不許這樣寫
            //rsp_valid <= 1'b1;                // 兩行寫在一起會卡住
          end else begin
            next_state <= WAIT_DATA_INPUT;
          end
        end
        DATA_EXP_CALC: begin
          exp_calc_state = exp_calc_nt_state;
          case (exp_calc_state)
            EXP_INIT: begin
              i <= 1;                           // 初始化計算項次
              output_value <= 32'h08000000;     // Q4.27 format (第一項為 1 )
              term_32b <= 32'h08000000;         // Q4.27 format 
              exp_calc_nt_state <= EXP_MUT;
            end
            EXP_MUT: begin
              if (i <= 6) begin
                term_64b <= $signed(term_32b) * $signed(input_value);   // 計算泰勒展開的分子部分 , Q9.54 format
                case (i)
                   1: factorial <= 32'h08000000; // 除法乘階設為    1 , Q4.27 format
                   2: factorial <= 32'h04000000; // 除法乘階設為  1/2 , Q4.27 format
                   3: factorial <= 32'h02aaaaab; // 除法乘階設為  1/3 , Q4.27 format
                   4: factorial <= 32'h02000000; // 除法乘階設為  1/4 , Q4.27 format
                   5: factorial <= 32'h0199999a; // 除法乘階設為  1/5 , Q4.27 format
                   6: factorial <= 32'h01555555; // 除法乘階設為  1/6 , Q4.27 format
                   7: factorial <= 32'h01249249; // 除法乘階設為  1/7 , Q4.27 format
                   8: factorial <= 32'h01000000; // 除法乘階設為  1/8 , Q4.27 format
                   9: factorial <= 32'h00e38e39; // 除法乘階設為  1/9 , Q4.27 format
                  10: factorial <= 32'h00cccccd; // 除法乘階設為 1/10 , Q4.27 format
                endcase
                exp_calc_nt_state <= EXP_DIV;
              end else begin
                exp_calc_nt_state <= EXP_DONE;
              end
            end
            EXP_DIV: begin
              term_output <= $signed({term_64b[63], term_64b[57:54], term_64b[53:27]}) * $signed(factorial);   // term_64b (Q9.54 -> Q4.27) * Q4.27 = Q9.54 format
              exp_calc_nt_state <= EXP_ADD;
            end
            EXP_ADD: begin
              output_value <= $signed(output_value) + $signed({term_output[63], term_output[57:54], term_output[53:27]}); // term_output Q9.54 -> Q4.27 format
              term_32b <= {term_output[63], term_output[57:54], term_output[53:27]};                                      // term_output Q9.54 -> Q4.27 format 
              i <= i + 1;
              exp_calc_nt_state <= EXP_MUT;
            end
            EXP_DONE: begin
              rsp_payload_outputs_0 <= {output_value[31], (output_value[30:0] << 4)}; // Q4.27 format -> // Q0.31 format
              next_state <= DATA_OUTPUT;
            end
          endcase
        end
        DATA_OUTPUT: begin
          rsp_valid <= 1'b1;
          next_state <= WAIT_DATA_INPUT;
          exp_calc_nt_state <= EXP_INIT;
        end
      endcase
    end
  end
endmodule


