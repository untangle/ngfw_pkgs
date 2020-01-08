# Untangle Traffic Classification Daemon
# Copyright (c) 2011 Untangle, Inc.
# All Rights Reserved
# Written by Michael A. Hotz

DESTDIR ?= .

DEBUG = -g3 -ggdb
#GPROF = -pg
SPEED = -O2

BUILDID := "$(shell date -u "+%G/%m/%d %H:%M:%S UTC")"

CXXFLAGS += $(DEBUG) $(GPROF) $(SPEED) -Wall -pthread
CXXFLAGS += -DBUILDID=\"$(BUILDID)\"

LDLIBS += -lpthread -ldl -lnetfilter_log

OBJFILES := $(patsubst src/%.cpp,src/%.o,$(wildcard src/*.cpp))

nflogd : $(OBJFILES)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(LDLIBS) -o $@ $^

install: nflogd
	mkdir -p $(DESTDIR)/usr/bin
	cp nflogd $(DESTDIR)/usr/bin/

$(OBJFILES) : Makefile src/*.h

clean : force
	rm -f nflogd
	rm -f src/*.o

force :
