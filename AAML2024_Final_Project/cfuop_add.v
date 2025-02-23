module cfuop_add (
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

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;
  
  /******** fixed parameters ********/
  localparam left_shift               = $signed(22'd1048576); // 1 << 20 = 2 ^ 20 = 1048576
  localparam round_input1             = $signed(64'd1) << 32; // input1_shift: -2
  localparam input2_multiplier        = $signed(32'd1073741824);
  localparam round_input2             = $signed(64'd1) << 30; // input2_shift: 0
  localparam output_offset            = $signed(-8'd128);
  localparam quantized_activation_min = $signed(-32'd128);
  localparam quantized_activation_max = $signed(32'd127);

  /******** state definition ********/
  reg [3:0] state, next_state;
  reg [3:0] calc_state, next_calc_state;

  parameter IDLE            = 4'd0;
  parameter CALC            = 4'd1;
  parameter CFU_DONE        = 4'd2;

  parameter SCALED          = 4'd0;
  parameter RAW_SUM         = 4'd1;
  parameter WITHOUT_SHIFT   = 4'd2;
  parameter WITHOUT_OFFSET  = 4'd3;
  parameter RAW_OUTPUT      = 4'd4;

  /******* internal register ********/
  reg [31:0] x_val, y_val;
  reg signed [15:0] input1_offset, input2_offset, output_shift;
  reg signed [31:0] input1_multiplier;
  reg signed [31:0] output_multiplier;

  reg signed [31:0] total_output_shift;
  reg signed [63:0] round_output;

  reg signed [31:0] shifted_input1_val_0;
  reg signed [31:0] shifted_input1_val_1;
  reg signed [31:0] shifted_input1_val_2;
  reg signed [31:0] shifted_input1_val_3;
  reg signed [31:0] shifted_input2_val_0;
  reg signed [31:0] shifted_input2_val_1;
  reg signed [31:0] shifted_input2_val_2;
  reg signed [31:0] shifted_input2_val_3;

  reg signed [31:0] raw_sum_0;
  reg signed [31:0] raw_sum_1;
  reg signed [31:0] raw_sum_2;
  reg signed [31:0] raw_sum_3;

  reg signed [63:0] raw_output_0_without_shift;
  reg signed [63:0] raw_output_1_without_shift;
  reg signed [63:0] raw_output_2_without_shift;
  reg signed [63:0] raw_output_3_without_shift;

  reg signed [31:0] raw_output_0_without_offset;
  reg signed [31:0] raw_output_1_without_offset;
  reg signed [31:0] raw_output_2_without_offset;
  reg signed [31:0] raw_output_3_without_offset;

  reg signed [31:0] raw_output_0;
  reg signed [31:0] raw_output_1;
  reg signed [31:0] raw_output_2;
  reg signed [31:0] raw_output_3;

  /********* internal wire **********/
  wire signed [31:0] clamped_output_0_min;
  wire signed [31:0] clamped_output_1_min;
  wire signed [31:0] clamped_output_2_min;
  wire signed [31:0] clamped_output_3_min;

  wire signed [31:0] clamped_output_0;
  wire signed [31:0] clamped_output_1;
  wire signed [31:0] clamped_output_2;
  wire signed [31:0] clamped_output_3;

  assign clamped_output_0_min = (raw_output_0 > quantized_activation_min) ? raw_output_0 : quantized_activation_min;
  assign clamped_output_1_min = (raw_output_1 > quantized_activation_min) ? raw_output_1 : quantized_activation_min;
  assign clamped_output_2_min = (raw_output_2 > quantized_activation_min) ? raw_output_2 : quantized_activation_min;
  assign clamped_output_3_min = (raw_output_3 > quantized_activation_min) ? raw_output_3 : quantized_activation_min;
  assign clamped_output_0 = (clamped_output_0_min < quantized_activation_max) ? clamped_output_0_min : quantized_activation_max;
  assign clamped_output_1 = (clamped_output_1_min < quantized_activation_max) ? clamped_output_1_min : quantized_activation_max;
  assign clamped_output_2 = (clamped_output_2_min < quantized_activation_max) ? clamped_output_2_min : quantized_activation_max;
  assign clamped_output_3 = (clamped_output_3_min < quantized_activation_max) ? clamped_output_3_min : quantized_activation_max;

  always @(posedge clk or posedge reset) begin
     if (reset) begin
      state <= IDLE;
      next_state <= IDLE;
      calc_state <= SCALED;
      next_calc_state <= SCALED;
     end else if (rsp_valid) rsp_valid <= 1'b0;
     else begin
      state = next_state;
      case (state)
        IDLE: begin
          if (cmd_valid) begin
            if (cmd_payload_function_id[9:3] == 7'd0) begin
              input1_offset <= $signed(cmd_payload_inputs_0[31:16]);
              input2_offset <= $signed(cmd_payload_inputs_0[15:0]);
              output_shift <= $signed(cmd_payload_inputs_1[15:0]);
              total_output_shift = $signed(32'd31) - $signed(cmd_payload_inputs_1);
              round_output = $signed(64'd1) << ($signed(32'd30) - $signed(cmd_payload_inputs_1));
              rsp_valid <= 1'b1;
            end
            else if(cmd_payload_function_id[9:3] == 7'd1) begin
              input1_multiplier <= cmd_payload_inputs_0;
              output_multiplier <= cmd_payload_inputs_1;
              rsp_valid <= 1'b1;
            end
            else if(cmd_payload_function_id[9:3] == 7'd2) begin
              x_val <= cmd_payload_inputs_0;
              y_val <= cmd_payload_inputs_1;
              next_state <= CALC;
            end
          end else begin
            next_state <= IDLE;
          end
        end
        CALC: begin
          calc_state = next_calc_state;
          case (calc_state)
            SCALED: begin
              shifted_input1_val_0 <= ($signed(x_val[7 : 0]) + input1_offset) * left_shift;
              shifted_input1_val_1 <= ($signed(x_val[15: 8]) + input1_offset) * left_shift;
              shifted_input1_val_2 <= ($signed(x_val[23:16]) + input1_offset) * left_shift;
              shifted_input1_val_3 <= ($signed(x_val[31:24]) + input1_offset) * left_shift;

              shifted_input2_val_0 <= ($signed(y_val[7 : 0]) + input2_offset) * left_shift;
              shifted_input2_val_1 <= ($signed(y_val[15: 8]) + input2_offset) * left_shift;
              shifted_input2_val_2 <= ($signed(y_val[23:16]) + input2_offset) * left_shift;
              shifted_input2_val_3 <= ($signed(y_val[31:24]) + input2_offset) * left_shift; 
              next_calc_state <= RAW_SUM;
            end
            RAW_SUM: begin
              raw_sum_0 <= ((shifted_input1_val_0 * input1_multiplier + round_input1) >>> 33) + 
                           ((shifted_input2_val_0 * input2_multiplier + round_input2) >>> 31);
              raw_sum_1 <= ((shifted_input1_val_1 * input1_multiplier + round_input1) >>> 33) + 
                           ((shifted_input2_val_1 * input2_multiplier + round_input2) >>> 31);
              raw_sum_2 <= ((shifted_input1_val_2 * input1_multiplier + round_input1) >>> 33) + 
                           ((shifted_input2_val_2 * input2_multiplier + round_input2) >>> 31);
              raw_sum_3 <= ((shifted_input1_val_3 * input1_multiplier + round_input1) >>> 33) + 
                           ((shifted_input2_val_3 * input2_multiplier + round_input2) >>> 31);
              next_calc_state <= WITHOUT_SHIFT;
            end
            WITHOUT_SHIFT: begin
              raw_output_0_without_shift <= raw_sum_0 * output_multiplier + round_output;
              raw_output_1_without_shift <= raw_sum_1 * output_multiplier + round_output;
              raw_output_2_without_shift <= raw_sum_2 * output_multiplier + round_output;
              raw_output_3_without_shift <= raw_sum_3 * output_multiplier + round_output;
              next_calc_state <= WITHOUT_OFFSET;
            end
            WITHOUT_OFFSET: begin
              raw_output_0_without_offset <= raw_output_0_without_shift >>> total_output_shift;
              raw_output_1_without_offset <= raw_output_1_without_shift >>> total_output_shift;
              raw_output_2_without_offset <= raw_output_2_without_shift >>> total_output_shift;
              raw_output_3_without_offset <= raw_output_3_without_shift >>> total_output_shift;
              next_calc_state <= RAW_OUTPUT;
            end
            RAW_OUTPUT: begin
              raw_output_0 <= raw_output_0_without_offset + output_offset;
              raw_output_1 <= raw_output_1_without_offset + output_offset;
              raw_output_2 <= raw_output_2_without_offset + output_offset;
              raw_output_3 <= raw_output_3_without_offset + output_offset;
              next_calc_state <= SCALED;
              next_state <= CFU_DONE;
            end
          endcase
        end
        CFU_DONE: begin
          rsp_valid <= 1'b1;
          rsp_payload_outputs_0 <= {clamped_output_3[7:0], clamped_output_2[7:0], clamped_output_1[7:0], clamped_output_0[7:0]};
          next_state <= IDLE;
        end
      endcase
    end
  end
endmodule