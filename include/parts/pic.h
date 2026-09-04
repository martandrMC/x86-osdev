#ifndef PIC_H
#define PIC_H

#include <stdint.h>

void pic_setup(uint8_t irq_base);
void pic_send_eoi(uint8_t id);
void pic_enable_line(uint8_t id);
void pic_disable_line(uint8_t id);

#endif
