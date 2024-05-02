CC = gcc -c
LD = ld
NAME = main

GNU_EFI_DIR = gnu-efi
TARGET_DIR = /boot/EFI/osdev
CONFIG_DIR = /boot/loader/entries
CONFIG_PRESET = example.conf
OVMF_DIR = /usr/share/edk2-ovmf/x64
TMP_DIR = tmp
EFIROOT_DIR = efiroot
UEFI_SCRIPT = startup.nsh

LIB =												\
	-L$(GNU_EFI_DIR)/x86_64/lib						\
	-L$(GNU_EFI_DIR)/x86_64/gnuefi					\
	-T$(GNU_EFI_DIR)/gnuefi/elf_x86_64_efi.lds 		\
	$(GNU_EFI_DIR)/x86_64/gnuefi/crt0-efi-x86_64.o 	\
	-lgnuefi										\
	-lefi 											\
	-nostdlib 										\

INC = 							\
	-I$(GNU_EFI_DIR)/inc 		\
	-I$(GNU_EFI_DIR)/x86_64/inc \

CFLAGS = 						\
	-fno-stack-protector 		\
	-fpic 						\
	-fshort-wchar 				\
	-mno-red-zone 				\
	-ffreestanding 				\
	-fno-stack-check 			\
	-maccumulate-outgoing-args 	\
	-MMD -MP 					\
	-ggdb  						\
	$(INC) 						\
    -DEFI_FUNCTION_WRAPPER 		\

SOFLAGS =		\
	-shared 	\
	-Bsymbolic	\

LDFLAGS =  			\
	-g 				\
    -znocombreloc	\
	$(LIB)			\


SRCS := \
	$(NAME).c \
	
OBJS := $(patsubst %.c,%.o,$(SRCS))
DEPS := $(patsubst %.c,%.d,$(SRCS))

SO = $(NAME).so
PE = $(NAME).efi
PE_DEBUG = debug.efi
IMG = $(NAME).img
IMG_DEBUG = debug.img

DIRS = 				\
	$(TMP_DIR)		\
	$(EFIROOT_DIR) 	\

TARGETS = 		 \
	$(OBJS) 	 \
	$(SO)		 \
	$(PE)		 \
	$(PE_DEBUG)	 \
	$(IMG)		 \
	$(IMG_DEBUG) \



PE_SECTIONS = \
	-j .text \
	-j .sdata \
	-j .data \
	-j .rodata \
	-j .dynamic \
	-j .dynsym \
	-j .rel \
	-j .rela \
	-j .rel.* \
	-j .rela.* \
	-j .reloc \

DEBUG_SECTIONS = \
	-j .debug_info \
	-j .debug_abbrev   \
	-j .debug_loclists      \
	-j .debug_aranges  \
	-j .debug_line     \
	-j .debug_line_str     \
	-j .debug_str \

QEMU = qemu-system-x86_64

QEMU_FLAGS = 																		\
	-cpu qemu64 																	\
	-net none 																		\
	-s 																				\
	--serial stdio																	\
	-drive if=pflash,format=raw,unit=0,file=$(OVMF_DIR)/OVMF_CODE.fd,readonly=on	\
	-drive if=pflash,format=raw,unit=1,file=$(OVMF_DIR)/OVMF_VARS.fd 				\


all: $(DIRS) $(TARGETS)

clean: 
	rm -rf $(TARGETS)
	rm -rf ${DIRS:%=%/*}
	

new: clean all

install: $(PE)
	cp $< $(TARGET_DIR)/$<
	cp $(CONFIG_PRESET) $(CONFIG_DIR)/

all-debug: $(PE_DEBUG)

debug: $(PE_DEBUG) $(PE)
	uefi-run -b $(OVMF_DIR)/OVMF.fd -q $(QEMU) $(PE) -- $(QEMU_FLAGS)\
	&gdb $(PE)

run: $(IMG)
	$(QEMU) $(QEMU_FLAGS) -drive if=ide,format=raw,file=$<

$(IMG): $(PE)
	rm -rf $(EFIROOT_DIR)/*
	cp $^ $(EFIROOT_DIR)
	cp $(UEFI_SCRIPT) $(EFIROOT_DIR)
	echo $< >> $(EFIROOT_DIR)/$(UEFI_SCRIPT)
	dd if=/dev/zero of=$(TMP_DIR)/$@ bs=512 count=91669
	dd if=/dev/zero of=$@ bs=512 count=111669
	parted $@ -s -a minimal mklabel gpt
	parted $@ -s -a minimal mkpart EFI FAT16 2048s 93716s
	parted $@ -s -a minimal toggle 1 boot
	mformat -i $(TMP_DIR)/$@ -h 32 -t 32 -n 64 -c 1
	mcopy -i $(TMP_DIR)/$@ $(EFIROOT_DIR)/* ::
	dd if=$(TMP_DIR)/$@ of=$@ bs=512 count=91669 seek=2048 conv=notrunc

$(IMG_DEBUG): $(PE_DEBUG)
	rm -rf $(EFIROOT_DIR)/*
	cp $^ $(EFIROOT_DIR)
	cp $(UEFI_SCRIPT) $(EFIROOT_DIR)
	echo $< >> $(EFIROOT_DIR)/$(UEFI_SCRIPT)
	dd if=/dev/zero of=$(TMP_DIR)/$@ bs=512 count=91669
	dd if=/dev/zero of=$@ bs=512 count=111669
	parted $@ -s -a minimal mklabel gpt
	parted $@ -s -a minimal mkpart EFI FAT16 2048s 93716s
	parted $@ -s -a minimal toggle 1 boot
	mformat -i $(TMP_DIR)/$@ -h 32 -t 32 -n 64 -c 1
	mcopy -i $(TMP_DIR)/$@ $(EFIROOT_DIR)/* ::
	dd if=$(TMP_DIR)/$@ of=$@ bs=512 count=91669 seek=2048 conv=notrunc

$(PE_DEBUG): $(SO)
	objcopy $(PE_SECTIONS) $(DEBUG_SECTIONS) --target efi-app-x86_64 --subsystem=10 $^ $@

$(PE): $(SO)
	objcopy $(PE_SECTIONS) --target efi-app-x86_64 --subsystem=10 $^ $@

$(SO): $(OBJS)
	$(LD) $(LDFLAGS) $(SOFLAGS) $^ -o $@

$(DIRS):
	mkdir -p $(DIRS)

%.o: %.c
	$(CC) $(CFLAGS) $< -o $@

-include $(DEPS)