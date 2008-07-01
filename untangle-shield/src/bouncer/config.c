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

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/list.h>
#include <mvutil/unet.h>
#include <mvutil/utime.h>

#include <json/json.h>

#include "bouncer/config.h"
#include "json/object_utils.h"


/* XXX What are reasonable defaults */
/* Default limits: lax, tight, closed */
/* XXX CPU Loads are really high (ignored) until we have a way getting a load average with 
 * a shorter interval */
#define _CPU_LOAD_LIMITS        40.0, 60.0, 80.0, 1000.0
#define _ACTIVE_SESSION_LIMITS  512, 1024, 1536, 100
#define _REQUEST_LOAD_LIMITS    60, 75, 85, 200.0
#define _SESSION_LOAD_LIMITS    50, 60, 75, 200.0
#define _TCP_CHK_LOAD_LIMITS    5000, 10000, 14000, 5000.0
#define _UDP_CHK_LOAD_LIMITS    3000, 6000, 10000, 5000.0
#define _ICMP_CHK_LOAD_LIMITS   3000, 6000, 10000, 1000.0
#define _EVIL_LOAD_LIMITS       800, 1600, 2000, 1200.0

/* Use a scale from 0 to 100 */
#define _SHIELD_REP_MAX 100

#define _REQUEST_LOAD_MULT     (((_SHIELD_REP_MAX+0.0)/30)  * (.3))
#define _SESSION_LOAD_MULT     (((_SHIELD_REP_MAX+0.0)/30)  * (.2))
#define _TCP_CHK_LOAD_MULT     (((_SHIELD_REP_MAX+0.0)/100) * (.4))
#define _UDP_CHK_LOAD_MULT     (((_SHIELD_REP_MAX+0.0)/100) * (.4))
#define _EVIL_LOAD_MULT        (((_SHIELD_REP_MAX+0.0)/75)  * (.1))
#define _ACT_SESSION_MULT      (((_SHIELD_REP_MAX+0.0)/100) * (.1))

/* This is not actually a multiplier, it is just a rate limit in seconds per IP */
#define _ICMP_CHK_LOAD_MULT    40.0

/* For debugging, if the shield exceeds this threshold a lot of
 * information is printed about the reputation being analyzed */
#define _REPUTATION_DEBUG_THRESHOLD 160.0

/* This is the defaults for controlling the log rotation and size,
 * using these defaults for ten second resolution and about 2 minutes
 * of back buffer. */
#define _DEFAULT_LOG_ROTATE_DELAY  SEC_TO_MSEC( 10 )
#define _DEFAULT_LOG_SIZE          12

/* This is the minimum number of users per node */
#define _DEFAULT_MIN_USERS 3

static void _load_limits( struct json_object* config_json, bouncer_shield_config_t* config );
static void _load_limit( struct json_object* limit_json, nc_shield_limit_t* limit );

static void _load_fences( struct json_object* fences, bouncer_shield_config_t* config );
static void _load_fence( struct json_object* fence_json, nc_shield_fence_t* fence );
static void _load_post( struct json_object* post_json, nc_shield_post_t* post );

static void _load_multipliers( struct json_object* multipliers_json, bouncer_shield_config_t* config );
static void _load_lru( struct json_object* lru_json, bouncer_shield_config_t* config );
static void _load_misc( struct json_object* debug_json, bouncer_shield_config_t* config );

static int _load_user( struct json_object* user_json, barfight_shield_bless_t* user );

static void _update_int( struct json_object* limit_json, char* field, int* value, int allow_zero );
static void _update_double( struct json_object* limit_json, char* field, double* value, int allow_zero );

/* Functions for converting from a C -> JSON */
static int _add_limits( struct json_object* config_json, bouncer_shield_config_t* config );
static int _add_limit( struct json_object* config_json, char* name, nc_shield_limit_t* limit );

