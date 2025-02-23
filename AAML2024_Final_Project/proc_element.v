module proc_element #(
    parameter DataWidth = 8,
    parameter AccWidth = 32,
    parameter UseSigned = 0
) (
    input clk,
    input rst_n,
    input clear,
    input      [DataWidth-1:0] in_x,
    input      [DataWidth-1:0] in_y,
    output reg [DataWidth-1:0] out_x,
    output reg [DataWidth-1:0] out_y,
    output     [AccWidth-1:0]  value
);
reg  [AccWidth-1:0]    acc;
wire [2*DataWidth-1:0] mul;
wire [AccWidth-1:0]    acc_nxt;


generate
    if (UseSigned) begin
        assign mul = $signed(in_x) * $signed(in_y);
        assign acc_nxt = $signed(acc) + $signed(mul);
    end else begin
        assign mul = in_x * in_y;
        assign acc_nxt = acc + mul;
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        out_x <= 'd0;
        out_y <= 'd0;
        acc <= 'd0;
    end else begin
        out_x <= in_x;
        out_y <= in_y;
        acc <= clear ? 'd0 : acc_nxt;
    end
end
assign value = acc;

endmodule