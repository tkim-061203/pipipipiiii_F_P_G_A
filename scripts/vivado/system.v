`timescale 1 ns / 1 ps
// ============================================================
// PicoSoC — AXI System Bus + APB Peripheral Bus
// ============================================================
// MEMORY MAP (firmware-compatible)
//   0x0000_0000 – 0x0000_0FFF  Boot BRAM  4 KB  (RO, on APB)
//   0x0001_0000 – 0x0001_3FFF  App  BRAM 16 KB  (RW, on AXI)
//   0x1000_0000                LED  out_byte     W
//   0x1000_0004                UART TX Data      W
//   0x1000_0008                UART RX Data      R
//   0x1000_000C                UART Status       R
//   0x1000_0010                UART Baud Divider R/W
//   0x2000_0000                Switches          R
//   0x2000_0004                Buttons           R
//   0x3000_0000 – 0x3000_0060  TinyJAMBU         R/W
//   0x4000_0000 – 0x4000_0074  Xoodyak           R/W
//   0x5000_0000 – 0x5000_0078  GIFT-COFB         R/W
//   0x6000_0000 – 0x6000_000C  SD SPI Master     R/W
// ============================================================

module system (
    input            clk,
    input            resetn_btn,
    output           trap,
    output reg [7:0] out_byte,
    output reg       out_byte_en,
    input      [3:0] sw,
    input      [3:0] btn,
    output           uart_tx,
    input            uart_rx,
    output           sd_cs_n,
    output           sd_sck,
    output           sd_mosi,
    input            sd_miso
);
    parameter BOOT_SIZE = 1024;   // 4 KB in words
    parameter APP_SIZE  = 4096;   // 16 KB in words

    // --------------------------------------------------------
    // Power-on reset
    // --------------------------------------------------------
    reg [5:0] reset_cnt = 0;
    reg [2:0] resetn_sync = 3'b000;

    always @(posedge clk)
        resetn_sync <= {resetn_sync[1:0], resetn_btn};

    always @(posedge clk) begin
        if (!resetn_sync[2] && (&reset_cnt))
            reset_cnt <= 0;
        else if (!(&reset_cnt))
            reset_cnt <= reset_cnt + 1;
    end

    wire resetn = &reset_cnt;

    // --------------------------------------------------------
    // Switch / Button synchroniser
    // --------------------------------------------------------
    reg [3:0] sw_sync1, sw_sync2;
    reg [3:0] btn_sync1, btn_sync2;

    always @(posedge clk) begin
        sw_sync1  <= sw;        sw_sync2  <= sw_sync1;
        btn_sync1 <= btn;       btn_sync2 <= btn_sync1;
    end

    // --------------------------------------------------------
    // UART
    // --------------------------------------------------------
    wire        uart_dat_wait;
    wire [31:0] uart_dat_do;
    wire [31:0] uart_div_do;
    wire uart_rx_valid = (uart_dat_do != 32'hFFFF_FFFF);

    reg        uart_we;
    reg        uart_rx_rd;
    reg  [7:0] uart_tx_data;
    reg  [3:0] uart_div_we;
    reg [31:0] uart_div_di;
    reg        tx_busy;
    reg [15:0] tx_countdown;
    wire uart_tx_ready = !tx_busy;

    simpleuart #(.DEFAULT_DIV(868)) uart_inst (
        .clk        (clk),
        .resetn     (resetn),
        .ser_tx     (uart_tx),
        .ser_rx     (uart_rx),
        .reg_div_we (uart_div_we),
        .reg_div_di (uart_div_di),
        .reg_div_do (uart_div_do),
        .reg_dat_we (uart_we),
        .reg_dat_re (uart_rx_rd),
        .reg_dat_di ({24'b0, uart_tx_data}),
        .reg_dat_do (uart_dat_do),
        .reg_dat_wait(uart_dat_wait)
    );

    // --------------------------------------------------------
    // SD SPI Master
    // --------------------------------------------------------
    reg  [7:0] sdspi_tx_data;
    reg [15:0] sdspi_clkdiv;
    reg        sdspi_start;
    reg        sdspi_cs_n_reg;
    reg        sdspi_done_sticky;
    reg  [7:0] sdspi_rx_data_reg;
    wire [7:0] sdspi_rx_data;
    wire       sdspi_busy;
    wire       sdspi_done;

    simple_spi_master u_sdspi (
        .clk      (clk),
        .resetn   (resetn),
        .start    (sdspi_start),
        .tx_data  (sdspi_tx_data),
        .clkdiv   (sdspi_clkdiv),
        .cs_n     (sdspi_cs_n_reg),
        .rx_data  (sdspi_rx_data),
        .busy     (sdspi_busy),
        .done     (sdspi_done),
        .spi_sck  (sd_sck),
        .spi_mosi (sd_mosi),
        .spi_miso (sd_miso),
        .spi_cs_n (sd_cs_n)
    );

    always @(posedge clk) begin
        if (!resetn) begin
            sdspi_done_sticky <= 0;
            sdspi_rx_data_reg <= 8'hFF;
        end else begin
            if (sdspi_start)  sdspi_done_sticky <= 0;
            if (sdspi_done) begin
                sdspi_done_sticky <= 1;
                sdspi_rx_data_reg <= sdspi_rx_data;
            end
        end
    end

    // --------------------------------------------------------
    // TinyJAMBU (APB slave @ 0x3000_0000)
    // --------------------------------------------------------
    reg [127:0] jb_key;
    reg [ 95:0] jb_nonce;
    reg [127:0] jb_ad, jb_data_in;
    reg [ 63:0] jb_tag_in;
    reg [  4:0] jb_ad_length, jb_data_length;
    reg [  2:0] jb_sel_type;
    reg         jb_ena;
    reg         jb_done_sticky, jb_valid_sticky;

    wire [127:0] jb_data_out;
    wire [ 63:0] jb_tag_out;
    wire         jb_valid, jb_done;

    tinyjambu_core u_jambu (
`ifdef USE_POWER_PINS
        .VPWR(VPWR), .VGND(VGND),
