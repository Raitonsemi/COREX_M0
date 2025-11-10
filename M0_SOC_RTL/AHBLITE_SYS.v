module CORTEX_M0_SYS(
    input  wire          CLK,                // Oscillator - 100MHz
    input  wire          RESET,              // Reset

    
   // VGA IO
    output wire    [2:0] vgaRed,
    output wire    [2:0] vgaGreen,
    output wire    [1:0] vgaBlue,
    output wire          Hsync,          // VGA Horizontal Sync
    output wire          Vsync,          // VGA Vertical Sync
   
    // TO UART
    input  wire          RsRx,
    output wire          RsTx,
	
	// Switch Inputs
    input  wire    [7:0] sw,
    
    // 7 Segment display
    output wire    [6:0] seg,
    output wire          dp,
    output wire    [3:0] an,


    
    // Debug
    input  wire          TDI,                // JTAG TDI
    input  wire          TCK,                // SWD Clk / JTAG TCK
    inout  wire          TMS,                // SWD I/O / JTAG TMS
    output wire          TDO                 // SWV     / JTAG TDO
    );

    // Clock
    wire          fclk;                      // Free running clock
    // Reset
    wire          reset_n = RESET;
	
    // Select signals
    wire    [3:0] mux_sel;

    wire          hsel_program_mem;
    wire          hsel_code_mem;
    wire          hsel_led;
    wire          hsel_vga;
    wire          hsel_uart;
    wire          hsel_io_board;

    // Slave read data
    wire   [31:0] hrdata_program_mem;
    wire   [31:0] hrdata_code_mem;
    wire   [31:0] hrdata_led;
    wire   [31:0] hrdata_vga;
    wire   [31:0] hrdata_uart;
    wire   [31:0] hrdata_io_board;

    // Slave hready
    wire          hready_program_mem;
    wire          hready_code_mem;
    wire          hready_led;
    wire          hready_vga;
    wire          hready_uart;
    wire          hready_io_board;

    // CM-DS Sideband signals
    wire          lockup;
    wire          lockup_reset_req;
    wire          sys_reset_req;
    wire          txev;
    wire          sleeping;
    wire  [31:0]  irq;
    reg clk_div;
    
    // Interrupt signals
    assign        irq = {32'b0};
    
    // Clock divider, divide the frequency by two, hence less time constraint 

    always @(posedge CLK)
    begin
        clk_div=~clk_div;
    end
// For simulation, BUFG is not functional — use direct assign
`ifndef SYNTHESIS
  initial clk_div = 1'b0;
  assign fclk = clk_div;
`else
  BUFG BUFG_CLK (
      .O(fclk),
      .I(clk_div)
  );
`endif

    
    // Reset synchronizer
    reg  [4:0]     reset_sync_reg;
    always @(posedge fclk or negedge reset_n)
    begin
        if (!reset_n)
            reset_sync_reg <= 5'b00000;
        else
        begin
            reset_sync_reg[3:0] <= {reset_sync_reg[2:0], 1'b1};
            reset_sync_reg[4] <= reset_sync_reg[2] & (~sys_reset_req);
        end
    end

    // CPU System Bus
    wire          hresetn = reset_sync_reg[4];
    wire   [31:0] haddrs; 
    wire    [2:0] hbursts; 
    wire          hmastlocks; 
    wire    [3:0] hprots; 
    wire    [2:0] hsizes; 
    wire    [1:0] htranss; 
    wire   [31:0] hwdatas; 
    wire          hwrites; 
    wire   [31:0] hrdatas; 
    wire          hreadys; 
    wire    [1:0] hresps = 2'b00;            // System generates no error response
    wire          exresps = 1'b0;

    // Debug signals (TDO pin is used for SWV unless JTAG mode is active)
    wire          dbg_tdo;                   // SWV / JTAG TDO
    wire          dbg_tdo_nen;               // SWV / JTAG TDO tristate enable (active low)
    wire          dbg_swdo;                  // SWD I/O 3-state output
    wire          dbg_swdo_en;               // SWD I/O 3-state enable
    wire          dbg_jtag_nsw;              // SWD in JTAG state (HIGH)
    wire          dbg_swo;                   // Serial wire viewer/output
    wire          tdo_enable     = !dbg_tdo_nen | !dbg_jtag_nsw;
    wire          tdo_tms        = dbg_jtag_nsw         ? dbg_tdo    : dbg_swo;
    assign        TMS            = dbg_swdo_en          ? dbg_swdo   : 1'bz;
    assign        TDO            = tdo_enable           ? tdo_tms    : 1'bz;

    // CoreSight requires a loopback from REQ to ACK for a minimal
    // debug power control implementation
    wire          cpu0cdbgpwrupreq;
    wire          cpu0cdbgpwrupack;
    assign        cpu0cdbgpwrupack = cpu0cdbgpwrupreq;

    // DesignStart simplified integration level
    CORTEXM0INTEGRATION u_CORTEXM0INTEGRATION (
        // CLOCK AND RESETS
        .FCLK          (fclk),               // Free running clock
        .SCLK          (fclk),               // System clock
        .HCLK          (fclk),               // AHB clock
        .DCLK          (fclk),               // Debug system clock
        .PORESETn      (reset_sync_reg[2]),  // Power on reset
        .DBGRESETn     (reset_sync_reg[3]),  // Debug reset
        .HRESETn       (hresetn),            // AHB and System reset

        // AHB-LITE MASTER PORT
        .HADDR         (haddrs),
        .HBURST        (hbursts),
        .HMASTLOCK     (hmastlocks),
        .HPROT         (hprots),
        .HSIZE         (hsizes),
        .HTRANS        (htranss),
        .HWDATA        (hwdatas),
        .HWRITE        (hwrites),
        .HRDATA        (hrdatas),
        .HREADY        (hreadys),
        .HRESP         (hresps),
        .HMASTER       (),

        // CODE SEQUENTIALITY AND SPECULATION
        .CODENSEQ      (),
        .CODEHINTDE    (),
        .SPECHTRANS    (),

        // DEBUG
        .nTRST         (1'b1),
        .SWCLKTCK      (TCK),
        .SWDITMS       (TMS),
        .TDI           (TDI),
        .SWDO          (dbg_swdo),
        .SWDOEN        (dbg_swdo_en),
        .TDO           (dbg_tdo),
        .nTDOEN        (dbg_tdo_nen),
        .DBGRESTART    (1'b0),               // Debug Restart request - Not needed in a single CPU system
        .DBGRESTARTED  (),
        .EDBGRQ        (1'b0),               // External Debug request to CPU
        .HALTED        (),

        // MISC
        .NMI           (1'b0),               // Non-maskable interrupt input
        .IRQ           (irq),                // Interrupt request inputs
        .TXEV          (),                   // Event output (SEV executed)
        .RXEV          (1'b0),               // Event input
        .LOCKUP        (lockup),             // Core is locked-up
        .SYSRESETREQ   (sys_reset_req),      // System reset request
        .STCALIB       ({1'b1,               // No alternative clock source
                         1'b0,               // Exact multiple of 10ms from FCLK
                         24'h007A11F}),      // Calibration value for SysTick for 50 MHz source
        .STCLKEN       (1'b0),               // SysTick SCLK clock disable
        .IRQLATENCY    (8'h00),
        .ECOREVNUM     (28'h0),

        // POWER MANAGEMENT
        .GATEHCLK      (),                   // When high, HCLK can be turned off
        .SLEEPING      (),                   // Core and NVIC sleeping
        .SLEEPDEEP     (),                   // The processor is in deep sleep mode
        .WAKEUP        (),                   // Active HIGH signal from WIC to the PMU that indicates a wake-up event has
                                             // occurred and the system requires clocks and power
        .WICSENSE      (),
        .SLEEPHOLDREQn (1'b1),               // Extend Sleep request
        .SLEEPHOLDACKn (),                   // Acknowledge for SLEEPHOLDREQn
        .WICENREQ      (1'b0),               // Active HIGH request for deep sleep to be WIC-based deep sleep
        .WICENACK      (),                   // Acknowledge for WICENREQ - WIC operation deep sleep mode
        .CDBGPWRUPREQ  (cpu0cdbgpwrupreq),   // Debug Power Domain up request
        .CDBGPWRUPACK  (cpu0cdbgpwrupack),   // Debug Power Domain up acknowledge.

        // SCAN IO
        .SE            (1'b0),               // DFT is tied off in this example
        .RSTBYPASS     (1'b0)                // Reset bypass - active high to disable internal generated reset for testing
    );

    // Address Decoder 
    AHBDCD uAHBDCD (
      .HADDR(haddrs),
     
      .HSEL_S0(hsel_program_mem),
      .HSEL_S1(hsel_code_mem),
      .HSEL_S2(),
      .HSEL_S3(),
      .HSEL_S4(hsel_uart),
      .HSEL_S5(),
      .HSEL_S6(),
      .HSEL_S7(),
      .HSEL_S8(hsel_vga),
      .HSEL_S9(hsel_io_board),
      .HSEL_NOMAP(),
     
      .MUX_SEL(mux_sel[3:0])
    );

    // Slave to Master Mulitplexor
    AHBMUX uAHBMUX (
      .HCLK(fclk),
      .HRESETn(hresetn),
      .MUX_SEL(mux_sel[3:0]),
     
      .HRDATA_S0(hrdata_program_mem),
      .HRDATA_S1(hrdata_code_mem),
      .HRDATA_S2(),
      .HRDATA_S3(),
      .HRDATA_S4(hrdata_uart),
      .HRDATA_S5(),
      .HRDATA_S6(),
      .HRDATA_S7(),
      .HRDATA_S8(hrdata_vga),
      .HRDATA_S9(hrdata_io_board),
      .HRDATA_NOMAP(32'hDEADBEEF),
     
      .HREADYOUT_S0(hready_program_mem),
      .HREADYOUT_S1(hready_code_mem),
      .HREADYOUT_S2(),
      .HREADYOUT_S3(),
      .HREADYOUT_S4(hready_uart),
      .HREADYOUT_S5(),
      .HREADYOUT_S6(1'b1),
      .HREADYOUT_S7(1'b1),
      .HREADYOUT_S8(hready_vga),
      .HREADYOUT_S9(hready_io_board),
      .HREADYOUT_NOMAP(1'b1),
    
      .HRDATA(hrdatas),
      .HREADY(hreadys)
    );

    // AHBLite Peripherals
    
    // AHBLite Memory Controller
    AHB2MEM  #(.MEMWIDTH(20)) uAHB2RAM_PROGRAM_MEMORY (
      //AHBLITE Signals
      .HSEL(hsel_program_mem),
      .HCLK(fclk), 
      .HRESETn(hresetn), 
      .HREADY(hreadys),     
      .HADDR(haddrs),
      .HTRANS(htranss), 
      .HWRITE(hwrites),
      .HSIZE(hsizes),
      .HWDATA(hwdatas), 
      .HRDATA(hrdata_program_mem), 
      .HREADYOUT(hready_program_mem)
    );

       AHB2MEM  #(.MEMWIDTH(16)) uAHB2RAM_CODE_MEMORY (
      //AHBLITE Signals
      .HSEL(hsel_code_mem),
      .HCLK(fclk), 
      .HRESETn(hresetn), 
      .HREADY(hreadys),     
      .HADDR(haddrs),
      .HTRANS(htranss), 
      .HWRITE(hwrites),
      .HSIZE(hsizes),
      .HWDATA(hwdatas), 
      .HRDATA(hrdata_code_mem), 
      .HREADYOUT(hready_code_mem)
    );
            
    
  // AHBLite VGA Controller  
    AHBVGA uAHBVGA (
        .HCLK(fclk), 
        .HRESETn(hresetn), 
        .HADDR(haddrs), 
        .HWDATA(hwdatas), 
        .HREADY(hreadys), 
        .HWRITE(hwrites), 
        .HTRANS(htranss), 
        .HSEL(hsel_vga), 
        .HRDATA(hrdata_vga), 
        .HREADYOUT(hready_vga), 
        .hsync(Hsync), 
        .vsync(Vsync), 
        .rgb({vgaRed,vgaGreen,vgaBlue})
    );
    
      // AHBLite UART Peripheral 
AHB_PRINTBUF uAHB_PRINTBUF (
    .HCLK(fclk),
    .HRESETn(hresetn),
    .HADDR(haddrs),
    .HTRANS(htranss),
    .HWDATA(hwdatas),
    .HWRITE(hwrites),
    .HREADY(hreadys),
    .HREADYOUT(hready_uart),
    .HRDATA(hrdata_uart),
    .HSEL(hsel_uart)
);


        
 
    
endmodule
