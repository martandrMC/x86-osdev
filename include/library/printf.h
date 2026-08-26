#ifndef PRINTF_H
#define PRINTF_H

#include <stddef.h>
#include <stdarg.h>

int vsnprintf(char *output, size_t max, const char *fmt, va_list args);
int snprintf(char *output, size_t max, const char *fmt, ...);

#endif
