module controller (
    input clk,
    input rst_n,
    input in_valid,
    input [7:0] K,
    input [7:0] M,
    input [7:0] N,
    output      busy,
    output      complete,
    // Memory
    output        a_wr_en,
    output [15:0] a_addr,
    input  [31:0] a_data,
    output        b_wr_en,
    output [15:0] b_addr,
    input  [31:0] b_data,
    output        c_wr_en,
    output [15:0] c_addr,
    // Systolic Array
    input      sa_busy,
    output     sa_start,
    output reg [2:0] sa_row_en,
    input      sa_o_last,
    input      sa_o_valid,
    output reg sa_i_last,
    output reg sa_i_vaild,
    output reg [31:0] sa_weight,
    output reg [31:0] sa_input
);
// (6x7)*(7x5) for example:
// M=6, K=7, N=5 
// weight_reuse = ceil(6/4)=2, input_loop = ceil(5/4)=2
//
// clk          | _/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\
// in_valid     | ___/---\__________________________________________________________________________________________
// cur_state    | IDLE | W | READ................. | WAIT......................... | READ................. | WAIT...
// busy         | _____/--------------------------------------------------------------------------------------------
// sa_start     | _____/---\_______________________/-------------------------------\_______________________/-------------------------\
// sa_busy      | _________/---------------------------------------------------\___/---------------------------------------\___/
// cnt          |  | 0 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 0............................ | 1 | 2 | 3 | 4 | 5 | 6 | 0...
// cnt_ifeature |  | 0.................................................................................... | 1...
// ifeature_ptr |  | 0............................ | 7.................................................... | 0...
// ifeature_addr|  | 0 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7............................ | 8 | 9 | 10| 11| 12| 13| 0...
// cnt_weight   |  | 0............................ | 1.................................................... | 0...
// weight_ptr   |  | 0.................................................................................... | 1...
// weight_addr  |  | 0 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 0............................ | 1 | 2 | 3 | 4 | 5 | 6 | 7...
// sa_data      |  |   |   | * | * | * | * | * | * | * |   |   |   |   |   |   |   | * | * | * | * | * | * | * |   |   |   |   |   |   |   |
// sa_ivalid    | _________/---------------------------\___________________________/---------------------------\___________________________
// padding_data |  | x | x | * | * | * | * | * | * | * | * | * | * | x | x | x | x | * | * | * | * | * | * | * | * | * | * | x | x | x | x |
// sa_acc       |  | x | x | 0 | * | * | * | * | * | * | * | * | * | * | * | * |ans| 0 | * | * | * | * | * | * | * | * | * | * | * | * |ans|
// sa_last      | _________________________________/---\___________________________________________________/---\____________________________
// d_last       | _____________________________________________/---\___________________________________________________/---\________________
// done         | _____________________________________________________________/---\___________________________________________________/---\
// out_vaild    | _____________________________________________________________/---------------\_______________________________________/----
// out_last     | _________________________________________________________________________/---\____________________________________________

// ==========
//  PARAMS
// ==========
localparam S_IDLE = 'd0;
localparam S_WAIT = 'd1;
localparam S_READ = 'd2;

// ==========
//  WIRE & REG
// ==========
reg [1:0] cur_state, nxt_state;
reg [7:0] max_cnt, cnt;
reg [5:0] max_weight_reuse, max_input_loop, cnt_ifeature, cnt_weight;
reg [1:0] row_offset;
reg [15:0] ifeature_addr, weight_addr, ofeature_addr;
wire sa_run, finish;

// ==========
//  DESIGN
// ==========
// FSM
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        cur_state <= S_IDLE;
    end else begin
        cur_state <= nxt_state;
    end
end
always @(*) begin
    case (cur_state)
        S_IDLE: nxt_state = in_valid ? S_WAIT : S_IDLE;
        S_WAIT: begin
            if (sa_run)
                nxt_state = S_READ;
            else if (finish)
                nxt_state = S_IDLE;
            else
                nxt_state = S_WAIT;
        end
        S_READ: nxt_state = cnt == max_cnt ? S_WAIT : S_READ;
        default: nxt_state = cur_state;
    endcase
