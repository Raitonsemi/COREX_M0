`timescale 1ns / 1ps

module tb_CORTEX_M0_SYS;

  //==============================
  // DUT I/O
  //==============================
  reg         CLK;
  reg         RESET;
  reg         RsRx;
  reg  [7:0]  sw;
  wire [2:0]  vgaRed;
  wire [2:0]  vgaGreen;
  wire [1:0]  vgaBlue;
  wire        Hsync;
  wire        Vsync;
  wire        RsTx;
  wire [6:0]  seg;
  wire        dp;
  wire [3:0]  an;

  // Debug I/Os
  reg         TDI;
  reg         TCK;
  wire        TDO;

  //==============================
  // Parameters
  //==============================
  localparam CLK_PERIOD_NS = 10;       // 100 MHz

// ============================================================
// UART MONITOR TASK
// Monitors the UART TX line (idle high) and prints decoded chars
// Compatible with your AHBUART (8N1, fixed baud = 19200 or faster)
// ============================================================

task automatic uart_monitor(input tx_line);
    real baud_rate, bit_time;
    integer i;
    reg [7:0] rx_byte;
    begin
      baud_rate = 19200;
      bit_time = 1.0e9 / baud_rate;
      $display("[UART MONITOR] Started at %0t ns (baud=%0f, bit=%0f ns)",
               $time, baud_rate, bit_time);
      forever begin
        @(negedge tx_line);
        #(bit_time * 0.5);
        if (tx_line !== 1'b0) continue;
        #(bit_time);
        rx_byte = 0;
        for (i = 0; i < 8; i++) begin
          rx_byte[i] = tx_line;
          #(bit_time);
        end
        #(bit_time);
        if (rx_byte >= 8'h20 && rx_byte < 8'h7F)
          $write("%s", rx_byte);
        else if (rx_byte == 8'h0A)
          $write("\n");
        else if (rx_byte == 8'h04)
          $display("\n[UART MONITOR] End-of-simulation (0x04)");
        else
          $write("[0x%02h]", rx_byte);
      end
    end
  endtask

  //==============================
  // Clock Generation
  //==============================
  initial CLK = 0;
  always #(CLK_PERIOD_NS/2) CLK = ~CLK;

  //==============================
  // DUT Instantiation
  //==============================
  CORTEX_M0_SYS u_SOC (
    .CLK      (CLK),
    .RESET    (RESET),
    .vgaRed   (vgaRed),
    .vgaGreen (vgaGreen),
    .vgaBlue  (vgaBlue),
    .Hsync    (Hsync),
    .Vsync    (Vsync),
    .RsRx     (RsRx),
    .RsTx     (RsTx),
    .sw       (sw),
    .seg      (seg),
    .dp       (dp),
    .an       (an),
    .TDI      (TDI),
    .TCK      (TCK)
    // .TDO    (TDO)
  );

  //==============================
  // Reset Logic
  //==============================
  initial begin
    RESET = 0;
    RsRx  = 1'b1; // idle
    TDI   = 0;
    TCK   = 0;
    sw    = 8'h00;
    #100;
    RESET = 1;
  end

  //==============================
  // Switch Input Stimulus
  //==============================
  initial begin
    #200;
    forever begin
      #10000 sw = $random;
    end
  end


initial begin
  // Start UART monitor in parallel
  fork
    uart_monitor(RsTx);
  join_none
end


  //==============================
  // Simulation Control
  //==============================
  initial begin
    $display("==== Simulation Started ====");
    #100ms; // adjust duration
    $error("\n==== ERROR WATCHDOG TIMED OUT !!! ====");
    $finish;
  end

  //==============================
  // VCD Dump
  //==============================
  initial begin
    $dumpfile("CORTEX_M0_SYS_tb.vcd");
    $dumpvars(0, tb_CORTEX_M0_SYS);
  end

  // Program memory preload
  initial begin
    $readmemh("code.hex", tb_CORTEX_M0_SYS.u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory);
    $display("[TB] code.hex loaded into %m at time %0t", $time);
    #1000;
    $display("[TB] memory[0]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[0]);
    $display("[TB] memory[1]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[1]);
    $display("[TB] memory[2]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[2]);
    $display("[TB] memory[3]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[3]);
    $display("[TB] memory[4]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[4]);
    $display("[TB] memory[5]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[5]);
    $display("[TB] memory[6]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[6]);
    $display("[TB] memory[7]=%h", u_SOC.uAHB2RAM_PROGRAM_MEMORY.memory[7]);
  end

/*
initial begin
  $monitor("%t %m HADDR=%h HWRITE=%b HWDATA=%h HRDATA=%h HRESETn=%b HREADY=%b LOCKUP=%b SYSRESETREQ=%b",
           $time,
           u_SOC.u_CORTEXM0INTEGRATION.HADDR,
           u_SOC.u_CORTEXM0INTEGRATION.HWRITE,
           u_SOC.u_CORTEXM0INTEGRATION.HWDATA,
           u_SOC.u_CORTEXM0INTEGRATION.HRDATA,
           u_SOC.u_CORTEXM0INTEGRATION.HRESETn,
           u_SOC.u_CORTEXM0INTEGRATION.HREADY,
           u_SOC.lockup,
           u_SOC.sys_reset_req);
end


// ============================================================
// AHB Decoder Monitor - Observes address decode behavior
// ============================================================
always @(u_SOC.uAHBDCD.HADDR or
         u_SOC.uAHBDCD.HSEL_S0 or
         u_SOC.uAHBDCD.HSEL_S1 or
         u_SOC.uAHBDCD.HSEL_S4 or
         u_SOC.uAHBDCD.HSEL_S8 or
         u_SOC.uAHBDCD.HSEL_S9 or
         u_SOC.uAHBDCD.MUX_SEL)
begin
	
  $display("[%0t ns] [AHBDCD] HADDR=0x%08h | S0=%b S1=%b S4=%b S8=%b S9=%b | MUX_SEL=%0h",
           $time,
           u_SOC.uAHBDCD.HADDR,
           u_SOC.uAHBDCD.HSEL_S0,
           u_SOC.uAHBDCD.HSEL_S1,
           u_SOC.uAHBDCD.HSEL_S4,
           u_SOC.uAHBDCD.HSEL_S8,
           u_SOC.uAHBDCD.HSEL_S9,
           u_SOC.uAHBDCD.MUX_SEL);
end

// ============================================================
// AHB MUX Monitor - Monitors return data path to the CPU
// ============================================================
always @(
  u_SOC.uAHBMUX.MUX_SEL or
  u_SOC.uAHBMUX.HRDATA_S0 or
  u_SOC.uAHBMUX.HRDATA_S1 or
  u_SOC.uAHBMUX.HRDATA_S4 or
  u_SOC.uAHBMUX.HRDATA_S8 or
  u_SOC.uAHBMUX.HRDATA_S9 or
  u_SOC.uAHBMUX.HRDATA or
  u_SOC.uAHBMUX.HREADY
) begin
  $display("[%0t ns] [AHBMUX] MUX_SEL=%0h | HRDATA=%08h | HREADY=%b | HRDATA_S0=%08h HRDATA_S1=%08h HRDATA_S4=%08h HRDATA_S8=%08h HRDATA_S9=%08h",
           $time,
           u_SOC.uAHBMUX.MUX_SEL,
           u_SOC.uAHBMUX.HRDATA,
           u_SOC.uAHBMUX.HREADY,
           u_SOC.uAHBMUX.HRDATA_S0,
           u_SOC.uAHBMUX.HRDATA_S1,
           u_SOC.uAHBMUX.HRDATA_S4,
           u_SOC.uAHBMUX.HRDATA_S8,
           u_SOC.uAHBMUX.HRDATA_S9);
end


always @(posedge u_SOC.fclk) begin
  if (u_SOC.uAHB2RAM_PROGRAM_MEMORY.HSEL && u_SOC.uAHB2RAM_PROGRAM_MEMORY.HTRANS[1]) begin
    if (u_SOC.uAHB2RAM_PROGRAM_MEMORY.HWRITE)
      $display("[%0t] MEM WRITE Addr=%08h Data=%08h", $time, u_SOC.uAHB2RAM_PROGRAM_MEMORY.HADDR, u_SOC.uAHB2RAM_PROGRAM_MEMORY.HWDATA);
    else
      $display("[%0t] MEM READ  Addr=%08h -> Data=%08h", $time, u_SOC.uAHB2RAM_PROGRAM_MEMORY.HADDR, u_SOC.uAHB2RAM_PROGRAM_MEMORY.HRDATA);
  end
end

always @(u_SOC.reset_sync_reg or u_SOC.hresetn) begin
  $display("[%0t] reset_sync_reg=%b hresetn=%b", $time, u_SOC.reset_sync_reg, u_SOC.hresetn);
end


initial begin
  $display("=== Clock/Reset monitor ===");
  $display("time(ns) | CLK  clk_div  fclk  reset_n  reset_sync  hresetn");
end
*/


endmodule

