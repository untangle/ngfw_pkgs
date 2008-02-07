<%@page contentType="text/html; charset=UTF-8" %>
<%@page language="java" %>
<%@page import="org.slf4j.LoggerFactory" %>
<jsp:useBean id="JSONRPCBridge" scope="session"
     class="org.jabsorb.JSONRPCBridge"
/>
<jsp:useBean id="testObject" scope="session"
     class="org.jabsorb.test.Test"
/>
<%
   response.setDateHeader ("Expires", 0);
   JSONRPCBridge.registerObject("test", testObject);
   JSONRPCBridge.registerReference(org.jabsorb.test.Test.RefTest.class);
   JSONRPCBridge.registerCallableReference(org.jabsorb.test.Test.CallableRefTest.class);
%>
<%!
  String title = "Unit Tests (for &quot;minimized&quot; version, <b>jsonrpc-min.js</b>)";
  String head =
    "    <link rel=\"stylesheet\" type=\"text/css\" href=\"css/unit.css\">\n" +
    "    <script type=\"text/javascript\" src=\"jsonrpc-min.js\"></script>\n" +
    "    <script type=\"text/javascript\" src=\"unitTests.js\"></script>\n" +
    "    <script type=\"text/javascript\" src=\"unit.js\"></script>\n";
  String onLoad = "onLoad()";
%>
<%@ include file="header.jspinc" %>
<%@ include file="unit.jspinc" %>
<%@ include file="footer.jspinc" %>
