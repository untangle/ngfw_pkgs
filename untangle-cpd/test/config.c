#include <stdio.h>
#include <json/json.h>

#include <libmvutil.h>
#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "faild.h"


/**
 * 
 */
int main( int argc, char** argv )
{  
    if ( libmvutil_init() < 0 ) {
        printf( "Unable to initialize libmvutil\n" );
        return -1;
    }

    /* Configure the debug level */
    debug_set_mylevel( 10 );

    debug( 0, "Loading the file '%s'\n", argv[1] );
    struct json_object* json_object = json_object_from_file( argv[1] );
    if ( json_object == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_from_file\n" );
    }

    if ( is_error( json_object )) {
        return errlog( ERR_CRITICAL, "json_object_from_file\n" );
    }
        
    debug( 0, "Loaded the file %s\n", argv[1] );

    /* Convert the object to a c config */
    faild_config_t config;

    faild_config_load_json( &config, json_object );
    
    /* Convert the c config back to json */
    json_object = faild_config_to_json( &config );
    
    debug( 0, "Serializing file to %s\n", argv[1] );
    json_object_to_file( argv[2], json_object );
    debug( 0, "Serialized the file\n" );


    return 0;
}
