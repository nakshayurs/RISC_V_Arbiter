`timescale 1ns/1ps

module tb_round_robin;

    // --- Parameters ---
    parameter N_MASTERS = 4;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;

    // --- Signals ---
    reg clk;
    reg rst_n;

    // Master Inputs (Packed Arrays)
    reg [N_MASTERS-1:0]                   req_i;
    reg [N_MASTERS*ADDR_WIDTH-1:0]        addr_i;
    reg [N_MASTERS*DATA_WIDTH-1:0]        wdata_i;
    reg [N_MASTERS-1:0]                   we_i;

    // Arbiter Outputs
    wire [N_MASTERS-1:0]                  gnt_o;

    // Slave Interface
    wire                                  slave_valid_o;
    wire [ADDR_WIDTH-1:0]                 slave_addr_o;
    wire [DATA_WIDTH-1:0]                 slave_wdata_o;
    wire                                  slave_we_o;
    reg                                   slave_ready_i;
    reg  [DATA_WIDTH-1:0]                 slave_rdata_i;

    // --- Instantiate the DUT (Device Under Test) ---
    round_robin_interconnect #(
        .N_MASTERS(N_MASTERS),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .req_i(req_i),
        .addr_i(addr_i),
        .wdata_i(wdata_i),
        .we_i(we_i),
        .gnt_o(gnt_o),
        .slave_valid_o(slave_valid_o),
        .slave_addr_o(slave_addr_o),
        .slave_wdata_o(slave_wdata_o),
        .slave_we_o(slave_we_o),
        .slave_ready_i(slave_ready_i),
        .slave_rdata_i(slave_rdata_i)
    );

    // --- Clock Generation (100MHz -> 10ns period) ---
    always #5 clk = ~clk;

    // --- Helper Task: Drive a specific Master ---
    task drive_master(input integer id, input [31:0] addr, input [31:0] data);
        begin
            req_i[id] = 1'b1;
            // Bit slicing to put data into the correct slot of the packed array
            addr_i[id*ADDR_WIDTH +: ADDR_WIDTH] = addr;
            wdata_i[id*DATA_WIDTH +: DATA_WIDTH] = data;
            we_i[id] = 1'b1;
        end
    endtask

    // --- Helper Task: Clear a specific Master ---
    task clear_master(input integer id);
        begin
            req_i[id] = 1'b0;
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        // 1. Initialization
        $display("=== Starting Simulation ===");
        $dumpfile("arbiter_wave.vcd"); // For waveform viewing
        $dumpvars(0, tb_round_robin);

        clk = 0;
        rst_n = 0;
        req_i = 0;
        addr_i = 0;
        wdata_i = 0;
        we_i = 0;
        slave_ready_i = 0; // Slave is initially busy
        slave_rdata_i = 32'hDEADBEEF;

        // 2. Reset Sequence
        #20 rst_n = 1;
        $display("[%0t] Reset Released", $time);

        // ------------------------------------------------------------
        // CASE 1: Single Master Request (Sanity Check)
        // ------------------------------------------------------------
        $display("[%0t] Case 1: Master 0 only", $time);
        slave_ready_i = 1; // Slave is ready
        drive_master(0, 32'h1000, 32'hAAAA);
        #10;
        if (gnt_o[0] !== 1)
        clear_master(0);
        #10;

        // ------------------------------------------------------------
        // CASE 2: Simultaneous Requests (Testing Priority)
        // ------------------------------------------------------------
        $display("[%0t] Case 2: Master 1 and 2 request same time", $time);
        // Current Pointer should be at 1 (since M0 just won)
        drive_master(1, 32'h2000, 32'hBBBB);
        drive_master(2, 32'h3000, 32'hCCCC);
        
        #10; 
        // We expect Master 1 to win first (Sequential order 0->1->2)
        if (gnt_o[1]) $display(" -> Master 1 won (Correct)");
        else          $display(" -> Master 1 LOST (Wrong)");
        
        // Hold requests. In next cycle, M1 should lose grant and M2 should win
        // because pointer rotates.
        #10;
        if (gnt_o[2]) $display(" -> Master 2 won (Correct - Round Robin worked)");
        else          $display(" -> Master 2 LOST (Wrong)");

        clear_master(1);
        clear_master(2);
        #10;

        // ------------------------------------------------------------
        // CASE 3: Slave Backpressure (Wait State)
        // ------------------------------------------------------------
        $display("[%0t] Case 3: Slave is BUSY (Backpressure)", $time);
        slave_ready_i = 0; // STOP!
        drive_master(3, 32'h4000, 32'hDDDD);
        
        #10;
        // Even though M3 requests, arbiter might grant internally, 
        // but pointer shouldn't move effectively until handshake completes.
        // (Implementation dependent: usually grant asserts, but new requests are blocked)
        
        #20; 
        slave_ready_i = 1; // GO!
        #10;
        clear_master(3);

        // ------------------------------------------------------------
        // CASE 4: The "Stress Test" (All 4 Masters)
        // ------------------------------------------------------------
        $display("[%0t] Case 4: All Masters Requesting at once", $time);
        drive_master(0, 32'hA00, 1);
        drive_master(1, 32'hB00, 2);
        drive_master(2, 32'hC00, 3);
        drive_master(3, 32'hD00, 4);

        // We will run for 5 cycles and see who wins.
        repeat(5) begin
            #10;
            if (gnt_o[0]) $display("[%0t] Grant -> Master 0", $time);
            if (gnt_o[1]) $display("[%0t] Grant -> Master 1", $time);
            if (gnt_o[2]) $display("[%0t] Grant -> Master 2", $time);
            if (gnt_o[3]) $display("[%0t] Grant -> Master 3", $time);
        end

        clear_master(0); clear_master(1); clear_master(2); clear_master(3);
        
        #50;
        $display("=== Simulation Finished ===");
        $finish;
    end

endmodule
