#include "library/malloc.h"
#include <stdint.h>
#include <stdbool.h>
#include "idt.h"
#include "defs.h"

void assert(bool cond) {
	if(cond) return;
	for(;;) interrupt_wait();
}

typedef struct block {
	size_t size;
	struct block *left;
	uintptr_t data[];
} block_t;

#define WORD_SIZE (sizeof (uintptr_t))
#define ROUNDUP(x) (((x) - 1) / WORD_SIZE + 1)
#define HEADER_WORDS (ROUNDUP(sizeof (block_t)))
#define MIN_WORDS (HEADER_WORDS + 2)

#define BLOCK_SET_SIZE(b, w, f) ((b)->size = ((w) << 1) | ((f) ? 1 : 0))
#define BLOCK_GET_SIZE(b) ((b)->size >> 1)
#define BLOCK_GET_FREE(b) (((b)->size & 1) != 0)
#define BLOCK_TGL_FREE(b) ((b)->size ^= 1)

#define BLOCK_LEFT(b) ((b)->left)
#define BLOCK_RIGHT(b) ((block_t *) &(b)->data[BLOCK_GET_SIZE(b)])
#define BLOCK_PREV(b) (*(block_t **) &(b)->data[0])
#define BLOCK_NEXT(b) (*(block_t **) &(b)->data[1])

#define BLOCK_IS_LEFTMOST(b) (BLOCK_LEFT(b) == NULL)
#define BLOCK_IS_RIGHTMOST(b) (b == state.rightmost)

extern uintptr_t _prot_bss_end[];
static struct {
	size_t heap_break;
	block_t *free_first;
	block_t *free_last;
	block_t *rightmost;
} state;

static block_t *free_list_find(size_t size_words) {
	size_t size_split = MIN_WORDS + size_words;

	block_t *curr = state.free_first;
	for(; curr != NULL; curr = BLOCK_NEXT(curr)) {
		if(BLOCK_GET_SIZE(curr) == size_words) break;
		if(BLOCK_GET_SIZE(curr) >= size_split) break;
	}

	return curr;
}

static void free_list_append(block_t *block) {
	if(state.free_first == NULL) {
		assert(state.free_last == NULL);
		BLOCK_PREV(block) = BLOCK_NEXT(block) = NULL;
		state.free_first = state.free_last = block;
	} else {
		assert(state.free_last != NULL);
		BLOCK_PREV(block) = state.free_last;
		BLOCK_NEXT(block) = NULL;
		BLOCK_NEXT(state.free_last) = block;
		state.free_last = block;
	}
}

static void free_list_remove(block_t *block) {
	if(BLOCK_PREV(block) == NULL) state.free_first = BLOCK_NEXT(block);
	else BLOCK_NEXT(BLOCK_PREV(block)) = BLOCK_NEXT(block);

	if(BLOCK_NEXT(block) == NULL) state.free_last = BLOCK_PREV(block);
	else BLOCK_PREV(BLOCK_NEXT(block)) = BLOCK_PREV(block);

	BLOCK_PREV(block) = BLOCK_NEXT(block) = NULL;
}

static void coalesce_blocks(block_t *left) {
	block_t *right = BLOCK_RIGHT(left);
	assert(BLOCK_GET_FREE(left) && BLOCK_GET_FREE(right));

	if(!BLOCK_IS_RIGHTMOST(right)) {
		block_t *used = BLOCK_RIGHT(right);
		assert(!BLOCK_GET_FREE(used) && BLOCK_LEFT(used) == right);
		BLOCK_LEFT(used) = left;
	} else state.rightmost = left;

	size_t sum_words = BLOCK_GET_SIZE(left) + BLOCK_GET_SIZE(right);
	BLOCK_SET_SIZE(left, sum_words + HEADER_WORDS, true);
}

static void shrink_block(block_t *block, size_t size_words) {
	assert(BLOCK_GET_FREE(block));
	size_t block_size = BLOCK_GET_SIZE(block);
	assert(block_size >= MIN_WORDS + size_words);
	BLOCK_SET_SIZE(block, size_words, true);

	size_t new_size = block_size - HEADER_WORDS - size_words;
	block_t *new_block = (block_t *) &block->data[size_words];
	BLOCK_SET_SIZE(new_block, new_size, true);

	if(BLOCK_IS_RIGHTMOST(block)) state.rightmost = new_block;
	else BLOCK_LEFT(BLOCK_RIGHT(new_block)) = new_block;
	BLOCK_LEFT(new_block) = block;
	
	free_list_append(new_block);
}

void *malloc(size_t size_bytes) {
	if(size_bytes == 0) return NULL;
	size_t size_words = ROUNDUP(size_bytes);
	if(size_words < 2) size_words = 2;

	block_t *new_block = free_list_find(size_words);
	if(new_block == NULL) {
		new_block = (block_t *) &_prot_bss_end[state.heap_break];
		state.heap_break += size_words + HEADER_WORDS;
		BLOCK_SET_SIZE(new_block, size_words, false);

		BLOCK_LEFT(new_block) = state.rightmost;
		state.rightmost = new_block;
	} else {
		free_list_remove(new_block);
		size_t new_size = BLOCK_GET_SIZE(new_block);
		if(new_size > size_words)
			shrink_block(new_block, size_words);
		BLOCK_TGL_FREE(new_block);
	}

	return new_block->data;
}

void free(void *data) {
	block_t *block = container_of(data, block_t, data);

	assert(!BLOCK_GET_FREE(block));
	BLOCK_TGL_FREE(block);

	if(!BLOCK_IS_RIGHTMOST(block)) {
		block_t *right = BLOCK_RIGHT(block);
		assert(BLOCK_LEFT(right) == block);
		if(BLOCK_GET_FREE(right)) {
			free_list_remove(right);
			coalesce_blocks(block);
		}
	}

	if(!BLOCK_IS_LEFTMOST(block)) {
		block_t *left = BLOCK_LEFT(block);
		assert(BLOCK_RIGHT(left) == block);
		if(BLOCK_GET_FREE(left)) {
			free_list_remove(left);
			block = left;
			coalesce_blocks(block);
		}
	}

	free_list_append(block);
}