static int _add_fences( struct json_object* config_json, bouncer_shield_config_t* config );
static int _add_fence( struct json_object* fences_json, char* name, nc_shield_fence_t* fence );
static int _add_post( struct json_object* fence_json, char* name, nc_shield_post_t* post );

static int _add_multipliers( struct json_object* config_json, bouncer_shield_config_t* config );
static int _add_lru( struct json_object* config_json, bouncer_shield_config_t* config );
static int _add_misc( struct json_object* config_json, bouncer_shield_config_t* config );

static int _add_users( struct json_object* config_json, barfight_shield_bless_array_t* bless_array );
static int _add_user( struct json_object* users_json, barfight_shield_bless_t* user );

static int _verify_config( bouncer_shield_config_t* config );
static int _verify_fence( nc_shield_fence_t* fence );

/* Load the default shield configuration */
int bouncer_shield_config_default( bouncer_shield_config_t* config )
{
    /* Shield default configuration */
    static const bouncer_shield_config_t default_config = {
        .limit = {
            .cpu_load      = { _CPU_LOAD_LIMITS }, 
            .sessions      = { _ACTIVE_SESSION_LIMITS }, 
            .request_load  = { _REQUEST_LOAD_LIMITS }, 
            .session_load  = { _SESSION_LOAD_LIMITS }, 
            .tcp_chk_load  = { _TCP_CHK_LOAD_LIMITS }, 
            .udp_chk_load  = { _UDP_CHK_LOAD_LIMITS }, 
            .icmp_chk_load = { _ICMP_CHK_LOAD_LIMITS }, 
            .evil_load     = { _EVIL_LOAD_LIMITS }
        },
        .mult = {
            .request_load  = _REQUEST_LOAD_MULT,
            .session_load  = _SESSION_LOAD_MULT,
            .tcp_chk_load  = _TCP_CHK_LOAD_MULT,
            .udp_chk_load  = _UDP_CHK_LOAD_MULT,
            .icmp_chk_load = _ICMP_CHK_LOAD_MULT,
            .evil_load     = _EVIL_LOAD_MULT,
            .active_sess   = _ACT_SESSION_MULT
        },
        .lru = {
            .low_water    = 512,
            .high_water   = 1024,
            .sieve_size   = 8,
            .ip_rate      = .016, /* 1/60  */
        },
        .fence = {
            .relaxed = {
                .inheritance = .1,
                .limited = { .prob = 70.0, .post = _SHIELD_REP_MAX * 0.65 },
                .closed  = { .prob = 85.0, .post = _SHIELD_REP_MAX * 0.90 },
                .error   = { .prob = 95.0, .post = _SHIELD_REP_MAX * 1.00 }
            },
            .lax = {
                .inheritance = .4,
                .limited = { .prob = 75.0, .post = _SHIELD_REP_MAX * 0.50 },
                .closed  = { .prob = 80.0, .post = _SHIELD_REP_MAX * 0.80 },
                .error   = { .prob = 95.0, .post = _SHIELD_REP_MAX * 1.00 }
            },
            .tight = {
                .inheritance = .6,
                .limited = { .prob = 70.0, .post = _SHIELD_REP_MAX * 0.15 },
                .closed  = { .prob = 90.0, .post = _SHIELD_REP_MAX * 0.60 },
                .error   = { .prob = 95.0, .post = _SHIELD_REP_MAX * 0.70 }
            }, 
            .closed = {
                .inheritance = .9,
                .limited = { .prob = 90.0, .post = _SHIELD_REP_MAX * 0.05 },
                .closed  = { .prob = 95.0, .post = _SHIELD_REP_MAX * 0.20 },
                .error   = { .prob = 95.0, .post = _SHIELD_REP_MAX * 0.40 }
            }
        },
        .rep_threshold = _REPUTATION_DEBUG_THRESHOLD,

        .bless_array = { 
            .count = 0
        },

        .min_users = _DEFAULT_MIN_USERS,
        
        .log_rotate_delay_ms = _DEFAULT_LOG_ROTATE_DELAY,
        .log_size = _DEFAULT_LOG_SIZE,
    };
    
    if ( config == NULL ) return errlogargs();

    memcpy ( config, &default_config, sizeof ( bouncer_shield_config_t ));

    config->bless_array.d = config->bless_data;

    return 0;
}

