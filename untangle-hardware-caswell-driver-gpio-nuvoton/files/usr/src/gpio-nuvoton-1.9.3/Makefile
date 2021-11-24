CFILES = nct5581d.c nct6775f.c nct6776f.c nct6779d.c nct6104d.c nct6116d.c nct6796d.c nuvoton_main.c

HFILES = nct5581d.h nct6775f.h nct6776f.h nct6779d.h nct6104d.h nct6116d.h nct6796d.h nuvoton_main.h

DRIVER_NAME = gpio-nuvoton

obj-m += $(DRIVER_NAME).o
$(DRIVER_NAME)-objs := $(CFILES:.c=.o)

KSRC  ?= /lib/modules/$(shell uname -r)/build

all:
	make -C $(KSRC) M=$(shell pwd) modules

clean:
	make -C $(KSRC) M=$(shell pwd) clean
	@rm -rf Module.markers Module.symvers modules.order

