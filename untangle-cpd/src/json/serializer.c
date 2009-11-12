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

#include <stdarg.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>


#include "json/object_utils.h"
#include "json/serializer.h"

static int _is_terminator( json_serializer_field_t* field );

static int _validate_array_serializer( json_serializer_array_t* arg );

static int _validate_field( json_serializer_field_t* field );

/* Create a new JSON object and fill in the fields from c_struct */
struct json_object* json_serializer_to_json( json_serializer_t* serializer, void* c_data )
{
    if ( serializer == NULL ) return errlogargs_null();

    if ( c_data == NULL ) return errlogargs_null();

    struct json_object* json_object = NULL;
    if (( json_object = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    int _critical_section() {
        debug( 10, "Converting a %s to JSON\n", serializer->name );
        
        int c = 0;
        json_serializer_field_t* field = NULL;
        
        for ( c = 0 ; ; c++ ) {
            field = &serializer->fields[c];
            if ( _is_terminator( field )) break;
            if ( _validate_field( field ) < 0 ) return errlog( ERR_CRITICAL, "_validate_field\n" );
            if ( field->to_json == NULL ) continue;

            debug( 10, "Converting the field %s.%s to JSON\n", serializer->name, field->name );
            
            if ( field->to_json( json_object, field, c_data ) < 0 ) {
                return errlog( ERR_CRITICAL, "field->to_json\n" );
            }
        }

        return 0;
    }

    if ( _critical_section() < 0 ) {
        json_object_put( json_object );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }
    
    return json_object;
}

/* Using the fields in serializer, fill in the value from json_object into c_struct */
int json_serializer_to_c( json_serializer_t* serializer, struct json_object* json_object, void* c_data )
{
    if ( serializer == NULL ) return errlogargs();
    if ( json_object == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    
    int c = 0;
    struct json_object* json_field;

    json_serializer_field_t* field = NULL;

    for ( c = 0 ; ; c++ ) {
        field = &serializer->fields[c];

        if ( _is_terminator( field )) break;
        
        if ( _validate_field( field ) < 0 ) return errlog( ERR_CRITICAL, "_validate_field\n" );
        if ( field->to_c == NULL ) continue;
        
        debug( 10, "Converting the field %s.%s to C\n", serializer->name, field->name );
        
        if (( json_field = json_object_object_get( json_object, field->name )) == NULL ) {
            if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_CALL ) {
            } else if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_IGNORE ) {
                debug( 10, "Ignoring missing field %s.%s to C\n", serializer->name, field->name );
                continue;
            } else if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_ERROR ) {
                return errlog( ERR_WARNING, "Missing field %s.%s\n",  serializer->name, field->name );
            } else {
                return errlog( ERR_CRITICAL, "Invalid if_empty flag %d\n", field->if_empty );
            }
        }
            
        /* Use the object if you do not want to fetch the arg */
        if ( field->fetch_arg == 0 ) json_field = json_object;
        
        if ( field->to_c( json_field, field, c_data ) < 0 ) {
            return errlog( ERR_CRITICAL, "field->to_json\n" );
        }            
    }
    
    return 0;
}

