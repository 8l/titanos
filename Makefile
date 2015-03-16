O ?= target/target/debug
DEP_O ?= target/target/debug/deps

ARCH ?= aarch64
export ARCH

TARGET_FILE=src/arch/$(ARCH)/target.json

include src/arch/$(ARCH)/Makefile.include

# Don't use default rules
.SUFFIXES:

RUSTC ?= rustc
CC = $(CROSS_COMPILE)gcc
AR = $(CROSS_COMPILE)ar
AS = $(CROSS_COMPILE)as
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

RSFLAGS += -O -g
CFLAGS += -O2

COMMON_FLAGS += -g
COMMON_FLAGS += -Wall -nostdlib

AFLAGS += -D__ASSEMBLY__ $(COMMON_FLAGS) -Ic/include
CFLAGS += $(COMMON_FLAGS) -Ic/include
LDFLAGS += $(COMMON_FLAGS)

RSFLAGS += --cfg arch_$(ARCH)
LDFLAGS +=
CFLAGS += -Irt/$(ARCH)/include/

AFLAGS += -D__ASSEMBLY__ $(COMMON_FLAGS) -Ic/include

.PHONY: all

all: $(O)/titanos.hex $(O)/titanos.bin

RT_SRCS=rt/$(ARCH)/head.S

RT_OBJS = $(RT_SRCS:.c=.o)
RT_OBJS := $(RT_OBJS:.S=.o)

RT_OBJS := $(addprefix $(O)/,$(RT_OBJS))

RT_OBJS_DEPS := $(RT_OBJS:.o=.o.d)
-include $(RT_OBJS_DEPS)

$(O)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@
	$(CC) $(CFLAGS) -MM -MT$@ -MF$@.d -c $< -o $@

$(O)/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) $(AFLAGS) -c $< -o $@
	$(CC) $(AFLAGS) -MM -MT$@ -MF$@.d -c $<

$(DEP_O)/libcompiler-rt.a: $(RT_OBJS) $(TARGET_FILE)
	mkdir -p $(dir $@)
	$(AR) rcs $@ $(RT_OBJS)

$(O)/titanos: $(DEP_O)/libcompiler-rt.a FORCE
	PATH=wrappers/:$$PATH cargo build --target $(TARGET_FILE) --verbose

$(O)/titanos.hex: $(O)/titanos
	$(OBJCOPY) -O ihex $(O)/titanos $(O)/titanos.hex

$(O)/titanos.bin: $(O)/titanos
	$(OBJCOPY) -O binary $(O)/titanos $(O)/titanos.bin

.PHONY: clean
clean:
	cargo clean
	echo "FIXME: del leftovers"

.PHONY: objdump
objdump:
	$(OBJDUMP) -D $(O)/titanos

.PHONY: run
run: qemu

.PHONY: debug
debug: qemu-gdb

.PHONY: qemu
qemu: qemu-$(ARCH)

.PHONY: qemu-gdb
qemu-gdb: qemu-$(ARCH)-gdb

.PHONY: qemu-aarch64
qemu-aarch64:
	qemu-system-aarch64 -nographic -machine vexpress-a15 -cpu cortex-a57 -m 2048 -kernel $(O)/titanos.bin

.PHONY: qemu-aarch64-gdb
qemu-aarch64-gdb:
	qemu-system-aarch64 -S -s -nographic -machine vexpress-a15 -cpu cortex-a57 -m 2048 -kernel $(O)/titanos.bin

.PHONY: gdb
gdb:
	$(CROSS_COMPILE)gdb -s $(O)/titanos -ex "target remote localhost:1234"

.PHONY: FORCE