/* This parser buffer as a JSON object and loads it */
int bouncer_shield_config_load( bouncer_shield_config_t* config, char* buffer, int buffer_len )
{
    if ( config == NULL ) return errlogargs();
    if ( buffer == NULL ) return errlogargs();
    if ( buffer_len <= 0 ) return errlogargs();

    struct json_tokener* tokener = NULL;
    struct json_object* config_json = NULL;
    
    int _critical_section() {
        /* Parse the remaining data. */
        if (( config_json = json_tokener_parse_ex( tokener, buffer, buffer_len )) == NULL ) {
            return errlog( ERR_CRITICAL, "json_tokener_parse_ex\n" );
        }

        if ( bouncer_shield_config_load_json( config, config_json ) < 0 ) {
            return errlog( ERR_CRITICAL, "bouncer_shield_config_load_json\n" );
        }
        
        if ( _verify_config( config ) < 0 ) {
            return errlog( ERR_CRITICAL, "_verify_config\n" );
        }

        return 0;
    }
    
    if (( tokener = json_tokener_new()) == NULL ) return errlog( ERR_CRITICAL, "json_tokener_new\n" );
    int ret = _critical_section();
    json_tokener_free( tokener );
    if ( config_json != NULL ) json_object_put( config_json );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return 0;
}

int bouncer_shield_config_load_json( bouncer_shield_config_t* config, struct json_object* config_json )
{
    if ( config == NULL ) return errlogargs();
    if ( config_json == NULL ) return errlogargs();

    struct json_object* bless_array_json = NULL;

    /* Load the defaults so the configuration only has to override the
     * desired values. */
    if ( bouncer_shield_config_default( config ) < 0 ) {
        return errlog( ERR_CRITICAL, "bouncer_shield_config_default\n" );
    }

    /* First load all of the limits */
    _load_limits( config_json, config );
    
    _load_fences( json_object_object_get( config_json, "fence" ), config );
    
    _load_multipliers( json_object_object_get( config_json, "multipliers" ), config );

    _load_lru( json_object_object_get( config_json, "lru" ), config );

    _load_misc( json_object_object_get( config_json, "misc" ), config );
    
    if (( bless_array_json = json_object_object_get( config_json, "users" )) != NULL ) {
        if ( bouncer_shield_config_load_bless_json( &config->bless_array, bless_array_json ) < 0 ) {
            return errlog( ERR_CRITICAL, "bouncer_shield_config_load_bless_json\n" );
        }
    }
    

    return 0;
}

/* Convert the current configuration to a JSON object */
struct json_object* bouncer_shield_config_to_json( bouncer_shield_config_t* config )
{
    struct json_object* config_json = NULL;
    
