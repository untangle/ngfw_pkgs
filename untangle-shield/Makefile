build_dir     = build

USE_DEBUG     = true

CC            = gcc
DEFINES       = -D_GNU_SOURCE -D_REENTRANT -DDEBUG_ON -DDEBUG_PKG=100
WARNINGS      = -Wall
OPTIMIZATIONS =
INC           = ${build_dir}/include src
INC_FLAGS     = $(patsubst %,-I%,$(INC))
LDDIR         = lib $(build_lib_path)  
LDDIR_FLAGS   = $(patsubst %,-L%,$(LDDIR))
LIBS          = netfilter_conntrack netfilter_queue json microhttpd m
LIBS_FLAGS    = -pthread $(patsubst %,-l%,$(LIBS)) --warn-common
FLAGS        += 
CFLAGS        =  $(FLAGS) $(DEFINES) $(WARNINGS) $(OPTIMIZATIONS) $(INC_FLAGS) $(LDDIR_FLAGS)

ifeq ($(strip $(USE_DEBUG)),true)
    DEFINES  +=  -DDEBUG_ON
    FLAGS    += -g -ggdb
    STRIPCMD  = /bin/true -Not_stripping_DEBUG_MODE
else
    OPTIMIZATIONS += -funroll-loops -fomit-frame-pointer
    FLAGS    += $(WARNINGS) $(OPTIMIZATIONS)
    LDFLAGS  += -s
    STRIPCMD  = echo "Stripping debug symbols..." ; $(STRIP) --strip-debug --remove-section=.note --remove-section=.comment -x
endif

object_dir=${build_dir}/objects

## Libmvutil source
mvutil_source=libmvutil/src/debug.c libmvutil/src/errlog.c libmvutil/src/hash.c \
	libmvutil/src/libmvutil.c libmvutil/src/list.c libmvutil/src/lock.c \
	libmvutil/src/mailbox.c libmvutil/src/mvpoll.c libmvutil/src/unet.c \
	libmvutil/src/uthread.c libmvutil/src/utime.c

## Shield source
bf_source=src/utils/sched.c src/utils/lru.c src/json/server.c src/json/object_utils.c \
	src/bouncer/shield.c src/bouncer/mode.c src/bouncer/load.c src/bouncer/reader.c \
	src/bouncer/config.c src/bouncer/logs.c src/trie/item.c src/trie/base.c \
	src/trie/root.c src/trie/level.c src/trie/trie.c src/net/packet.c src/net/nfqueue.c \
	src/functions.c src/main.c ${mvutil_source}

bf_objects=$(patsubst %.c,${object_dir}/%.o, ${bf_source})
bf_binary=shield

default: ${object_dir} mvutil_includes ${bf_binary}

${bf_binary}: ${bf_objects} ${mvutil_source}
	@echo "==> gcc ${bf_objects} -> $@"
	@${CC} ${CFLAGS} ${LIBS_FLAGS} ${bf_objects} -o $@

${object_dir}/%.o: %.c
	@if [ ! -d `dirname $@` ] ; then echo "==> mkdir `dirname $@`" ; mkdir -p `dirname $@` ; fi
	@echo "==> gcc $@"
	@${CC} -c $< ${CFLAGS} -o $@

${object_dir}:
	@echo "==> Making directory ${object_dir}"
	@mkdir -p ${object_dir}

mvutil_includes:
	@echo "==> cp -a libmvutil/include/ ${build_dir}/include"
	@tar --exclude=.svn -cf - -C libmvutil include | tar -xf - -C ${build_dir}

clean:
	@echo "==> Removing object files in ${object_dir}"
	@rm -rf ${object_dir}
	@rm -f ${bf_binary}

install:
	@echo "Installing"

