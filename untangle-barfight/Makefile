build_dir     = build

USE_DEBUG     = true

CC            = gcc
DEFINES       = -D_GNU_SOURCE -D_REENTRANT -DDEBUG_ON -DDEBUG_PKG=100
WARNINGS      = -Wall
OPTIMIZATIONS =
INC           = include src
INC_FLAGS     = $(patsubst %,-I%,$(INC))
LDDIR         = lib $(build_lib_path)  
LDDIR_FLAGS   = $(patsubst %,-L%,$(LDDIR))
LIBS          = mvutil netfilter_conntrack netfilter_queue json microhttpd m
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

object_dir=${build_dir}

## Barfight source
bf_source=utils/sched.c utils/lru.c json/server.c json/object_utils.c bouncer/shield.c bouncer/mode.c bouncer/load.c bouncer/reader.c bouncer/config.c bouncer/logs.c trie/item.c trie/base.c trie/root.c trie/level.c trie/trie.c net/packet.c net/nfqueue.c functions.c main.c

bf_objects=$(patsubst %.c,${object_dir}/%.o, ${bf_source})
bf_binary=barfight

default: ${object_dir} ${bf_binary}

${bf_binary}: ${bf_objects}
	@echo "==> gcc ${bf_objects} -> $@"
	@${CC} ${CFLAGS} ${LIBS_FLAGS} ${bf_objects} -o $@

${object_dir}/%.o: src/%.c
	@if [ ! -d `dirname $@` ] ; then echo "==> mkdir `dirname $@`" ; mkdir -p `dirname $@` ; fi
	@echo "==> gcc $@"
	@${CC} -c $< ${CFLAGS} -o $@

${object_dir}:
	@echo "==> Making directory ${object_dir}"
	@mkdir -p ${object_dir}

clean:
	@echo "==> Removing object files in ${object_dir}"
	@rm -rf ${object_dir}
	@rm -f ${binary}

install:
	@echo "Installing"

