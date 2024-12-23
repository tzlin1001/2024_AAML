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
  input               cmd_valid, // input valid
  output              cmd_ready, // comm
  input      [9:0]    cmd_payload_function_id, // mode
  input      [31:0]   cmd_payload_inputs_0, // input data
  input      [31:0]   cmd_payload_inputs_1,
  output reg          rsp_valid, // output valid
  input               rsp_ready, // comm
  output reg [31:0]   rsp_payload_outputs_0, // output data
  input               reset,
  input               clk
);
  
  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  reg [9:0] mode;
  reg [31:0] x;
  reg [7:0] index_base;
  reg [31:0] lut_index[63:0];
  reg [31:0] lut_value[63:0];
  //*********** LUT **************//
  always @(*) begin // Q4.27 // x1, x2
    lut_index[ 0] = 32'hd8000000; // x = -5
    lut_index[ 1] = 32'hdc000000; // x = -4.5
    lut_index[ 2] = 32'he0000000; // x = -4
    lut_index[ 3] = 32'he4000000; // x = -3.5
    lut_index[ 4] = 32'he8000000; // x = -3
    lut_index[ 5] = 32'hea000000; // x = -2.75
    lut_index[ 6] = 32'hec000000; // x = -2.5
    lut_index[ 7] = 32'hee000000; // x = -2.25
    lut_index[ 8] = 32'hf0000000; // x = -2
    lut_index[ 9] = 32'hf30a3d71; // x = -1.62
    lut_index[10] = 32'hf4a3d70a; // x = -1.42
    lut_index[11] = 32'hf63d70a4; // x = -1.22
    lut_index[12] = 32'hf7851ebc; // x = -1.05
    lut_index[13] = 32'hf7d70a3d; // x = -1.02
    lut_index[14] = 32'hf8000000; // x = -1
    lut_index[15] = 32'hf8a3d70a; // x = -0.92

    lut_index[16] = 32'hf8cccccd; // x = -0.9
    lut_index[17] = 32'hf8f5c28f; // x = -0.88
    lut_index[18] = 32'hf9333333; // x = -0.85
    lut_index[19] = 32'hf970a3d7; // x = -0.82
    lut_index[20] = 32'hf999999a; // x = -0.8
    lut_index[21] = 32'hf9c28f5c; // x = -0.78
    lut_index[22] = 32'hfa000000; // x = -0.75
    lut_index[23] = 32'hfa3d70a4; // x = -0.72
    lut_index[24] = 32'hfa666666; // x = -0.7
    lut_index[25] = 32'hfa8f5c29; // x = -0.68
    lut_index[26] = 32'hfacccccd; // x = -0.65
    lut_index[27] = 32'hfb0a3d71; // x = -0.62
    lut_index[28] = 32'hfb333333; // x = -0.6
    lut_index[29] = 32'hfb5c28f6; // x = -0.58
    lut_index[30] = 32'hfb99999a; // x = -0.55
    lut_index[31] = 32'hfbd70a3d; // x = -0.52

    lut_index[32] = 32'hfc000000; // x = -0.5
    lut_index[33] = 32'hfc3d70a4; // x = -0.47
    lut_index[34] = 32'hfc666666; // x = -0.45
    lut_index[35] = 32'hfca3d70a; // x = -0.42
    lut_index[36] = 32'hfccccccd; // x = -0.4
    lut_index[37] = 32'hfd0a3d71; // x = -0.37
    lut_index[38] = 32'hfd333333; // x = -0.35
    lut_index[39] = 32'hfd70a3d7; // x = -0.32
    lut_index[40] = 32'hfd99999a; // x = -0.3
    lut_index[41] = 32'hfdd70a3d; // x = -0.27
    lut_index[42] = 32'hfe000000; // x = -0.25
    lut_index[43] = 32'hfe3d70a4; // x = -0.22
    lut_index[44] = 32'hfe666666; // x = -0.2
    lut_index[45] = 32'hfe851eb8; // x = -0.185
    lut_index[46] = 32'hfeae147b; // x = -0.165
    lut_index[47] = 32'hfecccccd; // x = -0.15

    lut_index[48] = 32'hff333333; // x = -0.1
    lut_index[49] = 32'hff51eb85; // x = -0.085
    lut_index[50] = 32'hff70a3d7; // x = -0.07
    lut_index[51] = 32'hff99999a; // x = -0.05
    lut_index[52] = 32'hffae147b; // x = -0.04
    lut_index[53] = 32'hffc28f5c; // x = -0.03
    lut_index[54] = 32'hffd70a3d; // x = -0.02
    lut_index[55] = 32'hffdd2f1b; // x = -0.017
    lut_index[56] = 32'hffe147ae; // x = -0.015
    lut_index[57] = 32'hffe56042; // x = -0.013
    lut_index[58] = 32'hffeb851f; // x = -0.01
    lut_index[59] = 32'hffed9168; // x = -0.009
    lut_index[60] = 32'hfff1a9fc; // x = -0.007
    lut_index[61] = 32'hfff5c28f; // x = -0.005
    lut_index[62] = 32'hfff9db23; // x = -0.003
    lut_index[63] = 32'hffffffff; // x = 0
  end

  always @(*) begin // Q0.31 // X1, X2
    lut_value[ 0] = 32'h00dcc9ff; // x = -5
    lut_value[ 1] = 32'h016c0504; // x = -4.5
    lut_value[ 2] = 32'h02582ab7; // x = -4
    lut_value[ 3] = 32'h03dd8203; // x = -3.5
    lut_value[ 4] = 32'h065f6c33; // x = -3
    lut_value[ 5] = 32'h082ec9c5; // x = -2.75
    lut_value[ 6] = 32'h0a81c2e0; // x = -2.5
    lut_value[ 7] = 32'h0d7db8c7; // x = -2.25
    lut_value[ 8] = 32'h1152aaa4; // x = -2
    lut_value[ 9] = 32'h1954be9c; // x = -1.62
    lut_value[10] = 32'h1ef07c23; // x = -1.42
    lut_value[11] = 32'h25ca1a24; // x = -1.22
    lut_value[12] = 32'h2ccac29a; // x = -1.05
    lut_value[13] = 32'h2e27f99a; // x = -1.02
    lut_value[14] = 32'h2f16ac6c; // x = -1
    lut_value[15] = 32'h3302ac04; // x = -0.92

    lut_value[16] = 32'h340a7980; // x = -0.9
    lut_value[17] = 32'h35179b40; // x = -0.88
    lut_value[18] = 32'h36b58851; // x = -0.85
    lut_value[19] = 32'h38601080; // x = -0.82
    lut_value[20] = 32'h39839c8b; // x = -0.8
    lut_value[21] = 32'h3aad0c55; // x = -0.78
    lut_value[22] = 32'h3c7681d8; // x = -0.75
    lut_value[23] = 32'h3e4de5de; // x = -0.72
    lut_value[24] = 32'h3f901b74; // x = -0.7
    lut_value[25] = 32'h40d8d35b; // x = -0.68
    lut_value[26] = 32'h42d26561; // x = -0.65
    lut_value[27] = 32'h44db5d03; // x = -0.62
    lut_value[28] = 32'h463f75ae; // x = -0.6
    lut_value[29] = 32'h47aabfeb; // x = -0.58
    lut_value[30] = 32'h49d97dcc; // x = -0.55
    lut_value[31] = 32'h4c193fd3; // x = -0.52

    lut_value[32] = 32'h4da2cbf2; // x = -0.5
    lut_value[33] = 32'h50001307; // x = -0.47
    lut_value[34] = 32'h519dcc9d; // x = -0.45
    lut_value[35] = 32'h541a1c36; // x = -0.42
    lut_value[36] = 32'h55cd0c1a; // x = -0.4
    lut_value[37] = 32'h5869fb88; // x = -0.37
    lut_value[38] = 32'h5a333826; // x = -0.35
    lut_value[39] = 32'h5cf2739f; // x = -0.32
    lut_value[40] = 32'h5ed321a7; // x = -0.3
    lut_value[41] = 32'h61b66b55; // x = -0.27
    lut_value[42] = 32'h63afbe7b; // x = -0.25
    lut_value[43] = 32'h66b8ef9c; // x = -0.22
    lut_value[44] = 32'h68cc2b58; // x = -0.2
    lut_value[45] = 32'h6a61a00b; // x = -0.185
    lut_value[46] = 32'h6c87c7e9; // x = -0.165
    lut_value[47] = 32'h6e2badd1; // x = -0.15

    lut_value[48] = 32'h73d1b667; // x = -0.1
    lut_value[49] = 32'h7591cf7f; // x = -0.085
    lut_value[50] = 32'h7758ae42; // x = -0.07
    lut_value[51] = 32'h79c1e2c3; // x = -0.05
    lut_value[52] = 32'h7afb25fa; // x = -0.04
    lut_value[53] = 32'h7c378f2b; // x = -0.03
    lut_value[54] = 32'h7d77266f; // x = -0.02
    lut_value[55] = 32'h7dd7a6fa; // x = -0.017
    lut_value[56] = 32'h7e1825e6; // x = -0.015
    lut_value[57] = 32'h7e58c5df; // x = -0.013
    lut_value[58] = 32'h7eb9f3f5; // x = -0.01
    lut_value[59] = 32'h7eda6940; // x = -0.009
    lut_value[60] = 32'h7f1b6cc9; // x = -0.007
    lut_value[61] = 32'h7f5c91a5; // x = -0.005
    lut_value[62] = 32'h7f9dd7e3; // x = -0.003
    lut_value[63] = 32'h00000000; // x = 0
  end
  //************ in_valid delay 1 T **************//
  reg flag;
  always@(posedge clk)begin
    if(reset)
      flag <= 0;
    else if(cmd_valid)
      flag <= cmd_valid;
    else
      flag <= 0;
  end
  //*********** output ******************//
  always @(posedge clk) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
    end 
    else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end 
    else if (flag) begin
      rsp_valid <= 1'b1;
      // Accumulate step:
      if (index_base == 8'd63) begin
        rsp_payload_outputs_0 <= |mode[9:3]
          ? 32'b0
          : 32'h00000000;
      end
      else begin
      rsp_payload_outputs_0 <= |mode[9:3]
          ? 32'b0
          : lut_value[index_base] + ((lut_value[index_base + 1] - lut_value[index_base]) * (x - lut_index[index_base]) / (lut_index[index_base + 1] - lut_index[index_base]));
      end
    end
  end
  //*********** input reg ******************//
  always@(posedge clk) begin
    if(reset)
      mode <= 0;
    else if(cmd_valid)
      mode <= cmd_payload_function_id;
  end
  always@(posedge clk) begin
    if(reset)
      x <= 0;
    else if(cmd_valid)
      x <= cmd_payload_inputs_0;
  end
  //*********** compare index ******************//
  always@(posedge clk)begin
    if (cmd_valid) begin
      if (cmd_payload_inputs_0 >= lut_index[48]) begin //48-63
             if(cmd_payload_inputs_0 >= lut_index[63]) index_base <= 8'd63;
        else if(cmd_payload_inputs_0 >= lut_index[62]) index_base <= 8'd62;
        else if(cmd_payload_inputs_0 >= lut_index[61]) index_base <= 8'd61;
        else if(cmd_payload_inputs_0 >= lut_index[60]) index_base <= 8'd60;
        else if(cmd_payload_inputs_0 >= lut_index[59]) index_base <= 8'd59;
        else if(cmd_payload_inputs_0 >= lut_index[58]) index_base <= 8'd58;
        else if(cmd_payload_inputs_0 >= lut_index[57]) index_base <= 8'd57;
        else if(cmd_payload_inputs_0 >= lut_index[56]) index_base <= 8'd56;
        else if(cmd_payload_inputs_0 >= lut_index[55]) index_base <= 8'd55;
        else if(cmd_payload_inputs_0 >= lut_index[54]) index_base <= 8'd54;
        else if(cmd_payload_inputs_0 >= lut_index[53]) index_base <= 8'd53;
        else if(cmd_payload_inputs_0 >= lut_index[52]) index_base <= 8'd52;
        else if(cmd_payload_inputs_0 >= lut_index[51]) index_base <= 8'd51;
        else if(cmd_payload_inputs_0 >= lut_index[50]) index_base <= 8'd50;
        else if(cmd_payload_inputs_0 >= lut_index[49]) index_base <= 8'd49;
        else index_base <= 8'd48;
      end
      else if (cmd_payload_inputs_0 >= lut_index[32]) begin //32-47
             if(cmd_payload_inputs_0 >= lut_index[47]) index_base <= 8'd47;
        else if(cmd_payload_inputs_0 >= lut_index[46]) index_base <= 8'd46;
        else if(cmd_payload_inputs_0 >= lut_index[45]) index_base <= 8'd45;
        else if(cmd_payload_inputs_0 >= lut_index[44]) index_base <= 8'd44;
        else if(cmd_payload_inputs_0 >= lut_index[43]) index_base <= 8'd43;
        else if(cmd_payload_inputs_0 >= lut_index[42]) index_base <= 8'd42;
        else if(cmd_payload_inputs_0 >= lut_index[41]) index_base <= 8'd41;
        else if(cmd_payload_inputs_0 >= lut_index[40]) index_base <= 8'd40;
        else if(cmd_payload_inputs_0 >= lut_index[39]) index_base <= 8'd39;
        else if(cmd_payload_inputs_0 >= lut_index[38]) index_base <= 8'd38;
        else if(cmd_payload_inputs_0 >= lut_index[37]) index_base <= 8'd37;
        else if(cmd_payload_inputs_0 >= lut_index[36]) index_base <= 8'd36;
        else if(cmd_payload_inputs_0 >= lut_index[35]) index_base <= 8'd35;
        else if(cmd_payload_inputs_0 >= lut_index[34]) index_base <= 8'd34;
        else if(cmd_payload_inputs_0 >= lut_index[33]) index_base <= 8'd33;
        else index_base <= 8'd32;      
      end
      else if (cmd_payload_inputs_0 >= lut_index[16]) begin //16-31
             if(cmd_payload_inputs_0 >= lut_index[31]) index_base <= 8'd31;
        else if(cmd_payload_inputs_0 >= lut_index[30]) index_base <= 8'd30;
        else if(cmd_payload_inputs_0 >= lut_index[29]) index_base <= 8'd29;
        else if(cmd_payload_inputs_0 >= lut_index[28]) index_base <= 8'd28;
        else if(cmd_payload_inputs_0 >= lut_index[27]) index_base <= 8'd27;
        else if(cmd_payload_inputs_0 >= lut_index[26]) index_base <= 8'd26;
        else if(cmd_payload_inputs_0 >= lut_index[25]) index_base <= 8'd25;
        else if(cmd_payload_inputs_0 >= lut_index[24]) index_base <= 8'd24;
        else if(cmd_payload_inputs_0 >= lut_index[23]) index_base <= 8'd23;
        else if(cmd_payload_inputs_0 >= lut_index[22]) index_base <= 8'd22;
        else if(cmd_payload_inputs_0 >= lut_index[21]) index_base <= 8'd21;
        else if(cmd_payload_inputs_0 >= lut_index[20]) index_base <= 8'd20;
        else if(cmd_payload_inputs_0 >= lut_index[19]) index_base <= 8'd19;
        else if(cmd_payload_inputs_0 >= lut_index[18]) index_base <= 8'd18;
        else if(cmd_payload_inputs_0 >= lut_index[17]) index_base <= 8'd17;
        else index_base <= 8'd16;
      end
      else begin //0-15
             if(cmd_payload_inputs_0 >= lut_index[15]) index_base <= 8'd15;
        else if(cmd_payload_inputs_0 >= lut_index[14]) index_base <= 8'd14;
        else if(cmd_payload_inputs_0 >= lut_index[13]) index_base <= 8'd13;
        else if(cmd_payload_inputs_0 >= lut_index[12]) index_base <= 8'd12;
        else if(cmd_payload_inputs_0 >= lut_index[11]) index_base <= 8'd11;
        else if(cmd_payload_inputs_0 >= lut_index[10]) index_base <= 8'd10;
        else if(cmd_payload_inputs_0 >= lut_index[ 9]) index_base <= 8'd9;
        else if(cmd_payload_inputs_0 >= lut_index[ 8]) index_base <= 8'd8;
        else if(cmd_payload_inputs_0 >= lut_index[ 7]) index_base <= 8'd7;
        else if(cmd_payload_inputs_0 >= lut_index[ 6]) index_base <= 8'd6;
        else if(cmd_payload_inputs_0 >= lut_index[ 5]) index_base <= 8'd5;
        else if(cmd_payload_inputs_0 >= lut_index[ 4]) index_base <= 8'd4;
        else if(cmd_payload_inputs_0 >= lut_index[ 3]) index_base <= 8'd3;
        else if(cmd_payload_inputs_0 >= lut_index[ 2]) index_base <= 8'd2;
        else if(cmd_payload_inputs_0 >= lut_index[ 1]) index_base <= 8'd1;
        else index_base <= 8'd0;
      end
    end
  end

endmodule
