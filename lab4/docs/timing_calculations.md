# Timing Calculations for UART TX Controller

## UART Baud Rate Configuration

### Given Parameters
- System Clock: 100 MHz (10 ns period)
- Target Baud Rate: 57600 bps
- UART Data Format: 1 start bit + 8 data bits + 1 stop bit = 10 bits per character

### Baud Rate Divisor Calculation
```
Divisor = System_Clock_Freq / Baud_Rate
Divisor = 100,000,000 / 57,600
Divisor = 1736.111...
Divisor = 1736 (rounded down for slight overspeed: 57,604 bps actual)
```

### Bit Period
```
Bit_Period = Divisor × System_Clock_Period
Bit_Period = 1736 × 10 ns
Bit_Period = 17,360 ns = 17.36 μs
```

### Actual Baud Rate
```
Actual_Baud = System_Clock_Freq / Divisor
Actual_Baud = 100,000,000 / 1736
Actual_Baud = 57,604 bps
Error = (57,604 - 57,600) / 57,600 = 0.007% ✓ (acceptable)
```

## Inter-Byte Delay Configuration

All delays are configurable via SW[9:8]:

### Delay 0: No Delay
- Wait cycles: 0
- Actual delay: immediate (same clock cycle)

### Delay 1: 50ms
```
Cycles_needed = 50 ms / (10 ns)
Cycles_needed = 50 × 10^-3 / 10 × 10^-9
Cycles_needed = 5,000,000 cycles
Counter_max = 5,000,000 - 1 = 4,999,999 (23-bit counter)
```

### Delay 2: 100ms
```
Cycles_needed = 100 ms / (10 ns)
Cycles_needed = 10,000,000 cycles
Counter_max = 10,000,000 - 1 = 9,999,999 (24-bit counter)
```

### Delay 3: 200ms
```
Cycles_needed = 200 ms / (10 ns)
Cycles_needed = 20,000,000 cycles
Counter_max = 20,000,000 - 1 = 19,999,999 (25-bit counter)
```

**Recommended**: Use a 25-bit delay counter

## 7-Segment Display Refresh Rate

### Target Requirement
- Refresh rate: 500 Hz (no flickering)
- Period between display updates: 2 ms

### Clock Divisor Calculation
```
Display_Refresh_CLK = System_Clock / 500 Hz
Display_Refresh_CLK = 100,000,000 / 500
Display_Refresh_CLK = 200,000

Divisor = 200,000 - 1 = 199,999 (18-bit counter)
Period = 200,000 × 10 ns = 2,000,000 ns = 2 ms ✓
```

**Recommended**: Use an 18-bit clock divisor counter

## Button Debouncing and Latching

### Debounce Configuration
- Typical mechanical switch: 20-50 ms bounce time
- Debounce window: Use 20 ms (2,000,000 cycles)
- Debounce counter: 21-bit required

### Latch Trigger Configuration
- Latch activation: > 1 second hold (from requirements)
- 1 second = 1,000 ms = 100,000,000 cycles
- Latch counter: 27-bit required

**Recommended Implementation**:
1. Read button input
2. Start debounce counter when input changes
3. After 20 ms stable, accept as new state
4. If held for > 1 second, trigger latch
5. Latch holds configuration until next trigger

## UART TX Timing

### Transmission Pattern
For each data byte:
1. Send 10-bit UART frame (start + 8 data bits + stop)
   - Time = 10 × 17.36 μs = 173.6 μs
2. Send delimiter character (0x20)
   - Time = 173.6 μs + inter-byte delay
3. For last byte in row: send CR (0x0D) + LF (0x0A)
   - Time = 2 × 173.6 μs = 347.2 μs

### Row Calculation
- For 32 bytes: 32 bytes per row
- For 128 bytes: √128 ≈ 11.3 bytes per row (use 11 or 12?)
- For 256 bytes: √256 = 16 bytes per row

**Note**: Lab description mentions "rows" for a square pattern. Clarify row length with instructor if needed.

## Summary of Key Parameters

| Parameter | Value | Counter Bits |
|-----------|-------|-------------|
| Baud Divisor | 1736 | 11 |
| 50ms Delay | 5,000,000 | 23 |
| 100ms Delay | 10,000,000 | 24 |
| 200ms Delay | 20,000,000 | 25 |
| Display Refresh Divisor | 199,999 | 18 |
| Button Debounce | 2,000,000 | 21 |
| Button Latch Trigger | 100,000,000 | 27 |
