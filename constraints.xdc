# Timing constraints for UART Transceiver

# 100 MHz System Clock
create_clock -period 10.000 -name clk_sys [get_ports clk_sys]

# 50 MHz UART Base Clock
create_clock -period 20.000 -name clk_uart [get_ports clk_uart]

# Clocks are asynchronous
set_clock_groups -asynchronous -group [get_clocks clk_sys] -group [get_clocks clk_uart]
