# RISC_V_Arbiter
bus arbiter for a RISC-V processor implemented using round robin
**Course Name**: Computer Architecture

**EL Title**: Design of a Fair Bus Arbitration Unit for Multi-Core RISC-V Instruction & Data Memory Access

**Architecture**: RISC-V (RV32I/RV64I compatible)

**Implementation**: Round Robin Logic with 8-Core Support

# 1. Architectural Implementation
In a multi-core RISC-V system, the bus arbiter manages the "Structural Hazard" that occurs when multiple cores attempt to access the shared System Bus or Global Memory simultaneously.

The Round Robin Strategy
While Fixed Priority can lead to Starvation (where Core 7 might never execute if Core 0 is constantly requesting data), the Round Robin approach implemented here ensures each RISC-V Hart (Hardware Thread) receives a guaranteed time slice.

Priority Pointer: The design uses 8 sequential instances to act as a "token" holder.

Arbitration Cycle: Once a core completes its memory transaction (indicated by the ready signal in the RISC-V bus protocol), the arbiter shifts the priority to the next core in a circular queue.

Instruction vs. Data: This arbiter is specifically designed to handle concurrent Instruction Fetches (IF) and Data Memory Accesses (MEM) across the core cluster.

# 2. Quantitative Analysis (Computer Architecture Metrics)
Using the data from the Cadence Genus reports, we can quantify the performance of the memory subsystem.

Timing & Throughput
Clock Frequency: The arbiter operates at 100 MHz (10ns period).

Path Latency: The critical path from the grant register to the slave data output is 4.749 ns.

Memory Access Penalty: Since the timing slack is a healthy 5051 ps, the arbiter does not introduce "wait states" into the RISC-V pipeline, allowing for single-cycle bus grant operations.

Area Efficiency
Complexity: The Round Robin implementation requires 229 combinational gates. In architectural terms, this is a small trade-off in area (3905.194 units) to achieve fairness across the multi-core fabric.

Comparison: Compared to a Fixed Priority arbiter (which uses only 142 gates), the Round Robin logic increases the interconnect area by ~32% to eliminate core starvation.

# 3. Expected Output & Execution
To verify the implementation within a RISC-V simulation environment:
Instruction Execution: Run a parallel "Matrix Multiplication" across 8 cores.
Bus Monitoring: Observe the gnt_o signals. In a Round Robin scheme, you should see the grants cycle through: 00000001 -> 00000010 -> 00000100...
Synthesis Validation: Open Genus and run report_qor to ensure TNS is 0.0.
