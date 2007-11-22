// Include the Ruby headers and goodies
#define _GNU_SOURCE

#include "ruby.h"

#include <security/pam_appl.h>
#include <string.h>

#include <stdio.h>

/* Don't think anyone has credentials this long */
#define USER_INFO_MAX_LEN  128

typedef struct
{
    char username[USER_INFO_MAX_LEN];
    char password[USER_INFO_MAX_LEN];
} _pam_app_data_t;

static int _auth_pam_talker( int num_msg, const struct pam_message **msg, struct pam_response **response,
                             void *app_data );

static VALUE _authenticate(VALUE self, VALUE username, VALUE password );

static VALUE _initialize(VALUE self, VALUE service_name );

void Init_pam_auth()
{
    VALUE pam_auth;
    pam_auth = rb_define_class( "PamAuth", rb_cObject );
    rb_define_method( pam_auth, "authenticate", _authenticate, 2);
    rb_define_method( pam_auth, "initialize", _initialize, 1 );
}

static int _auth_pam_talker( int num_msg, const struct pam_message **msg, struct pam_response **response,
                         void *app_data )
{
    if ( num_msg <= 0 ) return PAM_CONV_ERR;
    
    if (( msg == NULL ) || ( response == NULL ) || ( app_data == NULL )) return PAM_CONV_ERR;

    _pam_app_data_t* pam_app_data = app_data;
    
    int _critical_section() {
        int c = 0;
        for ( c = 0 ; c < num_msg ; c++ ) {
            switch( msg[c]->msg_style ) {
            case PAM_PROMPT_ECHO_ON:
                (*response)[c].resp = strndup( pam_app_data->username, sizeof( pam_app_data->username ));
                break;

            case PAM_PROMPT_ECHO_OFF:
                (*response)[c].resp = strndup( pam_app_data->password, sizeof( pam_app_data->password ));
                break;

            default:
                rb_raise( rb_eException, "Unknown message style %d", msg[c]->msg_style );
                return -1;
            }
        }

        return 0;
    }
    
    int ret;
    int c;

    /* Create enough memory for the responses */
    *response = calloc( num_msg, sizeof( struct pam_response ));

    ret = _critical_section();

    if ( ret < 0 ) {
        /* Free the strings that are referenced. */
        for ( c = 0 ; c < num_msg ; c++ ) {
            if ( (*response)[c].resp != NULL ) free( (*response)[c].resp );
            (*response)[c].resp = NULL;
        }
        free( *response );
        *response = NULL;
        return PAM_CONV_ERR;
    }

    return PAM_SUCCESS;
}

static VALUE _initialize(VALUE self, VALUE service_name )
{
    /* Verify the inputs types */
    STR2CSTR( service_name );

    rb_iv_set( self, "@service_name", service_name );
    return self;
}

/**
 * Authenticate username and password against PAM.
 */
static VALUE _authenticate( VALUE self, VALUE rb_username, VALUE rb_password )
{
    char* username;
    char* password;
    pam_handle_t* pam_handle = NULL;

    int ret;
    
    int _critical_section() {
        switch ( ret = pam_authenticate( pam_handle, PAM_DISALLOW_NULL_AUTHTOK )) {
        case PAM_SUCCESS:
            break;
            
        case PAM_AUTH_ERR: /* fallthrough */
        case PAM_USER_UNKNOWN:
            return 0;

        default:
            return -1;
        }
        
        if (( ret = pam_acct_mgmt( pam_handle, PAM_DISALLOW_NULL_AUTHTOK )) != PAM_SUCCESS ) {
            rb_raise( rb_eException, "pam_acct_mgmt %s", pam_strerror( pam_handle, ret ));
            return -1;
        }

        return 1;
    }

    _pam_app_data_t pam_app_data;

    struct pam_conv conv_info = { _auth_pam_talker, &pam_app_data };

    username = STR2CSTR( rb_username );
    password = STR2CSTR( rb_password );

    bzero( &pam_app_data, sizeof( _pam_app_data_t ));

    strncpy( pam_app_data.username, username, sizeof( pam_app_data.username ));
    strncpy( pam_app_data.password, password, sizeof( pam_app_data.password ));

    char *service_name = STR2CSTR( rb_iv_get( self, "@service_name" ));
    if (( ret = pam_start( service_name, username, &conv_info, &pam_handle )) != PAM_SUCCESS ) {
        rb_raise( rb_eException, "pam_start %s", pam_strerror( pam_handle, ret ));
        return Qnil;
    }

    ret = _critical_section();

    pam_end( pam_handle, PAM_SUCCESS );

    if ( ret < 0 ) return Qnil;

    return ( ret == 1 ) ? Qtrue : Qfalse;
}


