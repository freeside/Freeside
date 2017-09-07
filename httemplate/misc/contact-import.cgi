<% include("/elements/header.html",'Batch Contacts Import') %>

Import a file containing customer contact records.
<BR><BR>

<& /elements/form-file_upload.html,
     'name'      => 'ContactImportForm',
     'action'    => 'process/contact-import.cgi',
     'num_files' => 1,
     'fields'    => [ 'custbatch', 'format' ],
     'message'   => 'Customer contacts import successful',
     'onsubmit'  => "document.ContactImportForm.submitButton.disabled=true;",
&>

<% &ntable("#cccccc", 2) %>

  <INPUT TYPE="hidden" NAME="custbatch" VALUE="<% $custbatch %>"%>

  <TR>
    <TH ALIGN="right">Format</TH>
    <TD>
      <SELECT NAME="format">
        <OPTION VALUE="default" SELECTED>Default
      </SELECT>
    </TD>
  </TR>

  <% include( '/elements/file-upload.html',
                'field' => 'file',
                'label' => 'Filename',
            )
  %>

  <TR>
    <TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px">
      <INPUT TYPE    = "submit"
             NAME    = "submitButton"
             ID      = "submitButton"
             VALUE   = "Import file"
      >
    </TD>
  </TR>

</TABLE>

</FORM>

<BR>

Uploaded files can be CSV (comma-separated value) files or Excel spreadsheets.  The file should have a .CSV or .XLS extension.
<BR><BR>

Default Format has the following field order:
<BR>
<i>custnum<%$req%>, last<%$req%>, first<%$req%>, title<%$req%>, comment, selfservice_access, emailaddress, workphone, mobilephone, homephone</i>
<BR><BR>

Field information:
<BR>
You must include a customer number and either a last name, first name or title.

<ul>

  <li><i>custnum</i>: This is the customer number of the customer the contact is attached to.</li>

  <li><i>last</i>: Last name for contact.</li>

  <li><i>first</i>: First name for contact.</li>

  <li><i>title</i>: Optional title for contact.</li>

  <li><i>comment</i>: Optional comment for contact.</li>

  <li><i>selfservice_access</i>: Empty for no self service access or Y if granting self service access.</li>

  <li><i>emailaddress</i>: Email address for contact.</li>

  <li><i>workphone</i>: Work phone number for contact. Format xxxxxxxxxx</li>

  <li><i>mobilephone</i>: Mobile phone number for contact. Format xxxxxxxxxx</li>

  <li><i>homephone</i>: Home phone number for contact. Format xxxxxxxxxx</li>

</ul>

<BR>

<% include('/elements/footer.html') %>

<%once>

my $req = qq!<font color="#ff0000">*</font>!;

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $custbatch = time2str('webimport-%Y/%m/%d-%T'. "-$$-". rand() * 2**32, time);

</%init>