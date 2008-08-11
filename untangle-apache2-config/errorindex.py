from mod_python import apache

# pages --------------------------------------------------------------------------

def status400(req):
    _write_report(req, "Bad Request")

def status401(req):
    _write_report(req, "Unauthorized")

def status402(req):
    _write_report(req, "Payment Required")

def status403(req):
    _write_report(req, "Forbidden")

def status404(req):
    _write_report(req, "Not Found")

def status405(req):
    _write_report(req, "Method Not Allowed")

def status406(req):
    _write_report(req, "Not Acceptable")

def status407(req):
    _write_report(req, "Proxy Authentication Required")

def status408(req):
    _write_report(req, "Request Timeout")

def status409(req):
    _write_report(req, "Conflict")

def status410(req):
    _write_report(req, "Gone")

def status411(req):
    _write_report(req, "Length Required")

def status412(req):
    _write_report(req, "Precondition Failed")

def status413(req):
    _write_report(req, "Request Entity Too Large")

def status414(req):
    _write_report(req, "Request-URI Too Long")

def status415(req):
    _write_report(req, "Unsupported Media Type")

def status416(req):
    _write_report(req, "Requested Range Not Satisfiable")

def status417(req):
    _write_report(req, "Expectation Failed")

def status500(req):
    _write_report(req, "Internal Server Error")

def status501(req):
    _write_report(req, "Not Implemented")

def status502(req):
    _write_report(req, "Bad Gateway")

def status503(req):
    _write_report(req, "Service Unavailable")

def status504(req):
    _write_report(req, "Gateway Timeout")

def status505(req):
    _write_report(req, "HTTP Version Not Supported")

# internal methods ---------------------------------------------------------------

def _write_report(req, msg):
    req.content_type = "text/html"
    req.send_http_header()

    req.write("""\
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\">
<head>
<title>Untangle Server</title>
<meta http-equiv=\"Content-Type\" content=\"text/html;charset=iso-8859-1\" />
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
<b>Untangle Server</b><br /><br />
<em>%s</em>
</center><br /><br />
</div></div></div><div class=\"main-bot-left\"></div><div class=\"main-bot-right\"></div>
</div>
</body>
</html>
""" % msg)
    return apache.OK
