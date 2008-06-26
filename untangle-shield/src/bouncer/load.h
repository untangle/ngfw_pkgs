/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_load.h $
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


#ifndef __NETCAP_LOAD_H_
#define __NETCAP_LOAD_H_

#include <sys/time.h>
#include <time.h>

typedef double barfight_load_val_t;

typedef struct barfight_load {
    struct timeval    last_update;
    barfight_load_val_t load;
    barfight_load_val_t interval;
    int               total;
} barfight_load_t;

#define NC_LOAD_INIT_TIME 1

/**
 * load: load to update
 * count: Amount to update the total by
 * val: amount to update the load by
 */ 
int               barfight_load_update  ( barfight_load_t* load, int count, barfight_load_val_t val );

barfight_load_val_t barfight_load_get     ( barfight_load_t* load );

barfight_load_t*    barfight_load_malloc  ( void );
int               barfight_load_init    ( barfight_load_t* load, barfight_load_val_t interval, int if_init_time );
barfight_load_t*    barfight_load_create  ( barfight_load_val_t interval, int if_init_time );

void              barfight_load_free    ( barfight_load_t* load );
void              barfight_load_destroy ( barfight_load_t* load );
void              barfight_load_raze    ( barfight_load_t* load );

#endif // __NETCAP_LOAD_H_
