BUILD_DIR  = build
SOURCE_DIR = source

VOLUME_LABEL = "OSDEV"
VOLUME_DIR   = $(BUILD_DIR)/volume
VOLUME_IMAGE = $(BUILD_DIR)/floppy.img
BOOT_SECTOR  = $(SOURCE_DIR)/boot.asm

### User Rules ###
.PHONY: all run clean

all: $(VOLUME_IMAGE)

run: $(VOLUME_IMAGE)
	GDK_SCALE=2 qemu-system-i386 -M accel=kvm -m 16 -display gtk \
		-boot order=a -drive format=raw,if=floppy,index=0,file=$<

clean:
	-rm -r $(BUILD_DIR)

### Whatever all this is ###
$(VOLUME_IMAGE): $(VOLUME_DIR)/loader.sys
	dd bs=1K count=1440 if=/dev/zero of=$(VOLUME_IMAGE)
	mkfs.fat -F12 -n $(VOLUME_LABEL) -s2 $(VOLUME_IMAGE)
	nasm -fbin $(BOOT_SECTOR) -o /dev/stdout | \
		dd bs=1 seek=62 conv=notrunc of=$(VOLUME_IMAGE)
	mcopy -i $(VOLUME_IMAGE) $^ ::/
	mattrib -i $(VOLUME_IMAGE) +r +s -a \
		$(foreach f,$^,::/$(shell basename $f))

GET_DEPS = $(patsubst $(SOURCE_DIR)%.c,$(BUILD_DIR)%.o, \
	$(patsubst $(SOURCE_DIR)%.asm,$(BUILD_DIR)%.o, \
	$(shell find $(SOURCE_DIR)/$1 -type f -regex ".*\.\(asm\|c\)")))

$(VOLUME_DIR)/loader.sys: $(call GET_DEPS,loader)
	dirname $@ | xargs mkdir -p
	ld -m elf_i386 -T $(SOURCE_DIR)/loader/linker.ld -nostdlib -N -o $@ $^

### Generic Compilation Rules ###
$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.asm
	dirname $@ | xargs mkdir -p
	nasm -felf32 -o $@ $<

$(BUILD_DIR)/%.o: $(SOURCE_DIR)/%.c
	dirname $@ | xargs mkdir -p
	gcc -Wall -Wextra -pedantic -m32 -ffreestanding -fno-pie -c -o $@ $<
