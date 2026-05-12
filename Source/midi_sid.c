#include "midi_sid.h"

#include <math.h>
#include <stdbool.h>
#include <stdint.h>

#include "pico/stdlib.h"
#include "bsp/board.h"
#include "tusb.h"

#define DIN_MIDI_GPIO 0
#define DIN_MIDI_BAUD 31250
#define DIN_MIDI_BIT_US 32

#define SID_VOICES 3
#define SID_RING_SIZE 256
#define SID_AUDIO_RATE 44100

extern uint16_t ringBuf[SID_RING_SIZE];
extern uint32_t ringTime[SID_RING_SIZE];
extern uint8_t ringWrite;
extern uint8_t ringRead;

extern volatile int32_t newSample;
extern volatile uint64_t lastSIDEmulationCycle;
extern uint64_t c64CycleCounter;
extern uint32_t C64_CLOCK;

static uint8_t running_status = 0;
static uint8_t midi_data[2];
static uint8_t midi_data_count = 0;

static uint8_t voice_note[SID_VOICES] = { 255, 255, 255 };
static uint8_t next_voice = 0;

static const uint8_t voice_base[SID_VOICES] = {
    0x00, 0x07, 0x0e
};

static void sid_enqueue_write(uint8_t reg, uint8_t value)
{
    uint8_t next = ringWrite + 1;
    if (next >= SID_RING_SIZE)
        next = 0;

    while (next == ringRead)
        tight_loop_contents();

    ringTime[ringWrite] = (uint32_t)c64CycleCounter;
    ringBuf[ringWrite] = ((uint16_t)(reg & 0x1f) << 8) | value;
    ringWrite = next;
}

static uint16_t midi_note_to_sid_freq(uint8_t note)
{
    float hz = 440.0f * powf(2.0f, ((float)note - 69.0f) / 12.0f);
    float sidf = hz * 16777216.0f / (float)C64_CLOCK;

    if (sidf < 0.0f)
        sidf = 0.0f;
    if (sidf > 65535.0f)
        sidf = 65535.0f;

    return (uint16_t)(sidf + 0.5f);
}

static void sid_note_on(uint8_t note, uint8_t velocity)
{
    uint8_t v = next_voice;
    next_voice++;
    if (next_voice >= SID_VOICES)
        next_voice = 0;

    uint8_t base = voice_base[v];
    uint16_t f = midi_note_to_sid_freq(note);

    voice_note[v] = note;

    sid_enqueue_write(base + 0, f & 0xff);
    sid_enqueue_write(base + 1, f >> 8);

    // Attack/Decay and Sustain/Release. Tweak later for instrument presets.
    sid_enqueue_write(base + 5, 0x09);
    sid_enqueue_write(base + 6, 0xf3);

    // Sawtooth + gate.
    // 0x20 = saw, 0x01 = gate.
    sid_enqueue_write(base + 4, 0x21);

    (void)velocity;
}

static void sid_note_off(uint8_t note)
{
    for (uint8_t v = 0; v < SID_VOICES; v++)
    {
        if (voice_note[v] == note)
        {
            uint8_t base = voice_base[v];
            voice_note[v] = 255;

            // Sawtooth, gate off.
            sid_enqueue_write(base + 4, 0x20);
        }
    }
}

static void midi_handle_message(uint8_t status, uint8_t d1, uint8_t d2)
{
    uint8_t type = status & 0xf0;

    if (type == 0x90)
    {
        if (d2 == 0)
            sid_note_off(d1);
        else
            sid_note_on(d1, d2);
    }
    else if (type == 0x80)
    {
        sid_note_off(d1);
    }
}

static void midi_parse_byte(uint8_t b)
{
    if (b & 0x80)
    {
        running_status = b;
        midi_data_count = 0;
        return;
    }

    if (!running_status)
        return;

    midi_data[midi_data_count++] = b;

    if (midi_data_count >= 2)
    {
        midi_handle_message(running_status, midi_data[0], midi_data[1]);
        midi_data_count = 0;
    }
}

static bool din_midi_try_read_byte(uint8_t *out)
{
    static uint8_t last = 1;
    uint8_t cur = gpio_get(DIN_MIDI_GPIO);

    if (last == 1 && cur == 0)
    {
        uint8_t value = 0;

        sleep_us(DIN_MIDI_BIT_US + DIN_MIDI_BIT_US / 2);

        for (uint8_t i = 0; i < 8; i++)
        {
            if (gpio_get(DIN_MIDI_GPIO))
                value |= (1u << i);

            sleep_us(DIN_MIDI_BIT_US);
        }

        // Stop bit.
        sleep_us(DIN_MIDI_BIT_US);

        *out = value;
        last = gpio_get(DIN_MIDI_GPIO);
        return true;
    }

    last = cur;
    return false;
}

void midi_sid_init(void)
{
    board_init();
    tusb_init();

    gpio_init(DIN_MIDI_GPIO);
    gpio_set_dir(DIN_MIDI_GPIO, GPIO_IN);
    gpio_pull_up(DIN_MIDI_GPIO);

    // Basic default SID volume.
    sid_enqueue_write(0x18, 0x0f);
}

void midi_sid_task(void)
{
    tud_task();

    uint8_t packet[4];

    while (tud_midi_available())
    {
        if (tud_midi_packet_read(packet))
        {
            midi_parse_byte(packet[1]);
            midi_parse_byte(packet[2]);
            midi_parse_byte(packet[3]);
        }
    }

    uint8_t b;
    if (din_midi_try_read_byte(&b))
        midi_parse_byte(b);
}

void midi_sid_pump_timing(void)
{
    static uint32_t last_us = 0;
    static uint32_t sample_acc = 0;

    uint32_t now = time_us_32();

    if (last_us == 0)
    {
        last_us = now;
        return;
    }

    uint32_t delta_us = now - last_us;

    if (delta_us == 0)
        return;

    last_us = now;

    uint32_t cycles = (uint32_t)(((uint64_t)delta_us * (uint64_t)C64_CLOCK) / 1000000ull);

    if (cycles == 0)
        return;

    c64CycleCounter += cycles;
    sample_acc += cycles * SID_AUDIO_RATE;

    while (sample_acc > C64_CLOCK)
    {
        sample_acc -= C64_CLOCK;

        if (newSample == 0xffff)
            newSample = 0xfffe;
    }
}
