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
  /********** function id ***********/
  reg [6:0] function_id;

  /******** state definition ********/
  reg [1:0] state, next_state;
  reg [2:0] exp_state, exp_next_state;
  reg [2:0] reci_state, reci_next_state;

  parameter WAIT_DATA_INPUT    = 2'd0;
  parameter DATA_CALC          = 2'd1;
  parameter DATA_OUTPUT        = 2'd2;

  parameter EXP_INIT = 3'd0;
  parameter EXP_MUT  = 3'd1;
  parameter EXP_DIV  = 3'd2;
  parameter EXP_ADD  = 3'd3;
  parameter EXP_DONE = 3'd4;

  parameter RECI_INIT = 3'd0;
  parameter RECI_MUT1 = 3'd1;
  parameter RECI_MUT2 = 3'd2;
  parameter RECI_MUT3 = 3'd3;
  parameter RECI_ADD  = 3'd4;
  parameter RECI_DONE = 3'd5;

  /******** internal register ********/
  reg signed [31:0] input_value;
  reg signed [31:0] output_value;

  /******** exponent register ********/
  reg signed [31:0] term_32b, factorial, b;   // b為算倒數的分母項，1/b
  reg signed [63:0] term_64b, term_64b_2, term_output;
  integer i;                                  // 計算項次

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= WAIT_DATA_INPUT;
      next_state <= WAIT_DATA_INPUT;
      exp_state <= EXP_INIT;
      exp_next_state <= EXP_INIT;
      reci_state <= RECI_INIT;
      reci_next_state <= RECI_INIT;
    end else if (rsp_valid) rsp_valid <= 1'b0;
    else begin
      state = next_state;
      case (state)
        WAIT_DATA_INPUT: begin
          if (cmd_valid) begin
            function_id <= cmd_payload_function_id[9:3];
            input_value <= cmd_payload_inputs_0;
            next_state <= DATA_CALC;
            exp_next_state <= EXP_INIT;
            reci_next_state <= RECI_INIT;
          end else begin
            next_state <= WAIT_DATA_INPUT;
          end
        end
        DATA_CALC: begin
          if (function_id == 7'd0) begin
            exp_state = exp_next_state;
            case (exp_state)
              EXP_INIT: begin
                i <= 1;                           // 初始化計算項次
                output_value <= 32'h07ffffff;     // Q4.27 format (第一項為1，因為Q0.31範圍沒有涵蓋1，最接近的值就是32'h7fffffff)
                term_32b <= 32'h07ffffff;         // Q4.27 format 
                exp_next_state <= EXP_MUT;
              end
              EXP_MUT: begin
                if (i <= 5) begin
                  term_64b <= term_32b * input_value;   // 計算泰勒展開的分子部分 , Q9.54 format
                  case (i)
                     1: factorial <= 32'h07ffffff; // 除法乘階設為    1 , Q4.27 format
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
                  exp_next_state <= EXP_DIV;
                end else begin
                  exp_next_state <= EXP_DONE;
                end
              end
              EXP_DIV: begin
                term_output <= term_64b[58:27] * factorial;   // term_64b (Q9.54 -> Q4.27) * Q4.27 = Q9.54 format 
                exp_next_state <= EXP_ADD;
              end
              EXP_ADD: begin
                if ( (i % 2) == 1) 
                  output_value <= output_value - term_output[58:27]; // term_output Q9.54 -> Q4.27 format
                else
                  output_value <= output_value + term_output[58:27]; // term_output Q9.54 -> Q4.27 format
                i <= i + 1;
                term_32b <= term_output[58:27]; // term_output Q9.54 -> Q4.27 format
                exp_next_state <= EXP_MUT;
              end
              EXP_DONE: begin
                rsp_payload_outputs_0 <= {output_value[31], (output_value[30:0] << 4)}; // Q4.27 format -> // Q0.31 format
                next_state <= DATA_OUTPUT;
              end
            endcase
          end else if (function_id == 7'd1) begin
            reci_state = reci_next_state;
            case (reci_state)
              RECI_INIT: begin
                i <= 1;
                output_value <= 32'h30000000;             // Q1.30 format，從 0.75 開始迭代逼近
                b <= 32'h3fffffff + (input_value >> 1);   // Q1.30 format，分母項為 1 + x (這邊的1也是因為Q0.31範圍沒有涵蓋1，最接近的值就是32'h7fffffff)
                reci_next_state <= RECI_MUT1;
              end
              RECI_MUT1: begin
                if (i <= 5) begin
                  term_64b <= 32'h7fffffff * output_value;    // Q1.30 format(2) * Q1.30 format(n) = Q3.60 format(2n)
                  term_64b_2 <= output_value * output_value;  // Q1.30 format(n) * Q1.30 format(n) = Q3.60 format(n^2)
                  reci_next_state <= RECI_MUT2;
                end else begin
                  reci_next_state <= RECI_DONE;
                end
              end
              RECI_MUT2: begin
                term_32b <= term_64b_2[61:30];    // term_64b (Q3.60 -> Q1.30) format
                reci_next_state <= RECI_MUT3;
              end
              RECI_MUT3: begin
                term_64b_2 <= b * term_32b;     // Q1.30 format(b) * Q1.30 format(n^2) = Q3.60 format(bn^2)
                reci_next_state <= RECI_ADD;
              end
              RECI_ADD: begin
                output_value <= term_64b[61:30] - term_64b_2[61:30];   // Q3.60 -> Q1.30 format (2n - bn^2)
                i <= i + 1;
                reci_next_state <= RECI_MUT1;
              end
              RECI_DONE: begin
                rsp_payload_outputs_0 <= {output_value[31], (output_value[30:0] << 1)}; // Q1.30 format -> // Q0.31 format
                next_state <= DATA_OUTPUT;
              end
            endcase
          end else if (function_id == 7'd2) begin
            exp_state = exp_next_state;
            case (exp_state)
              EXP_INIT: begin
                i <= 1;                           // 初始化計算項次
                output_value <= 32'h03ffffff;     // Q5.26 format (第一項為1，這邊的1也是因為Q0.31範圍沒有涵蓋1，最接近的值就是32'h7fffffff)
                term_32b <= 32'h03ffffff;         // Q5.26 format
                exp_next_state <= EXP_MUT;
              end
              EXP_MUT: begin
                if (i <= 5) begin
                  term_64b <= term_32b * input_value;   // 計算泰勒展開的分子部分 , Q11.52 format
                  case (i)
                     1: factorial <= 32'h03ffffff; // 除法乘階設為    1 , Q5.26 format
                     2: factorial <= 32'h02000000; // 除法乘階設為  1/2 , Q5.26 format
                     3: factorial <= 32'h01555555; // 除法乘階設為  1/3 , Q5.26 format
                     4: factorial <= 32'h01000000; // 除法乘階設為  1/4 , Q5.26 format
                     5: factorial <= 32'h00cccccd; // 除法乘階設為  1/5 , Q5.26 format
                     6: factorial <= 32'h00aaaaab; // 除法乘階設為  1/6 , Q5.26 format
                     7: factorial <= 32'h00924925; // 除法乘階設為  1/7 , Q5.26 format
                     8: factorial <= 32'h00800000; // 除法乘階設為  1/8 , Q5.26 format
                     9: factorial <= 32'h0071c71c; // 除法乘階設為  1/9 , Q5.26 format
                    10: factorial <= 32'h00666666; // 除法乘階設為 1/10 , Q5.26 format
                  endcase
                  exp_next_state <= EXP_DIV;
                end else begin
                  exp_next_state <= EXP_DONE;
                end
              end
              EXP_DIV: begin
                term_output <= term_64b[57:26] * factorial;   // term_64b (Q11.52 -> Q5.26) * Q5.26 = Q11.52 format
                exp_next_state <= EXP_ADD;
              end
              EXP_ADD: begin
                if ( (i % 2) == 1) 
                  output_value <= output_value - term_output[57:26]; // term_output Q11.52 -> Q5.26 format
                else
                  output_value <= output_value + term_output[57:26]; // term_output Q11.52 -> Q5.26 format
                i <= i + 1;
                term_32b <= term_output[57:26]; // term_output Q11.52 -> Q5.26 format
                exp_next_state <= EXP_MUT;
              end
              EXP_DONE: begin
                rsp_payload_outputs_0 <= {output_value[31], (output_value[30:0] << 5)}; // Q5.26 format -> // Q0.31 format
                next_state <= DATA_OUTPUT;
              end
            endcase
          end
        end
        DATA_OUTPUT: begin
          rsp_valid <= 1'b1;
          next_state <= WAIT_DATA_INPUT;
          exp_next_state <= EXP_INIT;
          reci_next_state <= RECI_INIT;
        end
      endcase
    end
  end
endmodule


