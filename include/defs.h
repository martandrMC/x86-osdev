#ifndef DEFS_H
#define DEFS_H

#define packed       __attribute__ ((packed))
#define force_inline __attribute__((always_inline)) static
#define asm_iface

#define min(x,y) ((x) < (y) ? (x) : (y))
#define max(x,y) ((x) > (y) ? (x) : (y))

#endif
