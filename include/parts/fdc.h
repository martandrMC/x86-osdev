#ifndef PARTS_FDC_H
#define PARTS_FDC_H

#include "defs.h"
#include <stdbool.h>
#include <stdint.h>

typedef struct packed media_info {
	uint16_t total_sects, sects_per_trk;
	uint8_t head_count, boot_drive_id;
} media_info_t;

bool fdc_init(media_info_t *info, uint8_t *dma_buffer, uint16_t dma_size);
bool fdc_read(uint8_t *data_out, uint16_t lba, uint8_t sects);

#endif