`endif
        .clk(clk), .rst_n(resetn),
        .ena(jb_ena), .sel_type(jb_sel_type),
        .key(jb_key), .nonce(jb_nonce),
        .ad(jb_ad), .ad_length(jb_ad_length),
        .data_length(jb_data_length),
        .data_in(jb_data_in), .tag_in(jb_tag_in),
        .data_out(jb_data_out), .tag(jb_tag_out),
        .valid(jb_valid), .done(jb_done)
    );

    always @(posedge clk) begin
        if      (!resetn) begin jb_done_sticky<=0; jb_valid_sticky<=0; end
        else if (jb_ena)  begin jb_done_sticky<=0; jb_valid_sticky<=0; end
        else if (jb_done) begin jb_done_sticky<=1; jb_valid_sticky<=jb_valid; end
    end

    // --------------------------------------------------------
    // Xoodyak (APB slave @ 0x4000_0000)
    // --------------------------------------------------------
    reg [127:0] xd_key, xd_nonce, xd_ad, xd_data_in, xd_tag_in;
    reg [  4:0] xd_ad_length, xd_data_length;
    reg [  1:0] xd_sel_type;
    reg         xd_ena;
    reg         xd_done_sticky, xd_valid_sticky;

    wire [127:0] xd_data_out, xd_tag_out;
    wire         xd_valid, xd_done;

    xoodyakcore u_xoodyak (
`ifdef USE_POWER_PINS
        .VPWR(VPWR), .VGND(VGND),
`endif
        .clk(clk), .rst_n(resetn),
        .ena(xd_ena), .restart(1'b0),
        .sel_type(xd_sel_type),
        .key(xd_key), .nonce(xd_nonce),
        .ad(xd_ad), .ad_length(xd_ad_length),
        .data_length(xd_data_length),
        .data_in(xd_data_in), .tag_in(xd_tag_in),
        .valid(xd_valid), .tag(xd_tag_out),
        .data_out(xd_data_out), .done(xd_done)
    );

    always @(posedge clk) begin
        if      (!resetn) begin xd_done_sticky<=0; xd_valid_sticky<=0; end
        else if (xd_ena)  begin xd_done_sticky<=0; xd_valid_sticky<=0; end
        else if (xd_done) begin xd_done_sticky<=1; xd_valid_sticky<=xd_valid; end
    end

    // --------------------------------------------------------
    // GIFT-COFB (APB slave @ 0x5000_0000)
    // --------------------------------------------------------
    reg [127:0] gc_key, gc_nonce, gc_ad, gc_data_in, gc_tag_in;
    reg [  7:0] gc_ad_length, gc_data_length;
    reg         gc_decrypt_mode;
    reg         gc_start;
    reg         gc_ad_ack, gc_msg_ack;
    reg         gc_done_sticky, gc_valid_sticky;

    wire [127:0] gc_data_out, gc_tag_out;
    wire         gc_valid, gc_done;
    wire         gc_ad_req, gc_msg_req;
    wire         gc_data_out_valid;

    cofb_core u_giftcofb (
`ifdef USE_POWER_PINS
        .VPWR(VPWR), .VGND(VGND),
