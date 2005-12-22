<HTML>
  <HEAD>
    <TITLE>Packages</TITLE>
  </HEAD>
  <BODY BGCOLOR="#e8e8e8">
    <H1>Packages</H1>
    <FORM ACTION="cust_pkg.cgi" METHOD="GET">
    <INPUT TYPE="hidden" NAME="magic" VALUE="bill">
      Return packages with next bill date:<BR><BR>
      <TABLE>
        <%= include( '/elements/tr-input-beginning_ending.html' ) %>
        <%= include( '/elements/tr-select-agent.html',
                       $cgi->param('agentnum'),
                   )
        %>
      </TABLE>
      <BR><INPUT TYPE="submit" VALUE="Get Report">

    </FORM>

  </BODY>
</HTML>

