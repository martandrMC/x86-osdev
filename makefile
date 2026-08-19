BUILD_DIR   = build
SOURCE_DIR  = source
INCLUDE_DIR = include

VOLUME_LABEL = "OSDEV"
VOLUME_DIR   = $(BUILD_DIR)/volume
VOLUME_IMAGE = $(BUILD_DIR)/floppy.img
BOOT_SECTOR  = $(SOURCE_DIR)/boot.asm

CC = ./local/tooling/bin/i686-elf-gcc
LD = ./local/tooling/bin/i686-elf-ld

override CC_FLAGS_COM += -Wall -Wextra -pedantic \
	-ffreestanding -fno-pie -std=c99
override LD_FLAGS     += -m elf_i386 -nostdlib -N

### User Rules ###
.PHONY: debug release clean run

debug: CC_FLAGS = $(CC_FLAGS_COM) -O0
debug: $(VOLUME_IMAGE)

release: CC_FLAGS = $(CC_FLAGS_COM) -Werror -O2
release: $(VOLUME_IMAGE)

clean:
	-rm -r $(BUILD_DIR)

run: $(VOLUME_IMAGE)
	GDK_SCALE=2 qemu-system-i386 -display gtk -boot order=a \
		-M accel=kvm -m 16 -serial stdio \
		-drive format=raw,if=floppy,index=0,file=$<

### Whatever all this is ###
$(VOLUME_IMAGE): $(BOOT_SECTOR) $(VOLUME_DIR)/loader.sys
	dirname $@ | xargs mkdir -p
	dd bs=1K count=1440 if=/dev/zero of=$(VOLUME_IMAGE)
	mkfs.fat -F12 -f1 -s2 -r32 -n $(VOLUME_LABEL) $(VOLUME_IMAGE)
	nasm -fbin $(BOOT_SECTOR) -o /dev/stdout | \
		dd bs=1 seek=62 conv=notrunc of=$(VOLUME_IMAGE)
	mcopy -i $(VOLUME_IMAGE) $(VOLUME_DIR)/loader.sys ::/
	mattrib -i $(VOLUME_IMAGE) +r +s -a ::/loader.sys

GET_DEPS_C   = $(shell find $(SOURCE_DIR)/$1 -type f -name "*.c")
GET_DEPS_ASM = $(shell find $(SOURCE_DIR)/$1 -type f -name "*.asm")
GET_OBJS = $(patsubst $(SOURCE_DIR)%.c,$(BUILD_DIR)%.o,$(call GET_DEPS_C,$1)) \
	$(patsubst $(SOURCE_DIR)%.asm,$(BUILD_DIR)%.o,$(call GET_DEPS_ASM,$1))

$(VOLUME_DIR)/loader.sys: $(call GET_OBJS,loader)
	@dirname $@ | xargs mkdir -p
	$(LD) -T $(SOURCE_DIR)/loader/linker.ld $(LD_FLAGS) -o $@ $^

### Generic Compilation Rules ###
$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.asm
	@dirname $@ | xargs mkdir -p
	nasm -felf32 -w-zeroing -o $@ $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.c
	@dirname $@ | xargs mkdir -p
	$(CC) $(CC_FLAGS) -I$(INCLUDE_DIR) -c -o $@ $<