`endif
        .clk(clk), .rst_n(resetn),
        .start(gc_start), .decrypt_mode(gc_decrypt_mode),
        .key(gc_key), .nonce(gc_nonce),
        .ad_data(gc_ad), .ad_total_len(gc_ad_length),
        .ad_ack(gc_ad_ack),
        .msg_data(gc_data_in), .msg_total_len(gc_data_length),
        .msg_ack(gc_msg_ack),
        .tag_in(gc_tag_in),
        .ad_req(gc_ad_req), .msg_req(gc_msg_req),
        .data_out(gc_data_out), .data_out_valid(gc_data_out_valid),
        .tag_out(gc_tag_out),
        .valid(gc_valid), .done(gc_done)
    );

    always @(posedge clk) begin
        if      (!resetn)  begin gc_done_sticky<=0; gc_valid_sticky<=0; end
        else if (gc_start) begin gc_done_sticky<=0; gc_valid_sticky<=0; end
        else if (gc_done)  begin gc_done_sticky<=1; gc_valid_sticky<=gc_valid; end
    end

    // --------------------------------------------------------
    // Memory (BRAM)
    // --------------------------------------------------------
    reg [31:0] boot_mem [0:BOOT_SIZE-1];
    initial $readmemh("bootloader.hex", boot_mem);
    reg [31:0] app_mem [0:APP_SIZE-1];

    // ========================================================
    // PicoRV32 CPU — AXI4-Lite Master
    // ========================================================
    wire        cpu_awvalid, cpu_wvalid, cpu_arvalid;
    wire [31:0] cpu_awaddr, cpu_wdata, cpu_araddr;
    wire [ 3:0] cpu_wstrb;
    wire [ 2:0] cpu_awprot, cpu_arprot;
    wire        cpu_bready, cpu_rready;

    // To CPU (from interconnect)
    wire        cpu_awready, cpu_wready, cpu_bvalid;
    wire        cpu_arready, cpu_rvalid;
    wire [31:0] cpu_rdata;

    picorv32_axi cpu (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_axi_awvalid(cpu_awvalid), .mem_axi_awready(cpu_awready),
        .mem_axi_awaddr (cpu_awaddr),  .mem_axi_awprot (cpu_awprot),
        .mem_axi_wvalid (cpu_wvalid),  .mem_axi_wready (cpu_wready),
        .mem_axi_wdata  (cpu_wdata),   .mem_axi_wstrb  (cpu_wstrb),
        .mem_axi_bvalid (cpu_bvalid),  .mem_axi_bready (cpu_bready),
        .mem_axi_arvalid(cpu_arvalid), .mem_axi_arready(cpu_arready),
        .mem_axi_araddr (cpu_araddr),  .mem_axi_arprot (cpu_arprot),
        .mem_axi_rvalid (cpu_rvalid),  .mem_axi_rready (cpu_rready),
        .mem_axi_rdata  (cpu_rdata),
        // PCPI — unused
        .pcpi_wr(1'b0), .pcpi_rd(32'b0),
        .pcpi_wait(1'b0), .pcpi_ready(1'b0),
        // IRQ — unused
        .irq(32'b0),
        // Trace — unused
        .trace_valid(), .trace_data()
    );

    // ========================================================
    // AXI INTERCONNECT — 1 Master × 2 Slaves
    // ========================================================
    // Slave 0 = RAM  (addr[31:16] == 0x0001)
    // Slave 1 = APB  (everything else)

    wire [31:0] decode_addr = cpu_awvalid ? cpu_awaddr : cpu_araddr;
    wire decode_is_ram = (decode_addr[31:16] == 16'h0001);

    // Track which slave owns the in-flight transaction
    reg  active_is_ram;
    reg  txn_active;
    always @(posedge clk) begin
        if (!resetn) begin
            txn_active <= 0;
        end else begin
            if (!txn_active && (cpu_awvalid || cpu_arvalid)) begin
                active_is_ram <= decode_is_ram;
                txn_active    <= 1;
            end
            if (txn_active && ((cpu_bvalid && cpu_bready) ||
                               (cpu_rvalid && cpu_rready)))
                txn_active <= 0;
        end
    end

    wire is_ram = txn_active ? active_is_ram : decode_is_ram;

    // --- RAM slave AXI signals ---
    wire ram_awready, ram_wready, ram_bvalid;
    wire ram_arready, ram_rvalid;
    wire [31:0] ram_rdata;

    // --- Bridge AXI signals ---
    wire brg_awready, brg_wready, brg_bvalid;
    wire brg_arready, brg_rvalid;
    wire [31:0] brg_rdata;

    // Mux responses back to CPU
    assign cpu_awready = is_ram ? ram_awready : brg_awready;
    assign cpu_wready  = is_ram ? ram_wready  : brg_wready;
    assign cpu_bvalid  = is_ram ? ram_bvalid  : brg_bvalid;
    assign cpu_arready = is_ram ? ram_arready : brg_arready;
    assign cpu_rvalid  = is_ram ? ram_rvalid  : brg_rvalid;
    assign cpu_rdata   = is_ram ? ram_rdata   : brg_rdata;

    // Gated valids to each slave
    wire ram_i_awv = cpu_awvalid &  is_ram;
    wire ram_i_wv  = cpu_wvalid  &  is_ram;
    wire ram_i_arv = cpu_arvalid &  is_ram;
    wire brg_i_awv = cpu_awvalid & ~is_ram;
    wire brg_i_wv  = cpu_wvalid  & ~is_ram;
    wire brg_i_arv = cpu_arvalid & ~is_ram;

    // ========================================================
    // AXI SLAVE 0 — RAM (App BRAM 16 KB)
    // ========================================================
    reg        ram_bvalid_r, ram_rvalid_r;
    reg [31:0] ram_rdata_r;

    wire ram_wr_accept = ram_i_awv && ram_i_wv && !ram_bvalid_r;
    wire ram_rd_accept = ram_i_arv && !ram_rvalid_r;

    assign ram_awready = ram_wr_accept;
    assign ram_wready  = ram_wr_accept;
    assign ram_bvalid  = ram_bvalid_r;
    assign ram_arready = ram_rd_accept;
    assign ram_rvalid  = ram_rvalid_r;
    assign ram_rdata   = ram_rdata_r;

    always @(posedge clk) begin
        if (!resetn) begin
            ram_bvalid_r <= 0;
            ram_rvalid_r <= 0;
        end else begin
            // Clear on handshake
            if (ram_bvalid_r && cpu_bready) ram_bvalid_r <= 0;
            if (ram_rvalid_r && cpu_rready) ram_rvalid_r <= 0;
            // Write
            if (ram_wr_accept) begin
                if (cpu_wstrb[0]) app_mem[(cpu_awaddr-32'h0001_0000)>>2][ 7: 0] <= cpu_wdata[ 7: 0];
                if (cpu_wstrb[1]) app_mem[(cpu_awaddr-32'h0001_0000)>>2][15: 8] <= cpu_wdata[15: 8];
                if (cpu_wstrb[2]) app_mem[(cpu_awaddr-32'h0001_0000)>>2][23:16] <= cpu_wdata[23:16];
                if (cpu_wstrb[3]) app_mem[(cpu_awaddr-32'h0001_0000)>>2][31:24] <= cpu_wdata[31:24];
                ram_bvalid_r <= 1;
            end
            // Read
            if (ram_rd_accept) begin
                ram_rdata_r  <= app_mem[(cpu_araddr - 32'h0001_0000) >> 2];
                ram_rvalid_r <= 1;
            end
        end
    end

    // ========================================================
    // AXI SLAVE 1 — AXI-to-APB Bridge
    // ========================================================
    localparam BRG_IDLE   = 2'd0;
    localparam BRG_SETUP  = 2'd1;
    localparam BRG_ACCESS = 2'd2;

    reg [1:0]  brg_state;
    reg        brg_bvalid_r, brg_rvalid_r;
    reg [31:0] brg_rdata_r;

    // APB master outputs (directly from bridge regs)
    reg        apb_psel, apb_penable, apb_pwrite;
    reg [31:0] apb_paddr, apb_pwdata;

    wire [31:0] apb_prdata;            // muxed from peripherals
    wire        apb_pready = 1'b1;     // all slaves: no wait

    wire brg_aw_acc = (brg_state == BRG_IDLE) && brg_i_awv && brg_i_wv && !brg_bvalid_r;
    wire brg_ar_acc = (brg_state == BRG_IDLE) && brg_i_arv && !brg_rvalid_r && !brg_aw_acc;

    assign brg_awready = brg_aw_acc;
    assign brg_wready  = brg_aw_acc;
    assign brg_arready = brg_ar_acc;
    assign brg_bvalid  = brg_bvalid_r;
    assign brg_rvalid  = brg_rvalid_r;
    assign brg_rdata   = brg_rdata_r;

    always @(posedge clk) begin
        if (!resetn) begin
            brg_state    <= BRG_IDLE;
            brg_bvalid_r <= 0;
            brg_rvalid_r <= 0;
            apb_psel     <= 0;
            apb_penable  <= 0;
        end else begin
            // Clear completed responses
            if (brg_bvalid_r && cpu_bready) brg_bvalid_r <= 0;
            if (brg_rvalid_r && cpu_rready) brg_rvalid_r <= 0;

            case (brg_state)
                BRG_IDLE: begin
                    if (brg_aw_acc) begin
                        apb_psel    <= 1;
                        apb_penable <= 0;
                        apb_pwrite  <= 1;
                        apb_paddr   <= cpu_awaddr;
                        apb_pwdata  <= cpu_wdata;
                        brg_state   <= BRG_SETUP;
                    end else if (brg_ar_acc) begin
                        apb_psel    <= 1;
                        apb_penable <= 0;
                        apb_pwrite  <= 0;
                        apb_paddr   <= cpu_araddr;
                        brg_state   <= BRG_SETUP;
                    end
                end

                BRG_SETUP: begin
                    // APB SETUP phase visible (PSEL=1, PENABLE=0)
                    apb_penable <= 1;
                    brg_state   <= BRG_ACCESS;
                end

                BRG_ACCESS: begin
                    // APB ACCESS phase visible (PSEL=1, PENABLE=1)
                    apb_psel    <= 0;
                    apb_penable <= 0;
                    if (apb_pwrite)
                        brg_bvalid_r <= 1;
                    else begin
                        brg_rvalid_r <= 1;
                        brg_rdata_r  <= apb_prdata;
                    end
                    brg_state <= BRG_IDLE;
                end
            endcase
        end
    end

    // ========================================================
    // APB INTERCONNECT — Address decode
    // ========================================================
    wire psel_rom   = apb_psel && (apb_paddr[31:28] == 4'h0);
    wire psel_uart  = apb_psel && (apb_paddr[31:28] == 4'h1);
    wire psel_input = apb_psel && (apb_paddr[31:28] == 4'h2);
    wire psel_jambu = apb_psel && (apb_paddr[31:28] == 4'h3);
    wire psel_xdy   = apb_psel && (apb_paddr[31:28] == 4'h4);
    wire psel_gcofb = apb_psel && (apb_paddr[31:28] == 4'h5);
    wire psel_sdspi = apb_psel && (apb_paddr[31:28] == 4'h6);

    // ========================================================
    // APB READ DATA — Boot ROM (registered in SETUP phase)
    // ========================================================
    reg [31:0] rom_rdata_r;
    always @(posedge clk) begin
        if (psel_rom && !apb_penable)
            rom_rdata_r <= boot_mem[apb_paddr[11:2]];
    end

    // ========================================================
    // APB READ DATA — Combinational mux per peripheral
    // ========================================================
    reg [31:0] prdata_uart, prdata_input, prdata_jambu;
    reg [31:0] prdata_xdy, prdata_gcofb, prdata_sdspi;

    always @* begin
        case (apb_paddr[4:0])
            5'h08:   prdata_uart = uart_dat_do;
            5'h0C:   prdata_uart = {30'b0, uart_rx_valid, uart_tx_ready};
            5'h10:   prdata_uart = uart_div_do;
            default: prdata_uart = 32'h0;
        endcase
    end

    always @* begin
        case (apb_paddr[2:0])
            3'h0:    prdata_input = {28'b0, sw_sync2};
            3'h4:    prdata_input = {28'b0, btn_sync2};
            default: prdata_input = 32'h0;
        endcase
    end

    always @* begin
        case (apb_paddr[7:0])
            8'h48:   prdata_jambu = {30'd0, jb_done_sticky, jb_valid_sticky};
            8'h4C:   prdata_jambu = jb_data_out[ 31:  0];
            8'h50:   prdata_jambu = jb_data_out[ 63: 32];
            8'h54:   prdata_jambu = jb_data_out[ 95: 64];
            8'h58:   prdata_jambu = jb_data_out[127: 96];
            8'h5C:   prdata_jambu = jb_tag_out [ 31:  0];
            8'h60:   prdata_jambu = jb_tag_out [ 63: 32];
            default: prdata_jambu = 32'h0;
        endcase
    end

    always @* begin
        case (apb_paddr[7:0])
            8'h54:   prdata_xdy = {30'd0, xd_done_sticky, xd_valid_sticky};
            8'h58:   prdata_xdy = xd_data_out[ 31:  0];
            8'h5C:   prdata_xdy = xd_data_out[ 63: 32];
            8'h60:   prdata_xdy = xd_data_out[ 95: 64];
            8'h64:   prdata_xdy = xd_data_out[127: 96];
            8'h68:   prdata_xdy = xd_tag_out [ 31:  0];
            8'h6C:   prdata_xdy = xd_tag_out [ 63: 32];
            8'h70:   prdata_xdy = xd_tag_out [ 95: 64];
            8'h74:   prdata_xdy = xd_tag_out [127: 96];
            default: prdata_xdy = 32'h0;
        endcase
    end

    always @* begin
        case (apb_paddr[7:0])
            8'h54:   prdata_gcofb = {28'd0, gc_ad_req, gc_msg_req,
                                     gc_done_sticky, gc_valid_sticky};
            8'h58:   prdata_gcofb = gc_data_out[ 31:  0];
            8'h5C:   prdata_gcofb = gc_data_out[ 63: 32];
            8'h60:   prdata_gcofb = gc_data_out[ 95: 64];
            8'h64:   prdata_gcofb = gc_data_out[127: 96];
            8'h68:   prdata_gcofb = gc_tag_out [ 31:  0];
            8'h6C:   prdata_gcofb = gc_tag_out [ 63: 32];
            8'h70:   prdata_gcofb = gc_tag_out [ 95: 64];
            8'h74:   prdata_gcofb = gc_tag_out [127: 96];
            default: prdata_gcofb = 32'h0;
        endcase
    end

    always @* begin
        case (apb_paddr[3:0])
            4'h0:    prdata_sdspi = {24'd0, sdspi_rx_data_reg};
            4'h4:    prdata_sdspi = {29'd0, sdspi_cs_n_reg, sdspi_busy,
                                     sdspi_done_sticky};
            4'h8:    prdata_sdspi = {31'd0, sdspi_cs_n_reg};
            4'hC:    prdata_sdspi = {16'd0, sdspi_clkdiv};
            default: prdata_sdspi = 32'h0;
        endcase
    end

    // Final APB read-data mux
    assign apb_prdata =
        psel_rom   ? rom_rdata_r  :
        psel_uart  ? prdata_uart  :
        psel_input ? prdata_input :
        psel_jambu ? prdata_jambu :
        psel_xdy   ? prdata_xdy   :
        psel_gcofb ? prdata_gcofb :
        psel_sdspi ? prdata_sdspi :
        32'h0;

    // ========================================================
    // APB PERIPHERAL WRITE + READ side-effects
    // ========================================================
    wire apb_wr = apb_psel && apb_penable && apb_pwrite;
    wire apb_rd = apb_psel && apb_penable && !apb_pwrite;

    always @(posedge clk) begin
        if (!resetn) begin
            out_byte_en <= 0;
            uart_we <= 0; uart_rx_rd <= 0;
            uart_div_we <= 0; uart_div_di <= 0;
            tx_busy <= 0; tx_countdown <= 0;
            uart_tx_data <= 0;
            jb_key<=0; jb_nonce<=0; jb_ad<=0; jb_data_in<=0; jb_tag_in<=0;
            jb_ad_length<=0; jb_data_length<=0; jb_sel_type<=3'b001; jb_ena<=0;
            xd_key<=0; xd_nonce<=0; xd_ad<=0; xd_data_in<=0; xd_tag_in<=0;
            xd_ad_length<=0; xd_data_length<=0; xd_sel_type<=0; xd_ena<=0;
            gc_key<=0; gc_nonce<=0; gc_ad<=0; gc_data_in<=0; gc_tag_in<=0;
            gc_ad_length<=0; gc_data_length<=0; gc_decrypt_mode<=0; gc_start<=0;
            gc_ad_ack<=0; gc_msg_ack<=0;
            sdspi_tx_data<=8'hFF; sdspi_clkdiv<=16'd199;
            sdspi_start<=0; sdspi_cs_n_reg<=1'b1;
        end else begin
            // ---- Defaults: clear single-cycle pulses ----
            out_byte_en <= 0;
            uart_we     <= 0;
            uart_rx_rd  <= 0;
            uart_div_we <= 0;
            jb_ena      <= 0;
            xd_ena      <= 0;
            gc_start    <= 0;
            gc_ad_ack   <= 0;
            gc_msg_ack  <= 0;
            sdspi_start <= 0;

            // UART TX busy countdown
            if (tx_busy) begin
                if (tx_countdown != 0) tx_countdown <= tx_countdown - 1;
                else                   tx_busy      <= 0;
            end

            // ---- APB WRITE ----
            if (apb_wr) begin
                // GPIO / UART (0x1000_xxxx)
                if (psel_uart) begin
                    case (apb_paddr[4:0])
                        5'h00: begin out_byte_en<=1; out_byte<=apb_pwdata[7:0]; end
                        5'h04: begin
                            if (!tx_busy) begin
                                uart_tx_data <= apb_pwdata[7:0];
                                uart_we      <= 1;
                                tx_busy      <= 1;
                                tx_countdown <= 16'd9000;
                            end
                        end
                        5'h10: begin
                            uart_div_we <= 4'hF;
                            uart_div_di <= apb_pwdata;
                        end
                        default: ;
                    endcase
                end

                // SD SPI (0x6000_xxxx)
                if (psel_sdspi) begin
                    case (apb_paddr[3:0])
                        4'h0: begin
                            if (!sdspi_busy) begin
                                sdspi_tx_data <= apb_pwdata[7:0];
                                sdspi_start   <= 1;
                            end
                        end
                        4'h8: sdspi_cs_n_reg <= apb_pwdata[0];
                        4'hC: sdspi_clkdiv   <= apb_pwdata[15:0];
                        default: ;
                    endcase
                end

                // TinyJAMBU (0x3000_xxxx)
                if (psel_jambu) begin
                    case (apb_paddr[7:0])
                        8'h00: jb_key[  31:  0] <= apb_pwdata;
                        8'h04: jb_key[  63: 32] <= apb_pwdata;
                        8'h08: jb_key[  95: 64] <= apb_pwdata;
                        8'h0C: jb_key[ 127: 96] <= apb_pwdata;
                        8'h10: jb_nonce[ 31:  0] <= apb_pwdata;
                        8'h14: jb_nonce[ 63: 32] <= apb_pwdata;
                        8'h18: jb_nonce[ 95: 64] <= apb_pwdata;
                        8'h1C: jb_ad[    31:  0] <= apb_pwdata;
                        8'h20: jb_ad[    63: 32] <= apb_pwdata;
                        8'h24: jb_ad[    95: 64] <= apb_pwdata;
                        8'h28: jb_ad[   127: 96] <= apb_pwdata;
                        8'h2C: jb_data_in[ 31:  0] <= apb_pwdata;
                        8'h30: jb_data_in[ 63: 32] <= apb_pwdata;
                        8'h34: jb_data_in[ 95: 64] <= apb_pwdata;
                        8'h38: jb_data_in[127: 96] <= apb_pwdata;
                        8'h3C: jb_tag_in[ 31:  0] <= apb_pwdata;
                        8'h40: jb_tag_in[ 63: 32] <= apb_pwdata;
                        8'h44: begin
                            jb_sel_type    <= apb_pwdata[18:16];
                            jb_ad_length   <= apb_pwdata[12: 8];
                            jb_data_length <= apb_pwdata[ 4: 0];
                            jb_ena         <= 1;
                        end
                        default: ;
                    endcase
                end

                // Xoodyak (0x4000_xxxx)
                if (psel_xdy) begin
                    case (apb_paddr[7:0])
                        8'h00: xd_key[  31:  0] <= apb_pwdata;
                        8'h04: xd_key[  63: 32] <= apb_pwdata;
                        8'h08: xd_key[  95: 64] <= apb_pwdata;
                        8'h0C: xd_key[ 127: 96] <= apb_pwdata;
                        8'h10: xd_nonce[ 31:  0] <= apb_pwdata;
                        8'h14: xd_nonce[ 63: 32] <= apb_pwdata;
                        8'h18: xd_nonce[ 95: 64] <= apb_pwdata;
                        8'h1C: xd_nonce[127: 96] <= apb_pwdata;
                        8'h20: xd_ad[    31:  0] <= apb_pwdata;
                        8'h24: xd_ad[    63: 32] <= apb_pwdata;
                        8'h28: xd_ad[    95: 64] <= apb_pwdata;
                        8'h2C: xd_ad[   127: 96] <= apb_pwdata;
                        8'h30: xd_data_in[ 31:  0] <= apb_pwdata;
                        8'h34: xd_data_in[ 63: 32] <= apb_pwdata;
                        8'h38: xd_data_in[ 95: 64] <= apb_pwdata;
                        8'h3C: xd_data_in[127: 96] <= apb_pwdata;
                        8'h40: xd_tag_in[ 31:  0] <= apb_pwdata;
                        8'h44: xd_tag_in[ 63: 32] <= apb_pwdata;
                        8'h48: xd_tag_in[ 95: 64] <= apb_pwdata;
                        8'h4C: xd_tag_in[127: 96] <= apb_pwdata;
                        8'h50: begin
                            xd_sel_type    <= apb_pwdata[17:16];
                            xd_ad_length   <= apb_pwdata[12: 8];
                            xd_data_length <= apb_pwdata[ 4: 0];
                            xd_ena         <= 1;
                        end
                        default: ;
                    endcase
                end

                // GIFT-COFB (0x5000_xxxx)
                if (psel_gcofb) begin
                    case (apb_paddr[7:0])
                        8'h00: gc_key[  31:  0] <= apb_pwdata;
                        8'h04: gc_key[  63: 32] <= apb_pwdata;
                        8'h08: gc_key[  95: 64] <= apb_pwdata;
                        8'h0C: gc_key[ 127: 96] <= apb_pwdata;
                        8'h10: gc_nonce[ 31:  0] <= apb_pwdata;
                        8'h14: gc_nonce[ 63: 32] <= apb_pwdata;
                        8'h18: gc_nonce[ 95: 64] <= apb_pwdata;
                        8'h1C: gc_nonce[127: 96] <= apb_pwdata;
                        8'h20: gc_ad[    31:  0] <= apb_pwdata;
                        8'h24: gc_ad[    63: 32] <= apb_pwdata;
                        8'h28: gc_ad[    95: 64] <= apb_pwdata;
                        8'h2C: gc_ad[   127: 96] <= apb_pwdata;
                        8'h30: gc_data_in[ 31:  0] <= apb_pwdata;
                        8'h34: gc_data_in[ 63: 32] <= apb_pwdata;
                        8'h38: gc_data_in[ 95: 64] <= apb_pwdata;
                        8'h3C: gc_data_in[127: 96] <= apb_pwdata;
                        8'h40: gc_tag_in[ 31:  0] <= apb_pwdata;
                        8'h44: gc_tag_in[ 63: 32] <= apb_pwdata;
                        8'h48: gc_tag_in[ 95: 64] <= apb_pwdata;
                        8'h4C: gc_tag_in[127: 96] <= apb_pwdata;
                        8'h50: begin
                            gc_decrypt_mode <= apb_pwdata[16];
                            gc_ad_length    <= apb_pwdata[15:8];
                            gc_data_length  <= apb_pwdata[ 7:0];
                            gc_start        <= 1;
                        end
                        8'h78: begin
                            gc_ad_ack  <= apb_pwdata[1];
                            gc_msg_ack <= apb_pwdata[0];
                        end
                        default: ;
                    endcase
                end
            end // apb_wr

            // ---- APB READ side-effects ----
            if (apb_rd) begin
                if (psel_uart && apb_paddr[4:0] == 5'h08)
                    uart_rx_rd <= 1;
            end
        end
    end

endmodule
