#!/usr/bin/env bash

BUILD="build"
SOURCE="source"

LABEL='OSDEV'
BOOT="$SOURCE/boot.asm"
IMAGE="$BUILD/floppy.img"

function add_sysfile {
	local name="::/$(basename $1 | cut -d. -f1 | \
		tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9').SYS"
	nasm -fbin $1 -o /dev/stdout | mcopy -i $IMAGE - $name
	mattrib -i $IMAGE +r +s -a $name
}

function process_task {
	case $1 in
		"clean")
			[ -d $BUILD ] && rm -r $BUILD
		;;

		"build")
			mkdir -p $BUILD
			dd bs=1K count=1440 if=/dev/zero of=$IMAGE
			mkfs.fat -F12 -n "$LABEL" -s2 $IMAGE
			nasm -fbin $BOOT -o /dev/stdout | \
				dd bs=1 seek=62 conv=notrunc of=$IMAGE
			add_sysfile "$SOURCE/loader.asm"
		;;

		"run")
			local floppy="-drive format=raw,if=floppy,index=0,file=$IMAGE"
			qemu-system-i386 -boot order=a $floppy
		;;
	esac
}

for t in "${@}"; do
	process_task $t
done
