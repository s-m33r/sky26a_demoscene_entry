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

module tt_um_weird_numbers(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
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
  localparam CHAR_GAP_X = 10 * SCALE;          
  localparam CHAR_GAP_Y = 10 * SCALE;          
  localparam CELL_W     = CHAR_W + CHAR_GAP_X; // 20
  localparam CELL_H     = CHAR_H + CHAR_GAP_Y; // 24

  // ---- Grid area logic ----
  localparam TOP_PAD     = 40;
  localparam BOT_BAR_TOP = 420;   
  localparam GRID_H      = BOT_BAR_TOP - TOP_PAD;
  localparam MAX_ROWS_FIT = GRID_H / CELL_H;

  wire [9:0] grid_y  = (pix_y >= TOP_PAD) ? (pix_y - TOP_PAD[9:0]) : 10'd0;
  wire       in_grid_y = (pix_y >= TOP_PAD) && (pix_y < TOP_PAD + MAX_ROWS_FIT * CELL_H);
  wire [9:0] cell_col  = pix_x / CELL_W;
  wire [9:0] cell_row  = grid_y / CELL_H;
  wire [9:0] cell_px_x = pix_x - cell_col * CELL_W;
  wire [9:0] cell_px_y = grid_y - cell_row * CELL_H;

// ---- Wobble Mask Logic ----
  function wobble_enabled;
    input [9:0] col;
    input [9:0] row;
    reg [15:0] s;
    integer i;
    begin
      // Use a different salt (4'hA) so it doesn't match the digit pattern
      s = SEED ^ {col[5:0], row[5:0], 4'hA}; 
      if (s == 0) s = 16'hBEEF;
      for (i = 0; i < 4; i = i + 1)
        s = lfsr_next(s);
      // Only wobble if the last bit is 1 (approx 50% of the screen)
      wobble_enabled = s[0]; 
    end
  endfunction

  wire cell_should_wobble = wobble_enabled(cell_col << 2, cell_row << 2);

  // ---- Wobble Effect ----
// ---- Conditional Wobble ----
  // If the cell shouldn't wobble, we set the offset to 0
  wire [1:0] eff_wobble_x = cell_should_wobble ? (counter[5:4] ^ cell_col[0:0]) : 2'b00;
  wire [1:0] eff_wobble_y = cell_should_wobble ? (counter[6:5] ^ cell_row[0:0]) : 2'b00;

  wire [1:0] wobble_x = counter[5:4] ^ cell_col[0:0];
  wire [1:0] wobble_y = counter[6:5] ^ cell_row[0:0];

  wire signed [10:0] wpx = $signed({1'b0, cell_px_x}) - $signed({1'b0, eff_wobble_x});
  wire signed [10:0] wpy = $signed({1'b0, cell_px_y}) - $signed({1'b0, eff_wobble_y});

  wire in_char = in_grid_y && (wpx >= 0) && (wpx < CHAR_W) && (wpy >= 0) && (wpy < CHAR_H);
  wire [2:0] font_col = 4 - (wpx[4:0] / SCALE);
  wire [2:0] font_row = wpy[4:0] / SCALE;

  // ---- Pseudorandom Digits for Grid ----
  localparam [15:0] SEED = 16'hDEAD;
  function [3:0] cell_digit;
    input [9:0] col; input [9:0] row;
    reg [15:0] s; integer i;
    begin
      s = SEED ^ {col[5:0], row[5:0], 4'hF};
      if (s == 0) s = 16'hFFFF;
      for (i = 0; i < 8; i = i + 1) s = lfsr_next(s);
      cell_digit = (s[3:0] >= 10) ? s[3:0] - 10 : s[3:0];
    end
  endfunction

  wire [3:0] digit_val = cell_digit(cell_col, cell_row);
  wire [4:0] row_pixels;
  font_rom font(.digit(digit_val), .row(font_row), .pixels(row_pixels));

  // ---- Folder-style Bottom Bar (5 Folders) ----
  localparam COMP_W          = 640 / 5; // 128px per folder
  localparam TAB_W           = 40;
  localparam TAB_H           = 8;
  localparam FOLDER_BODY_TOP = 430;
  
  wire [9:0] segment_x      = pix_x % COMP_W;
  wire in_folder_tab        = (pix_y >= (FOLDER_BODY_TOP - TAB_H)) && (pix_y < FOLDER_BODY_TOP) && (segment_x < TAB_W);
  wire in_folder_body       = (pix_y >= FOLDER_BODY_TOP);
  wire in_folder_shape      = in_folder_tab || in_folder_body;

  wire in_folder_border = in_folder_shape && (
    (pix_y == FOLDER_BODY_TOP - TAB_H && in_folder_tab) || 
    (pix_y == 479) || (pix_x == 0) || (pix_x == 639) || (segment_x == 0) ||
    (segment_x == TAB_W && pix_y < FOLDER_BODY_TOP) || 
    (pix_y == FOLDER_BODY_TOP && segment_x > TAB_W)
  );

  // Bottom bar digits
  localparam BAR_DIGIT_MARGIN_X = 10;
  localparam BAR_DIGIT_MARGIN_Y = 5;
  wire [9:0] bar_col   = pix_x / COMP_W;
  wire [9:0] bar_px_x  = pix_x - bar_col * COMP_W - BAR_DIGIT_MARGIN_X;
  wire [9:0] bar_px_y  = pix_y - FOLDER_BODY_TOP - BAR_DIGIT_MARGIN_Y;
  wire in_bar_char     = in_folder_body && (bar_px_x < CHAR_W) && (bar_px_y < CHAR_H);
  wire [3:0] bar_digit_val = bar_col[3:0] + 4'd1;
  wire [4:0] bar_row_pixels;
  font_rom bar_font(.digit(bar_digit_val), .row(bar_px_y[4:0]/SCALE), .pixels(bar_row_pixels));
  wire bar_digit_pixel = in_bar_char && bar_row_pixels[4 - (bar_px_x[4:0]/SCALE)];

// ---- Top Bar (Quarter Width, Left) ----
  localparam TOP_BAR_W   = 580;
  localparam TOP_BAR_H   = 23;   
  
  // This signal is true for EVERY pixel inside the 160x30 area
  wire in_top_rect = (pix_y < TOP_BAR_H) && (pix_x < TOP_BAR_W);

  // ---- Logo Logic (Far Right Edge) ----
  localparam LOGO_W  = 40;
  localparam LOGO_H  = 23;
  localparam LOGO_X0 = 640 - LOGO_W - 4; 
  localparam LOGO_Y0 = (TOP_BAR_H - LOGO_H) / 2; 
  
  wire in_logo_bbox = (pix_y < TOP_BAR_H) && 
                      (pix_x >= LOGO_X0) && (pix_x < LOGO_X0 + LOGO_W) && 
                      (pix_y >= LOGO_Y0) && (pix_y < LOGO_Y0 + LOGO_H);

  wire [9:0] llx_f = in_logo_bbox ? (pix_x - LOGO_X0[9:0]) : 10'd0;
  wire [9:0] lly_f = in_logo_bbox ? (pix_y - LOGO_Y0[9:0]) : 10'd0;

  wire logo_pixel = in_logo_bbox && logo_pixel_at(llx_f[5:0], lly_f[4:0]);

  // ---- Final Pixel Assembly ----
  // We use 'in_top_rect' directly now to create a solid fill
  wire font_pixel = (in_char && row_pixels[font_col]) || 
                    in_folder_border || 
                    bar_digit_pixel || 
                    in_top_rect || 
                    logo_pixel;

  assign R = video_active ? (font_pixel ? 2'b01 : 2'b00) : 2'b00;
  assign G = video_active ? (font_pixel ? 2'b11 : 2'b00) : 2'b00;
  assign B = video_active ? (font_pixel ? 2'b11 : 2'b00) : 2'b00;

  // Function for Logo
  function logo_pixel_at;
    input [5:0] lx; input [4:0] ly;
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

endmodule
