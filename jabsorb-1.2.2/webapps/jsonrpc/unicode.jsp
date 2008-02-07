<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page language="java" %>
<%@ page import="org.jabsorb.JSONRPCBridge" %>
<%@ page import="org.jabsorb.test.Unicode" %>
<jsp:useBean id="JSONRPCBridge" scope="session"
     class="org.jabsorb.JSONRPCBridge" />
<jsp:useBean id="unicode" scope="session"
     class="org.jabsorb.test.Unicode" />
<%
   response.setDateHeader ("Expires", 0);
   //JSONRPCBridge.setDebug(true);
   JSONRPCBridge.registerObject("unicode", unicode);
%>
<%!String title = "Unicode Tests";
  String head =
    "    <link rel=\"stylesheet\" type=\"text/css\" href=\"css/unicode.css\">\n" +
    "    <script type=\"text/javascript\" src=\"jsonrpc.js\"></script>\n" +
    "    <script type=\"text/javascript\" src=\"unicode.js\"></script>\n";
  String onLoad = "onLoad()";%>
<%@ include file="header.jspinc" %>

    <h2><%=appName%> <%=title%></h2>

    <p>The tests run automatically when you load the page. It may take a second or so to run the tests and display the table.</p>

    <h3>Description of table fields</h3>
    <ul>
      <li><em>Description</em> - what character set should be expected.</li>
      <li><em>Recieve</em> - unicode data recieved from the server.</li>
      <li><em>Echo Compare</em> - received data send back and compared with the server-side data.</li>
      <li><em>Pass</em> - server-side compare result.</li>
    </ul>

    <table class="test_table">
      <thead>
       <tr>
        <th class="test_th" width="150"><div class="desc_heading">Description</div></th>
        <th class="test_th" width="50%"><div class="recv_heading">Receive</div></th>
        <th class="test_th" width="50%"><div class="echo_heading">Echo Compare</div></th>
        <th class="test_th" width="32"><div class="pass_heading">Pass</div></th>
       </tr>
      </thead>
      <tbody id="tests"></tbody>
    </table>

<%@ include file="footer.jspinc" %>
