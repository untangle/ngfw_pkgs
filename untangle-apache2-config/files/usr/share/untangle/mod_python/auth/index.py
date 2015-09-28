# $Id$
import md5
import uvmlogin
import cgi
import base64
import sys

from mod_python import apache, Session, util
from psycopg2 import connect

def get_node_settings_item(a,b):
    return None
def get_uvm_settings_item(a,b):
    return None

try:
    from uvm.settings_reader import get_node_settings_item
    from uvm.settings_reader import get_uvm_settings_item
except ImportError:
    pass

# pages -----------------------------------------------------------------------

def login(req, url=None, realm='Administrator'):
    uvmlogin.setup_gettext()

    options = req.get_options()

    args = util.parse_qs(req.args or '')

    if req.form.has_key('username') or req.form.has_key('password'):
        is_error = True
    else:
        is_error = False

    if req.form.has_key('username') and req.form.has_key('password'):
        username = req.form['username']
        password = req.form['password']
        # debug
        # assert False, ("User:Pass = %s %s" % (username,password))

        if _valid_login(req, realm, username, password):
            sess = Session.Session(req)
            sess.set_timeout(uvmlogin.SESSION_TIMEOUT)
            uvmlogin.save_session_user(sess, realm, username)
            sess.save()
            sess.unlock()

            if url == None:
                return apache.OK
            else:
                util.redirect(req, url, text="Login Successful")

    company_name = uvmlogin.get_company_name()
    title = _("Administrator Login")
    # some i18n company_names cause exception here, so wrap to handle this 
    # revert to "Administrator Login" if exception occurs
    try:
        title = cgi.escape(_("%s Administrator Login") % company_name)
    except:
        pass

    host = cgi.escape(req.hostname)

    _write_login_form(req, title, host, is_error)

def logout(req, url=None, realm='Administrator'):
    sess = Session.Session(req)
    sess.set_timeout(uvmlogin.SESSION_TIMEOUT)
    uvmlogin.delete_session_user(sess, realm)
    sess.save()
    sess.unlock()

    if url == None:
        return apache.OK
    else:
        util.redirect(req, url, text="Logout Successfull")

# internal methods ------------------------------------------------------------

def _valid_login(req, realm, username, password):
    if realm == 'Administrator': 
        return _admin_valid_login(req, realm, username, password)
    elif realm == 'Reports':
        if _admin_valid_login(req, 'Administrator', username, password, False):
            return True;
        else:
            return _reports_valid_login(req, realm, username, password)
    else:
        return False

def _reports_valid_login(req, realm, username, password, log=True):
    users = get_node_settings_item('untangle-node-reports','reportsUsers')
    if users == None:
        return False;
    if users['list'] == None:
        return False;
    for user in users['list']:
        if user['emailAddress'] != username:
            continue;
        pw_hash_base64 = user['passwordHashBase64']
        pw_hash = base64.b64decode(pw_hash_base64)
        raw_pw = pw_hash[0:len(pw_hash) - 8]
        salt = pw_hash[len(pw_hash) - 8:]
        if raw_pw == md5.new(password + salt).digest():
            if log:
                uvmlogin.log_login(req, username, False, True, None)
            return True
        else:
            if log:
                uvmlogin.log_login(req, username, False, False, 'P')
            return False
    if log:
        uvmlogin.log_login(req, username, False, False, 'U')
    return False

def _admin_valid_login(req, realm, username, password, log=True):
    users = get_uvm_settings_item('admin','users')
    if users == None:
        return False;
    if users['list'] == None:
        return False;
    for user in users['list']:
        if user['username'] != username:
            continue;
        pw_hash_base64 = user['passwordHashBase64']
        pw_hash = base64.b64decode(pw_hash_base64)
        raw_pw = pw_hash[0:len(pw_hash) - 8]
        salt = pw_hash[len(pw_hash) - 8:]
        if raw_pw == md5.new(password + salt).digest():
            if log:
                uvmlogin.log_login(req, username, False, True, None)
            return True
        else:
            if log:
                uvmlogin.log_login(req, username, False, False, 'P')
            return False
    if log:
        uvmlogin.log_login(req, username, False, False, 'U')
    return False

def _write_login_form(req, title, host, is_error):
    login_url = cgi.escape(req.unparsed_uri)
    req.content_type = "text/html; charset=utf-8"
    req.send_http_header()

    if is_error:
        error_msg = '<b style="color:#f00">%s</b><br/><br/>' % cgi.escape(_('Error: Username and Password do not match'))
    else:
        error_msg = ''

    server_str = cgi.escape(_("Server:"))
    username_str = cgi.escape(_("Username:"))
    password_str = cgi.escape(_("Password:"))
    login_str = cgi.escape(_("Login"))

    if not type(title) is str:
        title = cgi.escape(title).encode("utf-8")
    if not type(host) is str:
        host = cgi.escape(host).encode("utf-8")

    banner_msg = get_node_settings_item('untangle-node-branding-manager','bannerMessage')
    if banner_msg != None and banner_msg != "":
        banner_msg = banner_msg.replace("\n", "<br/>")
        banner_msg = "<br>" + banner_msg.encode('utf-8')
    else:
        banner_msg = ""
        
    html = """\
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>%s</title>
<script type="text/javascript">if (top.location!=location) top.location.href=document.location.href;</script>
<style type="text/css">
/* <![CDATA[ */
@import url(/images/base.css);
/* ]]> */
</style>
</head>
<body class="loginPage">
<div id="main" style="width: 500px; margin: 50px auto 0 auto;">
    <form method="post" action="%s" class="form-signin">
        <center>
    	    <img style="margin-bottom:10px;" src="/images/BrandingLogo.png"><br/>
            <span class="form-signin-heading"><strong>%s</strong></span>
            <br/>
            <div class="banner">%s</div>
            <br/>
            <span><strong>%s</strong></span>
            <table>
                <tbody>
                    <tr><td style="text-align:right;color:white;">%s</td><td><em><font color="white">&nbsp;%s</font></em></td></tr>
                    <tr><td style="text-align:right;color:white;">%s</td><td><input id="username" type="text" name="username" value="admin" class="input-block-level"/></td></tr>
                    <tr><td style="text-align:right;color:white;">%s</td><td><input id="password" type="password" name="password" class="input-block-level"/></td></tr>
                </tbody>
            </table>
            <br/>
            <div style="text-align: center;color:white;"><button value="login" type="submit">%s</button></div>
        </center>
    </form>
    <script type="text/javascript">document.getElementById('password').focus();</script>
</div>
</body>
</html>""" % (title, login_url,title,banner_msg,error_msg, server_str, host, username_str, password_str, login_str)
    
    req.write(html)
