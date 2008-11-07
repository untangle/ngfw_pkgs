import gettext
import uvmlogin
import cgi

from mod_python import apache

gettext.bindtextdomain('untangle-apache2-config')
gettext.textdomain('untangle-apache2-config')
_ = gettext.gettext

# pages -----------------------------------------------------------------------

def status400(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Bad Request"))

def status401(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Unauthorized"))

def status402(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Payment Required"))

def status403(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Forbidden"))

def status404(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Not Found"))

def status405(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Method Not Allowed"))

def status406(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Not Acceptable"))

def status407(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Proxy Authentication Required"))

def status408(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Request Timeout"))

def status409(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Conflict"))

def status410(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Gone"))

def status411(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Length Required"))

def status412(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Precondition Failed"))

def status413(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Request Entity Too Large"))

def status414(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Request-URI Too Long"))

def status415(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Unsupported Media Type"))

def status416(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Requested Range Not Satisfiable"))

def status417(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Expectation Failed"))

def status500(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Internal Server Error"))

def status501(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Not Implemented"))

def status502(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Bad Gateway"))

def status503(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Service Unavailable"))

def status504(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("Gateway Timeout"))

def status505(req):
    uvmlogin.setup_gettext()
    _write_error_page(req, _("HTTP Version Not Supported"))

# private methods --------------------------------------------------------------

def _write_error_page(req, msg):
    req.content_type = "text/html; charset=utf-8"
    req.send_http_header()

    us = _("%s Server") % uvmlogin.get_company_name()

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