    int _critical_section() {
        if ( _add_limits( config_json, config ) < 0 ) return errlog( ERR_CRITICAL, "_add_limits\n" );

        if ( _add_fences( config_json, config ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_fences\n" );
        }
        if ( _add_multipliers( config_json, config ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_multipliers\n" );
        }
        if ( _add_lru( config_json, config ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_lru\n" );
        }
        if ( _add_misc( config_json, config ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_misc\n" );
        }
        if ( _add_users( config_json, &config->bless_array ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_users\n" );
        }

        return 0;
    }

    if (( config_json = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        json_object_put( config_json );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    return config_json;
}

/* Convert an array of JSON user and fill in a bless array */
int bouncer_shield_config_load_bless_json( barfight_shield_bless_array_t* bless_array,
                                           struct json_object* bless_array_json )
{
    if ( bless_array == NULL ) return errlogargs();
    if ( bless_array_json == NULL ) return errlogargs();

    int c = 0;
    struct array_list* user_array_list = NULL;
    struct json_object* user_json = NULL;

    if (( user_array_list = json_object_get_array( bless_array_json )) == NULL ) {
        debug( 10, "The field 'users' is not an array.\n" );
        return -1;
    }
    
    if (( bless_array->count = array_list_length( user_array_list )) < 0 ) {
        debug( 10, "The field 'users' is not an array.\n" );
        return -1;
    }
    
    if ( bless_array->count > BLESS_COUNT_MAX ) {
        errlog( ERR_WARNING, "Requested to bless %d users, only blessing first %d.\n", 
                bless_array->count, BLESS_COUNT_MAX );
        bless_array->count = BLESS_COUNT_MAX;
    }
        
    for ( c = 0; c < bless_array->count ; c++ ) {
        if (( user_json = array_list_get_idx( user_array_list, c )) == NULL ) {
            return errlog( ERR_WARNING, "array_list_get_idx\n" );
        }

        bzero( &bless_array->d[c], sizeof( barfight_shield_bless_t ));
        
        if ( _load_user( user_json, &bless_array->d[c] ) < 0 ) return -1;
    }

    return 0;
}


static void _load_limits( struct json_object* config_json, bouncer_shield_config_t* config )
{
    _load_limit( json_object_object_get( config_json, "cpu-limit" ), &config->limit.cpu_load );
    _load_limit( json_object_object_get( config_json, "sess-limit" ), &config->limit.sessions );
    _load_limit( json_object_object_get( config_json, "request-load" ), &config->limit.request_load );
    _load_limit( json_object_object_get( config_json, "session-load" ), &config->limit.session_load );
    _load_limit( json_object_object_get( config_json, "tcp-chk-load" ), &config->limit.tcp_chk_load );
    _load_limit( json_object_object_get( config_json, "udp-chk-load" ), &config->limit.udp_chk_load );
    _load_limit( json_object_object_get( config_json, "icmp-chk-load" ), &config->limit.icmp_chk_load );
    _load_limit( json_object_object_get( config_json, "evil-load" ), &config->limit.evil_load );
}

static void _load_limit( struct json_object* limit_json, nc_shield_limit_t* limit )
{
    /* Design to not require every possible parameter, just fall back to the defaults */
    if ( limit_json == NULL ) return;

    _update_double( limit_json, "lax", &limit->lax, 0 );
    _update_double( limit_json, "tight", &limit->tight, 0 );
    _update_double( limit_json, "closed", &limit->closed, 0 );
    _update_double( limit_json, "max", &limit->max, 0 );

    return;
}

static void _load_fences( struct json_object* fences, bouncer_shield_config_t* config )
{
    if ( fences == NULL ) return;

    _load_fence( json_object_object_get( fences, "relaxed" ), &config->fence.relaxed );
    _load_fence( json_object_object_get( fences, "lax" ), &config->fence.lax );
    _load_fence( json_object_object_get( fences, "tight" ), &config->fence.tight );
    _load_fence( json_object_object_get( fences, "closed" ), &config->fence.closed );
}

static void _load_fence( struct json_object* fence_json, nc_shield_fence_t* fence )
{
    if ( fence_json == NULL ) return;

    _update_double( fence_json, "prob", &fence->inheritance, 0 );
    _load_post( json_object_object_get( fence_json, "limited" ), &fence->limited );
    _load_post( json_object_object_get( fence_json, "closed" ), &fence->closed );
    _load_post( json_object_object_get( fence_json, "error" ), &fence->error );
}

static void _load_post( struct json_object* post_json, nc_shield_post_t* post )
{
    if ( post_json == NULL ) return;
    
    _update_double( post_json, "prob", &post->prob, 0 );
    _update_double( post_json, "post", &post->post, 0 );
}

static void _load_multipliers( struct json_object* multipliers_json, bouncer_shield_config_t* config )
{
    if ( multipliers_json == NULL ) return;

    _update_double( multipliers_json, "request-load", &config->mult.request_load, 0 );
    _update_double( multipliers_json, "session-load", &config->mult.session_load, 0 );
    _update_double( multipliers_json, "evil-load", &config->mult.evil_load, 0 );
    _update_double( multipliers_json, "tcp-chk-load", &config->mult.tcp_chk_load, 0 );
    _update_double( multipliers_json, "udp-chk-load", &config->mult.udp_chk_load, 0 );
    _update_double( multipliers_json, "icmp-chk-load", &config->mult.icmp_chk_load, 0 );
    _update_double( multipliers_json, "active-sessions", &config->mult.active_sess, 0 );
}

static void _load_lru( struct json_object* lru_json, bouncer_shield_config_t* config )
{
    if ( lru_json == NULL ) return;

    _update_int( lru_json, "low-water", &config->lru.low_water, 0 );
    _update_int( lru_json, "high-water", &config->lru.high_water, 0 );
    _update_int( lru_json, "sieve-size", &config->lru.sieve_size, 0 );
    _update_double( lru_json, "ip-rate", &config->lru.ip_rate, 0 );
}

static void _load_misc( struct json_object* misc_json, bouncer_shield_config_t* config )
{
    if ( misc_json == NULL ) return;

    _update_int( misc_json, "debug-rate", &config->print_delay, 0 );
    _update_double( misc_json, "debug-threshold", &config->rep_threshold, 0 );
    _update_int( misc_json, "log-rotate-delay", &config->log_rotate_delay_ms, 0 );
    _update_int( misc_json, "log-size", &config->log_size, 0 );
    _update_int( misc_json, "min-users", &config->min_users, 0 );
}

static int _load_user( struct json_object* user_json, barfight_shield_bless_t* user )
{
    if ( user_json == NULL ) return errlogargs();
    if ( user == NULL ) return errlogargs();
    char *ip;
    char *netmask;

    _update_double( user_json, "divider", &user->divider, 0 );

    if (( ip = json_object_utils_get_string( user_json, "ip" )) == NULL ) {
        /* Debug because this is not controllable. */
        debug( 10, "The user is missing an IP\n" );
        return -1;
    }

    if (( netmask = json_object_utils_get_string( user_json, "netmask" )) == NULL ) {
        debug( 10, "The user is missing a netmask\n" );
        return -1;
    }

    if (( inet_aton( ip, &user->address )) < 0 ) {
        debug( 10, "The user has an invalid IP\n" );
        return -1;        
    }

    if (( inet_aton( netmask, &user->netmask )) < 0 ) {
        debug( 10, "The user has an invalid netmask\n" );
        return -1;        
    }

    return 0;
}

static void _update_int( struct json_object* limit_json, char* field, int* value, int allow_zero )
{
    struct json_object* temp = NULL;
    if (( temp = json_object_object_get( limit_json, field )) == NULL ) return;

    int v = json_object_get_int( temp );
    if (( allow_zero == 0 ) && ( v == 0.0 )) return;
    
    *value = v;
    
    return;
}

static void _update_double( struct json_object* limit_json, char* field, double* value, int allow_zero )
{
    struct json_object* temp = NULL;
    if (( temp = json_object_object_get( limit_json, field )) == NULL ) return;

    double v = json_object_get_double( temp );
    if (( allow_zero == 0 ) && ( v == 0.0 )) return;
    
    *value = v;
    
    return;
}

/* C -> json configuration */
static int _add_limits( struct json_object* config_json, bouncer_shield_config_t* config )
{
    if ( _add_limit( config_json, "cpu-limit", &config->limit.cpu_load ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }
    if ( _add_limit( config_json, "sess-limit", &config->limit.sessions ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }
    if ( _add_limit( config_json, "request-load", &config->limit.request_load ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }
    if ( _add_limit( config_json, "session-load", &config->limit.session_load ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }
    if ( _add_limit( config_json, "tcp-chk-load", &config->limit.tcp_chk_load ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }
    if ( _add_limit( config_json, "udp-chk-load", &config->limit.udp_chk_load ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }
    if ( _add_limit( config_json, "icmp-chk-load", &config->limit.icmp_chk_load ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }
    if ( _add_limit( config_json, "evil-load", &config->limit.evil_load ) < 0 ) {
        return errlog( ERR_CRITICAL, "_add_limit\n" );
    }

    return 0;
}

static int _add_limit( struct json_object* config_json, char* name, nc_shield_limit_t* limit )
{
    struct json_object* limit_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_double( limit_json, "lax", limit->lax ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( limit_json, "tight", limit->tight ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( limit_json, "closed", limit->closed ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( limit_json, "max", limit->max ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_object( config_json, name, limit_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            limit_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( limit_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }
    
    if ( _critical_section() < 0 ) {
        if ( limit_json != NULL ) json_object_put( limit_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
    
}

static int _add_fences( struct json_object* config_json, bouncer_shield_config_t* config )
{
    struct json_object* fences_json = NULL;

    int _critical_section() {
        if ( _add_fence( fences_json, "relaxed", &config->fence.relaxed ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_fence\n" );
        }
        
        if ( _add_fence( fences_json, "lax", &config->fence.lax ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_fence\n" );
        }

        if ( _add_fence( fences_json, "tight", &config->fence.tight ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_fence\n" );
        }

        if ( _add_fence( fences_json, "closed", &config->fence.closed ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_fence\n" );
        }

        if ( json_object_utils_add_object( config_json, "fence", fences_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            fences_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }        
        
        return 0;
    }
    
    if (( fences_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( fences_json != NULL ) json_object_put( fences_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
}


static int _add_fence( struct json_object* fences_json, char* name, nc_shield_fence_t* fence )
{
    struct json_object* fence_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_double( fence_json, "inheritance", fence->inheritance ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( _add_post( fence_json, "limited", &fence->limited ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_post\n" );
        }
        if ( _add_post( fence_json, "closed", &fence->closed ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_post\n" );
        }
        if ( _add_post( fence_json, "error", &fence->error ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_post\n" );
        }

        if ( json_object_utils_add_object( fences_json, name, fence_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            fence_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( fence_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( fence_json != NULL ) json_object_put( fence_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;    
}

static int _add_post( struct json_object* fence_json, char* name, nc_shield_post_t* post )
{
    struct json_object* post_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_double( post_json, "prob", post->prob ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_double( post_json, "post", post->post ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_object( fence_json, name, post_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            fence_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( post_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( post_json != NULL ) json_object_put( post_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;        
}

static int _add_multipliers( struct json_object* config_json, bouncer_shield_config_t* config )
{
    struct json_object* mult_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_double( mult_json, "request-load", config->mult.request_load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_double( mult_json, "session-load", config->mult.session_load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( mult_json, "evil-load", config->mult.evil_load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( mult_json, "tcp-chk-load", config->mult.tcp_chk_load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( mult_json, "udp-chk-load", config->mult.udp_chk_load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( mult_json, "icmp_chk-load", config->mult.icmp_chk_load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( mult_json, "active-session", config->mult.active_sess ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_object( config_json, "multipliers", mult_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            mult_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( mult_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( mult_json != NULL ) json_object_put( mult_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0; 
}

static int _add_lru( struct json_object* config_json, bouncer_shield_config_t* config )
{
    struct json_object* lru_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_int( lru_json, "low-water", config->lru.low_water ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_int( lru_json, "high-water", config->lru.high_water ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_int( lru_json, "sieve-size", config->lru.sieve_size ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( lru_json, "ip-rate", config->lru.ip_rate ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_object( config_json, "lru", lru_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            lru_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( lru_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( lru_json != NULL ) json_object_put( lru_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
}

static int _add_misc( struct json_object* config_json, bouncer_shield_config_t* config )
{
    struct json_object* misc_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_int( misc_json, "debug-rate", config->print_delay ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( misc_json, "debug-threshold", config->rep_threshold ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_int( misc_json, "log-rotate-delay", config->log_rotate_delay_ms ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }
        if ( json_object_utils_add_int( misc_json, "log-size", config->log_size ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }
        if ( json_object_utils_add_int( misc_json, "min-users", config->min_users ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }

        if ( json_object_utils_add_object( config_json, "misc", misc_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            misc_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( misc_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( misc_json != NULL ) json_object_put( misc_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;    
}

static int _add_users( struct json_object* config_json, barfight_shield_bless_array_t* bless_array )
{
    struct json_object* users_json = NULL;

    int _critical_section() {
        int c = 0;
        int count = bless_array->count;

        if ( count > BLESS_COUNT_MAX ) count = BLESS_COUNT_MAX;

        for ( c = 0 ; c < count  ; c++ ) {
            if ( _add_user( users_json, &bless_array->d[c] ) < 0 ) {
                return errlog( ERR_CRITICAL, "_add_user\n" );
            }
        }

        if ( json_object_utils_add_object( config_json, "users", users_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            users_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( users_json = json_object_new_array()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_array\n" );
    }

    if ( bless_array->count < 0 ) return errlogargs();

    if ( _critical_section() < 0 ) {
        if ( users_json != NULL ) json_object_put( users_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
}

static int _add_user( struct json_object* users_json, barfight_shield_bless_t* user )
{
    struct json_object* user_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_double( user_json, "divider", user->divider ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_string( user_json, "ip",
                                           unet_inet_ntoa( user->address.s_addr )) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_string\n" );
        }

        if ( json_object_utils_add_string( user_json, "netmask", 
                                           unet_inet_ntoa( user->netmask.s_addr )) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_string\n" );
        }

        if ( json_object_array_add( users_json, user_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            return errlog( ERR_CRITICAL, "json_object_array_add\n" );
        }
        
        return 0;
    }
    
    if (( user_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( user_json != NULL ) json_object_put( user_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
}


static int _verify_config            ( bouncer_shield_config_t* config )
{
    if ( config->lru.low_water > config->lru.high_water ) {
        return errlog ( ERR_INFORM, "low water (%d) < high water (%d)\n", 
                        config->lru.low_water, config->lru.high_water );
    }

    if ( config->lru.high_water <= 0 ) {
        return errlog ( ERR_INFORM, "high water < 0 (%d)\n", config->lru.high_water );
    }

    /* Arbitrary value */
    if ( config->log_rotate_delay_ms <= 10 ) {
        return errlog ( ERR_INFORM, "log rotation delay too short(%d)\n", config->log_rotate_delay_ms );
    }

    if ( config->log_size <= 0 ) {
        return errlog ( ERR_INFORM, "log rotation size <= 0(%d)\n", config->log_size );
    }
    
    if (( _verify_fence ( &config->fence.relaxed ) < 0 ) ||
        ( _verify_fence ( &config->fence.lax     ) < 0 ) ||
        ( _verify_fence ( &config->fence.tight   ) < 0 ) ||
        ( _verify_fence ( &config->fence.closed  ) < 0 )) {
        return errlog ( ERR_INFORM, "Shield: Invalid fence configuration\n" );
    }

    return 0;
}

static int _verify_fence          ( nc_shield_fence_t* fence )
{
    if ( fence->limited.prob < 0 || fence->limited.prob > 1 ) {
        return errlog ( ERR_INFORM, "Shield: Fence limited probability must be between 0 and 1\n" );
    }
    
    if ( fence->closed.prob < 0 || fence->closed.prob > 1 ) {
        return errlog ( ERR_INFORM, "Shield: Fence closed probability must be between 0 and 1\n" );
    }

    if ( fence->closed.post < fence->limited.post ) {
        return errlog ( ERR_INFORM, "Shield: Fence closed post must be greater than limited post\n" );
    }
   
    return 0;
}