end

// Control signal
assign sa_start = (cur_state == S_WAIT) & (cnt_ifeature <= max_input_loop);
assign sa_run = sa_start & ~sa_busy;
assign finish = (cnt_ifeature > max_input_loop) & sa_o_last;
always @(*) begin
    if (cnt_weight == max_weight_reuse) begin
        case (row_offset)
            'd1: sa_row_en = 3'b000;
            'd2: sa_row_en = 3'b001;
            'd3: sa_row_en = 3'b011;
            default: sa_row_en = 3'b111;
        endcase
    end else begin
        sa_row_en = 3'b111;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        sa_i_last <= 1'b0;
    else
        sa_i_last <= (cnt == max_cnt) & sa_i_vaild;
end
always @(posedge clk or negedge rst_n) begin
    if (~rst_n)
        sa_i_vaild <= 1'b0;
    else
        sa_i_vaild <= (sa_run | cur_state==S_READ) ? 1'b1 : 1'b0;
end

// K, M, N
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        max_cnt <= 'd0;
        max_input_loop <= 'd0;
        max_weight_reuse <= 'd0;
        row_offset <= 'd0;
    end else begin
        if (cur_state==S_IDLE & in_valid) begin
            max_cnt <= K - 1'd1;
            max_input_loop <= (N >> 2) - (~|N[1:0]);
            max_weight_reuse <= (M >> 2) - (~|M[1:0]);
            row_offset <= M[1:0];
        end
    end
end

// Read Address
assign a_wr_en = 1'b0;
assign a_addr = ifeature_addr;
assign b_wr_en = 1'b0;
assign b_addr = weight_addr;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        cnt <= 'd0;
    end else begin
        if (cnt == max_cnt)
            cnt <= 'd0;
        else if (cnt == 'd0)
            cnt <= sa_run ? cnt + 1'b1 : cnt;
        else
            cnt <= cnt + 1'b1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        cnt_ifeature <= 'd0;
        cnt_weight <= 'd0;
    end else begin
        case (cur_state)
            S_IDLE: begin
                cnt_ifeature <= 'd0;
                cnt_weight <= 'd0;
            end
            S_READ: begin
                if (cnt == max_cnt) begin
                    cnt_ifeature <= cnt_weight == max_weight_reuse ? cnt_ifeature + 1'b1 : cnt_ifeature;
                    cnt_weight <= cnt_weight == max_weight_reuse ? 'd0 : cnt_weight + 1'b1;
                end
            end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ifeature_addr <= 'd0;
    end else begin
        case (cur_state)
            S_WAIT: if (sa_run) ifeature_addr <= ifeature_addr + 1'b1;
            S_READ: begin
                if (cnt == max_cnt) begin
                    ifeature_addr <= cnt_weight == max_weight_reuse ? 'd0 : ifeature_addr + 1'b1;
                end else begin
                    ifeature_addr <= ifeature_addr + 1'b1;
                end
            end 
            default: ifeature_addr <= 'd0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        weight_addr <= 'd0;
    end else begin
        case (cur_state)
            S_WAIT: if (sa_run) weight_addr <= weight_addr + 1'b1;
            S_READ: begin
                if (cnt == max_cnt) begin
                    weight_addr <= cnt_weight == max_weight_reuse ? weight_addr + 1'b1 : weight_addr - max_cnt;
                end else begin
                    weight_addr <= weight_addr + 1'b1;
                end
            end
            default: weight_addr <= 'd0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        sa_input <= 'd0;
        sa_weight <= 'd0;
    end else begin
        sa_input <= a_data;
        sa_weight <= b_data;
    end
end

// Write Address
assign c_wr_en = sa_o_valid;
assign c_addr = ofeature_addr;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        ofeature_addr <= 'd0;
    end else begin
        if (finish)
            ofeature_addr <= 'd0;
        else if (sa_o_valid)
            ofeature_addr <= ofeature_addr + 1'b1;
    end
end

// Output
assign busy = cur_state != S_IDLE;
assign complete = finish;

endmodule