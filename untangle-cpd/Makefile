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
LIBS          = json microhttpd dl rt m sysfs lua5.1
LIBS_FLAGS    = -pthread $(patsubst %,-l%,$(LIBS)) --warn-common
FLAGS        += -rdynamic -std=c99
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

## cpd source
cpd_source=src/json/server.c src/json/object_utils.c \
	src/json/serializer.c src/main.c src/functions.c \
	src/cpd/config.c src/cpd/manager.c src/cpd/status.c \
	src/cpd/reader.c ${mvutil_source} libipulog/libipulog.c

cpd_objects=$(patsubst %.c,${object_dir}/%.o, ${cpd_source})
cpd_binary=cpd

default: ${object_dir} mvutil_includes libipulog_includes ${cpd_binary}

${cpd_binary}: ${cpd_objects}
	@echo "==> gcc ${cpd_objects} -> $@"
	@${CC} ${CFLAGS} ${LIBS_FLAGS} ${cpd_objects} -o $@

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

libipulog_includes:
	@echo "==> cp -a libipulog/include/ ${build_dir}/include"
	@tar --exclude=.svn -cf - -C libipulog include | tar -xf - -C ${build_dir}

clean:
	@echo "==> Removing object files in ${object_dir}"
	@rm -rf ${object_dir}
	@rm -f ${cpd_binary}

install:
	@echo "Installing"
