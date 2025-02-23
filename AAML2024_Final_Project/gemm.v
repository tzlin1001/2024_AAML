`include "systolic_array.v"
`include "controller.v"

module gemm(
    clk,
    rst_n,

    in_valid,
    K,
    M,
    N,
    offset,
    busy,
    complete,

    A_wr_en,
    A_index,
    A_data_in,
    A_data_out,

    B_wr_en,
    B_index,
    B_data_in,
    B_data_out,

    C_wr_en,
    C_index,
    C_data_in,
    C_data_out
);
input clk;
input rst_n;
input            in_valid;
input [7:0]      K;
input [7:0]      M;
input [7:0]      N;
input [8:0]      offset;
output           busy;
output           complete;

output           A_wr_en;
output [15:0]    A_index;
output [31:0]    A_data_in;
input  [31:0]    A_data_out;

output           B_wr_en;
output [15:0]    B_index;
output [31:0]    B_data_in;
input  [31:0]    B_data_out;

output           C_wr_en;
output [15:0]    C_index;
output [127:0]   C_data_in;
input  [127:0]   C_data_out;

//* Implement your design here

// Interconnect
wire [2:0] w_sa_row_en;
wire [31:0] w_sa_input, w_sa_weight;
wire w_sa_busy, w_sa_start;
wire w_sa_i_last, w_sa_i_valid;
wire w_sa_o_last, w_sa_o_valid;

controller u_ctrl (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_valid   (in_valid),
    .K          (K),
    .M          (M),
    .N          (N),
    .busy       (busy),
    .complete   (complete),
    // Memory Control Signal
    .a_wr_en    (A_wr_en),
    .a_addr     (A_index),
    .a_data     (A_data_out),
    .b_wr_en    (B_wr_en),
    .b_addr     (B_index),
    .b_data     (B_data_out),
    .c_wr_en    (C_wr_en),
    .c_addr     (C_index),
    // Systolic Array Control Signal
    .sa_busy   (w_sa_busy),
    .sa_start  (w_sa_start),
    .sa_row_en (w_sa_row_en),
    .sa_o_last (w_sa_o_last),
    .sa_o_valid(w_sa_o_valid),
    .sa_i_last (w_sa_i_last),
    .sa_i_vaild(w_sa_i_valid),
    .sa_input  (w_sa_input),
    .sa_weight (w_sa_weight)
);

systolic_array #(
    .ArraySize(4),
    .DataWidth(8),
    .AccWidth (32),
    .UseSigned(1)
) u_sa (
    .clk       (clk),
    .rst_n     (rst_n),
    .busy      (w_sa_busy),
    .start     (w_sa_start),
    .row_en    (w_sa_row_en),
    .in_valid  (w_sa_i_valid),
    .in_last   (w_sa_i_last),
    .weight_row(w_sa_weight),
    .input_col (w_sa_input),
    .out_valid (w_sa_o_valid),
    .out_last  (w_sa_o_last),
    .output_row(C_data_in),
    .offset    (offset)
);

endmodule