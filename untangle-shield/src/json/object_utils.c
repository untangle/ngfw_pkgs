/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_shield.c $
 * Copyright (c) 2003-2008 Untangle, Inc. 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2,
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
 * NONINFRINGEMENT.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <stdarg.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>


#include "json/object_utils.h"

#define DEFAULT_BUFFER_SIZE 128

int json_object_utils_add( struct json_object* object, char* key, struct json_object* value )
{
    if ( object == NULL ) return errlogargs();

    if ( key == NULL ) return errlogargs();
    
    if ( value == NULL ) return errlogargs();

    json_object_object_add( object, key, value );

    return 0;
}

struct json_object* json_object_utils_build_string( size_t buffer_size, char* fmt, ... )
{
    if ( buffer_size <= 0 ) buffer_size = DEFAULT_BUFFER_SIZE;
    if ( fmt == NULL ) return errlogargs_null();

    /* amazed this works, it is dangerous because this goes onto the stack. */
    char buffer[buffer_size];

    va_list argptr;
    
    va_start( argptr, fmt );
    vsnprintf( buffer, buffer_size, fmt, argptr );
    va_end( argptr );

    struct json_object* object;
    if (( object = json_object_new_string( buffer )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_string\n" );
    }

    return object;
}

int json_object_utils_add_object( struct json_object* object, char* key, struct json_object* value )
{
    if ( object == NULL ) return errlogargs();
    if ( key == NULL ) return errlogargs();
    if ( value == NULL ) return errlogargs();

    if ( json_object_utils_add( object, key, value ) < 0 ) {
        json_object_put( value );
        return errlog( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    return 0;
}

int json_object_utils_add_string( struct json_object* object, char* key, char* string )
{
    struct json_object* json_string = NULL;

    if ( object == NULL ) return errlogargs();
    if ( key == NULL ) return errlogargs();
    if ( string == NULL ) return errlogargs();

    if (( json_string = json_object_new_string( string  )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_string\n" );
    }

    if ( json_object_utils_add( object, key, json_string ) < 0 ) {
        json_object_put( json_string );
        return errlog( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    return 0;
}


/**
 * Retrieve a string from a JSON object
 */
char* json_object_utils_get_string( struct json_object* object, char* key )
{
    if ( object == NULL ) return errlogargs_null();
    if ( key == NULL ) return errlogargs_null();

    struct json_object *value_json = NULL;
    char* value = NULL;
    if (( value_json = json_object_object_get( object, key )) == NULL ) {
        debug( 10, "The object doesn't contain a value for key %s\n", key );
        return NULL;
    }

    if (( value = json_object_get_string( value_json )) == NULL ) {
        debug( 10, "The object doesn't contain a string a key %s\n", key );
        return NULL;
    }

    return value;
}


int json_object_utils_add_int( struct json_object* object, char* key, int value )
{
    struct json_object* json_value = NULL;

    if ( object == NULL ) return errlogargs();
    if ( key == NULL ) return errlogargs();

    if (( json_value = json_object_new_int( value )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_string\n" );
    }

    if ( json_object_utils_add( object, key, json_value ) < 0 ) {
        json_object_put( json_value );
        return errlog( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    return 0;
}

int json_object_utils_add_double( struct json_object* object, char* key, double value )
{
    struct json_object* json_value = NULL;

    if ( object == NULL ) return errlogargs();
    if ( key == NULL ) return errlogargs();

    if (( json_value = json_object_new_double( value )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_string\n" );
    }

    if ( json_object_utils_add( object, key, json_value ) < 0 ) {
        json_object_put( json_value );
        return errlog( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    return 0;
}


int json_object_utils_array_add_object( struct json_object* object, struct json_object* value )
{
    if ( object == NULL ) return errlogargs();
    if ( value == NULL ) return errlogargs();

    if ( json_object_array_add( object, value ) < 0 ) {
        json_object_put( value );
        return errlog( ERR_CRITICAL, "json_object_array_add\n" );
    }
    
    return 0;
}

int json_object_utils_array_add_string( struct json_object* object, char* string )
{
    struct json_object* json_string = NULL;

    if ( object == NULL ) return errlogargs();
    if ( string == NULL ) return errlogargs();

    if (( json_string = json_object_new_string( string  )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_string\n" );
    }

    if ( json_object_array_add( object, json_string ) < 0 ) {
        json_object_put( json_string );
        return errlog( ERR_CRITICAL, "json_object_array_add\n" );
    }
    
    return 0;
}

int json_object_utils_array_add_int( struct json_object* object, int value )
{
    struct json_object* json_value = NULL;

    if ( object == NULL ) return errlogargs();

    if (( json_value = json_object_new_int( value )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_string\n" );
    }

    if ( json_object_array_add( object, json_value ) < 0 ) {
        json_object_put( json_value );
        return errlog( ERR_CRITICAL, "json_object_array_add\n" );
    }
    
    return 0;
}

int json_object_utils_array_add_double( struct json_object* object, double value )
{
    struct json_object* json_value = NULL;

    if ( object == NULL ) return errlogargs();

    if (( json_value = json_object_new_double( value )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_string\n" );
    }

    if ( json_object_array_add( object, json_value ) < 0 ) {
        json_object_put( json_value );
        return errlog( ERR_CRITICAL, "json_object_array_add\n" );
    }
    
    return 0;
}

struct json_object* json_object_utils_create_timeval( struct timeval* timeval )
{
    if ( timeval == NULL ) return errlogargs_null();

    struct json_object* timeval_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_string( timeval_json, "type", TIMEVAL_TYPE ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_new_object\n" );
        }

        if ( json_object_utils_add_int( timeval_json, "tv_sec", timeval->tv_sec ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }

        if ( json_object_utils_add_int( timeval_json, "tv_usec", timeval->tv_usec ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }

        return 0;
    }

    
    if (( timeval_json = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        json_object_put( timeval_json );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    return timeval_json;
}

int json_object_utils_parse_timeval( struct json_object* object, struct timeval* timeval )
{
    if ( object == NULL ) return errlogargs();
    if ( timeval == NULL ) return errlogargs();
    
    bzero( timeval, sizeof( struct timeval ));
    
    struct json_object* temp = NULL;
    if (( temp = json_object_object_get( object, "type" )) == NULL ) {
        debug( 10, "OBJECT_UTILS: missing type declaration\n" );
        return -1;
    }

    char *type;
    /* This should not be null */
    if (( type = json_object_get_string( temp )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_get_string\n" );
    }
    
    if ( strncmp( type, TIMEVAL_TYPE, sizeof( TIMEVAL_TYPE ) + 1 ) != 0 ) {
        debug( 10, "OBJECT_UTILS: invalid type declaration (%s)\n", type );
        return -1;
    }
    
    if (( temp = json_object_object_get( object, "tv_sec" )) == NULL ) {
        debug( 10, "OBJECT_UTILS: mussing tv_sec parameter\n" );
        return -1;
    }
    
    timeval->tv_sec = json_object_get_int( temp );
    
    if (( temp = json_object_object_get( object, "tv_usec" )) == NULL ) {
        debug( 10, "OBJECT_UTILS: mussing tv_usec parameter\n" );
        return -1;
    }
    timeval->tv_usec = json_object_get_int( temp );

    return 0;
}


