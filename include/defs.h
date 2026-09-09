#ifndef DEFS_H
#define DEFS_H

#include <stddef.h>

#define packed       __attribute__ ((packed))
#define force_inline __attribute__((always_inline)) static
#define asm_iface

#define min(x,y) ((x) < (y) ? (x) : (y))
#define max(x,y) ((x) > (y) ? (x) : (y))

#define container_of(p, t, m) ((t *) ((char *)(p) - offsetof(t, m)))

#endif
