`include "proc_element.v"

module systolic_array #(
    parameter ArraySize = 4,
    parameter DataWidth = 8,
    parameter AccWidth = 32,
    parameter UseSigned = 0
) (
    input  clk,
    input  rst_n,
    // Control
    output busy,
    input  start,
    input  [ArraySize-2:0] row_en,
    input  in_valid,
    input  in_last,
    output out_valid,
    output out_last,
    // Data
    input      [DataWidth:0]           offset,
    input      [ArraySize*DataWidth-1:0] weight_row,
    input      [ArraySize*DataWidth-1:0] input_col,
    output reg [ArraySize*AccWidth-1:0]  output_row
);
// 4x4 for example:
// | d00 | d01 | d02 | d03 | d04 | d05 | d06 |
// | --- | --- | --- | --- | --- | --- | --- |
// | a00 | a01 | a02 | a03 |  0  |  0  |  0  |
// |  0  | a10 | a11 | a12 | a13 |  0  |  0  | 
// |  0  |  0  | a20 | a21 | a22 | a23 |  0  |
// |  0  |  0  |  0  | a30 | a31 | a32 | a33 |
//
// clk       | _/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\
// start     | _____/---\_______________________________/-----------\___________________________/---------------\
// busy      | _________/---------------------------------------\___/---------------------------------------\___/
// data      |  | x | x |d00|d01|d02|d03|d04|d05|d06| x | x | x | x |d00|d01|d02|d03|d04|d05|d06| x | x | x | x |
// sa        |  | x | x | 0 |acc|acc|acc|acc|acc|acc|acc|acc|acc|ans| 0 |acc|acc|acc|acc|acc|acc|acc|acc|acc|ans|
// in_valid  | _________/---------------\___________________________/---------------\____________________________
// last      | _____________________/---\_______________________________________/---\____________________________
// d_last    | _________________________________/---\_______________________________________/---\________________
// claer     | _____/---\_______________________________________/---\____________________________________________
// done      | _________________________________________________/---\_______________________________________/---\
// out_valid | _________________________________________________/---------------\___________________________/----

// ==========
//  WIRE & REG
// ==========
reg cur_state, nxt_state;
reg  [DataWidth-1:0] in_weight[0:ArraySize-1];
reg  [DataWidth-1:0] in_input[0:ArraySize-1];
wire [DataWidth-1:0] sa_yin[0:ArraySize-1];
wire [DataWidth-1:0] sa_xin[0:ArraySize-1];
reg  [ArraySize*AccWidth-1:0] obuffer[0:ArraySize-2];
wire [ArraySize*AccWidth-1:0] sa_out_row[0:ArraySize-1];
reg  [ArraySize-2:0] obuf_valid;
wire clear;
reg [ArraySize-2:0] row_valid;
wire done;

// ==========
//  PARAMS
// ==========
localparam S_IDLE = 'd0;
localparam S_RUN = 'd1;
integer idx;

// ==========
//  DESIGN
// ==========
// FSM
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) cur_state <= S_IDLE;
    else cur_state <= nxt_state;
end
always @(*) begin
    case (cur_state)
        S_IDLE: nxt_state = start ? S_RUN : S_IDLE;
        S_RUN:  nxt_state = done ? S_IDLE : S_RUN;
        default: nxt_state = cur_state;
    endcase
end
assign busy = cur_state == S_RUN;

// Input data
always @(*) begin
    for (idx = 0; idx < ArraySize; idx = idx + 1) begin
        in_weight[idx] = in_valid ? weight_row[(ArraySize-idx)*DataWidth-1 -: DataWidth] : 'd0;
        in_input[idx] = in_valid ? input_col[(ArraySize-idx)*DataWidth-1 -: DataWidth] : 'd0;
    end
end
generate
    genvar tdx;
    for (tdx = 0; tdx < ArraySize; tdx = tdx + 1) begin : monitor
        wire [DataWidth-1:0] m_weight, m_input;
        assign m_weight = in_weight[tdx];
        assign m_input = in_input[tdx];
    end
endgenerate

assign sa_xin[0] = in_input[0];
assign sa_yin[0] = in_weight[0];

// Input preprocessing
generate
    genvar m, k;
    for (m = 1; m < ArraySize; m = m + 1) begin : input_delay
        for (k = 0; k < m; k = k + 1) begin : delay_num
            reg [DataWidth-1:0] delay_xin, delay_yin;
            if (k == 0) begin
                always @(posedge clk or negedge rst_n) begin
                    if (~rst_n) begin
                        delay_xin <= 'd0;
                        delay_yin <= 'd0;
                    end else begin
                        delay_xin <= in_input[m];
                        delay_yin <= in_weight[m];
                    end
                end
            end else begin
                always @(posedge clk or negedge rst_n) begin
                    if (~rst_n) begin
                        delay_xin <= 'd0;
                        delay_yin <= 'd0;
                    end else begin
                        delay_xin <= input_delay[m].delay_num[k-1].delay_xin;
                        delay_yin <= input_delay[m].delay_num[k-1].delay_yin;
                    end
                end
            end

            if (k == m - 1) assign {sa_xin[m], sa_yin[m]} = {delay_xin, delay_yin};
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        row_valid <= 'd0;
    end else begin
        if (start & ~busy) row_valid <= row_en;
    end
end

// Last flag
generate
    genvar n;
    for (n = 0; n < 2*ArraySize-1; n = n + 1) begin : last_flag
        reg f;
        if (n == 0) begin
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) f <= 1'b0;
                else f <= in_last;
            end
        end else begin
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) f <= 1'b0;
                else f <= last_flag[n-1].f;
            end
        end
        if (n == 2*ArraySize - 2) assign done = f;
    end
endgenerate

// Clear
assign clear = start & ~busy;

// Output buffer
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        for (idx = 0; idx < ArraySize - 1; idx = idx + 1) begin
            obuffer[idx] <= 'd0;
            obuf_valid[idx] <= 1'b0;
        end
    end else begin
        if (done) begin
            for (idx = 0; idx < ArraySize - 1; idx = idx + 1) begin
                obuffer[idx] <= sa_out_row[idx+1];
                obuf_valid[idx] <= row_valid[idx];
            end
        end else begin
            for (idx = 0; idx < ArraySize - 2; idx = idx + 1) begin
                obuffer[idx] <= obuffer[idx+1];
                obuf_valid[idx] <= obuf_valid[idx+1];
            end
            obuffer[ArraySize-2] <= 'd0;
            obuf_valid[ArraySize-2] <= 1'b0;
        end
    end
end
assign out_valid = done | obuf_valid[0];
// assign out_last = (done & ~obuf_valid[0]) | (obuf_valid[0] & ~obuf_valid[1]);
assign out_last = out_valid & (~|row_valid | (obuf_valid[0] & ~obuf_valid[1]));

// Output
always @(*) begin
    if (done) output_row = sa_out_row[0];
    else output_row = obuffer[0];
end

// PE array
generate
    genvar i, j;
    for (i = 0; i < ArraySize; i = i + 1) begin : idx_x
        for (j = 0; j < ArraySize; j = j + 1) begin : idx_y
            wire [DataWidth:0] in_x, in_y, out_x, out_y;
            wire [AccWidth-1:0] value;

            if (i == 0) begin
                assign in_y = $signed(sa_yin[j]);
            end else begin
                assign in_y = idx_x[i-1].idx_y[j].out_y;
            end

            if (j == 0) begin
                assign in_x = {sa_xin[i][DataWidth-1], sa_xin[i]} + offset;
            end else begin
                assign in_x = idx_x[i].idx_y[j-1].out_x;
            end

            assign sa_out_row[i][(ArraySize-j)*AccWidth-1 -: AccWidth] = value;

            proc_element #(
                .DataWidth(DataWidth+1),
                .AccWidth (AccWidth),
                .UseSigned(UseSigned)
            ) u_pe (
                .clk   (clk),
                .rst_n (rst_n),
                .clear (clear),
                .in_x  (in_x),
                .in_y  (in_y),
                .out_x (out_x),
                .out_y (out_y),
                .value (value)
            );
        end
    end
endgenerate
    
endmodule