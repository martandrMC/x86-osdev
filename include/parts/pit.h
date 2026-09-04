#ifndef PIT_H
#define PIT_H

#define USEC 1
#define MSEC 1000
#define SEC  1000000

void pit_setup(void);
void pit_delay(unsigned usec);

typedef void (*timeout_f)(void);
int pit_register_timeout(timeout_f callback, unsigned usec);
void pit_cancel_timeout(timeout_f callback, int timeout_id);

#endif
