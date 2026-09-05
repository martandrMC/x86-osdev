#include "library/snprintf.h"
#include "library/string.h"
#include <stdbool.h>
#include <stdint.h>

#pragma GCC diagnostic ignored "-Wsign-compare"

typedef struct specifier {
	int width, prec;
	bool alternate_form  : 1;
	bool left_justify    : 1;
	bool right_pad_zeros : 1;
	bool add_plus_sign   : 1;
	bool add_space_sign  : 1;
	enum {
		LMOD_NONE, LMOD_NMAX,  LMOD_SIZE, LMOD_PDIFF,
		LMOD_HALF, LMOD_2HALF, LMOD_LONG, LMOD_2LONG
	} lmod_kind : 3;
} specifier_t;

typedef struct state {
	char *output;
	unsigned max, size;
} state_t;

static void output_chars(state_t *state, char c, unsigned count) {
	unsigned to_write = 0;
	if(state->size + count < state->max) to_write = count;
	else if(state->size < state->max) to_write = state->max - state->size;
	memset(&state->output[state->size], c, to_write);
	state->size += count;
}

static void output_string(
	state_t *state, const char *str,
	unsigned len, bool reverse
) {
	unsigned to_copy = 0;
	if(state->size + len < state->max) to_copy = len;
	else if(state->size < state->max) to_copy = state->max - state->size;

	for(unsigned i = 0; i < to_copy; i++) {
		char c = (reverse ? str[len - i - 1] : str[i]);
		state->output[state->size + i] = c;
	}

	state->size += len;
}

static unsigned search_for_specifier(const char *fmt) {
	for(unsigned i = 0; ; i++) {
		char c = fmt[i];
		if(c == '%' || c == '\0')
			return i;
	}
}

static unsigned parse_number(const char *str, int *num_out) {
	if(str[0] < '0' || str[0] > '9') return 0;
	*num_out = 0;
	for(unsigned i = 0; ; i++) {
		unsigned char c = str[i] - '0';
		if(c > 9) return i;
		*num_out = *num_out * 10 + c;
	}
}

static unsigned parse_flags(specifier_t *spec, const char *fmt) {
	for(unsigned i = 0; ; i++) switch(fmt[i]) {
		case '#': spec->alternate_form  = true; break;
		case '-': spec->left_justify    = true; break;
		case '0': spec->right_pad_zeros = true; break;
		case '+': spec->add_plus_sign   = true; break;
		case ' ': spec->add_space_sign  = true; break;
		default: return i;
	}
}

static unsigned parse_lenmods(specifier_t *spec, const char *fmt) {
	switch(fmt[0]) {
		case 'l':
			spec->lmod_kind = (fmt[1] == 'l' ? LMOD_2LONG : LMOD_LONG);
			return (fmt[1] == 'l' ? 2 : 1);
		case 'h':
			spec->lmod_kind = (fmt[1] == 'h' ? LMOD_2HALF : LMOD_HALF);
			return (fmt[1] == 'h' ? 2 : 1);
		case 'j': spec->lmod_kind = LMOD_NMAX;  return 1;
		case 't': spec->lmod_kind = LMOD_PDIFF; return 1;
		case 'z': spec->lmod_kind = LMOD_SIZE;  return 1;
		default:  spec->lmod_kind = LMOD_NONE;  return 0;
	}
}

static unsigned emit_number(
	char *buf, uintmax_t num,
	unsigned base, bool capitals
) {
	const char *alphabet =
		"0123456789abcdef"
		"0123456789ABCDEF";

	if(base == 0) return 0;
	unsigned offset = (capitals ? 16 : 0);
	for(unsigned i = 0; ; i++) {
		if(num == 0) return i;
		unsigned idx = num % base + offset;
		buf[i] = alphabet[idx], num /= base;
	}
}

static void output_padded_number(
	state_t *state, specifier_t *spec,
	const char *number, unsigned number_len,
	const char *prefix, unsigned prefix_len
) {
	if(spec->prec < 0) spec->prec = 1;
	else spec->right_pad_zeros = false;

	if(spec->left_justify) {
		output_string(state, prefix, prefix_len, false);
		if(number_len < spec->prec) output_chars(state, '0', spec->prec - number_len);
		output_string(state, number, number_len, true);
		unsigned start = (spec->prec > number_len ? spec->prec : number_len) + prefix_len;
		if(start < spec->width) output_chars(state, ' ', spec->width - start);
	} else {
		if(spec->right_pad_zeros) spec->prec = spec->width - prefix_len;
		unsigned start = (spec->prec > number_len ? spec->prec : number_len) + prefix_len;
		if(start < spec->width) output_chars(state, ' ', spec->width - start);
		output_string(state, prefix, prefix_len, false);
		if(number_len < spec->prec) output_chars(state, '0', spec->prec - number_len);
		output_string(state, number, number_len, true);
	}
}

