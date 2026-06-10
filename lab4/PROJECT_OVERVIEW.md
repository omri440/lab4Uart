# Lab 4: TX UART Controller Project

## Project Overview
Design and implement a UART TX controller that communicates with PC and transmits digital values to be displayed on 7-segment displays and Nexys board.

## Key Requirements
- **Baud Rate**: 57600 bps
- **Inputs**: System clock, SW[7:0] (data), SW[9:8] (speed), SW[14:13] (byte count), center push-button, CPU reset
- **Outputs**: TX serial line, LED[0] (toggles on each byte)
- **Features**:
  - TX FSM with wait states between bytes
  - Delimiter characters (0x20 after each byte, 0x0D 0x0A for end of row)
  - 7-segment display (4 displays for: T0-byte, T1-speed, T2-byte count, T3-transmitted rows)
  - Button latching (1+ second hold)
  - No flickering on displays (500Hz refresh rate)

## System Architecture

### Top-Level Hierarchy
```
tx_uart_controller (top)
├── uart_phy (baud rate generator)
├── tx_fsm (FSM state machine)
├── button_latch (debouncer & latch)
├── seven_segment_controller (4x displays)
└── byte_counter (transmitted byte counter)
```

## File Structure
```
rtl/
├── tx_uart_controller.v      (top module)
├── uart_phy.v                (baud rate generator)
├── tx_fsm.v                  (UART TX FSM)
├── button_latch.v            (push-button latching)
├── seven_segment_controller.v
├── seven_segment_decoder.v
└── byte_counter.v

tb/
├── tx_uart_controller_tb.v   (testbench)
└── uart_tx_monitor.v         (simulation helper)

xdc/
└── nexys.xdc                 (board constraints)

docs/
├── fsm_diagrams.md           (FSM state diagrams)
└── timing_calculations.md    (baud rate calculations)
```

## Development Phases

1. **Phase 1**: Component Design
   - UART PHY (baud rate generator)
   - TX FSM
   - Supporting modules

2. **Phase 2**: Integration
   - Connect all components
   - Top-level module

3. **Phase 3**: Simulation
   - Create testbench
   - Verify behavior

4. **Phase 4**: Implementation
   - Configure XDC
   - Synthesis & P&R
   - Bitstream generation

5. **Phase 5**: Hardware Testing
   - Test on Nexys board

## Key Calculations

### Baud Rate Generator
- System clock: 100 MHz
- Baud rate: 57600 bps
- Divisor: 100,000,000 / 57600 ≈ 1736

### Delay Configurations
- Speed 0: No delay
- Speed 1: 50ms delay
- Speed 2: 100ms delay
- Speed 3: 200ms delay

### Byte Counts
- Mode 0: 1 byte
- Mode 1: 32 bytes
- Mode 2: 128 bytes
- Mode 3: 256 bytes

### 7-Segment Refresh
- Target: 500 Hz
- Period: 2 μs
- Clock divisor needed: 100 MHz / 500 Hz = 200,000
