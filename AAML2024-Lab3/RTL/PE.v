module PE(clk, rst_n, in_left, in_up, out_right, out_down, result, go, clear);

	input clk, rst_n;
	input [7:0] in_left;
	input [7:0] in_up;
    input go, clear;
	output reg [7:0] out_right;
	output reg [7:0] out_down;
    output reg [31:0] result;

	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			out_right <= 0;
            out_down <= 0;
            result <= 0;
		end
		else begin
			if (go) begin
				out_right <= in_left;
                out_down <= in_up;
				result <= result + (in_left * in_up);
			end else if (clear) begin
                result <= 0;
            end else begin
				out_right <= 0;
				out_down <= 0;
                result <= result;
			end
		end
	end
endmodule