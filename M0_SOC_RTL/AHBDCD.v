// -----------------------------------------------------------------
//                       AHB-Lite Decoder 
// -----------------------------------------------------------------
//

module AHBDCD(
  input  wire [31:0] HADDR,   // AHB address bus
  output wire HSEL_S0,        // ROM / Flash
  output wire HSEL_S1,        // SRAM
  output wire HSEL_S2,        // TIMER0
  output wire HSEL_S3,        // TIMER1 (optional)
  output wire HSEL_S4,        // UART0
  output wire HSEL_S5,        // GPIO0
  output wire HSEL_S6,        // SYSCON
  output wire HSEL_S7,        // Reserved / Future
  output wire HSEL_S8,        // Reserved / Future
  output wire HSEL_S9,        // IO board
  output wire HSEL_NOMAP,     // Unmapped address
  output reg  [3:0] MUX_SEL
);

reg [15:0] dec;

// -----------------------------------------------------------------
// AHB Decode Logic (CMSDK-Compliant Memory Map)
//
//   0x0000_0000 - 0x000F_FFFF : ROM (S0)
//   0x2000_0000 - 0x2000_FFFF : SRAM (S1)
//   0x4000_2000 - 0x4000_2FFF : TIMER0 (S2)
//   0x4000_3000 - 0x4000_3FFF : TIMER1 (S3)
//   0x4000_4000 - 0x4000_4FFF : UART0 (S4)
//   0x4001_0000 - 0x4001_0FFF : GPIO0 (S5)
//   0x400F_0000 - 0x400F_0FFF : SYSCON (S6)
//   0x5000_0000 - 0x58FF_FFFF : IO board (S9)
// -----------------------------------------------------------------

assign HSEL_S0 = dec[0];  // ROM
assign HSEL_S1 = dec[1];  // SRAM
assign HSEL_S2 = dec[2];  // TIMER0
assign HSEL_S3 = dec[3];  // TIMER1
assign HSEL_S4 = dec[4];  // UART0
assign HSEL_S5 = dec[5];  // GPIO0
assign HSEL_S6 = dec[6];  // SYSCON
assign HSEL_S7 = dec[7];  // Reserved
assign HSEL_S8 = dec[8];  // Reserved
assign HSEL_S9 = dec[9];  // IO board 
assign HSEL_NOMAP = dec[15]; // Default / unmapped region

always @* begin
  // Default: no select
  dec      = 16'b1000_0000_0000_0000; // default to NOMAP
  MUX_SEL  = 4'b1111;

  // Decode based on HADDR
  casez (HADDR[31:12])
    20'h0000?: begin  // ROM / Flash
      dec     = 16'b0000_0000_0000_0001;
      MUX_SEL = 4'b0000;
    end

    20'h2000?: begin  // SRAM
      dec     = 16'b0000_0000_0000_0010;
      MUX_SEL = 4'b0001;
    end

    20'h40002: begin  // TIMER0
      dec     = 16'b0000_0000_0000_0100;
      MUX_SEL = 4'b0010;
    end

    20'h40003: begin  // TIMER1
      dec     = 16'b0000_0000_0000_1000;
      MUX_SEL = 4'b0011;
    end

    20'h40004: begin  // UART0
      dec     = 16'b0000_0000_0001_0000;
      MUX_SEL = 4'b0100;
    end

    20'h40010: begin  // GPIO0
      dec     = 16'b0000_0000_0010_0000;
      MUX_SEL = 4'b0101;
    end

    20'h400F0: begin  // SYSCON
      dec     = 16'b0000_0000_0100_0000;
      MUX_SEL = 4'b0110;
    end

    20'h50000: begin  // IO board
      dec     = 16'b0000_0000_1000_0000;
      MUX_SEL = 4'b0111;
    end

    default: begin
      dec     = 16'b1000_0000_0000_0000;
      MUX_SEL = 4'b1111;
    end
  endcase
end

endmodule

