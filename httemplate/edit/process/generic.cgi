%if($error) {
%  $cgi->param('error', $error);
<% $cgi->redirect($redirect_error . '?' . $cgi->query_string) %>
%} else {
<% $cgi->redirect($redirect_ok) %>
%}
<%doc>

See elements/process.html, newer and somewhat along the same lines,
though it still makes you setup a process file for the table.
Perhaps safer, perhaps more of a pain in the ass.

In any case, this is probably pretty deprecated; it is only used by
part_virtual_field.cgi, and so its ACL is hardcoded to 'Configuration'.

Welcome to generic.cgi.

This script provides a generic edit/process/ backend for simple table 
editing.  All it knows how to do is take the values entered into 
the script and insert them into the table specified by $cgi->param('table').
If there's an existing record with the same primary key, it will be 
replaced.  (Deletion will be added in the future.)

Special cgi params for this script:
table: the name of the table to be edited.  The script will die horribly 
       if it can't find the table.
redirect_ok: URL to be displayed after a successful edit.  The value of 
             the record's primary key will be passed as a keyword.
             Defaults to (freeside root)/view/$table.cgi.
redirect_error: URL to be displayed if there's an error.  The original 
                query string, plus the error message, will be passed.
                Defaults to $cgi->referer() (i.e. go back where you 
                came from).

</%doc>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $error;
my $p2 = popurl(2);
my $p3 = popurl(3);
my $table = $cgi->param('table');
my $dbdef = dbdef or die "Cannot fetch dbdef!";

my $dbdef_table = $dbdef->table($table) or die "Cannot fetch schema for $table";

my $pkey = $dbdef_table->primary_key or die "Cannot fetch pkey for $table";
my $pkey_val = $cgi->param($pkey);


#warn "new FS::Record ( $table, (hashref) )";
my $new = FS::Record::new ( "FS::$table", {
    map { $_, scalar($cgi->param($_)) } fields($table) 
} );

#warn 'created $new of class '.ref($new);

if($pkey_val and (my $old = qsearchs($table, { $pkey, $pkey_val} ))) {
  # edit
  $error = $new->replace($old);
} else {
  #add
  $error = $new->insert;
  $pkey_val = $new->getfield($pkey);
  # New records usually don't have their primary keys set until after 
  # they've been checked/inserted, so grab the new $pkey_val so we can 
  # redirect to it.
}

my $redirect_ok = (($cgi->param('redirect_ok')) ?
                    $cgi->param('redirect_ok') : $p3."browse/generic.cgi?$table");
my $redirect_error = (($cgi->param('redirect_error')) ?
                       $cgi->param('redirect_error') : $cgi->referer());

</%init>
