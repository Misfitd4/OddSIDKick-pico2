#!/usr/bin/env bash
set -euo pipefail

FILE="Source/SKpico.c"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: $FILE not found. Run this from repo root."
  exit 1
fi

cp "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 <<'PY'
from pathlib import Path

p = Path("Source/SKpico.c")
s = p.read_text()

# I2S pins for OddSIDKick-pico2 PCM5102
s = s.replace("#define AUDIO_I2S_CLOCK_PIN_BASE \t26", "#define AUDIO_I2S_CLOCK_PIN_BASE \t10")
s = s.replace("#define AUDIO_I2S_CLOCK_PIN_BASE \t26", "#define AUDIO_I2S_CLOCK_PIN_BASE \t10")
s = s.replace("#define AUDIO_I2S_DATA_PIN\t\t\t28", "#define AUDIO_I2S_DATA_PIN\t\t\t6")
s = s.replace("#define AUDIO_I2S_DATA_PIN\t\t\t28", "#define AUDIO_I2S_DATA_PIN\t\t\t6")
s = s.replace("( 3 << AUDIO_I2S_CLOCK_PIN_BASE )", "( 7 << AUDIO_I2S_CLOCK_PIN_BASE )")
s = s.replace("//#define USE_DAC", "#define USE_DAC")

# Add serial input flag and UART config after DIAGROM_HACK
needle = "#define DIAGROM_HACK\n"
insert = """#define DIAGROM_HACK

// OddSIDKick-pico2: receive SID writes over fast UART instead of C64 address/data bus
#define ODDSID_SERIAL_INPUT

#define SID_SERIAL_UART uart0
#define SID_SERIAL_BAUD 2000000
#define SID_SERIAL_TX_PIN 0
#define SID_SERIAL_RX_PIN 1
"""
if "#define ODDSID_SERIAL_INPUT" not in s:
    s = s.replace(needle, insert)

# Add UART include
needle = '#include "hardware/watchdog.h"\n'
insert = '#include "hardware/watchdog.h"\n#include "hardware/uart.h"\n'
if '#include "hardware/uart.h"' not in s:
    s = s.replace(needle, insert)

# Insert serial handler before handleBus()
marker = "void handleBus()\n"
serial_code = r'''
#ifdef ODDSID_SERIAL_INPUT

typedef enum {
    SIDPKT_WAIT_HEADER = 0,
    SIDPKT_VALUE,
    SIDPKT_DELAY_LO,
    SIDPKT_DELAY_HI
} SidSerialParserState;

typedef struct {
    uint8_t sid;
    uint8_t reg;
    uint8_t value;
    uint16_t delay;
} SidSerialWrite;

static SidSerialParserState sidSerialParserState = SIDPKT_WAIT_HEADER;
static SidSerialWrite sidSerialPacket;

static inline uint8_t sidSerialPoll(SidSerialWrite *out)
{
    while (uart_is_readable(SID_SERIAL_UART))
    {
        uint8_t b = uart_getc(SID_SERIAL_UART);

        switch (sidSerialParserState)
        {
            case SIDPKT_WAIT_HEADER:
                if (b & 0x80)
                {
                    sidSerialPacket.sid = (b & 0x20) ? 1 : 0;
                    sidSerialPacket.reg = b & 0x1f;
                    sidSerialParserState = SIDPKT_VALUE;
                }
                break;

            case SIDPKT_VALUE:
                sidSerialPacket.value = b;
                sidSerialParserState = SIDPKT_DELAY_LO;
                break;

            case SIDPKT_DELAY_LO:
                sidSerialPacket.delay = b;
                sidSerialParserState = SIDPKT_DELAY_HI;
                break;

            case SIDPKT_DELAY_HI:
                sidSerialPacket.delay |= ((uint16_t)b << 8);
                *out = sidSerialPacket;
                sidSerialParserState = SIDPKT_WAIT_HEADER;
                return 1;
        }
    }

    return 0;
}

void handleSerialSID()
{
    irq_set_mask_enabled(0xffffffff, 0);

    uart_init(SID_SERIAL_UART, SID_SERIAL_BAUD);
    gpio_set_function(SID_SERIAL_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(SID_SERIAL_RX_PIN, GPIO_FUNC_UART);
    uart_set_hw_flow(SID_SERIAL_UART, false, false);
    uart_set_format(SID_SERIAL_UART, 8, 1, UART_PARITY_NONE);
    uart_set_fifo_enabled(SID_SERIAL_UART, true);

    SidSerialWrite w;
    uint32_t serialCycleCounter = 0;

    while (true)
    {
        while (sidSerialPoll(&w))
        {
            serialCycleCounter += w.delay;

            uint16_t cmd = ((uint16_t)(w.reg & 0x1f) << 8) | w.value;
            if (w.sid)
                cmd |= (1 << 15);

            uint8_t nextWrite = ringWrite + 1;
            if (nextWrite >= RING_SIZE)
                nextWrite = 0;

            // If full, wait. First version: simple backpressure by stalling receiver.
            while (nextWrite == ringRead)
                tight_loop_contents();

            ringTime[ringWrite] = serialCycleCounter;
            ringBuf[ringWrite] = cmd;
            ringWrite = nextWrite;

            c64CycleCounter = serialCycleCounter;
        }

        tight_loop_contents();
    }
}

#endif

'''
if "void handleSerialSID()" not in s:
    s = s.replace(marker, serial_code + marker)

# Patch main() to use serial mode
old = '''#if defined( SKPICO_2350CR ) || defined( SKPICO_2350 )
\t// start bus handling and emulation
\tmulticore_launch_core1( runEmulation );
\tbus_ctrl_hw->priority = BUSCTRL_BUS_PRIORITY_PROC0_BITS;
\thandleBus();
#else
\t// start bus handling and emulation
\tmulticore_launch_core1( handleBus );
\tbus_ctrl_hw->priority = BUSCTRL_BUS_PRIORITY_PROC1_BITS;
\trunEmulation();
#endif'''
new = '''#ifdef ODDSID_SERIAL_INPUT
\t// OddSIDKick-pico2 serial SID-write input mode
\tmulticore_launch_core1( runEmulation );
\tbus_ctrl_hw->priority = BUSCTRL_BUS_PRIORITY_PROC0_BITS;
\thandleSerialSID();
#else
#if defined( SKPICO_2350CR ) || defined( SKPICO_2350 )
\t// start bus handling and emulation
\tmulticore_launch_core1( runEmulation );
\tbus_ctrl_hw->priority = BUSCTRL_BUS_PRIORITY_PROC0_BITS;
\thandleBus();
#else
\t// start bus handling and emulation
\tmulticore_launch_core1( handleBus );
\tbus_ctrl_hw->priority = BUSCTRL_BUS_PRIORITY_PROC1_BITS;
\trunEmulation();
#endif
#endif'''
if old not in s:
    print("WARNING: main() block not found exactly. I2S and serial handler were still patched.")
else:
    s = s.replace(old, new)

p.write_text(s)
PY

echo
echo "Patched. Review:"
git diff -- Source/SKpico.c
