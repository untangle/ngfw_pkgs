#include <stdio.h>
#include <json/json.h>

#include <libmvutil.h>
#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "json/object_utils.h"

#include "faild.h"

int main( int argc, char** argv )
{  
    if ( libmvutil_init() < 0 ) {
        printf( "Unable to initialize libmvutil\n" );
        return -1;
    }

    /* Configure the debug level */
    debug_set_mylevel( 10 );

    debug( 0, "Loading the file '%s'\n", argv[1] );
    struct json_object* json_object_1 = json_object_from_file( argv[1] );
    if ( json_object_1 == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_from_file\n" );
    }

    if ( is_error( json_object_1 )) {
        return errlog( ERR_CRITICAL, "json_object_from_file\n" );
    }

    debug( 0, "Loading the file '%s'\n", argv[2] );
    struct json_object* json_object_2 = json_object_from_file( argv[2] );
    if ( json_object_2 == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_from_file\n" );
    }

    if ( is_error( json_object_2 )) {
        return errlog( ERR_CRITICAL, "json_object_from_file\n" );
    }
    
    debug( 0, "json_object_equ : %d\n", json_object_equ( json_object_1, json_object_2 ));
}




