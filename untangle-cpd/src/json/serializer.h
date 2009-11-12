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

#ifndef __JSON_SERIALIZER_H
#define __JSON_SERIALIZER_H

#include <json/json.h>

#define JSON_SERIALIZER_NAME_LENGTH 32

#define JSON_SERIALIZER_FIELD_TERM \
              { .name = "", .arg = NULL, .to_c = NULL, .to_json = NULL }

typedef struct json_serializer_field
{
    char name[JSON_SERIALIZER_NAME_LENGTH];
    void* arg;
    /* If this is non-zero, this will fetch the json_object[name]
     * before calling to_c and pass that in instead of json_object.
     */
    char fetch_arg;
    
    enum {
        /* Call to_c even if the field is missing.  The value of
         * json_object depends on fetch_arg.  If fetch_arg is
         * non-zero, it will be NULL, otherwise it will be
         * json_object */
        JSON_SERIALIZER_FIELD_EMPTY_CALL,
        JSON_SERIALIZER_FIELD_EMPTY_IGNORE,  /* Skip the field if it is empty */
        JSON_SERIALIZER_FIELD_EMPTY_ERROR,   /* It is an error if this field is missing. */
    } if_empty;

    int (*to_c)( struct json_object* json_object, struct json_serializer_field* field, void* c_data );
    int (*to_json)( struct json_object* json_object, struct json_serializer_field* field, void* c_data );
} json_serializer_field_t;

typedef struct
{
    int len;
    int offset;
} json_serializer_string_t;

typedef struct
{
    char name[JSON_SERIALIZER_NAME_LENGTH];    
    /* A variable sized array of serializer, the last one must be JSON_SERIALIZER_FIELD_TERM */
    json_serializer_field_t fields[];
} json_serializer_t;

typedef struct
{
    int max_length;
    int data_offset;
    int length_offset;
    /* Set to 1 if this is an array of pointers.  If so, this will
     * not serialize any value that has NULL, and it will serialize
     * any value that is non-null.  Furthermore, this will
     * automatically allocate item_size for each entry when going from
     * JSON to C.  As of 2009.03.07, to_c hsa not been implemented.
     */
    int is_pointers;
    int (*get_size)( void *c_array );
    void *default_value;
    json_serializer_t* serializer;
    int item_size;
} json_serializer_array_t;

/* Create a new JSON object and fill in the fields from c_struct */
struct json_object* json_serializer_to_json( json_serializer_t* serializer, void* c_data );

/* Using the fields in serializer, fill in the value from json_object into c_struct */
int json_serializer_to_c( json_serializer_t* serializer, struct json_object* json_object, void* c_data );

int json_serializer_to_c_string( struct json_object* json_object, json_serializer_field_t* field, 
                                 void* c_data );

int json_serializer_to_json_string( struct json_object* json_object, json_serializer_field_t* field, 
                                    void* c_data );

int json_serializer_to_c_int( struct json_object* json_object, json_serializer_field_t* field, 
                              void* c_data );

int json_serializer_to_json_int( struct json_object* json_object, json_serializer_field_t* field, 
                                 void* c_data );

int json_serializer_to_c_double( struct json_object* json_object, json_serializer_field_t* field, 
                                 void* c_data );

int json_serializer_to_json_double( struct json_object* json_object, json_serializer_field_t* field, 
                                    void* c_data );

int json_serializer_to_c_boolean( struct json_object* json_object, json_serializer_field_t* field, 
                                  void* c_data );

int json_serializer_to_json_boolean( struct json_object* json_object, json_serializer_field_t* field, 
                                     void* c_data );

int json_serializer_to_c_in_addr( struct json_object* json_object, json_serializer_field_t* field, 
                                  void* c_data );

int json_serializer_to_json_in_addr( struct json_object* json_object, json_serializer_field_t* field, 
                                     void* c_data );

int json_serializer_to_c_array( struct json_object* json_object, json_serializer_field_t* field, 
                                void* c_data );

int json_serializer_to_json_array( struct json_object* json_object, json_serializer_field_t* field, 
                                   void* c_data );

int json_serializer_to_c_array( struct json_object* json_object, json_serializer_field_t* field, 
                                void* c_data );

int json_serializer_to_c_timeval( struct json_object* json_object, json_serializer_field_t* field, 
                                void* c_data );

int json_serializer_to_json_timeval( struct json_object* json_object, json_serializer_field_t* field, 
                                     void* c_data );

/* Just copy the JSON data in as is */
int json_serializer_to_c_json( struct json_object* json_object, json_serializer_field_t* field, 
                                void* c_data );

/* Just copy the JSON data in as is */
int json_serializer_to_json_json( struct json_object* json_object, json_serializer_field_t* field, 
                                  void* c_data );

#endif
