import base64
import os
import urllib

from mod_python import apache, Session, util

def authenhandler(req):
    if req.notes.has_key('authorized') and req.notes['authorized'] == 'true':
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

    sess = Session.Session(req)
    sess.save()

    username = session_user(sess, realm)

    if None == username and Realm == 'SetupWizard' and is_not_setup():
        username = 'setupwizard'
        save_session_user(sess, realm, username)

    if None == username and is_root(req):
        username = 'localadmin'
        save_session_user(sess, realm, username)

    if None != username:
        pw = base64.encodestring('%s' % username).strip()
        req.headers_in['Authorization'] = "BASIC % s" % pw
        req.notes['authorized'] = 'true'
        return apache.OK
    else:
        login_redirect(req, realm)

def session_user(sess, realm):
    if sess.has_key('apache_realms') and sess['apache_realms'].has_key(realm):
        realm_record = sess['apache_realms'][realm]

        if realm_record != None and realm_record.has_key('username'):
            return realm_record['username']

    return None

def is_not_setup():
    return os.path.exists('/usr/share/untangle/.regdone')

def is_root(req):
    (remote_ip, remote_port) = req.connection.remote_addr

    result = False;

    if remote_ip == "127.0.0.1":
        q = remote_ip.split(".")
        q.reverse()
        n = reduce(lambda a, b: long(a) * 256 + long(b), q)
        hexaddr = "%08X" % n
        hexport = "%04X" % remote_port

        infile = open('/proc/net/tcp', 'r')
        for l in infile:
            a = l.split()
            if len(a) > 2:
                p = a[1].split(':')
                if len(p) == 2 and p[0] == hexaddr and p[1] == hexport:
                    uid = a[7]
                    if uid == '0':
                        result = True
                        break
        infile.close()

    return result

def login_redirect(req, realm):
    url = urllib.quote(req.unparsed_uri)
    realm_str = urllib.quote(realm)

    redirect_url = '/login/login.py?url=%s&realm=%s' % (url, realm_str)
    util.redirect(req, redirect_url)

def save_session_user(sess, realm, username):
    if sess.has_key('apache_realms'):
        apache_realms = sess['apache_realms']
    else:
        sess['apache_realms'] = apache_realms = {}

    realm_record = {}
    realm_record['username'] = username
    apache_realms[realm] = realm_record

    sess.save()
