import base64
import cgi
import gettext
import grp
import os
import pwd
import re
import sets
import urllib
import os.path
import sys

from mod_python import apache, Session, util
from psycopg2 import connect


def authenhandler(req):
    if req.notes.get('authorized', 'false') == 'true':
        return apache.OK
    else:
        options = req.get_options()

        if options.has_key('Realm'):
            realm = options['Realm']
            login_redirect(req, realm)
        else:
            apache.log_error('no realm specified')
            return apache.DECLINED

def get_node_settings_item(a,b):
    return None
def get_uvm_settings_item(a,b):
    return None

try:
    from uvm.settings_reader import get_node_settings_item
    from uvm.settings_reader import get_uvm_settings_item
except ImportError:
    pass

SESSION_TIMEOUT = 1800

def headerparserhandler(req):
    options = req.get_options()

    if options.has_key('Realm'):
        realm = options['Realm']
    else:
        apache.log_error('no realm specified')
        return apache.DECLINED

    sess = Session.Session(req, lock=0)
    sess.set_timeout(SESSION_TIMEOUT)

    sess.lock()

    username = session_user(sess, realm)

    if None == username and realm == 'Reports':
        username = session_user(sess, 'Administrator')

    if None == username and realm == 'SetupWizard':
        username = session_user(sess, 'Administrator')

    if None == username and realm == 'SetupWizard' and not is_wizard_complete():
        username = 'setupwizard'
        save_session_user(sess, realm, username)

    if None == username and is_root(req):
        username = 'localadmin'
        log_login(req, username, True, True, None)
        save_session_user(sess, realm, username)

    sess.save()
    sess.unlock()

    if None != username:
        pw = base64.encodestring('%s' % username).strip()
        req.headers_in['Authorization'] = "BASIC % s" % pw
        req.notes['authorized'] = 'true'
        return apache.OK
    else:
        # we only do this as to not present a login screen when access
        # is restricted. a tomcat valve enforces this setting.
        if options.get('UseRemoteAccessSettings', 'no') == 'yes':
            (inside_http_enabled, outside_https_enabled) = get_access_settings()

            connection = req.connection

            (addr, port) = connection.local_addr

            if not re.match('127\.', connection.remote_ip):
                if 80 == port and not inside_http_enabled:
                    return apache.HTTP_FORBIDDEN
                elif 443 == port and not outside_https_enabled:
                    return apache.HTTP_FORBIDDEN

        login_redirect(req, realm)

def session_user(sess, realm):
    if sess.has_key('apache_realms') and sess['apache_realms'].has_key(realm):
        realm_record = sess['apache_realms'][realm]

        if realm_record != None and realm_record.has_key('username'):
            return realm_record['username']

    return None

def is_wizard_complete():
    return os.path.exists('/usr/share/untangle/conf/wizard-complete-flag')

def is_root(req):
    (remote_ip, remote_port) = req.connection.remote_addr

    result = False;

    if remote_ip == "127.0.0.1":
        uids = get_uvmlogin_uids()

        q = remote_ip.split(".")
        q.reverse()
        n = reduce(lambda a, b: long(a) * 256 + long(b), q)
        hexaddr = "%08X" % n
        hexport = "%04X" % remote_port

        try:
            infile = open('/proc/net/tcp', 'r')
            for l in infile:
                a = l.split()
                if len(a) > 2:
                    p = a[1].split(':')
                    if len(p) == 2 and p[0] == hexaddr and p[1] == hexport:
                        try:
                            uid = int(a[7])

                            if uid in uids:
                                result = True
                                break
                        except:
                            apache.log_error('bad uid: %s' % a[7])
        finally:
            infile.close()

    return result

def get_uvmlogin_uids():
    s = sets.Set([0])

    try:
        for username in grp.getgrnam('uvmlogin')[3]:
            try:
                s.add(pwd.getpwnam(username)[2])
            except:
                apache.log_error('bad user %s' % username)
    except:
        apache.log_error('could not get group info')

    return s


def login_redirect(req, realm):
    url = urllib.quote(req.unparsed_uri)

    if realm == "SetupWizard":
        realm = "Administrator"

    realm_str = urllib.quote(realm)

    redirect_url = '/auth/login?url=%s&realm=%s' % (url, realm_str)
    util.redirect(req, redirect_url)

def delete_session_user(sess, realm):
    if sess.has_key('apache_realms'):
        apache_realms = sess['apache_realms']
        if realm in apache_realms:
            del apache_realms[realm]

def save_session_user(sess, realm, username):
    if sess.has_key('apache_realms'):
        apache_realms = sess['apache_realms']
    else:
        sess['apache_realms'] = apache_realms = {}

    realm_record = {}
    realm_record['username'] = username
    apache_realms[realm] = realm_record

def setup_gettext():
    lang = get_uvm_language()
    try:
        trans = gettext.translation('untangle-apache2-config',
                                    languages=[lang],
                                    fallback=True)
        trans.install()
    except Exception, e:
        apache.log_error('could not install language: %s lang. %s' % (lang, e))
        import __builtin__
        __builtin__.__dict__['_'] = unicode

def get_company_name():
    company = 'Untangle'

    if (os.path.isfile("/etc/untangle/oem/oem.py")):
        sys.path.append("/etc/untangle/oem")
        import oem
        company = oem.oemName()

    brandco = get_node_settings_item('untangle-node-branding','companyName')
    if (brandco != None):
        company = brandco

    return company

def get_uvm_language():
    lang = 'us'

    setval = get_uvm_settings_item('language_settings','language')
    if (setval != None):
        lang = setval

    return lang

def get_access_settings():
    inside_http_enabled = get_uvm_settings_item('system','insideHttpEnabled')
    outside_https_enabled = get_uvm_settings_item('system','outsideHttpsEnabled')

    if inside_http_enabled == None:
        inside_http_enabled = True
    if outside_https_enabled == None:
        outside_https_enabled = True

    return (inside_http_enabled, outside_https_enabled)

def log_login(req, login, local, succeeded, reason):
    (client_addr, client_port) = req.connection.remote_addr
    conn = None
    try:
        conn = connect("dbname=uvm user=postgres")
        curs = conn.cursor()
        sql = "INSERT INTO reports.n_admin_logins (client_addr, login, local, succeeded, time_stamp) VALUES ('%s', '%s', '%s', '%s', now())" % (client_addr, login, local, succeeded)
        curs.execute(sql);
        conn.commit()
    except Exception, e:
        pass
    finally:
        if (conn != None):
            conn.close()

def write_error_page(req, msg):
    req.content_type = "text/html; charset=utf-8"
    req.send_http_header()

    us = _("%s Server") % get_company_name()

    req.write("""\
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\">
<head>
<title>%s</title>
<meta http-equiv=\"Content-Type\" content=\"text/html;charset=utf-8\" />
<style type=\"text/css\">
/* <![CDATA[ */
@import url(/images/base.css);
/* ]]> */
</style>
</head>
<body>
<div id=\"main\" style=\"width:500px;margin:50px auto 0 auto;\">
<div class=\"main-top-left\"></div><div class=\"main-top-right\"></div><div class=\"main-mid-left\"><div class=\"main-mid-right\"><div class=\"main-mid\">
<center>
<img alt=\"\" src=\"/images/BrandingLogo.gif\" /><br /><br />
<b>%s</b><br /><br />
<em>%s</em>
</center><br /><br />
</div></div></div><div class=\"main-bot-left\"></div><div class=\"main-bot-right\"></div>
</div>
</body>
</html>
""" % (us, us, cgi.escape(msg)))
