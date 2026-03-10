#pragma once
#include "stdint.h"
/*
define PRINTF_STATE_NORMAL         0
#define PRINTF_STATE_LENGTH         1
#define PRINTF_STATE_LENGTH_SHORT   2
#define PRINTF_STATE_LENGTH_LONG    3
#define PRINTF_STATE_SPEC           4

#define PRINTF_LENGTH_DEFAULT       0
#define PRINTF_LENGTH_SHORT_SHORT   1
#define PRINTF_LENGTH_SHORT         2
#define PRINTF_LENGTH_LONG          3
#define PRINTF_LENGTH_LONG_LONG     4
*/

void putc(char c);
void puts(const char* str);
void puts_f(const char far* str);
void _cdecl printf(const char* fmt, ...);
// int* printf_number(int* argp, int length, bool sign, int radix);
void print_buffer(const char* msg, const void far* buffer, uint16_t count);
