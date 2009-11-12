/*
 * Copyright (c) 2003-2008 Untangle, Inc.
 * All rights reserved.
 *
 * This software is the confidential and proprietary information of
 * Untangle, Inc. ("Confidential Information"). You shall
 * not disclose such Confidential Information.
 *
 * $Id$
 */

#include <pthread.h>

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <dirent.h>
#include <string.h>
#include <dlfcn.h>


#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/hash.h>
#include <mvutil/unet.h>

#include "cpd.h"

#define _LIB_HASH_TABLE_SIZE 37
#define _LIB_SUFFIX ".so"

static struct
{
    int libs_length;
    cpd_uplink_test_lib_t *libs;
    ht_t name_to_test_classes;
    pthread_mutex_t mutex;
} _globals = {
    .libs_length = 0,
    .libs = NULL,
    .mutex = PTHREAD_MUTEX_INITIALIZER
};

/*
 * @params lib_path_name Full path to the library.
 * @params lib_file_name The name of the library file itself.
 */
static int _load_library( char* lib_path_name, char* lib_file_name, cpd_uplink_test_lib_t* lib );
                          

static int _lib_name_filter( const struct dirent* dir );

int cpd_libs_init( void )
{
    if ( ht_init( &_globals.name_to_test_classes, _LIB_HASH_TABLE_SIZE, string_hash_func, string_equ_func,
                  HASH_FLAG_NO_LOCKS | HASH_FLAG_FREE_CONTENTS ) < 0 ) {
        return errlog( ERR_CRITICAL, "ht_init" );
    }

    return 0;
}

int cpd_libs_load_test_classes( char* lib_dir_name )
{
    if ( lib_dir_name == NULL ) return errlogargs();

    struct dirent **dir_list;
    int num_libs = 0;

    /* Full path to a lib */
    char *lib_path_name = NULL;

    int _critical_section()
    {
        if ( _globals.libs_length != 0 ) return errlog( ERR_CRITICAL, "Libraries already loaded.\n" );

        if ( _globals.libs != NULL ) return errlog( ERR_CRITICAL, "Libraries already loaded.\n" );

        int lib_path_name_length = strnlen( lib_dir_name, FILENAME_MAX ) + 
            sizeof((( struct dirent *)0)->d_name ) + 10;
        
        if (( lib_path_name = calloc( 1, lib_path_name_length )) == NULL ) {
            return errlogmalloc();
        }

        int c = 0;
        debug( 4, "Trying to load libs from '%s'\n", lib_dir_name );
        if (( num_libs = scandir( lib_dir_name, &dir_list, _lib_name_filter, alphasort )) < 0 ) {
            return perrlog( "scandir" );
        }
        
        if ( num_libs == 0 ) {
            debug( 0, "There are no libraries to load.\n" );
            return 0;
        }

        if (( _globals.libs = calloc( 1, num_libs * sizeof( cpd_uplink_test_lib_t ))) == NULL ) {
            return errlogmalloc();
        }
        
        for ( c = 0 ; c < num_libs ; c++ ) {
            debug( 4, "Loading the library '%s'\n", dir_list[c]->d_name );

            snprintf( lib_path_name, lib_path_name_length, "%s/%s", lib_dir_name, dir_list[c]->d_name );

            /* One failed library shouldn't cause all of them to fail. */
            if ( _load_library( lib_path_name, dir_list[c]->d_name, 
                                &_globals.libs[_globals.libs_length] ) < 0 ) {
                errlog( ERR_CRITICAL, "_load_library\n" );
            } else {
                debug( 4, "Loaded the library '%s'\n", dir_list[c]->d_name );
                _globals.libs_length++;
            }
            
            free( dir_list[c] );
            dir_list[c] = NULL;
        }
        
        free( dir_list );
        
        return 0;
    }

    int ret = 0;
    
    if ( pthread_mutex_lock( &_globals.mutex ) < 0 ) return perrlog( "pthread_mutex_lock" );
    ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) < 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( lib_path_name != NULL ) free( lib_path_name );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    return 0;
}

int cpd_libs_get_test_class( char* test_class_name, cpd_uplink_test_class_t** test_class )
{
    if ( test_class_name == NULL ) return errlogargs();
    if ( test_class == NULL ) return errlogargs();

    debug( 5, "Lookup up the test class '%s'\n", test_class_name );
    *test_class = (cpd_uplink_test_class_t*)ht_lookup( &_globals.name_to_test_classes, test_class_name );
    if ( *test_class == NULL ) {
        debug( 5, "The test class '%s' doesn't exist\n", test_class_name );
    }

    return 0;
}


