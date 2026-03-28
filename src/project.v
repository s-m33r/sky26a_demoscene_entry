/*
 * Copyright (c) 2026 Sameer Srivastava
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

function [15:0] lfsr_next;
  input [15:0] s;
  begin
    lfsr_next = {s[14:0], s[15] ^ s[14] ^ s[12] ^ s[3]};
  end
endfunction

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire hsync, vsync;
  wire [1:0] R, G, B;
  wire video_active;
  wire [9:0] pix_x, pix_y;

  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) counter <= 0;
    else        counter <= counter + 1;
  end

  hvsync_generator hvsync_gen(
    .clk(clk), .reset(~rst_n),
    .hsync(hsync), .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x), .vpos(pix_y)
  );

  // ---- Font / character parameters ----
  localparam SCALE      = 2;
  localparam CHAR_W     = 5 * SCALE;          // 10
  localparam CHAR_H     = 7 * SCALE;          // 14
  localparam CHAR_GAP_X = 10 * SCALE;          // 12  <-- increased spacing
  localparam CHAR_GAP_Y = 10 * SCALE;          // 12  <-- increased spacing
  localparam CELL_W     = CHAR_W + CHAR_GAP_X; // 22
  localparam CELL_H     = CHAR_H + CHAR_GAP_Y; // 26

  // ---- Bottom bar: fixed pixel rows ----
  localparam BOT_BAR_TOP = 420;   // bar starts at this Y (leaves ~40px bar to 479)
  localparam BOT_BAR_H   = 480 - BOT_BAR_TOP;  // 40px
  localparam TOP_PAD     = BOT_BAR_H;           // 40px — matches bottom bar
  localparam COMP_W      = 640 / 5; // 128px per segment

  // Grid occupies BOT_BAR_TOP pixels of height.
  // Reserve equal padding at top and bottom of the grid area.
  localparam GRID_H      = BOT_BAR_TOP - TOP_PAD;        // 440
  localparam MAX_ROWS_FIT = GRID_H / CELL_H;   // how many full rows fit

  // Adjust pix_y relative to the padded grid origin
  wire [9:0] grid_y  = (pix_y >= TOP_PAD) ? (pix_y - TOP_PAD[9:0]) : 10'd0;
  wire       in_grid_y = (pix_y >= TOP_PAD) && (pix_y < TOP_PAD + MAX_ROWS_FIT * CELL_H);

  wire [9:0] cell_col  = pix_x / CELL_W;
  wire [9:0] cell_row  = grid_y / CELL_H;

  wire [9:0] cell_px_x = pix_x - cell_col * CELL_W;
  wire [9:0] cell_px_y = grid_y - cell_row * CELL_H;

  // ---- Wobble ----
  wire [1:0] wobble_x = counter[5:4] ^ cell_col[0:0];
  wire [1:0] wobble_y = counter[6:5] ^ cell_row[0:0];

  wire signed [10:0] wpx = $signed({1'b0, cell_px_x}) - $signed({1'b0, wobble_x});
  wire signed [10:0] wpy = $signed({1'b0, cell_px_y}) - $signed({1'b0, wobble_y});

  wire in_char = in_grid_y &&
                 (wpx >= 0) && (wpx < CHAR_W) &&
                 (wpy >= 0) && (wpy < CHAR_H);

  wire [2:0] font_col = 4 - (wpx[4:0] / SCALE);
  wire [2:0] font_row =      wpy[4:0] / SCALE;

  // ---- Per-cell pseudorandom digit ----
  localparam [15:0] SEED = 16'hDEAD;

  function [3:0] cell_digit;
    input [9:0] col;
    input [9:0] row;
    reg [15:0] s;
    integer i;
    begin
      s = SEED ^ {col[5:0], row[5:0], 4'hF};
      if (s == 0) s = 16'hFFFF;
      for (i = 0; i < 8; i = i + 1)
        s = lfsr_next(s);
      cell_digit = (s[3:0] >= 10) ? s[3:0] - 10 : s[3:0];
    end
  endfunction

  wire [3:0] digit_val = cell_digit(cell_col, cell_row);

  wire [4:0] row_pixels;
  font_rom font(
    .digit(digit_val),
    .row(font_row),
    .pixels(row_pixels)
  );

  // ---- Bottom bar ----
  wire in_rect = (pix_y >= BOT_BAR_TOP);

  wire in_border = in_rect && (
    pix_y == BOT_BAR_TOP      ||   // top edge
    pix_y == 479              ||   // bottom edge
    pix_x == 0                ||   // left edge
    pix_x == 639              ||   // right edge
    (pix_x % COMP_W == 0)          // dividers
  );

 // ---- Bottom bar digit rendering ----
  // One digit per column (1–5), drawn at top-left of each segment
  localparam BAR_DIGIT_MARGIN = 10;  // pixels from top-left of each segment

  wire [9:0] bar_col   = pix_x / COMP_W;  // which segment (0–4)
  wire [9:0] bar_px_x  = pix_x - bar_col * COMP_W - BAR_DIGIT_MARGIN;
  wire [9:0] bar_px_y  = pix_y - BOT_BAR_TOP - BAR_DIGIT_MARGIN;

  wire in_bar_char = in_rect &&
                     (bar_px_x < CHAR_W) &&
                     (bar_px_y < CHAR_H) &&
                     (bar_px_x < COMP_W);  // don't bleed into next segment

  wire [2:0] bar_font_col = 4 - (bar_px_x[4:0] / SCALE);
  wire [2:0] bar_font_row =      bar_px_y[4:0] / SCALE;

  // Digits 1–5 mapped from bar_col 0–4
  wire [3:0] bar_digit_val = bar_col[3:0] + 4'd1;

  wire [4:0] bar_row_pixels;
  font_rom bar_font(
    .digit(bar_digit_val),
    .row(bar_font_row),
    .pixels(bar_row_pixels)
  );

  wire bar_digit_pixel = in_bar_char && bar_row_pixels[bar_font_col];

 // ---- Top bar ----
  localparam TOP_BAR_H   = 30;   // thinner than bottom bar
  localparam TOP_BAR_TOP = 5;

  wire in_top_rect = (pix_y < TOP_BAR_H);

wire in_top_border = in_top_rect && (
    pix_y == 0             ||   // top edge  <-- was missing
    pix_y == TOP_BAR_H - 1 ||   // bottom edge
    pix_x == 0             ||   // left edge
    pix_x == 639                // right edge
  );


function logo_pixel_at;
    input [5:0] lx;
    input [4:0] ly;
    reg [39:0] row;
    begin
      case (ly)
        5'd0:  row = 40'b0000111111111111111111111111111111110000;
        5'd1:  row = 40'b0011000000000000000000000000000000001100;
        5'd2:  row = 40'b0100000000000000000000000000000000000010;
        5'd3:  row = 40'b1000000000000000000000000000000000000001;
        5'd4:  row = 40'b1000000000000000000110000000000000000001;
        5'd5:  row = 40'b1000000000000000000110000000000000000001;
        5'd6:  row = 40'b1000000000000000001111000000000000000001;
        5'd7:  row = 40'b1000000000000000001111000000000000000001;
        5'd8:  row = 40'b1000000000000000011111100000000000000001;
        5'd9:  row = 40'b1000000000000000111111110000000000000001;
        5'd10: row = 40'b1000000000000001111111111000000000000001;
        5'd11: row = 40'b1000000000000001111111111000000000000001;
        5'd12: row = 40'b1000000000000011111111111100000000000001;
        5'd13: row = 40'b1000000000000011111111111100000000000001;
        5'd14: row = 40'b1000000000000011111111111100000000000001;
        5'd15: row = 40'b1000000000000011111111111100000000000001;
        5'd16: row = 40'b1000000000000001111111111000000000000001;
        5'd17: row = 40'b1000000000000000011111100000000000000001;
        5'd18: row = 40'b1000000000000000000000000000000000000001;
        5'd19: row = 40'b1000000000000000000000000000000000000001;
        5'd20: row = 40'b0100000000000000000000000000000000000010;
        5'd21: row = 40'b0011000000000000000000000000000000001100;
        5'd22: row = 40'b0000111111111111111111111111111111110000;
        default: row = 40'b0;
      endcase
      logo_pixel_at = row[39 - lx];
    end
  endfunction

  localparam LOGO_W  = 40;
  localparam LOGO_H  = 23;
  localparam LOGO_X0 = 640 - LOGO_W - 4;
  localparam LOGO_Y0 = (TOP_BAR_H - LOGO_H) / 2;


  wire in_logo_bbox = in_top_rect &&
                      (pix_x >= LOGO_X0) && (pix_x < LOGO_X0 + LOGO_W) &&
                      (pix_y >= LOGO_Y0) && (pix_y < LOGO_Y0 + LOGO_H);

  wire [5:0] llx = in_logo_bbox ? pix_x - LOGO_X0 : 6'd0;
  wire [4:0] lly = in_logo_bbox ? pix_y - LOGO_Y0 : 5'd0;

  wire logo_pixel = in_logo_bbox && logo_pixel_at(llx, lly);

  wire top_bar_pixel = in_top_border || logo_pixel;

  // Replace final font_pixel and color lines with:
  wire font_pixel = (in_char && row_pixels[font_col]) ||
                    in_border || bar_digit_pixel || top_bar_pixel;


  // ---- Color output ----
  assign R = video_active ? (font_pixel ? 2'b01 : 2'b00) : 2'b00;
  assign G = video_active ? (font_pixel ? 2'b11 : 2'b00) : 2'b00;
  assign B = video_active ? (font_pixel ? 2'b11 : 2'b00) : 2'b00;


  // List all unused inputs to prevent warnings
    wire _unused = &{ena, 1'b0};

endmodule
