// ---------------------------------------------------------------------------
// AHB_PRINTBUF - AHB-lite UART/Print buffer substitute with proper data phase
// ---------------------------------------------------------------------------

module AHB_PRINTBUF (
    input  wire         HCLK,
    input  wire         HRESETn,
    input  wire  [31:0] HADDR,
    input  wire  [1:0]  HTRANS,
    input  wire  [31:0] HWDATA,
    input  wire         HWRITE,
    input  wire         HREADY,
    output wire         HREADYOUT,
    output wire [31:0]  HRDATA,
    input  wire         HSEL
);

  // Internal storage
  reg [7:0] mem [0:255];
  integer wr_ptr;

  // AHB handshake
  assign HREADYOUT = 1'b1;
  assign HRDATA    = 32'h0;

  // ---------------------------------------------------------------
  // Phase pipeline — latch address phase signals for next data phase
  // ---------------------------------------------------------------
  reg [31:0] addr_reg;
  reg [1:0]  trans_reg;
  reg        write_reg;
  reg        sel_reg;

  always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      addr_reg  <= 32'h0;
      trans_reg <= 2'b00;
      write_reg <= 1'b0;
      sel_reg   <= 1'b0;
    end else if (HREADY) begin
      addr_reg  <= HADDR;
      trans_reg <= HTRANS;
      write_reg <= HWRITE;
      sel_reg   <= HSEL;
    end
  end

  // ---------------------------------------------------------------
  // Byte extraction (lane-insensitive)
  // ---------------------------------------------------------------
  wire [7:0] byte0 = HWDATA[7:0];
  wire [7:0] byte1 = HWDATA[15:8];
  wire [7:0] byte2 = HWDATA[23:16];
  wire [7:0] byte3 = HWDATA[31:24];

  reg [7:0] active_byte;
  always @(*) begin
    if (byte0 != 8'h00)
      active_byte = byte0;
    else if (byte1 != 8'h00)
      active_byte = byte1;
    else if (byte2 != 8'h00)
      active_byte = byte2;
    else
      active_byte = byte3;
  end

  // ---------------------------------------------------------------
  // Write sampling - use *latched* address phase, current data phase
  // ---------------------------------------------------------------
  always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      wr_ptr <= 0;
    end else if (sel_reg && trans_reg[1] && write_reg && (addr_reg[7:0] == 8'h00)) begin
      mem[wr_ptr] <= active_byte;
      wr_ptr <= wr_ptr + 1;

      if (active_byte >= 8'h20 && active_byte < 8'h7F)
        $write("%s", active_byte);
      else if (active_byte == 8'h0A)
        $write("\n");
      else if (active_byte == 8'h04) begin
        $display("\n[PRINTBUF] End of transmission (0x04) at %0t ns", $time);
        $finish;
      end else
        $write("[0x%02h]", active_byte);
    end
  end

endmodule

