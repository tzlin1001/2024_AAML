module cfuop_simd (
  input               cmd_valid,
  output              cmd_ready,
  input      [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  output reg          rsp_valid,
  input               rsp_ready,
  output reg signed [31:0]   rsp_payload_outputs_0,
  input               reset,
  input               clk
);

  /******** fixed parameters ********/
  localparam InputOffset = $signed(9'd128);
  localparam output_activation_min = $signed(-32'd128);
  localparam output_activation_max = $signed(32'd127);

  /******** state definition ********/
  reg [3:0] state, next_state;
  reg [3:0] calc_state, next_calc_state;

  parameter INPUT_DATA      = 4'd0;
  parameter CALC            = 4'd1;
  parameter CFU_DONE        = 4'd2;

  parameter ADD_BIAS        = 4'd0;
  parameter WITHOUT_SHIFT   = 4'd1;
  parameter WITHOUT_OFFSET  = 4'd2;
  parameter RAW_OUTPUT      = 4'd3;

  /******** internal register ********/
  reg signed [31:0] bias_data, output_offset;
  reg signed [31:0] output_multiplier, output_shift;
  reg signed [31:0] total_output_shift;
  reg signed [63:0] round_output;

  reg signed [63:0] raw_output_without_shift;
  reg signed [31:0] raw_output_without_offset;
  reg signed [31:0] raw_output;

  reg signed [31:0] total_sum;

  /********** internal wire **********/
  wire signed [31:0] clamped_output_min, clamped_output_max;

  // SIMD multiply step:
  wire signed [15:0] prod_0, prod_1, prod_2, prod_3;
  assign prod_0 =  ($signed(cmd_payload_inputs_0[7 : 0]) + InputOffset)
                  * $signed(cmd_payload_inputs_1[7 : 0]);
  assign prod_1 =  ($signed(cmd_payload_inputs_0[15: 8]) + InputOffset)
                  * $signed(cmd_payload_inputs_1[15: 8]);
  assign prod_2 =  ($signed(cmd_payload_inputs_0[23:16]) + InputOffset)
                  * $signed(cmd_payload_inputs_1[23:16]);
  assign prod_3 =  ($signed(cmd_payload_inputs_0[31:24]) + InputOffset)
                  * $signed(cmd_payload_inputs_1[31:24]);

  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3;

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  assign clamped_output_min = (raw_output > output_activation_min) ? raw_output : output_activation_min;
  assign clamped_output_max = (clamped_output_min < output_activation_max) ? clamped_output_min : output_activation_max;

  always @(posedge clk or posedge reset) begin
     if (reset) begin
      state <= INPUT_DATA;
      next_state <= INPUT_DATA;
      calc_state <= WITHOUT_SHIFT;
      next_calc_state <= WITHOUT_SHIFT;
     end else if (rsp_valid) rsp_valid <= 1'b0;
     else begin
      state = next_state;
      case (state)
        INPUT_DATA: begin
          if (cmd_valid) begin
            if (cmd_payload_function_id[9:3] == 7'd0) begin
              total_sum <= 32'b0;
              rsp_valid <= 1'b1;
            end else if (cmd_payload_function_id[9:3] == 7'd1) begin
              total_sum <= total_sum + sum_prods;
              rsp_payload_outputs_0 <= total_sum + sum_prods;
              rsp_valid <= 1'b1;
            end else if (cmd_payload_function_id[9:3] == 7'd2) begin
              bias_data <= cmd_payload_inputs_0;
              output_offset <= cmd_payload_inputs_1;
              rsp_valid <= 1'b1;
            end else if (cmd_payload_function_id[9:3] == 7'd3) begin
              output_multiplier <= cmd_payload_inputs_0;
              output_shift <= cmd_payload_inputs_1;
              total_output_shift = $signed(32'd31) - $signed(cmd_payload_inputs_1);
              round_output = $signed(64'd1) << ($signed(32'd30) - $signed(cmd_payload_inputs_1));
              next_calc_state <= ADD_BIAS;
              next_state <= CALC;
            end else if (cmd_payload_function_id[9:3] == 7'd4) begin
              total_sum <= cmd_payload_inputs_0;
              rsp_valid <= 1'b1;
            end
          end else begin
            next_state <= INPUT_DATA;
          end
        end
        CALC: begin
          calc_state = next_calc_state;
          case (calc_state)
            ADD_BIAS: begin
              total_sum <= total_sum + bias_data;
              next_calc_state <= WITHOUT_SHIFT;
            end
            WITHOUT_SHIFT: begin
              raw_output_without_shift <= total_sum * output_multiplier + round_output;
              next_calc_state <= WITHOUT_OFFSET;
            end
            WITHOUT_OFFSET: begin
              raw_output_without_offset <= raw_output_without_shift >>> total_output_shift;
              next_calc_state <= RAW_OUTPUT;
            end
            RAW_OUTPUT: begin
              raw_output <= raw_output_without_offset + output_offset;
              next_calc_state <= ADD_BIAS;
              next_state <= CFU_DONE;
            end
          endcase
        end
        CFU_DONE: begin
          rsp_valid <= 1'b1;
          rsp_payload_outputs_0 <= clamped_output_max;
          next_state <= INPUT_DATA;
        end
      endcase
    end
  end
endmodule