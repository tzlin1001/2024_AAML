`include "gemm.v"
`include "global_buffer_bram.v"

`define INDEX_CONGIG 2'b00
`define INDEX_BUFF_A 2'b01
`define INDEX_BUFF_B 2'b10
`define INDEX_BUFF_C 2'b11

`define OFFSET_CONFIG_K 0
`define OFFSET_CONFIG_M 1
`define OFFSET_CONFIG_N 2
`define OFFSET_CONFIG_O 3

`define CMD_WRITE_CONFIG 7'b100_0000
`define CMD_READ_CONFIG  7'b000_0000
`define CMD_WRITE_BUFF_A 7'b101_0000
`define CMD_READ_BUFF_A  7'b001_0000
`define CMD_WRITE_BUFF_B 7'b110_0000
`define CMD_READ_BUFF_B  7'b010_0000
`define CMD_WRITE_BUFF_C 7'b111_0000
`define CMD_READ_BUFF_C  7'b011_0000
`define CMD_COMPUTE      7'b000_0001

/*
 * gemm_wrapper
 *
 * Wrapper cfu interface and buffer with gemm unit.
 *
 */
module cfuop_sa #(
    parameter ADDR_BITS = 10
) (
    input               cmd_valid,
    output reg          cmd_ready,
    input      [9:0]    cmd_payload_function_id,
    input      [31:0]   cmd_payload_inputs_0,
    input      [31:0]   cmd_payload_inputs_1,
    output reg          rsp_valid,
    input               rsp_ready,
    output reg [31:0]   rsp_payload_outputs_0,
    input               reset,
    input               clk
);
// --------------------
// Params
// --------------------
localparam CHANNEL_WIDTH = 32;

// --------------------
// Wire & Reg
// --------------------
wire rst_n;
// control
wire cmd_data, cmd_write, cmd_read, cmd_comp;
wire cmd_config, cmd_buff_a, cmd_buff_b, cmd_buff_c;
wire cmd_a_we, cmd_b_we, cmd_c_we;
wire [6:0] cmd_payload_function7;
// configure
reg [7:0] k_reg, m_reg, n_reg;
reg [8:0] input_offset_reg;
// buffer
wire buff_sel;
wire buff_a_we, buff_b_we, buff_c_we;
wire [ADDR_BITS-1:0] buff_a_addr, buff_b_addr, buff_c_addr;
wire [CHANNEL_WIDTH-1:0] buff_a_din, buff_b_din, buff_a_dout, buff_b_dout;
wire [4*CHANNEL_WIDTH-1:0] buff_c_din, buff_c_dout;
// gemm unit
wire gemm_in_valid, gemm_busy, gemm_complete;
wire gemm_a_we, gemm_b_we, gemm_c_we;
wire [7:0] gemm_k, gemm_m, gemm_n;
wire [8:0] gemm_offset;
wire [ADDR_BITS-1:0] gemm_a_addr, gemm_b_addr, gemm_c_addr;
wire [4*CHANNEL_WIDTH-1:0] gemm_c_data;

// --------------------
// Control Signal
// --------------------
assign rst_n = ~reset;
// command
assign cmd_payload_function7 = cmd_payload_function_id[9:3];
assign cmd_data = ~cmd_payload_function7[0];
assign cmd_comp = cmd_payload_function7[0];
assign cmd_write = cmd_data & cmd_payload_function7[6];
assign cmd_read = cmd_data & ~cmd_payload_function7[6];
assign cmd_config = cmd_payload_function7[5:4] == `INDEX_CONGIG;
assign cmd_buff_a = cmd_payload_function7[5:4] == `INDEX_BUFF_A;
assign cmd_buff_b = cmd_payload_function7[5:4] == `INDEX_BUFF_B;
assign cmd_buff_c = cmd_payload_function7[5:4] == `INDEX_BUFF_C;

// buffer
assign cmd_a_we = cmd_valid & cmd_buff_a & cmd_write;
assign cmd_b_we = cmd_valid & cmd_buff_b & cmd_write;
assign cmd_c_we = cmd_valid & cmd_buff_c & cmd_write;
assign buff_sel = cmd_comp | gemm_busy;

// gemm unit
assign gemm_in_valid = cmd_valid & cmd_comp;
assign gemm_k = k_reg;
assign gemm_m = m_reg;
assign gemm_n = n_reg;
assign gemm_offset = input_offset_reg;

// --------------------
// Configure
// --------------------
always @(posedge clk or posedge reset) begin
    if (reset) begin
        k_reg <= 'd0;
        m_reg <= 'd0;
        n_reg <= 'd0;
        input_offset_reg <= 'd0;
    end else begin
        if (cmd_valid & cmd_write & cmd_config) begin
            case (cmd_payload_inputs_1[1:0])
                `OFFSET_CONFIG_K: k_reg <= cmd_payload_inputs_0;
                `OFFSET_CONFIG_M: m_reg <= cmd_payload_inputs_0;
                `OFFSET_CONFIG_N: n_reg <= cmd_payload_inputs_0;
                `OFFSET_CONFIG_O: input_offset_reg <= cmd_payload_inputs_0;
            endcase
        end
    end
end

// --------------------
// Data Buffer
// --------------------
global_buffer_bram #(
    .ADDR_BITS(ADDR_BITS),
    .DATA_BITS(CHANNEL_WIDTH)
) input_buffer (
    .clk     (clk),
    .rst_n   (1'b1),
    .ram_en  (1'b1),
    .wr_en   (buff_a_we),
    .index   (buff_a_addr),
    .data_in (buff_a_din),
    .data_out(buff_a_dout)
);
assign buff_a_we = buff_sel ? gemm_a_we : cmd_a_we;
assign buff_a_addr = buff_sel ? gemm_a_addr : cmd_payload_inputs_1;
assign buff_a_din = cmd_payload_inputs_0;

// global_buffer_bram #(
//     .ADDR_BITS(ADDR_BITS),
//     .DATA_BITS(CHANNEL_WIDTH)
// ) weight_buffer (
//     .clk     (clk),
//     .rst_n   (1'b1),
//     .ram_en  (1'b1),
//     .wr_en   (biff_b_we),
//     .index   (buff_b_addr),
//     .data_in (buff_b_din),
//     .data_out(buff_b_dout)
// );
// assign buff_b_we = buff_sel ? gemm_b_we : cmd_b_we;
assign buff_b_we = cmd_b_we;
assign buff_b_addr = buff_sel ? gemm_b_addr : cmd_payload_inputs_1;
assign buff_b_din = cmd_payload_inputs_0;
//
reg [CHANNEL_WIDTH-1:0] buff_b_reg[0:2**ADDR_BITS-1];
integer i;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        for (i = 0; i < 2**ADDR_BITS-1 ; i = i + 1) begin
            buff_b_reg[i] <= 'd0;
        end 
    end else if (buff_b_we) begin
        buff_b_reg[buff_b_addr] <= cmd_payload_inputs_0;
    end
end
assign buff_b_dout = buff_b_reg[buff_b_addr];
//

global_buffer_bram #(
    .ADDR_BITS(ADDR_BITS),
    .DATA_BITS(4*CHANNEL_WIDTH)
) output_buffer (
    .clk     (clk),
    .rst_n   (1'b1),
    .ram_en  (1'b1),
    .wr_en   (buff_c_we),
    .index   (buff_c_addr),
    .data_in (buff_c_din),
    .data_out(buff_c_dout)
);
assign buff_c_we = buff_sel ? gemm_c_we : cmd_c_we;
assign buff_c_addr = buff_sel ? gemm_c_addr : cmd_payload_inputs_1;
assign buff_c_din = buff_sel ? gemm_c_data :  cmd_payload_inputs_0;

// --------------------
// GEMM unit
// --------------------
gemm u_gemm(
    .clk       (clk),
    .rst_n     (rst_n),

    .in_valid  (gemm_in_valid),
    .K         (gemm_k),
    .M         (gemm_m),
    .N         (gemm_n),
    .offset    (gemm_offset),
    .busy      (gemm_busy),
    .complete  (gemm_complete),

    .A_wr_en   (gemm_a_we),
    .A_index   (gemm_a_addr),
    .A_data_in (),
    .A_data_out(buff_a_dout),

    .B_wr_en   (gemm_b_we),
    .B_index   (gemm_b_addr),
    .B_data_in (),
    .B_data_out(buff_b_dout),

    .C_wr_en   (gemm_c_we),
    .C_index   (gemm_c_addr),
    .C_data_in (gemm_c_data),
    .C_data_out()
);

// --------------------
// Output
// --------------------
always @(*) begin
    if (cmd_read) begin
        case (cmd_payload_function7[5:4])
            `INDEX_CONGIG: begin
                case (cmd_payload_inputs_1[1:0])
                    `OFFSET_CONFIG_K: rsp_payload_outputs_0 = k_reg;
                    `OFFSET_CONFIG_M: rsp_payload_outputs_0 = m_reg;
                    `OFFSET_CONFIG_N: rsp_payload_outputs_0 = n_reg;
                    `OFFSET_CONFIG_O: rsp_payload_outputs_0 = input_offset_reg;
                    default: rsp_payload_outputs_0 = 'd0;
                endcase
            end
            `INDEX_BUFF_A: rsp_payload_outputs_0 = buff_a_dout;
            `INDEX_BUFF_B: rsp_payload_outputs_0 = buff_b_dout;
            `INDEX_BUFF_C: begin
                case (cmd_payload_inputs_0[1:0])
                    2'd3: rsp_payload_outputs_0 = buff_c_dout[31:0];
                    2'd2: rsp_payload_outputs_0 = buff_c_dout[63:32];
                    2'd1: rsp_payload_outputs_0 = buff_c_dout[95:64];
                    default: rsp_payload_outputs_0 = buff_c_dout[127:96];
                endcase
            end
            default: rsp_payload_outputs_0 = 'd0;
        endcase
    end else begin
        rsp_payload_outputs_0 = 'd0;
    end
    // rsp_payload_outputs_0 = {buff_b_din, buff_b_addr[3:0], 3'b000, neg_b_we, 3'b000, buff_b_we};
end
always @(*) begin
    if (cmd_comp | gemm_busy) begin
        cmd_ready = gemm_complete;
        rsp_valid = gemm_complete;
    end else begin
        cmd_ready = rsp_ready;
        rsp_valid = cmd_valid;
    end
end

endmodule