cpd_uplink_test_class_t* cpd_uplink_test_class_malloc( void )
{
    cpd_uplink_test_class_t* test_class = NULL;
    if (( test_class = calloc( 1, sizeof( cpd_uplink_test_class_t ))) == NULL ) {
        return errlogmalloc_null();
    }

    return test_class;
}

int cpd_uplink_test_class_init( cpd_uplink_test_class_t* test_class, char* name,
                                  int (*init)( cpd_uplink_test_instance_t *instance ),
                                  int (*run)( cpd_uplink_test_instance_t *instance ),
                                  int (*cleanup)( cpd_uplink_test_instance_t *instance ),
                                  int (*destroy)( cpd_uplink_test_instance_t *instance ),
                                  struct json_array* params )
{
    if ( test_class == NULL ) return errlogargs();
    
    strncpy( test_class->name, name, sizeof( test_class->name ));

    test_class->init = init;
    test_class->run  = run;
    test_class->cleanup = cleanup;
    test_class->params = params;

    return 0;
}


cpd_uplink_test_class_t* 
cpd_uplink_test_class_create( char* name,
                                int (*init)( cpd_uplink_test_instance_t *instance ),
                                int (*run)( cpd_uplink_test_instance_t *instance ),
                                int (*cleanup)( cpd_uplink_test_instance_t *instance ),
                                int (*destroy)( cpd_uplink_test_instance_t *instance ),
                                struct json_array* params )
{
    cpd_uplink_test_class_t* test_class = NULL;
    
    if (( test_class = cpd_uplink_test_class_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "cpd_uplink_test_class_malloc\n" );
    }

    if ( cpd_uplink_test_class_init( test_class, name, init, run, cleanup, destroy, params ) < 0 ) {
        return errlog_null( ERR_CRITICAL, "cpd_uplink_test_class_init\n" );
    }

    return 0;
}

/** 
 * Utility function to call a command and wait for the return code.
 * system() does some badnesss with regards to the signal handlers.
 */
int cpd_libs_system( cpd_uplink_test_instance_t* instance, const char* path, const char* arg0, ... )
{
    va_list argptr;

    if ( path == NULL ) return errlogargs();
    if ( arg0 == NULL ) return errlogargs();
    if ( instance == NULL ) return errlogargs();

    int size = 0;
    va_start(argptr, arg0);
    while ( va_arg( argptr, char* ) != NULL ) size++;
    va_end(argptr);

    char* argv[size+2];
    char* argn;
    argv[0] = (char*)arg0;
    argv[size+1] = NULL;
    
    int c = 1;
    int is_debug_enabled = debug_get_mylevel() >= 10;

    char command_string[1024];
    command_string[0] = '\0';
    
    if ( is_debug_enabled ) {
        bzero( command_string, sizeof( command_string ));
        strncat( command_string, path, sizeof( command_string));
    }

    va_start(argptr, arg0);
    while (( argn = va_arg( argptr, char* )) != NULL ) {
        if ( is_debug_enabled ) {
            strncat( command_string, " ", sizeof( command_string ));
            strncat( command_string, argn, sizeof( command_string ));
        }
        argv[c++] = argn;
    }
    va_end(argptr);
    
    if ( is_debug_enabled ) debug( 10, "Running the command: '%s'\n", command_string );

    int exec_status;
    pid_t pid;
    int return_code;
    
    pid = fork();
    if ( pid == 0 ) {
        /* Setup the environment */

        char messages[256];
        int p = 0;
        
        bzero( messages, sizeof( messages ));


        /* Run the command to test DNS */
        cpd_uplink_t* uplink = &instance->uplink;
        
        char* ether_str = messages;
        p += 24;
                
        char* timeout_ms_str = messages + p;
        p += snprintf( timeout_ms_str, sizeof( messages ) - p, "%d", instance->config.timeout_ms ) + 1;
        
        char* aii_str = messages + p;
        p += snprintf( aii_str, sizeof( messages ) - p, "%d", uplink->alpaca_interface_id ) + 1;
        
        if ( setenv( "CPD_ALPACA_INTERFACE_ID", aii_str, 1 ) < 0 ) {
            perrlog( "setenv" );
            _exit( 254 );
        }

        if ( setenv( "CPD_OS_NAME", uplink->os_name, 1 ) < 0 ) {
            perrlog( "setenv" );
            _exit( 254 );
        }

        if ( setenv( "CPD_PRIMARY_ADDRESS", unet_inet_ntoa( uplink->primary_address.s_addr ), 1 ) < 0 ) {
            perrlog( "setenv" );
            _exit( 254 );
        }

        if ( setenv( "CPD_GATEWAY", unet_inet_ntoa( uplink->gateway.s_addr ), 1 ) < 0 ) {
            perrlog( "setenv" );
            _exit( 254 );
        }

        if ( setenv( "CPD_TIMEOUT_MS", timeout_ms_str, 1 ) < 0 ) {
            perrlog( "setenv" );
            _exit( 254 );
        }

        if ( setenv( "CPD_MAC_ADDRESS", ether_ntoa_r( &uplink->mac_address, ether_str ), 1 ) < 0 ) {
            perrlog( "setenv" );
            _exit( 254 );
        }
        
        if ( execv( path, argv ) < 0 ) perrlog( "execv" );
        _exit( 1 );
    } else if ( pid < 0 ) {
        return perrlog( "fork" );
    }  else {
        if ( waitpid( pid, &exec_status, 0 ) < 0 ) return perrlog( "waitpid" );
        
        if ( WIFEXITED( exec_status ) != 1 ) return errlog( ERR_CRITICAL, "Child process did not exit.\n" );
        
        return_code = WEXITSTATUS( exec_status );
    }

    return return_code;
}

