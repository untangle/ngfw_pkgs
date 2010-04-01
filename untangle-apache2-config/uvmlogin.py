# $HeadURL: svn://chef/work/src/spyware/impl/com/untangle/node/spyware/SpywareImpl.java $
# Copyright (c) 2003-2009 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Aaron Read <amread@untangle.com>

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
from psycopg import connect

SESSION_TIMEOUT = 1800

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

    if None == username and realm == 'SetupWizard' and is_not_setup():
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
            (allow_insecure, allow_outside_admin) = get_access_settings()

            connection = req.connection

            (addr, port) = connection.local_addr

            if not re.match('127\.', connection.remote_ip):
                if 80 == port and not allow_insecure:
                    return apache.HTTP_FORBIDDEN
                elif 443 == port and not allow_outside_admin:
                    return apache.HTTP_FORBIDDEN

        login_redirect(req, realm)

# This handler is for the proxy
def accesshandler(req):
    nonce = req.headers_in.get('X-Nonce', None);
    authorized = False

    if None != nonce:
        conn = connect("dbname=uvm user=postgres")
        try:
            curs = conn.cursor()
            curs.execute("SELECT 1 FROM settings.n_proxy_nonce WHERE nonce = %s AND create_time >= now() - '1 hour'::interval", (nonce,))
            authorized = 0 < curs.rowcount
            curs.execute("DELETE FROM settings.n_proxy_nonce WHERE nonce = %s OR create_time < now() - '1 hour'::interval", (nonce,))
            conn.commit()
        finally:
            conn.close()

    if authorized:
        return apache.OK
    else:
        return apache.HTTP_FORBIDDEN

def session_user(sess, realm):
    if sess.has_key('apache_realms') and sess['apache_realms'].has_key(realm):
        realm_record = sess['apache_realms'][realm]

        if realm_record != None and realm_record.has_key('username'):
            return realm_record['username']

    return None

def is_not_setup():
    return not os.path.exists('/usr/share/untangle/registration.info')

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

    conn = connect("dbname=uvm user=postgres")
    try:
        curs = conn.cursor()

        curs.execute('SELECT company_name FROM settings.n_branding_settings')
        r = curs.fetchone()
        if r != None:
            company = r[0]
    except Exception, e:
        pass
    finally:
        conn.close()

    return company

def get_uvm_language():
    lang = 'us'

    conn = connect("dbname=uvm user=postgres")
    try:
        curs = conn.cursor()
        curs.execute('SELECT language FROM settings.u_language_settings')
        r = curs.fetchone()
        if r != None:
            lang = r[0]
    finally:
        conn.close()

    return lang

def get_access_settings():
        conn = connect("dbname=uvm user=postgres")
        try:
            curs = conn.cursor()
            curs.execute('select allow_insecure, allow_outside_admin from settings.u_access_settings')
            r = curs.fetchone()
        finally:
            conn.close()

            if None == r:
                return (False, False)
            else:
                return r

def log_login(req, login, local, succeeded, reason):
    (client_addr, client_port) = req.connection.remote_addr

    conn = connect("dbname=uvm user=postgres")
    try:
        curs = conn.cursor()
        curs.execute("INSERT INTO events.u_login_evt (event_id, client_addr, login, local, succeeded, reason, time_stamp) VALUES (nextval('hibernate_sequence'), %s, %s, %s, %s, %s, now())",
                     (client_addr, login, local, succeeded, reason));
        conn.commit()
    finally:
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
