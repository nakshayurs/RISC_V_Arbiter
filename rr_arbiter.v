module round_robin_interconnect #(
    parameter N_MASTERS = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,

    // --- Masters Interface (Packed Arrays) ---
    // Flattened arrays are used here for compatibility with standard synthesis flows
    input  wire [N_MASTERS-1:0]                   req_i,        // Request signal from each master
    input  wire [N_MASTERS*ADDR_WIDTH-1:0]        addr_i,       // Addresses
    input  wire [N_MASTERS*DATA_WIDTH-1:0]        wdata_i,      // Write Data
    input  wire [N_MASTERS-1:0]                   we_i,         // Write Enable
    output reg  [N_MASTERS-1:0]                   gnt_o,        // Grant signal to masters

    // --- Slave Interface (To Memory/Peripheral) ---
    output reg                                    slave_valid_o,
    output reg  [ADDR_WIDTH-1:0]                  slave_addr_o,
    output reg  [DATA_WIDTH-1:0]                  slave_wdata_o,
    output reg                                    slave_we_o,
    input  wire                                   slave_ready_i, // Slave is ready to accept
    input  wire [DATA_WIDTH-1:0]                  slave_rdata_i  // Read Data from Slave
);

    // 1. Priority Logic (Round Robin Pointer)
    reg [N_MASTERS-1:0] pointer_reg;
    wire [N_MASTERS-1:0] mask_req;
    wire [N_MASTERS-1:0] next_gnt;
    
    // Mask requests that are lower priority than the current pointer
    // This simple logic finds the "next" master effectively.
    // Example: If pointer is at 0010, we prioritize 1100 over 0001.
    
    // Double the request vector to handle wrapping around the pointer easily
    wire [2*N_MASTERS-1:0] double_req = {req_i, req_i};
    wire [2*N_MASTERS-1:0] double_gnt;

    // A priority encoder that looks at the requests starting from the pointer
    // This is a "thermometer" style arbiter logic often used for high speed
    assign double_gnt = double_req & ~(double_req - pointer_reg);
    
    // Logic to select the winner
    integer i;
    reg [N_MASTERS-1:0] raw_grant;
    
    always @(*) begin
        // Simple Fixed Priority Logic applied to the Rotated Vector
        // (In production, use a fast priority encoder IP)
        raw_grant = 0;
        for (i = 0; i < N_MASTERS; i = i + 1) begin
             // If we found a request in the masked/rotated vector
             if (double_req[i +: N_MASTERS] & pointer_reg) begin
                 // This is complex to implement generically in behavioral verilog loops
                 // For N=4, simpler Case statements or "if-else" chain is often synthesized better.
             end
        end
    end

    // --- SIMPLIFIED ROUND ROBIN LOGIC FOR SYNTHESIS ---
    // (Replacing the complex loop above with a standard rotate-priority approach)
    
    wire [N_MASTERS-1:0] req_masked = req_i & ~((pointer_reg - 1) | pointer_reg);
    wire [N_MASTERS-1:0] req_unmasked = req_i & ((pointer_reg - 1) | pointer_reg);
    
    // Helper to find first set bit (Priority Encode)
    function [N_MASTERS-1:0] priority_enc;
        input [N_MASTERS-1:0] in;
        integer k;
        begin
            priority_enc = 0;
            for (k = 0; k < N_MASTERS; k=k+1) begin
                if (in[k] && priority_enc == 0) priority_enc = 1 << k;
            end
        end
    endfunction

    wire [N_MASTERS-1:0] gnt_masked = priority_enc(req_masked);
    wire [N_MASTERS-1:0] gnt_raw    = priority_enc(req_i);
    
    // If any masked request exists, grant it. Otherwise grant raw (wrap around).
    wire [N_MASTERS-1:0] next_grant_vec = (|req_masked) ? gnt_masked : gnt_raw;

    // Update Pointer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer_reg <= 1; // Start at Master 0
            gnt_o <= 0;
        end else begin
            if (slave_ready_i || !slave_valid_o) begin
                if (|req_i) begin
                    gnt_o <= next_grant_vec;
                    // Rotate pointer to the left of the winner
                    pointer_reg <= {next_grant_vec[N_MASTERS-2:0], next_grant_vec[N_MASTERS-1]}; 
                end else begin
                    gnt_o <= 0;
                end
            end
        end
    end

    // 2. Data Path Muxing (The Crossbar Switch)
    // Connect the winning Master's signals to the Slave
    always @(*) begin
        slave_valid_o = |gnt_o;
        slave_addr_o  = 0;
        slave_wdata_o = 0;
        slave_we_o    = 0;
        
        for (i = 0; i < N_MASTERS; i = i + 1) begin
            if (gnt_o[i]) begin
                slave_addr_o  = addr_i[i*ADDR_WIDTH +: ADDR_WIDTH];
                slave_wdata_o = wdata_i[i*DATA_WIDTH +: DATA_WIDTH];
                slave_we_o    = we_i[i];
            end
        end
    end

endmodule