int json_serializer_to_c_string( struct json_object* json_object, json_serializer_field_t* field, 
                                 void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    if ( field->arg == NULL ) return errlogargs();

    json_serializer_string_t* arg = field->arg;
    if ( arg->len <= 0 ) return errlog( ERR_CRITICAL, "Invalid string length %d\n", arg->len );
    if ( arg->offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", arg->offset );

    if ( json_object_is_type( json_object, json_type_string ) == 0 ) {
        debug( 10, "The field %s is not a string.\n", field->name );
        if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_IGNORE ) return 0;
        return -1;
    }
    
    char* c_string = NULL;
    if (( c_string = json_object_get_string( json_object )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_get_string\n" );
    }

    strncpy( &((char*)c_data)[arg->offset], c_string, arg->len );
    return 0;
}

int json_serializer_to_json_string( struct json_object* json_object, json_serializer_field_t* field, 
                                    void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    if ( field->arg == NULL ) return errlogargs();

    json_serializer_string_t* arg = field->arg;
    if ( arg->len <= 0 ) return errlog( ERR_CRITICAL, "Invalid string length %d\n", arg->len );
    if ( arg->offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", arg->offset );

    char* c_string = &((char*)c_data)[arg->offset];
    if ( strnlen( c_string, arg->len ) >= arg->len ) return errlog( ERR_CRITICAL, "Invalid string\n" );
    
    if ( json_object_utils_add_string( json_object, field->name, c_string ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_add_string\n" );
    }

    return 0;
}

int json_serializer_to_c_int( struct json_object* json_object, json_serializer_field_t* field, 
                              void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    int offset = *((int*)(&field->arg)) / sizeof( int );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    if ( json_object_is_type( json_object, json_type_int ) == 0 ) {
        debug( 10, "The field %s is not an int.\n", field->name );
        if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_IGNORE ) return 0;
        return -1;
    }
    
    ((int*)c_data)[offset] = json_object_get_int( json_object );
    
    return 0;
}

int json_serializer_to_json_int( struct json_object* json_object, json_serializer_field_t* field, 
                                 void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    int offset = *((int*)(&field->arg)) / sizeof( int );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    if ( json_object_utils_add_int( json_object, field->name, ((int*)c_data)[offset] ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
    }

    return 0;    
}

int json_serializer_to_c_double( struct json_object* json_object, json_serializer_field_t* field, 
                                 void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    int offset = *((int*)(&field->arg)) / sizeof( double );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    if ( json_object_is_type( json_object, json_type_double ) == 0 ) {
        debug( 10, "The field %s is not an double.\n", field->name );
        if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_IGNORE ) return 0;
        return -1;
    }
    
    ((double*)c_data)[offset] = json_object_get_double( json_object );
    
    return 0;
}

int json_serializer_to_json_double( struct json_object* json_object, json_serializer_field_t* field, 
                                    void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    int offset = *((int*)(&field->arg)) / sizeof( double );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    if ( json_object_utils_add_double( json_object, field->name, ((double*)c_data)[offset] ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
    }

    return 0;
}

int json_serializer_to_c_boolean( struct json_object* json_object, json_serializer_field_t* field, 
                                  void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    int offset = *((int*)(&field->arg)) / sizeof( int );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    if ( json_object_is_type( json_object, json_type_boolean ) == 0 ) {
        debug( 10, "The field %s is not an double.\n", field->name );
        if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_IGNORE ) return 0;
        return -1;
    }
    
    ((int*)c_data)[offset] = json_object_get_boolean( json_object );
    
    return 0;
}

int json_serializer_to_json_boolean( struct json_object* json_object, json_serializer_field_t* field, 
                                     void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    int offset = *((int*)(&field->arg)) / sizeof( int );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    if ( json_object_utils_add_boolean( json_object, field->name, ((int*)c_data)[offset] ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
    }

    return 0;
}


int json_serializer_to_c_in_addr( struct json_object* json_object, json_serializer_field_t* field, 
                                  void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    int offset = *((int*)(&field->arg));
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    struct in_addr* address = (struct in_addr*)&((char*)c_data)[offset];
    bzero( address, sizeof( address ));

    if ( json_object_is_type( json_object, json_type_string ) == 0 ) {
        debug( 10, "The field %s is not a string.\n", field->name );
        if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_IGNORE ) return 0;
        return -1;
    }

    char *ip_string = NULL;
    if (( ip_string = json_object_get_string( json_object )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_get_string\n" );
    }

    debug( 10, "Converting the string %s for %s\n", ip_string, field->name );

    if ( inet_aton( ip_string, address ) == 0 ) {
        return errlog( ERR_WARNING, "Invalid IP Address string %s\n", ip_string );
    }
    
    return 0;
}

int json_serializer_to_json_in_addr( struct json_object* json_object, json_serializer_field_t* field, 
                                     void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    int offset = *((int*)(&field->arg));
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    struct in_addr* address = (struct in_addr*)&((char*)c_data)[offset];

    if ( json_object_utils_add_string( json_object, field->name,
                                       unet_next_inet_ntoa( address->s_addr )) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
    }

    return 0;
}

int json_serializer_to_c_timeval( struct json_object* json_object, json_serializer_field_t* field, 
                                void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    int offset = *((int*)(&field->arg));
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    struct timeval* tv = (struct timeval*)&((char*)c_data)[offset];
    bzero( tv, sizeof( struct timeval ));

    if ( json_object_utils_parse_timeval( json_object, tv ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_parse_timeval\n" );
    }
    
    return 0;
}

int json_serializer_to_json_timeval( struct json_object* json_object, json_serializer_field_t* field, 
                                     void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( c_data == NULL ) return errlogargs();
    int offset = *((int*)(&field->arg));
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );
    
    struct timeval* tv = (struct timeval*)&((char*)c_data)[offset];

    struct json_object* tv_json = NULL;
    if (( tv_json = json_object_utils_create_timeval( tv )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_utils_create_timeval\n" );
    }

    if ( json_object_utils_add_object( json_object, field->name, tv_json ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
    }

    return 0;    
}


int json_serializer_to_c_array( struct json_object* json_object, json_serializer_field_t* field, 
                                void* c_array )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    if ( c_array == NULL ) return errlogargs();

    json_serializer_array_t* arg = field->arg;

    if ( arg == NULL ) return errlog( ERR_CRITICAL, "field->arg must be set\n" );
    
    if ( _validate_array_serializer( arg ) < 0 ) {
        return errlog( ERR_CRITICAL, "_validate_array_serializer" );
    }

    if ( arg->is_pointers == 1 ) {
        return errlog( ERR_CRITICAL, "is_pointers is not implemented for converting to C\n" );
    }

    if ( json_object_is_type( json_object, json_type_array ) == 0 ) {
        debug( 10, "The field %s is not an array.\n", field->name );
        if ( field->if_empty == JSON_SERIALIZER_FIELD_EMPTY_IGNORE ) return 0;
        return -1;
    }
    
    int length = 0;
    if (( length = json_object_array_length( json_object )) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_array_length\n" );
    }

    if ( length > arg->max_length ) {
        errlog( ERR_WARNING, "Too many items %d, limiting to %d\n", length, arg->max_length );
        length = arg->max_length;
    }

    int c = 0;
    int array_size = 0;
    int* c_length = &((int*)c_array)[arg->length_offset/sizeof( int )];
    char* data = &((char*)c_array)[arg->data_offset];

    if (( array_size = arg->get_size( c_array )) <= 0 ) {
        return errlog( ERR_CRITICAL, "arg->get_array_size\n" );
    }

    *c_length = 0;
    
    bzero( data, array_size );

    struct json_object* item_json = NULL;
    for ( c = 0 ; c < length ; c++ ) {
        if (( item_json = json_object_array_get_idx( json_object, c )) == NULL ) {
            return errlog( ERR_CRITICAL, "json_object_array_get_idx\n" );
        }

        char *item = &((char*)data)[c * arg->item_size];
        
        if ( arg->default_value != NULL ) {
            memcpy( item, arg->default_value, arg->item_size );
        }

        if ( json_serializer_to_c( arg->serializer, item_json, item ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_serializer_to_c\n" );
        }
    }
    
    *c_length = length;
    
    return 0;
}

int json_serializer_to_json_array( struct json_object* json_object, json_serializer_field_t* field, 
                                   void* c_array )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    if ( c_array == NULL ) return errlogargs();

    json_serializer_array_t* arg = field->arg;

    if ( _validate_array_serializer( arg ) < 0 ) {
        return errlog( ERR_CRITICAL, "_validate_array_serializer" );
    }

    int* c_length = &((int*)c_array)[arg->length_offset/sizeof( int )];

    if (( *c_length < 0 ) || ( *c_length > arg->max_length )) {
        return errlogargs();
    }

    struct json_object* array_json = NULL;
    struct json_object* item_json = NULL;
    if (( array_json = json_object_new_array()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_array\n" );
    }

    char* data = &((char*)c_array)[arg->data_offset];
    char* item = NULL;

    debug( 10, "Found %d c items to add to the JSON array.\n", *c_length );
    
    int _critical_section() {
        int c = 0;
        for ( c = 0 ; c < *c_length ; c++ ) {
            item = &data[c * arg->item_size];
            if ( arg->is_pointers == 1 ) {
                item = ((char**)data)[c];
                if ( item == NULL ) continue;
            }

            if (( item_json = json_serializer_to_json( arg->serializer, item )) ==
                NULL ) {
                return errlog( ERR_CRITICAL, "json_serializer_to_json\n" );
            }

            if ( json_object_array_add( array_json, item_json ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_array_add\n" );
            }
            
            item_json = NULL;
        }

        json_object_object_add( json_object, field->name, array_json );
        
        return 0;
    }

    if ( _critical_section() < 0 ) {
        if ( array_json != NULL ) json_object_put( array_json );
        if ( item_json != NULL ) json_object_put( item_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
}

static int _validate_array_serializer( json_serializer_array_t* arg )
{
    if ( arg == NULL ) return errlog( ERR_CRITICAL, "NULL json serializer array arg\n" );
    
    if ( arg->data_offset < 0 ) {
        return errlog( ERR_CRITICAL, "Invalid data offset %d\n", arg->data_offset );
    }
    if ( arg->length_offset < 0 ) {
        return errlog( ERR_CRITICAL, "Invalid length offset %d\n", arg->length_offset );
    }
    if ( arg->get_size == NULL) {
        return errlog( ERR_CRITICAL, "Invalid get_size function\n", arg->get_size );
    }
    if ( arg->serializer == NULL ) {
        return errlog( ERR_CRITICAL, "Invalid serializer\n" );
    }

    if ( arg->max_length <= 0 ) {
        return errlog( ERR_CRITICAL, "Invaid args->max_length: %d\n", arg->max_length );
    }

    if ( arg->item_size <= 0 ) {
        return errlog( ERR_CRITICAL, "Invalid arg->item_size: %d\n", arg->item_size );
    }
    
    return 0;
}

/* Just copy the JSON data in as is */
int json_serializer_to_c_json( struct json_object* json_object, json_serializer_field_t* field, 
                               void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    if ( c_data == NULL ) return errlogargs();

    int offset = *((int*)(&field->arg)) / sizeof( struct json_object* );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );

    if ((((struct json_object**)c_data)[offset] = json_object_get( json_object )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_obect_get\n" );
    }

    return 0;
}


/* Just copy the JSON data in as is */
int json_serializer_to_json_json( struct json_object* json_object, json_serializer_field_t* field, 
                                  void* c_data )
{
    if ( json_object == NULL ) return errlogargs();
    if ( field == NULL ) return errlogargs();
    if ( field->fetch_arg == 0 ) return errlog( ERR_CRITICAL, "field->fetch_arg must be set\n" );
    if ( c_data == NULL ) return errlogargs();

    int offset = *((int*)(&field->arg)) / sizeof( struct json_object* );
    if ( offset < 0 ) return errlog( ERR_CRITICAL, "Invalid offset %d\n", offset );
    
    struct json_object* json = ((struct json_object**)c_data)[offset];
    if (( json = json_object_get( json )) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_get\n" );
    }
    
    if ( json_object_utils_add_object( json_object, field->name, json ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
    }

    return 0;
}

static int _is_terminator( json_serializer_field_t* field )
{
    if ( field == NULL ) return 1;
    return (( field->to_c == NULL ) && ( field->to_json == NULL ));
}

static int _validate_field( json_serializer_field_t* field )
{
    if ( field == NULL ) return errlogargs();

    if ( strnlen( field->name, sizeof( field->name )) >= sizeof( field->name )) {
        return errlog( ERR_CRITICAL, "Field has an invalid name\n" );
    }

    switch ( field->if_empty ) {
    case JSON_SERIALIZER_FIELD_EMPTY_CALL:
    case JSON_SERIALIZER_FIELD_EMPTY_IGNORE:
    case JSON_SERIALIZER_FIELD_EMPTY_ERROR:
        break;
    default: 
        return errlog( ERR_CRITICAL, "Field has invalid if_empty flag %d\n", field->if_empty );
    }

    if (( field->to_c == NULL ) && ( field->to_json == NULL )) {
        return errlog( ERR_CRITICAL, "Either to_c or to_json must be set.\n" );
    }

    return 0;
}
