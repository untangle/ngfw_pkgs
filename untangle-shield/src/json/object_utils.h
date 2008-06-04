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

#ifndef __JSON_OBJECT_UTILS_H
#define __JSON_OBJECT_UTILS_H

#include <json/json.h>

#define TIMEVAL_TYPE "timeval"

/**
 * Utility function with some error handling built in.  This is useful for things like
 * json_object_add( foo, "foo_key", json_object_new_string( "random foo" ));
 * in this case it is hard to test for NULL from json_object_new_string.
 */
int json_object_utils_add( struct json_object* object, char* key, struct json_object* value );

/**
 * Utility function for building a JSON string.
 * Build a string with variable args using the printf syntax.
 */
struct json_object* json_object_utils_build_string( size_t buffer_size, char* fmt, ... );

/**
 * Useful utility, this will automatically delete if there is a
 * failure somewhere down the path */
int json_object_utils_add_object( struct json_object* object, char* key, struct json_object* value );

/**
 * Create a new string and automatically free the resources if it
 * cannot be added successfully.
 */
int json_object_utils_add_string( struct json_object* object, char* key, char* string );


/**
 * Create a new int and automatically free the resources if it
 * cannot be added successfully.
 */
int json_object_utils_add_int( struct json_object* object, char* key, int value );

/**
 * Create a new double and automatically free the resources if it
 * cannot be added successfully.
 */
int json_object_utils_add_double( struct json_object* object, char* key, double value );


/**
 * Useful utility, this will automatically delete if there is a
 * failure somewhere down the path */
int json_object_utils_array_add_object( struct json_object* object, struct json_object* value );

/**
 * Create a new string and automatically free the resources if it
 * cannot be added successfully.
 */
int json_object_utils_array_add_string( struct json_object* object, char* string );

/**
 * Retrieve a string from a JSON object
 */
char* json_object_utils_get_string( struct json_object* object, char* key );


/**
 * Create a new int and automatically free the resources if it
 * cannot be added successfully.
 */
int json_object_utils_array_add_int( struct json_object* object, int value );

int json_object_utils_array_add_double( struct json_object* object, double value );

/**
 * Create a JSON object to represent a timeval
 */
struct json_object* json_object_utils_create_timeval( struct timeval* timeval );

/**
 * Try to parse a time value.
 */
int json_object_utils_parse_timeval( struct json_object* object, struct timeval* timeval );


#endif
