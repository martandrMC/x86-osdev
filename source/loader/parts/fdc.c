#include "parts/fdc.h"
#include "parts/pit.h"
#include "parts/pic.h"
#include "library/string.h"
#include "ports.h"
#include "idt.h"

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
#define CMD_SEEKTRK 0x0F
#define CMD_READMFM 0x46

static struct {
	media_info_t *info;
	uint8_t *dma_buffer;
	uint16_t dma_size;
} state;

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

static bool dma_setup(void) {
	uintptr_t addr = (uintptr_t) state.dma_buffer;
	if(addr >> 16 != (addr + state.dma_size - 1) >> 16) return false;
	port_out8(0x0A, 0x06); // Mask chan2

	port_out8(0x0C, 0xFF);              // Reset flip flop
	port_out8(0x04, addr & 0xFF);       // Lo byte of addr
	port_out8(0x04, addr >> 8 & 0xFF);  // Md byte of addr
	port_out8(0x81, addr >> 16 & 0xFF); // Hi byte of addr

	port_out8(0x0B, 0x56); // Read, Auto Re-init, Single Xfer
	port_out8(0x0A, 0x02); // Unmask chan2
	return true;
}

static void dma_set_size(uint16_t bytes) {
	bytes--;
	port_out8(0x0A, 0x06); // Mask chan2
	port_out8(0x0C, 0xFF); // Reset flip flop
	port_out8(0x05, bytes & 0xFF); // Lo byte
	port_out8(0x05, bytes >> 8);   // Hi byte
	port_out8(0x0A, 0x02); // Unmask chan2
}

static bool controller_reset(void) {
	port_out8(GP_OUTPUT, 0);
	pit_delay(10*USEC);
	wait_prepare();
	port_out8(GP_OUTPUT, 0x0C);
	return wait_timeout(100*MSEC);
}

static bool controller_recalibrate(void) {
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

// TODO: Error checking
bool fdc_init(media_info_t *info, uint8_t *dma_buffer, uint16_t dma_size) {
	if(info->boot_drive_id != 0) return false;

	state.info = info;
	state.dma_buffer = dma_buffer;
	state.dma_size = dma_size;
	dma_setup();

	register_isr(irq_handler, 0x26, IDT_PRESENT | IDT_INTR_GATE);
	pic_enable_line(6);

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

	controller_recalibrate();
	return true;
}

// TODO: Error checking
bool controller_read(uint8_t cyl, uint8_t head, uint8_t sect) {
	uint8_t dummy;

	wait_prepare();
	fifo_send(CMD_SEEKTRK);
	fifo_send(head << head);
	fifo_send(cyl);
	wait_timeout(3*SEC);

	wait_prepare();
	fifo_send(CMD_READMFM);
	fifo_send(head << 2);
	fifo_send(cyl);
	fifo_send(head);
	fifo_send(sect);
	fifo_send(2); // 512B/sect
	fifo_send(state.info->sects_per_trk);
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

// TODO: Error checking
bool fdc_read(uint8_t *data_out, uint16_t lba, uint8_t sects) {
	if(data_out == NULL) return false;
	if(lba + sects > state.info->total_sects) return false;
	if(state.dma_size < 512) return false;

	uint8_t sect = lba % state.info->sects_per_trk;
	uint8_t cyl  = lba / state.info->sects_per_trk;
	uint8_t head = cyl % state.info->head_count;
	cyl /= state.info->head_count;

	for(uint8_t i = 0, count; i < sects; i += count) {
		count = min(sects - i, state.info->sects_per_trk - sect);
		count = min(count, state.dma_size / 512);
		dma_set_size(count * 512);
		controller_read(cyl, head, sect + 1);
		memcpy(&data_out[i * 512], state.dma_buffer, count * 512);

		sect += count;
		if(sect >= state.info->sects_per_trk) sect = 0, head++;
		if(head >= state.info->head_count) head = 0, cyl++;
	}

	return true;
}
