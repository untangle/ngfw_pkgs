<%@
page contentType="text/html; charset=UTF-8" %><%@
page language="java" %><%@
page import="org.jabsorb.test.Test"
%><jsp:useBean id="JSONRPCBridge" scope="session"
     class="org.jabsorb.JSONRPCBridge"
/><jsp:useBean id="testObject" scope="session"
     class="org.jabsorb.test.Test"
/><%
   response.setDateHeader ("Expires", 0);
   JSONRPCBridge.registerObject("test", testObject);
   JSONRPCBridge.registerReference(Test.RefTest.class);
   JSONRPCBridge.registerCallableReference(Test.CallableRefTest.class);
%>
<%!String title = "Tests";
String head = "    <script type=\"text/javascript\" src=\"jsonrpc.js\"></script>" +
              "    <script type=\"text/javascript\" src=\"test.js\"></script>";
String onLoad = "onLoad()";%>
<%@ include file="header.jspinc" %>

    <h2><%=appName%> <%=title%></h2>

    <h3>Test Output</h3>
    <table cellpadding="4" cellspacing="0" width="100%" style="border: 1px solid #c0c0c0; border-collapse: collapse;">
      <tr>
       <td>
        <textarea wrap="off" id="result" cols="80" rows="24"></textarea>
       </td>
       <td valign="top">
        <h3>Tests</h3>
        <p><a href="javascript:doListMethods();">List Methods</a><br>
        <a href="javascript:doBasicTests();">Basic Tests</a><br>
        <a href="javascript:doReferenceTests();">Reference Tests</a><br>
        <a href="javascript:doContainerTests();">Container Tests</a><br>
        <a href="javascript:doExceptionTest();">Exception Test</a></p>
        <h3>Callbacks</h3>
        <p><a href="javascript:setCallback(true);">Callback On</a><br>
        <a href="javascript:setCallback(false);">Callback Off</a></p>
          <p><em><strong>Note:</strong> the callback control only affects the debug output in the server side logs.</em></p>
       </td>
      </tr>
    </table>

<%@ include file="footer.jspinc" %>
