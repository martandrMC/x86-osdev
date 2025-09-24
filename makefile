BUILD_DIR  = build/
SOURCE_DIR = source/

VOLUME_LABEL = "OSDEV"
VOLUME_DIR   = $(BUILD_DIR)volume/
VOLUME_IMAGE = $(BUILD_DIR)floppy.img
BOOT_SECTOR  = $(SOURCE_DIR)boot.asm

.PHONY: all clean

all: $(VOLUME_IMAGE)

run: $(VOLUME_IMAGE)
	GDK_SCALE=2 qemu-system-i386 -M accel=kvm -m 16 -display gtk \
		-boot order=a -drive format=raw,if=floppy,index=0,file=$< -d int

clean:
	-rm -r $(BUILD_DIR)

$(VOLUME_IMAGE): $(VOLUME_DIR)loader.sys
	dd bs=1K count=1440 if=/dev/zero of=$(VOLUME_IMAGE)
	mkfs.fat -F12 -n $(VOLUME_LABEL) -s2 $(VOLUME_IMAGE)
	nasm -fbin $(BOOT_SECTOR) -o /dev/stdout | \
		dd bs=1 seek=62 conv=notrunc of=$(VOLUME_IMAGE)
	mcopy -i $(VOLUME_IMAGE) $^ ::/
	mattrib -i $(VOLUME_IMAGE) +r +s -a \
		$(foreach f,$^,::/$(shell basename $f))

$(VOLUME_DIR)loader.sys: $(BUILD_DIR)loader/setup.o $(BUILD_DIR)loader/entry.o
	dirname $@ | xargs mkdir -p
	ld -m elf_i386 -T source/loader/linker.ld -nostdlib -N -o $@ $^

$(BUILD_DIR)%.o: $(SOURCE_DIR)%.asm
	dirname $@ | xargs mkdir -p
	nasm -felf32 -o $@ $<

$(BUILD_DIR)%.o: $(SOURCE_DIR)%.c
	dirname $@ | xargs mkdir -p
	gcc -Wall -m32 -ffreestanding -fno-pie -c -o $@ $<