static void output_padded_string(
	state_t *state, specifier_t *spec, const char *str
) {
	unsigned str_len = (spec->prec < 0 ? strlen(str) : spec->prec);
	if(spec->left_justify) output_string(state, str, str_len, false);
	if(spec->width > str_len) output_chars(state, ' ', spec->width - str_len);
	if(!spec->left_justify) output_string(state, str, str_len, false);
}

// TODO: length modifiers
static bool finalize_specifier(
	state_t *state, specifier_t *spec,
	char spec_char, va_list *args
) {
	char buffer[64]; unsigned buffer_len;
	const char *prefix = NULL; unsigned prefix_len;
	bool capitals = false;
	switch(spec_char) {
		case 'd': case 'i':;
			int num = va_arg(*args, int);
			unsigned mag = (num < 0 ? 0 - (unsigned) num : (unsigned) num);
			prefix = (num < 0 ? "-" : spec->add_plus_sign ? "+" : " ");
			prefix_len = (spec->add_plus_sign || spec->add_space_sign || num < 0 ? 1 : 0);
			buffer_len = emit_number(buffer, mag, 10, capitals);
			output_padded_number(state, spec, buffer, buffer_len, prefix, prefix_len);
			break;
		case 'u':
			buffer_len = emit_number(buffer, va_arg(*args, unsigned), 10, capitals);
			output_padded_number(state, spec, buffer, buffer_len, prefix, 0);
			break;
		case 'X': capitals = true; /* fallthrough */ case 'x':
			prefix = (capitals ? "0X" : "0x");
			prefix_len = (spec->alternate_form ? 2 : 0);
			buffer_len = emit_number(buffer, va_arg(*args, unsigned), 16, capitals);
			output_padded_number(state, spec, buffer, buffer_len, prefix, prefix_len);
			break;
		case 'B': capitals = true; /* fallthrough */ case 'b':
			prefix = (capitals ? "0B" : "0b");
			prefix_len = (spec->alternate_form ? 2 : 0);
			buffer_len = emit_number(buffer, va_arg(*args, unsigned), 2, capitals);
			output_padded_number(state, spec, buffer, buffer_len, prefix, prefix_len);
			break;
		case 'c':
			if(!spec->left_justify) output_chars(state, va_arg(*args, int), 1);
			if(spec->width > 1) output_chars(state, ' ', spec->width - 1);
			if(spec->left_justify) output_chars(state, va_arg(*args, int), 1);
			break;
		case 's':;
			const char *str = va_arg(*args, char *);
			output_padded_string(state, spec, str);
			break;
		case 'p':;
			uintptr_t ptr = (uintptr_t) va_arg(*args, void *);
			buffer_len = emit_number(buffer, ptr, 16, false);
			spec->prec = (sizeof (uintptr_t) * 2);
			output_padded_number(state, spec, buffer, buffer_len, prefix, 0);
			break;
		case '%': output_chars(state, '%', 1); break;
		default: return false;
	}

	return true;
}

// Regex: %[ #0+-]*([1-9]\d*|\*)?(.(\d*|\*))?(ll?|hh?|[jtz])?[diuxXbBcsp%]
static bool vsnprintf_impl(state_t *state, const char *fmt, va_list *args) {
	for(unsigned i = 0; ; ) {
		specifier_t spec = {.prec = -1};

		unsigned to_copy = search_for_specifier(&fmt[i]);
		output_string(state, &fmt[i], to_copy, false);
		if(fmt[i + to_copy] == '\0') break;
		i += to_copy + 1;

		i += parse_flags(&spec, &fmt[i]);

		if(fmt[i] == '*') {
			i++, spec.width = va_arg(*args, int);
			if(spec.width < 0) spec.width *= -1, spec.left_justify = true;
		} else i += parse_number(&fmt[i], &spec.width);

		if(fmt[i] == '.') {
			if(fmt[++i] == '*') i++, spec.prec = va_arg(*args, int);
			else spec.prec = 0, i += parse_number(&fmt[i], &spec.prec);
		}

		i += parse_lenmods(&spec, &fmt[i]);
		bool succ = finalize_specifier(state, &spec, fmt[i++], args);
		if(!succ) return false;
	}

	if(state->max == 0) return true;
	if(state->size < state->max) state->output[state->size] = '\0';
	else state->output[state->max - 1] = '\0';
	return true;
}

int vsnprintf(char *output, size_t max, const char *fmt, va_list args) {
	state_t state = { .output = output, .max = max };
	bool succ = vsnprintf_impl(&state, fmt, &args);
	return (succ ? state.size : -1);
}

int snprintf(char *output, size_t max, const char *fmt, ...) {
	va_list args; va_start(args, fmt);
	int ret = vsnprintf(output, max, fmt, args);
	va_end(args);
	return ret;
}
