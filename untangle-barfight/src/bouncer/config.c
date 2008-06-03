/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_shield.c $
 * Copyright (c) 2003-2007 Untangle, Inc. 
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

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/list.h>
#include <mvutil/utime.h>

#include <json/json.h>

#include "bouncer/config.h"
#include "json/object_utils.h"


/* XXX What are reasonable defaults */
/* Default limits: lax, tight, closed */
/* XXX CPU Loads are really high (ignored) until we have a way getting a load average with 
 * a shorter interval */
#define _CPU_LOAD_LIMITS        40.0, 60.0, 80.0
#define _ACTIVE_SESSION_LIMITS  512, 1024, 1536
#define _REQUEST_LOAD_LIMITS    60, 75, 85
#define _SESSION_LOAD_LIMITS    50, 60, 75
#define _TCP_CHK_LOAD_LIMITS    5000, 10000, 14000
#define _UDP_CHK_LOAD_LIMITS    3000, 6000, 10000
#define _ICMP_CHK_LOAD_LIMITS   3000, 6000, 10000
#define _EVIL_LOAD_LIMITS       800, 1600, 2000

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


static void _load_limits( struct json_object* config_json, bouncer_shield_config_t* config );
static void _load_limit( struct json_object* limit_json, nc_shield_limit_t* limit );

static void _load_fences( struct json_object* fences, bouncer_shield_config_t* config );
static void _load_fence( struct json_object* fence_json, nc_shield_fence_t* fence );
static void _load_post( struct json_object* post_json, nc_shield_post_t* post );

static void _load_multipliers( struct json_object* multipliers_json, bouncer_shield_config_t* config );
static void _load_lru( struct json_object* lru_json, bouncer_shield_config_t* config );
static void _load_debug( struct json_object* debug_json, bouncer_shield_config_t* config );

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
static int _add_debug( struct json_object* config_json, bouncer_shield_config_t* config );

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
                .limited = { .prob = 0.70, .post = _SHIELD_REP_MAX * 0.65 },
                .closed  = { .prob = 0.85, .post = _SHIELD_REP_MAX * 0.90 },
                .error   = { .prob = 0.95, .post = _SHIELD_REP_MAX * 1.00 }
            },
            .lax = {
                .inheritance = .4,
                .limited = { .prob = 0.75, .post = _SHIELD_REP_MAX * 0.50 },
                .closed  = { .prob = 0.80, .post = _SHIELD_REP_MAX * 0.80 },
                .error   = { .prob = 0.95, .post = _SHIELD_REP_MAX * 1.00 }
            },
            .tight = {
                .inheritance = .6,
                .limited = { .prob = 0.70, .post = _SHIELD_REP_MAX * 0.15 },
                .closed  = { .prob = 0.90, .post = _SHIELD_REP_MAX * 0.60 },
                .error   = { .prob = 0.95, .post = _SHIELD_REP_MAX * 0.70 }
            }, 
            .closed = {
                .inheritance = .9,
                .limited = { .prob = 0.90, .post = _SHIELD_REP_MAX * 0.05 },
                .closed  = { .prob = 0.95, .post = _SHIELD_REP_MAX * 0.20 },
                .error   = { .prob = 0.95, .post = _SHIELD_REP_MAX * 0.40 }
            }
        },
        .rep_threshold = _REPUTATION_DEBUG_THRESHOLD
    };
    
    if ( config == NULL ) return errlogargs();

    memcpy ( config, &default_config, sizeof ( bouncer_shield_config_t ));

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

    _load_debug( json_object_object_get( config_json, "debug" ), config );

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
        if ( _add_debug( config_json, config ) < 0 ) {
            return errlog( ERR_CRITICAL, "_add_debug\n" );
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

    return;
}

static void _load_fences( struct json_object* fences, bouncer_shield_config_t* config )
{
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

static void _load_debug( struct json_object* debug_json, bouncer_shield_config_t* config )
{
    if ( debug_json == NULL ) return;

    _update_int( debug_json, "rate", &config->print_delay, 0 );
    _update_double( debug_json, "threshold", &config->rep_threshold, 0 );
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

static int _add_debug( struct json_object* config_json, bouncer_shield_config_t* config )
{
    struct json_object* debug_json = NULL;

    int _critical_section() {
        if ( json_object_utils_add_int( debug_json, "rate", config->print_delay ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }
        if ( json_object_utils_add_double( debug_json, "ip-rate", config->rep_threshold ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_object( config_json, "debug", debug_json ) < 0 ) {
            /* on failure it has already been scrubbed. */
            debug_json = NULL;
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        return 0;
    }
    
    if (( debug_json = json_object_new_object()) == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        if ( debug_json != NULL ) json_object_put( debug_json );
        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;    
}


