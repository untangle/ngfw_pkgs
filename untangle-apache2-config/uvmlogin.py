import base64
import urllib

from mod_python import apache, Session, util

def authenhandler(req):
    return apache.OK

def headerparserhandler(req):
    options = req.get_options()
    if options.has_key('Realm'):
        realm = options['Realm']
    else:
        apache.log_error('no realm specified')
        return apache.DECLINED

    sess = Session.Session(req)
    sess.save()
    if sess.has_key('apache_realms') and sess['apache_realms'].has_key(realm):
        realm_record = sess['apache_realms'][realm]

        if realm_record != None and realm_record.has_key('username'):
            username = realm_record['username']
            password = sess.id()
            pw = base64.encodestring('%s:%s' % (username, password)).strip()
            req.headers_in['Authorization'] = "BASIC % s" % pw
            return apache.OK
        else:
            login_redirect(req, realm)
    else:
        login_redirect(req, realm)

def login_redirect(req, realm):
    url = urllib.quote(req.unparsed_uri)
    realm_str = urllib.quote(realm)

    redirect_url = '/login/login.py?url=%s&realm=%s' % (url, realm_str)
    util.redirect(req, redirect_url)
