# Configurable Baud UART Transceiver

## Overview & Architecture
This project is a custom UART transceiver featuring a configurable baud rate and asynchronous FIFOs on both the TX and RX sides. This design inherently supports Clock Domain Crossing (CDC), safely bridging data between a master system and the internal UART logic that operate on independent clocks.

```mermaid


## Clock Domain Crossing (CDC)
To safely pass data between the `clk_sys` domain and the `clk_uart` domain, the design employs **Asynchronous FIFOs** with the following mechanisms:

1. **N+1 Bit Gray Code Pointers**: Memory read and write pointers are maintained in binary for memory addressing but are converted to Gray code before crossing clock domains. Gray code guarantees that only a single bit changes state per transition, entirely preventing multi-bit sampling errors (glitches) at the clock boundary. The extra MSB (N+1 bit) is used to differentiate between "FIFO Full" and "FIFO Empty" wrap-around conditions.
2. **2-Stage Synchronizers**: When a Gray code pointer crosses into a new clock domain, it passes through two flip-flops (a 2-stage synchronizer). This heavily mitigates the risk of metastability caused by setup/hold time violations from asynchronous signals.

## Module Interfaces (`uart_transceiver_top`)

### Parameters
| Parameter | Default | Description |
| :--- | :--- | :--- |
| `DATA_WIDTH` | 8 | Number of bits per data word (standard 8-bit UART). |
| `FIFO_DEPTH` | 4 | Depth of the Async FIFOs ($2^4 = 16$ words). |

### System Domain Ports (`clk_sys`)
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk_sys` | Input | 1 | System base clock. |
| `rst_sys_n` | Input | 1 | Active-low system reset. |
| `tx_data_in` | Input | `DATA_WIDTH` | Data written to the UART transmitter. |
| `tx_wr_en` | Input | 1 | Write enable to push `tx_data_in` to the TX FIFO. |
| `tx_full` | Output | 1 | Indicates the TX FIFO is full (cannot accept more data). |
| `rx_data_out` | Output| `DATA_WIDTH` | Data read from the UART receiver. |
| `rx_rd_en` | Input | 1 | Read enable to pop `rx_data_out` from the RX FIFO. |
| `rx_empty` | Output | 1 | Indicates the RX FIFO is empty (no data available). |

### UART Domain Ports (`clk_uart`)
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk_uart` | Input | 1 | UART base clock (can be asynchronous to `clk_sys`). |
| `rst_uart_n`| Input | 1 | Active-low UART reset. |
| `baud_divisor`| Input | 16 | Divisor value to configure the baud rate. |
| `uart_rx` | Input | 1 | Physical asynchronous serial receive pin. |
| `uart_tx` | Output | 1 | Physical asynchronous serial transmit pin. |

## Baud Rate Calculation
The FSMs for the transmitter and receiver rely on a 16x oversampled baud tick. This ensures the receiver can reliably sample data bits in the middle of a bit period. 

**Formula for 16x Baud Divisor:**
$$ \text{Divisor} = \frac{\text{Base Clock Frequency}}{16 \times \text{Desired Baud Rate}} $$

### Common Divisors for a 50 MHz Base Clock
| Desired Baud Rate | 16x Tick Rate (Hz) | Calculated Float | Integer Divisor (`baud_divisor`) |
| :--- | :--- | :--- | :--- |
| **9600** | 153,600 | 325.52 | **326** |
| **115200** | 1,843,200 | 27.126 | **27** |
