BUILD_DIR := build
SRC_DIR := src

NASM := nasm
ZIG := zig
LD := ld

ASM_SRC := $(wildcard $(SRC_DIR)/boot/*.asm)
ASM_OBJ := $(patsubst $(SRC_DIR)/boot/%.asm,$(BUILD_DIR)/%.o,$(ASM_SRC))

KERNEL_SRC := $(wildcard $(SRC_DIR)/kernel/*.zig) $(wildcard $(SRC_DIR)/kernel/lib/*.zig)
KERNEL_OBJ := $(BUILD_DIR)/kernel.o
KERNEL_ELF := $(BUILD_DIR)/kernel.elf
IMAGE := $(BUILD_DIR)/kfs.img
ISO := $(BUILD_DIR)/kfs.iso

ZIG_TARGET := x86-freestanding-none
ZIG_FLAGS := -target $(ZIG_TARGET) -mcpu i386 -O ReleaseSmall -fstrip -fno-stack-check -fno-stack-protector -femit-bin=$(KERNEL_OBJ)

all: $(KERNEL_ELF) image size

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/boot/%.asm | $(BUILD_DIR)
	$(NASM) -f elf32 $< -o $@

$(KERNEL_OBJ): $(SRC_DIR)/kernel/main.zig $(KERNEL_SRC) | $(BUILD_DIR)
	$(ZIG) build-obj $(SRC_DIR)/kernel/main.zig $(ZIG_FLAGS)

$(KERNEL_ELF): $(ASM_OBJ) $(KERNEL_OBJ) linker/kernel.ld
	$(LD) -m elf_i386 -nostdlib -T linker/kernel.ld -o $@ $(ASM_OBJ) $(KERNEL_OBJ)

image: $(KERNEL_ELF)
	./scripts/mkimg.sh

size:
	@test ! -f $(KERNEL_ELF) || [ $$(stat -c %s $(KERNEL_ELF)) -le 10485760 ]
	@test ! -f $(IMAGE) || [ $$(stat -c %s $(IMAGE)) -le 10485760 ]
	@test ! -f $(ISO) || [ $$(stat -c %s $(ISO)) -le 10485760 ]

# Unit tests run with host target using hardware mocks.
test:
	$(ZIG) test $(SRC_DIR)/kernel/tests.zig -O Debug

run: all
	./scripts/run_qemu.sh

debug: all
	qemu-system-i386 -m 128M -s -S -drive file=$(IMAGE),format=raw,if=floppy

clean:
	rm -rf $(BUILD_DIR)

fclean: clean

re: fclean all

.PHONY: all image size test run debug clean fclean re
