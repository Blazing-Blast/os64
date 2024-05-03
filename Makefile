CC = gcc -c
LD = ld
NAME = main

CONFIG_DIR = /boot/loader/entries
OVMF_DIR = /usr/share/edk2-ovmf/x64
GNU_EFI_DIR = gnu-efi
TMP_DIR = tmp
BUILD_DIR = build
EFIROOT_DIR = efiroot
TARGET_DIR = $(EFIROOT_DIR)/EFI/BOOT

TARGET = $(TARGET_DIR)/BOOTX64.EFI
CONFIG_PRESET = example.conf
UEFI_SCRIPT = startup.nsh


DIRS = 				\
	$(TMP_DIR)		\
	$(EFIROOT_DIR) 	\
	$(BUILD_DIR)	\
	$(TARGET_DIR)   \

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

SO = $(BUILD_DIR)/$(NAME).so
PE = $(BUILD_DIR)/$(NAME).efi
PE_DEBUG = $(BUILD_DIR)/debug.efi


TARGETS = 		\
	$(OBJS) 	\
	$(SO)		\
	$(PE)		\
	$(PE_DEBUG)	\
	$(TARGET)	\



PE_SECTIONS =	\
	-j .text	\
	-j .sdata	\
	-j .data	\
	-j .rodata	\
	-j .dynamic	\
	-j .dynsym	\
	-j .rel		\
	-j .rela	\
	-j .rel.*	\
	-j .rela.*	\
	-j .reloc	\

DEBUG_SECTIONS =		\
	-j .debug_info		\
	-j .debug_abbrev	\
	-j .debug_loclists	\
	-j .debug_aranges  	\
	-j .debug_line     	\
	-j .debug_line_str  \
	-j .debug_str 		\

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

install: $(PE) $(TARGET_DIR)
	cp $< $(TARGET)

install-debug: $(PE_DEBUG) $(TARGET_DIR)
	cp $< $(TARGET)

all-debug: $(PE_DEBUG)

debug: install-debug $(PE)
	$(QEMU) $(QEMU_FLAGS) -hdb fat:rw:$(EFIROOT_DIR)\
	&gdb $(PE)

run: install
	$(QEMU) $(QEMU_FLAGS) -hdb fat:rw:$(EFIROOT_DIR)

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