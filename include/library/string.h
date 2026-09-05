#ifndef LIBRARY_STRING_H
#define LIBRARY_STRING_H

#include "defs.h"
#include <stddef.h>

asm_iface void *memset(void *buf, int sample, size_t count);
asm_iface size_t strlen(const char *str);

#endif
