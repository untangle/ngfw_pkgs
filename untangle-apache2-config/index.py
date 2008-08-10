import md5
import uvmlogin

from mod_python import apache, Session, util
from psycopg import connect

# pages --------------------------------------------------------------------------

def login(req, url='/', realm='Administrator'):
    args = util.parse_qs(req.args or '')

    if req.form.has_key('username') and req.form.has_key('password'):
        username = req.form['username']
        password = req.form['password']

        if _valid_login(req, realm, username, password):
            sess = Session.Session(req)
            uvmlogin.save_session_user(sess, realm, username)

            apache.log_error('redirect to %s' % url)
            util.redirect(req, url)

    company_name = "Untangle"
    title = "%s Login" % company_name
    host = req.hostname
    _write_login_form(req, title, host)

    return apache.OK

def logout(req, url='/', realm='Administrator'):
    sess = Session.Session(req)
    uvmlogin.delete_session_user(sess, realm)
    util.redirect(req, url)

# internal methods ---------------------------------------------------------------

def _valid_login(req, realm, username, password):
    if realm == 'Administrator':
        return _admin_valid_login(req, username, password)
    else:
        apache.log_error('unknown realm: %s' % realm)
        return False

def _admin_valid_login(req, username, password):
    conn = connect("dbname=uvm user=postgres")
    curs = conn.cursor()
    curs.execute('SELECT password FROM settings.u_user WHERE login = %s',
                 (username,))
    r = curs.fetchone()

    if (r == None):
        return False
    else:
        pw_hash = r[0]
        raw_pw = pw_hash[0:len(pw_hash) - 8]
        salt = pw_hash[len(pw_hash) - 8:]
        return raw_pw == md5.new(password + salt).digest()

def _write_login_form(req, title, host):
    login_url = req.unparsed_uri
    req.content_type = "text/html"
    req.send_http_header()

    req.write("""\
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<!-- MagicComment: MVTimeout -->

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
<body>
<div id="main" style="width: 500px; margin: 50px auto 0 auto;">
 <div class="main-top-left"></div><div class="main-top-right"></div><div class="main-mid-left"><div class="main-mid-right"><div class="main-mid">
 <!-- Content Start -->

      <center>
        <img alt="" src="/images/BrandingLogo.gif" /><br />

        <b>%s</b><br/>

        <div style="margin: 0 auto; width: 250px; padding: 40px 0 5px;">

        <form method="post" action="%s">
          <table><tbody>
            <tr><td style="text-align:right">Server:</td><td><em>&nbsp;%s</em></td></tr>
            <tr><td style="text-align:right">Username:</td><td><input id="username" type="text" name="username" /></td></tr>
            <tr><td style="text-align:right">Password:</td><td><input id="password" type="password" name="password" /></td></tr>
          </tbody></table>
          <br />
          <div style="text-align: center;"><button value="login" type="submit">Login</button></div>
        </form>

        <script type="text/javascript">document.getElementById('username').focus();</script>

        </div>
      </center>


 <!-- Content End -->
 </div></div></div><div class="main-bot-left"></div><div class="main-bot-right"></div>
 <!-- Box End -->
</div>
</body>
</html>
""" % (title, title, login_url, host))
