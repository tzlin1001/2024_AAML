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

`include "global_buffer_bram.v"
`include "TPU.v"

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

  /******* internal register ********/
  reg signed [31:0] input_value_0, input_value_1;

  /******** state definition ********/
  reg [3:0] state, next_state;

  parameter WAIT_INPUT         = 4'd0;
  parameter INPUT_GBUFF_A      = 4'd1;
  parameter INPUT_GBUFF_B      = 4'd2;
  parameter WAIT_PROCESS       = 4'd3;
  parameter OUTPUT_GBUFF_C     = 4'd4;
  parameter CFU_DONE           = 4'd5;

  /********* cfu controller *********/
  reg cfu_A_wr, cfu_B_wr, cfu_C_rd;
  reg process_trigger_once;
  // reg [15:0] test;

  /******** wire connection *********/
  wire            clk, rst_n;
  reg             in_valid;
  reg [7:0]       K;
  reg [7:0]       M;
  reg [7:0]       N;
  wire            busy;
  wire            A_wr_en;
  wire [15:0]     A_index;
  wire [31:0]     A_data_in;
  wire [31:0]     A_data_out;
  wire            B_wr_en;
  wire [15:0]     B_index;
  wire [31:0]     B_data_in;
  wire [31:0]     B_data_out;
  wire            C_wr_en;
  wire [15:0]     C_index;
  wire [127:0]    C_data_in;
  wire [127:0]    C_data_out;
  wire [31:0]     input_offset;

  wire            A_wr_en_from_TPU;
  wire [15:0]     A_index_from_TPU;
  wire            B_wr_en_from_TPU;
  wire [15:0]     B_index_from_TPU;
  wire            C_wr_en_from_TPU;
  wire [15:0]     C_index_from_TPU;

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  TPU My_TPU(
      .clk            (clk),     
      .rst_n          (~reset),     
      .in_valid       (in_valid),         
      .K              (K), 
      .M              (M), 
      .N              (N), 
      .busy           (busy),     
      .A_wr_en        (A_wr_en_from_TPU),         
      .A_index        (A_index_from_TPU),         
      .A_data_in      (A_data_in),         
      .A_data_out     (A_data_out),         
      .B_wr_en        (B_wr_en_from_TPU),         
      .B_index        (B_index_from_TPU),         
      .B_data_in      (B_data_in),         
      .B_data_out     (B_data_out),         
      .C_wr_en        (C_wr_en_from_TPU),         
      .C_index        (C_index_from_TPU),         
      .C_data_in      (C_data_in),         
      .C_data_out     (C_data_out),
          
      .input_offset   (input_offset)     
  );

  global_buffer_bram #(
    .ADDR_BITS(10), // ADDR_BITS 12 -> generates 2^12 entries
    .DATA_BITS(32)  // DATA_BITS 32 -> 32 bits for each entries
  )
  gbuff_A(
    .clk(clk),
    .rst_n(1'b1),
    .ram_en(1'b1),
    .wr_en(A_wr_en),
    .index(A_index),
    .data_in(A_data_in),
    .data_out(A_data_out)
  );

  global_buffer_bram #(
    .ADDR_BITS(10), // ADDR_BITS 12 -> generates 2^12 entries
    .DATA_BITS(32)  // DATA_BITS 32 -> 32 bits for each entries
  )
  gbuff_B(
    .clk(clk),
    .rst_n(1'b1),
    .ram_en(1'b1),
    .wr_en(B_wr_en),
    .index(B_index),
    .data_in(B_data_in),
    .data_out(B_data_out)
  );

  global_buffer_bram #(
    .ADDR_BITS(10), // ADDR_BITS 12 -> generates 2^12 entries
    .DATA_BITS(128)  // DATA_BITS 32 -> 32 bits for each entries
  )
  gbuff_C(
    .clk(clk),
    .rst_n(1'b1),
    .ram_en(1'b1),
    .wr_en(C_wr_en),
    .index(C_index),
    .data_in(C_data_in),
    .data_out(C_data_out)
  );

  assign A_wr_en = cfu_A_wr;
  assign B_wr_en = cfu_B_wr;
  assign C_wr_en = C_wr_en_from_TPU;
  assign A_index = cfu_A_wr? input_value_1[15:0] : A_index_from_TPU;
  assign B_index = cfu_B_wr? input_value_1[15:0] : B_index_from_TPU;
  assign C_index = cfu_C_rd? input_value_0[15:0] : C_index_from_TPU;
  assign A_data_in = input_value_0;
  assign B_data_in = input_value_0;
  assign input_offset = input_value_0;

  always @(posedge clk or posedge reset) begin
     if (reset) begin
      process_trigger_once <= 1'b0;
      cfu_A_wr <= 1'b0;
      cfu_B_wr <= 1'b0;
      cfu_C_rd <= 1'b0;
      in_valid <= 1'b0;
      state <= WAIT_INPUT;
      next_state <= WAIT_INPUT;
     end else if (rsp_valid) rsp_valid <= 1'b0;
     else begin
      state = next_state;
      case (state)
        WAIT_INPUT: begin
          if (cmd_valid) begin
            input_value_0 <= cmd_payload_inputs_0;
            input_value_1 <= cmd_payload_inputs_1;
            if(cmd_payload_function_id[9:3] == 7'd1) begin
              cfu_A_wr <= 1'b1;              
              next_state <= CFU_DONE;
              // next_state <= INPUT_GBUFF_A;
            end
            else if(cmd_payload_function_id[9:3] == 7'd2) begin
              cfu_B_wr <= 1'b1;
              next_state <= CFU_DONE;
              // next_state <= INPUT_GBUFF_B;
            end
            else if(cmd_payload_function_id[9:3] == 7'd3) next_state <= WAIT_PROCESS;
            else if(cmd_payload_function_id[9:3] == 7'd4) begin
              cfu_C_rd <= 1'b1;
              next_state <= OUTPUT_GBUFF_C;
            end
          end else begin
            next_state <= WAIT_INPUT;
          end
        end
        INPUT_GBUFF_A: begin
          cfu_A_wr <= 1'b0;
          rsp_payload_outputs_0 <= A_data_in;
          next_state <= CFU_DONE;
        end
        INPUT_GBUFF_B: begin
          cfu_B_wr <= 1'b0;
          rsp_payload_outputs_0 <= B_data_in;
          next_state <= CFU_DONE;
        end
        WAIT_PROCESS: begin
          if (process_trigger_once == 1'b0) begin
            // test <= 0;
            in_valid <= 1'b1;
            K <= 8'd64;
            M <= 8'd64;
            N <= 8'd64;
            process_trigger_once <= 1'b1;
          end else begin
            if (busy == 1'b1) begin
              in_valid <= 1'b0;
              // test <= test + 1;
              next_state <= WAIT_PROCESS;
            end else begin
              rsp_payload_outputs_0 <= 0;
              process_trigger_once <= 1'b0;
              next_state <= CFU_DONE;
            end
          end
        end
        OUTPUT_GBUFF_C: begin
          if (input_value_1[1:0] == 2'd0) begin
            rsp_payload_outputs_0 <= C_data_out[127:96];
          end else if (input_value_1[1:0] == 2'd1) begin
            rsp_payload_outputs_0 <= C_data_out[95:64];
          end else if (input_value_1[1:0] == 2'd2) begin
            rsp_payload_outputs_0 <= C_data_out[63:32];
          end else if (input_value_1[1:0] == 2'd3) begin
            rsp_payload_outputs_0 <= C_data_out[31:0];
          end
          next_state <= CFU_DONE;
        end
        CFU_DONE: begin
          rsp_valid <= 1'b1;
          cfu_A_wr <= 1'b0;
          cfu_B_wr <= 1'b0;
          cfu_C_rd <= 1'b0;
          next_state <= WAIT_INPUT;
        end
      endcase
     end
  end

endmodule
