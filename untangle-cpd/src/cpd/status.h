/*
 * Copyright (c) 2003-2009 Untangle, Inc.
 * All rights reserved.
 *
 * This software is the confidential and proprietary information of
 * Untangle, Inc. ("Confidential Information"). You shall
 * not disclose such Confidential Information.
 *
 * $Id$
 */

#ifndef __CPD_STATUS_H_
#define __CPD_STATUS_H_

#include "cpd.h"

cpd_status_t* cpd_status_malloc( void );
int cpd_status_init( cpd_status_t* status );
cpd_status_t* cpd_status_create( void );

int cpd_status_free( cpd_status_t* status );
int cpd_status_destroy( cpd_status_t* status );
int cpd_status_raze( cpd_status_t* status );

int cpd_status_load_json( cpd_status_t* status, struct json_object* json_status );

struct json_object* cpd_status_to_json( cpd_status_t* status );

#endif // __CPD_STATUS_H_
