# Vivado Synthesis Script for UART Transceiver
# Run with: vivado -mode batch -source build.tcl

# 1. Create an in-memory project
create_project -in_memory -part xc7a35tcpg236-1 
# Note: Part number xc7a35tcpg236-1 (Basys 3) is a placeholder and can be changed as needed.

# 2. Read SystemVerilog Source Files
# Define the source directory relative to the script location
set SRC_DIR "."

read_verilog -sv [list \
    "${SRC_DIR}/async_fifo.sv" \
    "${SRC_DIR}/baud_rate_gen.sv" \
    "${SRC_DIR}/uart_tx.sv" \
    "${SRC_DIR}/uart_rx.sv" \
    "${SRC_DIR}/uart_tranciever_top.sv" \
]

# Read Timing Constraints
read_xdc [list "${SRC_DIR}/constraints.xdc"]

# 3. Set the Top Module
set_property top uart_transceiver_top [current_fileset]

# 4. Run Synthesis
synth_design -top uart_transceiver_top -part xc7a35tcpg236-1

# 5. Generate Reports
# Create reports directory if it doesn't exist
file mkdir reports

report_timing_summary -file reports/timing_summary.rpt
report_utilization -file reports/utilization.rpt

puts "Synthesis completed successfully!"
