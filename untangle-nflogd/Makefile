# Untangle Traffic Classification Daemon
# Copyright (c) 2011 Untangle, Inc.
# All Rights Reserved
# Written by Michael A. Hotz

DEBUG = -g3 -ggdb
#GPROF = -pg
SPEED = -O2

BUILDID := "$(shell date -u "+%G/%m/%d %H:%M:%S UTC")"
VERSION := $(shell svn info | /usr/bin/awk '/Revision/ { print $$2 }')
SYSTEM := $(shell uname)
ARCH := $(shell uname -m)

PLATFORM = -D__LINUX__
LIBFILES = -lpthread -ldl -lnetfilter_log

CXXFLAGS = $(DEBUG) $(GPROF) $(SPEED) -Wall -pthread

CXXFLAGS += -DVERSION=\"$(VERSION)\"
CXXFLAGS += -DBUILDID=\"$(BUILDID)\"
CXXFLAGS += -DPLATFORM=\"$(PLATFORM)\"

OBJFILES := $(patsubst src/%.cpp,src/%.o,$(wildcard src/*.cpp))

untangle-nflogd : $(OBJFILES)
	$(CXX) $(DEBUG) $(GPROF) $(SPEED) $(OBJFILES) $(LIBPATH) $(LIBFILES) -o nflogd

$(OBJFILES) : Makefile src/*.h

clean : force
	rm -f nflogd
	rm -f src/*.o

force :

