NAME := kfs
BUILD_DIR := build
SRC_DIR := src

NASM := nasm
ZIG := zig
LD := ld

ASM_SRC := $(SRC_DIR)/boot/boot.asm
ASM_OBJ := $(BUILD_DIR)/boot.o

ZIG_SRC := $(SRC_DIR)/kernel/main.zig
ZIG_OBJ := $(BUILD_DIR)/kernel.o

KERNEL := $(BUILD_DIR)/kernel.elf
IMAGE := $(BUILD_DIR)/kfs.img
ISO := $(BUILD_DIR)/kfs.iso

ZIG_TARGET := x86-freestanding-none
ZIG_FLAGS := -target $(ZIG_TARGET) -mcpu i386 -O ReleaseSmall -fstrip -fno-stack-check -fno-stack-protector -femit-bin=$(ZIG_OBJ)

all: $(KERNEL) image size

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(ASM_OBJ): $(ASM_SRC) | $(BUILD_DIR)
	$(NASM) -f elf32 $< -o $@

$(ZIG_OBJ): $(ZIG_SRC) $(SRC_DIR)/kernel/*.zig $(SRC_DIR)/kernel/lib/*.zig | $(BUILD_DIR)
	$(ZIG) build-obj $(ZIG_SRC) $(ZIG_FLAGS)

$(KERNEL): $(ASM_OBJ) $(ZIG_OBJ) linker/kernel.ld
	$(LD) -m elf_i386 -nostdlib -T linker/kernel.ld -o $(KERNEL) $(ASM_OBJ) $(ZIG_OBJ)

image: $(KERNEL)
	./scripts/mkimg.sh

size:
	./scripts/check_size.sh

run: all
	./scripts/run_qemu.sh

debug: all
	qemu-system-i386 -m 128M -s -S -cdrom $(ISO)

clean:
	rm -rf $(BUILD_DIR)

fclean: clean

re: fclean all

.PHONY: all image size run debug clean fclean re
