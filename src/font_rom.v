`default_nettype none

module font_rom (
  input  wire [3:0] digit,
  input  wire [2:0] row,
  output reg  [4:0] pixels
);
  always @(*) begin
    case ({digit, row})
      {4'd0, 3'd0}: pixels = 5'b01110;
      {4'd0, 3'd1}: pixels = 5'b10001;
      {4'd0, 3'd2}: pixels = 5'b10011;
      {4'd0, 3'd3}: pixels = 5'b10101;
      {4'd0, 3'd4}: pixels = 5'b11001;
      {4'd0, 3'd5}: pixels = 5'b10001;
      {4'd0, 3'd6}: pixels = 5'b01110;
      {4'd1, 3'd0}: pixels = 5'b00100;
      {4'd1, 3'd1}: pixels = 5'b01100;
      {4'd1, 3'd2}: pixels = 5'b00100;
      {4'd1, 3'd3}: pixels = 5'b00100;
      {4'd1, 3'd4}: pixels = 5'b00100;
      {4'd1, 3'd5}: pixels = 5'b00100;
      {4'd1, 3'd6}: pixels = 5'b01110;
      {4'd2, 3'd0}: pixels = 5'b01110;
      {4'd2, 3'd1}: pixels = 5'b10001;
      {4'd2, 3'd2}: pixels = 5'b00001;
      {4'd2, 3'd3}: pixels = 5'b00110;
      {4'd2, 3'd4}: pixels = 5'b01000;
      {4'd2, 3'd5}: pixels = 5'b10000;
      {4'd2, 3'd6}: pixels = 5'b11111;
      {4'd3, 3'd0}: pixels = 5'b01110;
      {4'd3, 3'd1}: pixels = 5'b10001;
      {4'd3, 3'd2}: pixels = 5'b00001;
      {4'd3, 3'd3}: pixels = 5'b00110;
      {4'd3, 3'd4}: pixels = 5'b00001;
      {4'd3, 3'd5}: pixels = 5'b10001;
      {4'd3, 3'd6}: pixels = 5'b01110;
      {4'd4, 3'd0}: pixels = 5'b00010;
      {4'd4, 3'd1}: pixels = 5'b00110;
      {4'd4, 3'd2}: pixels = 5'b01010;
      {4'd4, 3'd3}: pixels = 5'b10010;
      {4'd4, 3'd4}: pixels = 5'b11111;
      {4'd4, 3'd5}: pixels = 5'b00010;
      {4'd4, 3'd6}: pixels = 5'b00010;
      {4'd5, 3'd0}: pixels = 5'b11111;
      {4'd5, 3'd1}: pixels = 5'b10000;
      {4'd5, 3'd2}: pixels = 5'b11110;
      {4'd5, 3'd3}: pixels = 5'b00001;
      {4'd5, 3'd4}: pixels = 5'b00001;
      {4'd5, 3'd5}: pixels = 5'b10001;
      {4'd5, 3'd6}: pixels = 5'b01110;
      {4'd6, 3'd0}: pixels = 5'b00110;
      {4'd6, 3'd1}: pixels = 5'b01000;
      {4'd6, 3'd2}: pixels = 5'b10000;
      {4'd6, 3'd3}: pixels = 5'b11110;
      {4'd6, 3'd4}: pixels = 5'b10001;
      {4'd6, 3'd5}: pixels = 5'b10001;
      {4'd6, 3'd6}: pixels = 5'b01110;
      {4'd7, 3'd0}: pixels = 5'b11111;
      {4'd7, 3'd1}: pixels = 5'b00001;
      {4'd7, 3'd2}: pixels = 5'b00010;
      {4'd7, 3'd3}: pixels = 5'b00100;
      {4'd7, 3'd4}: pixels = 5'b01000;
      {4'd7, 3'd5}: pixels = 5'b01000;
      {4'd7, 3'd6}: pixels = 5'b01000;
      {4'd8, 3'd0}: pixels = 5'b01110;
      {4'd8, 3'd1}: pixels = 5'b10001;
      {4'd8, 3'd2}: pixels = 5'b10001;
      {4'd8, 3'd3}: pixels = 5'b01110;
      {4'd8, 3'd4}: pixels = 5'b10001;
      {4'd8, 3'd5}: pixels = 5'b10001;
      {4'd8, 3'd6}: pixels = 5'b01110;
      {4'd9, 3'd0}: pixels = 5'b01110;
      {4'd9, 3'd1}: pixels = 5'b10001;
      {4'd9, 3'd2}: pixels = 5'b10001;
      {4'd9, 3'd3}: pixels = 5'b01111;
      {4'd9, 3'd4}: pixels = 5'b00001;
      {4'd9, 3'd5}: pixels = 5'b00010;
      {4'd9, 3'd6}: pixels = 5'b01100;
      default:      pixels = 5'b00000;
    endcase
  end
endmodule
