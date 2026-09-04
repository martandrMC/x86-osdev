#include "parts/fdc.h"
#include "parts/pit.h"
#include "ports.h"
#include "idt.h"
#include "parts/pic.h"
#include "library/printf.h"

#define RQM_POLL_RETRIES 20

#define GP_OUTPUT 0x3F2 // write-only
#define MAIN_STAT 0x3F4 // read-only
#define DATA_FIFO 0x3F5 // read-write
#define CONF_CTRL 0x3F7 // write-only

#define MAIN_STAT_RQM (1 << 7)
#define MAIN_STAT_DIO (1 << 6)

#define CMD_SPECIFY 0x03
#define CMD_RECALIB 0x07
#define CMD_SENSINT 0x08
#define CMD_READMFM 0x46

static volatile bool timeout, irq_fired;
static void timeout_callback() { timeout = true; }
static void irq_handler(irq_state_t *dummy) {
	(void) dummy;
	irq_fired = true;
	pic_send_eoi(6);
}

static void wait_prepare(void) { irq_fired = timeout = false; }
static bool wait_timeout(unsigned usec) {
	int id = pit_register_timeout(timeout_callback, usec);
	if(id == -1) return false;
	while(!irq_fired && !timeout) interrupt_wait();
	if(!timeout) pit_cancel_timeout(timeout_callback, id);
	return irq_fired;
}

static void dma_setup(uintptr_t dma_buffer) {
	port_out8(0x0A, 0x06); // Mask chan2

	port_out8(0x0C, 0xFF);                    // Reset flip flop
	port_out8(0x04, dma_buffer & 0xFF);       // Lo byte of addr
	port_out8(0x04, dma_buffer >> 8 & 0xFF);  // Md byte of addr
	port_out8(0x81, dma_buffer >> 16 & 0xFF); // Hi byte of addr

	port_out8(0x0C, 0xFF); // Reset flip flop
	port_out8(0x05, 0xFF); // Lo byte of 512 - 1
	port_out8(0x05, 0x01); // Hi byte of 512 - 1

	port_out8(0x0B, 0x56); // Read, Auto Re-init, Single Xfer

	port_out8(0x0A, 0x02); // Unmask chan2
}

static bool fifo_send(uint8_t byte) {
	for (int i = 0; i < RQM_POLL_RETRIES; i++) {
		uint8_t stat = port_in8(MAIN_STAT);
		if(!(stat & MAIN_STAT_RQM)) continue;
		if(stat & MAIN_STAT_DIO) return false;
		port_out8(DATA_FIFO, byte);
		return true;
	}
	return false;
}

static bool fifo_recv(uint8_t *byte) {
	for (int i = 0; i < RQM_POLL_RETRIES; i++) {
		uint8_t stat = port_in8(MAIN_STAT);
		if (!(stat & MAIN_STAT_RQM)) continue;
		if (!(stat & MAIN_STAT_DIO)) return false;
		*byte = port_in8(DATA_FIFO);
		return true;
	}
	return false;
}

static bool controller_reset(void) {
	port_out8(GP_OUTPUT, 0);
	pit_delay(10*USEC);
	wait_prepare();
	port_out8(GP_OUTPUT, 0x0C);
	return wait_timeout(100*MSEC);
}

static bool head_recalibrate(void) {
	wait_prepare();
	if(!fifo_send(CMD_RECALIB)) return false;
	if(!fifo_send(0)) return false;
	if(!wait_timeout(3*SEC)) return false;

	uint8_t st0, track;
	if(!fifo_send(CMD_SENSINT)) return false;
	if(!fifo_recv(&st0)) return false;
	if(!fifo_recv(&track)) return false;

	return (st0 == 0x20 && track == 0);
}

extern void print_to_vga(const char *str);
bool fdc_init(uint8_t *dma_buffer) {
	register_isr(irq_handler, 0x26, IDT_PRESENT | IDT_INTR_GATE);
	pic_enable_line(6);
	dma_setup((uintptr_t) dma_buffer);

	controller_reset();
	port_out8(CONF_CTRL, 0);

	port_out8(GP_OUTPUT, 0x1C);
	pit_delay(500*MSEC);

	uint8_t dummy;
	for(int i = 0; i < 4; i++) {
		fifo_send(CMD_SENSINT);
		fifo_recv(&dummy);
		fifo_recv(&dummy);
	}

	fifo_send(CMD_SPECIFY);
	fifo_send(0x80);
	fifo_send(0x0A);

	head_recalibrate();

	wait_prepare();
	fifo_send(CMD_READMFM);
	fifo_send(0); // head
	fifo_send(0); // cyl
	fifo_send(0); // head, again
	fifo_send(1); // start sect
	fifo_send(2); // 512B/sect
	fifo_send(18); // last sect in track
	fifo_send(0x1b); // GAP1
	fifo_send(0xff); // 512B/sect
	wait_timeout(200*MSEC);
	fifo_recv(&dummy);
	fifo_recv(&dummy);
	fifo_recv(&dummy);
	fifo_recv(&dummy);
	fifo_recv(&dummy);
	fifo_recv(&dummy);
	fifo_recv(&dummy);

	return true;
}