/**
 * This must be called with the mutex locked.
 */
static int _load_library( char* lib_path_name, char* lib_file_name, cpd_uplink_test_lib_t* lib )
{
    void *handle = NULL;

    /* random magic number. */
    char function_name[300];

    /* name of the library minus the .so */
    char l[300];

    int c = 0;

    int num_test_classes = 0;

    char *so;

    strncpy( l, lib_file_name, sizeof( l ));
    if (( so = strstr( l, _LIB_SUFFIX )) == NULL ) {
        return errlog( ERR_CRITICAL, "lib_file_name '%s' doesn't end in .so", l );
    }
    so[0] = '\0';
    
    cpd_uplink_test_class_t *test_classes = NULL;

    snprintf( function_name, sizeof( function_name ), "cpd_%s_prototype", l );
    
    int _critical_section()
    {
        cpd_uplink_test_prototype_t function;

        if (( handle = dlopen( lib_path_name, RTLD_LAZY | RTLD_LOCAL )) == NULL ) {
            return errlog( ERR_WARNING, "Unable to open the library %s, %s\n", lib_file_name, dlerror());
        }
        
        function = (cpd_uplink_test_prototype_t)dlsym( handle, function_name );
        if ( function == NULL ) {
            return errlog( ERR_WARNING, "The library '%s' is missing the function '%s'\n", lib_file_name,
                           function_name );
        }

        if ( function( lib ) < 0 ) {
            return errlog( ERR_CRITICAL, "Unable to retrieve library prototype from %s\n", lib_file_name );
        }
        
        if ( lib->init() < 0 ) return errlog( ERR_CRITICAL, "lib->init\n" );

        if (( num_test_classes = lib->get_test_classes( &test_classes )) <= 0 ) {
            return errlog( ERR_CRITICAL, "lib->get_test_classes\n" );
        }
        
        if ( test_classes == NULL ) {
            return errlog( ERR_CRITICAL, "lib->get_test_classes\n" );
        }
        
        cpd_uplink_test_class_t *test_class = NULL;
        for ( c = 0 ; c < num_test_classes; c++ ) {
            if (( test_class = calloc( 1, sizeof( cpd_uplink_test_class_t ))) == NULL ) {
                return errlogmalloc();
            }
            memcpy( test_class, &test_classes[c], sizeof( cpd_uplink_test_class_t ));
            debug( 4, "Loading the test '%s'\n", test_class->name );
            if ( ht_add( &_globals.name_to_test_classes, test_class->name, test_class ) < 0 ) {
                return errlog( ERR_CRITICAL, "ht_add" );
            }
        }

        return 0;
    }

    int ret = _critical_section();

    if ( test_classes != NULL ) {
        free( test_classes );
    }

    if ( ret < 0 ) {
        if ( handle != NULL ) {
            dlclose( handle );
        }
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }
    
    
    return 0;
}



static int _lib_name_filter( const struct dirent* file )
{
    if ( file == NULL ) {
        errlogargs();
        return 0;
    }

    debug( 4, "Testing the file '%s'\n", file->d_name );

    char *match = NULL;
    
    if ( file->d_type != DT_REG ) {
        debug( 4, "The file '%s' is not a regular file %d.\n", file->d_name, file->d_type );
        return 0;
    }

    if ((( match = strstr( file->d_name, _LIB_SUFFIX )) == NULL ) || 
        ( strnlen( match, sizeof( _LIB_SUFFIX ) + 1 ) != ( sizeof( _LIB_SUFFIX ) - 1 ))) {
        debug( 4, "The file '%s' does not end in '.so'.\n", file->d_name );
        return 0;
    }

    return 1;
}
