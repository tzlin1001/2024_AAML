`include "PE.v"

module TPU(
    clk,
    rst_n,

    in_valid,
    K,
    M,
    N,
    busy,

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
output reg       busy;

output reg         A_wr_en;
output reg [15:0]  A_index;
output [31:0]      A_data_in;
input  [31:0]      A_data_out;

output reg         B_wr_en;
output reg [15:0]  B_index;
output [31:0]      B_data_in;
input  [31:0]      B_data_out;

output reg         C_wr_en;
output reg [15:0]  C_index;
output reg [127:0] C_data_in;
input  [127:0]     C_data_out;

//* Implement your design here

/******** matrix parameters ********/
reg [7:0] k, m, n;

/******** state definition ********/
reg [2:0] state,state_nxt;
parameter [2:0] IDLE 	= 3'd0,
                LOAD 	= 3'd1,
                EXE  	= 3'd2,
                OUTPUT	= 3'd3;


/******** data storage for PE ********/
reg [7:0] left_buf0_A [6:0];
reg [7:0] left_buf1_A [6:0];
reg [7:0] left_buf2_A [6:0];
reg [7:0] left_buf3_A [6:0];
reg [7:0] top_buf0_B [6:0];
reg [7:0] top_buf1_B [6:0];
reg [7:0] top_buf2_B [6:0];
reg [7:0] top_buf3_B [6:0];

/******** wire connection of PE ********/
wire [7:0] down_wire0 [2:0];
wire [7:0] down_wire1 [2:0];
wire [7:0] down_wire2 [2:0];
wire [7:0] down_wire3 [2:0];
wire [7:0] right_wire0 [2:0];
wire [7:0] right_wire1 [2:0];
wire [7:0] right_wire2 [2:0];
wire [7:0] right_wire3 [2:0];

/******** output buffer ********/
reg [31:0] C [3:0][3:0];

/******** control register ********/
integer i,j;
reg go_pe;
reg clear_pe;
reg [7:0] load_counter, exe_counter;
reg [15:0]  C_index_nxt;

/******** PR declaration ********/
PE pe00(.clk(clk), .rst_n(rst_n), 
        .in_left(left_buf0_A[0]), .in_up(top_buf0_B[0]),
        .out_right(right_wire0[0]), .out_down(down_wire0[0]), .result(C[0][0]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe01(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire0[0]), .in_up(top_buf1_B[0]),
        .out_right(right_wire0[1]), .out_down(down_wire1[0]), .result(C[0][1]), .go(go_pe), .clear(clear_pe)
        );
PE pe02(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire0[1]), .in_up(top_buf2_B[0]),
        .out_right(right_wire0[2]), .out_down(down_wire2[0]), .result(C[0][2]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe03(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire0[2]), .in_up(top_buf3_B[0]),
        .out_right(), .out_down(down_wire3[0]), .result(C[0][3]), .go(go_pe), .clear(clear_pe)
        );
PE pe10(.clk(clk), .rst_n(rst_n), 
        .in_left(left_buf1_A[0]), .in_up(down_wire0[0]),
        .out_right(right_wire1[0]), .out_down(down_wire0[1]), .result(C[1][0]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe11(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire1[0]), .in_up(down_wire1[0]),
        .out_right(right_wire1[1]), .out_down(down_wire1[1]), .result(C[1][1]), .go(go_pe), .clear(clear_pe)
        );
PE pe12(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire1[1]), .in_up(down_wire2[0]),
        .out_right(right_wire1[2]), .out_down(down_wire2[1]), .result(C[1][2]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe13(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire1[2]), .in_up(down_wire3[0]),
        .out_right(), .out_down(down_wire3[1]), .result(C[1][3]), .go(go_pe), .clear(clear_pe)
        );
PE pe20(.clk(clk), .rst_n(rst_n), 
        .in_left(left_buf2_A[0]), .in_up(down_wire0[1]),
        .out_right(right_wire2[0]), .out_down(down_wire0[2]), .result(C[2][0]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe21(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire2[0]), .in_up(down_wire1[1]),
        .out_right(right_wire2[1]), .out_down(down_wire1[2]), .result(C[2][1]), .go(go_pe), .clear(clear_pe)
        );
PE pe22(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire2[1]), .in_up(down_wire2[1]),
        .out_right(right_wire2[2]), .out_down(down_wire2[2]), .result(C[2][2]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe23(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire2[2]), .in_up(down_wire3[1]),
        .out_right(), .out_down(down_wire3[2]), .result(C[2][3]), .go(go_pe), .clear(clear_pe)
        );
PE pe30(.clk(clk), .rst_n(rst_n), 
        .in_left(left_buf3_A[0]), .in_up(down_wire0[2]),
        .out_right(right_wire3[0]), .out_down(), .result(C[3][0]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe31(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire3[0]), .in_up(down_wire1[2]),
        .out_right(right_wire3[1]), .out_down(), .result(C[3][1]), .go(go_pe), .clear(clear_pe)
        );
PE pe32(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire3[1]), .in_up(down_wire2[2]),
        .out_right(right_wire3[2]), .out_down(), .result(C[3][2]), .go(go_pe), .clear(clear_pe)
        ); 
PE pe33(.clk(clk), .rst_n(rst_n), 
        .in_left(right_wire3[2]), .in_up(down_wire3[2]),
        .out_right(), .out_down(), .result(C[3][3]), .go(go_pe), .clear(clear_pe)
        );

/******** combinational circuit ********/	
always @(*) begin
    if (in_valid) begin
        busy <= 1;
        state <= LOAD;
        load_counter <= 0;
        exe_counter <= 0;
        C_index_nxt <= 0;
        clear_pe <= 1;
        k <= K;
        m <= M;
        n <= N;
    end
end

/******** sequential circuit ********/
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy <= 0;
        state <= IDLE;
        A_wr_en <= 0;
        B_wr_en <= 0;
        C_wr_en <= 0;
        A_index <= 0;
        B_index <= 0;
        C_index <= 0;
        C_data_in <= 0;
        load_counter <= 0;
        exe_counter  <= 0;
        C_index_nxt <= 0;
        clear_pe <= 1;
        k <= 0;
        m <= 0;
        n <= 0;
    end else begin
        case (state)
            IDLE: begin
                busy <= 0;
                A_index <= 0;
                B_index <= 0;
                load_counter <= 0;
                exe_counter  <= 0;
                C_index_nxt <= 0;
                go_pe <= 0;
                clear_pe <= 1;
            end
            LOAD: begin
                go_pe <= 0;
                clear_pe <= 0;
                if ((load_counter % 4) == 0) begin
                    {left_buf0_A[0], left_buf1_A[1], left_buf2_A[2], left_buf3_A[3]} <= {A_data_out};
                    {top_buf0_B[0], top_buf1_B[1], top_buf2_B[2], top_buf3_B[3]}  <= {B_data_out};
                    A_index <= load_counter + 1;
                    B_index <= load_counter + 1;
                end else if ((load_counter % 4) == 1) begin
                    if (load_counter < k) begin
                        {left_buf0_A[1], left_buf1_A[2], left_buf2_A[3], left_buf3_A[4]} <= {A_data_out};
                        {top_buf0_B[1], top_buf1_B[2], top_buf2_B[3], top_buf3_B[4]}  <= {B_data_out};
                        A_index <= load_counter + 1;
                        B_index <= load_counter + 1;
                    end else begin
                        {left_buf0_A[1], left_buf1_A[2], left_buf2_A[3], left_buf3_A[4]} <= {32'd0};
                        {top_buf0_B[1], top_buf1_B[2], top_buf2_B[3], top_buf3_B[4]}  <= {32'd0};
                    end
                end else if ((load_counter % 4) == 2) begin
                    if (load_counter < k) begin
                        {left_buf0_A[2], left_buf1_A[3], left_buf2_A[4], left_buf3_A[5]} <= {A_data_out};
                        {top_buf0_B[2], top_buf1_B[3], top_buf2_B[4], top_buf3_B[5]}  <= {B_data_out};
                        A_index <= load_counter + 1;
                        B_index <= load_counter + 1;
                    end else begin
                        {left_buf0_A[2], left_buf1_A[3], left_buf2_A[4], left_buf3_A[5]} <= {32'd0};
                        {top_buf0_B[2], top_buf1_B[3], top_buf2_B[4], top_buf3_B[5]}  <= {32'd0};
                    end
                end else if ((load_counter % 4) == 3) begin
                    if (load_counter < k) begin
                        {left_buf0_A[3], left_buf1_A[4], left_buf2_A[5], left_buf3_A[6]} <= {A_data_out};
                        {top_buf0_B[3], top_buf1_B[4], top_buf2_B[5], top_buf3_B[6]}  <= {B_data_out};
                    end else begin
                        {left_buf0_A[3], left_buf1_A[4], left_buf2_A[5], left_buf3_A[6]} <= {32'd0};
                        {top_buf0_B[3], top_buf1_B[4], top_buf2_B[5], top_buf3_B[6]}  <= {32'd0};
                    end

                    {left_buf0_A[4], left_buf0_A[5], left_buf0_A[6]} <= {24'd0};
                    {left_buf1_A[0], left_buf1_A[5], left_buf1_A[6]} <= {24'd0};
                    {left_buf2_A[0], left_buf2_A[1], left_buf2_A[6]} <= {24'd0};
                    {left_buf3_A[0], left_buf3_A[1], left_buf3_A[2]} <= {24'd0};

                    {top_buf0_B[4], top_buf0_B[5], top_buf0_B[6]} <= {24'd0};
                    {top_buf1_B[0], top_buf1_B[5], top_buf1_B[6]} <= {24'd0};
                    {top_buf2_B[0], top_buf2_B[1], top_buf2_B[6]} <= {24'd0};
                    {top_buf3_B[0], top_buf3_B[1], top_buf3_B[2]} <= {24'd0};

                    A_index <= load_counter + 1;
                    B_index <= load_counter + 1;

                    state <= EXE;
                end
                load_counter <= load_counter + 1;
            end
            EXE: begin
                go_pe <= 1;
                if (exe_counter <= 6) begin
                    left_buf0_A[0] <= left_buf0_A[exe_counter];
                    left_buf1_A[0] <= left_buf1_A[exe_counter];
                    left_buf2_A[0] <= left_buf2_A[exe_counter];
                    left_buf3_A[0] <= left_buf3_A[exe_counter];
                    top_buf0_B[0] <= top_buf0_B[exe_counter];
                    top_buf1_B[0] <= top_buf1_B[exe_counter];
                    top_buf2_B[0] <= top_buf2_B[exe_counter];
                    top_buf3_B[0] <= top_buf3_B[exe_counter];
                end else begin
                    left_buf0_A[0] <= 0;
                    left_buf1_A[0] <= 0;
                    left_buf2_A[0] <= 0;
                    left_buf3_A[0] <= 0;
                    top_buf0_B[0] <= 0;
                    top_buf1_B[0] <= 0;
                    top_buf2_B[0] <= 0;
                    top_buf3_B[0] <= 0;                
                end
                exe_counter <= exe_counter + 1;
                if (exe_counter == 10) begin
                    if (load_counter < k) begin
                        state = LOAD;
                    end else begin
                        state = OUTPUT;
                    end
                    go_pe <= 0;
                    exe_counter <= 0;
                end
            end
            OUTPUT: begin
                go_pe <= 0;
                C_wr_en <= 1;
                C_index <= C_index_nxt;
                case (C_index)
                    0: begin
                        C_data_in <= {C[0][0], C[0][1], C[0][2], C[0][3]};
                        C_index_nxt <= 1; 
                    end
                    1: begin
                        C_data_in <= {C[1][0], C[1][1], C[1][2], C[1][3]};
                        C_index_nxt <= 2; 
                    end
                    2: begin
                        C_data_in <= {C[2][0], C[2][1], C[2][2], C[2][3]};
                        C_index_nxt <= 3; 
                    end
                    3: begin
                        C_data_in <= {C[3][0], C[3][1], C[3][2], C[3][3]};
                        C_index_nxt <= 4; 
                    end
                    4: begin
                        C_wr_en <= 0;
                        C_index <= 0;
                        C_index_nxt <= 0;
                        busy <= 0;
                        state <= IDLE;
                    end
                endcase
            end
        endcase
    end
end

endmodule
