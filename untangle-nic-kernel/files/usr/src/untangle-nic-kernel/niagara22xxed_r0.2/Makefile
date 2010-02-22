obj-m += n22xxed.o

all: default util
default:
	make -C /lib/modules/$(shell uname -r)/build/ SUBDIRS=$(PWD) modules

util:
	gcc -Wall -o n22xxed_util n22xxed_util.c

clean:
	rm -f *o *ko *.mod.c n22xxed_util 
