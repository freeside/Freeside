<% include( 'elements/browse.html',
     'title'          => "Tax Products $title",
     'name_singular'  => 'tax product',
     'menubar'        => \@menubar,
     'html_init'      => $html_init,
     'query'          => {
                           'table'     => 'part_pkg_taxproduct',
                           'hashref'   => $hashref,
                           'order_by'  => 'ORDER BY description',
                           'extra_sql' => $extra_sql,
                         },
     'count_query'    => $count_query,
     'header'         => \@header,
     'fields'         => \@fields,
     'align'          => $align,
     'links'          => \@links,
     'link_onclicks'  => \@link_onclicks,
  )
%>
<%once>

my $conf = new FS::Conf;

my $select_link = [ 'javascript:void(0);', sub { ''; } ];

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my @menubar;
my $title = '';
my $onclick = 'cClick';

my $data_vendor = '';
if ( $cgi->param('data_vendor') =~ /^(\w+)$/ ) {
  $data_vendor = $1;
  $title = "$data_vendor";
}
$cgi->delete('data_vendor');

$title = " for $title" if $title;

my $taxproductnum = $1
  if ( $cgi->param('taxproductnum') =~ /^(\d+)$/ );
my $tax_group = $1
  if ( $cgi->param('tax_group') =~ /^([- \w\(\).\/]+)$/ );
my $tax_item = $1
  if ( $cgi->param('tax_item') =~ /^([- \w\(\).\/&%]+)$/ );
my $tax_provider = $1
  if ( $cgi->param('tax_provider') =~ /^([ \w]+)$/ );
my $tax_customer = $1
  if ( $cgi->param('tax_customer') =~ /^([ \w]+)$/ );
my $id = $1
  if ( $cgi->param('id') =~ /^([ \w]+)$/ );

$onclick = $1
  if ( $cgi->param('onclick') =~ /^(\w+)$/ );
$cgi->delete('onclick');

my $remove_onclick = <<EOS
  parent.document.getElementById('$id').value = '';
  parent.document.getElementById('${id}_description').value = '';
  parent.$onclick();
EOS
  if $id;

my $select_onclick = sub {
  my $row = shift;
  my $taxnum = $row->taxproductnum;
  my $desc = $row->description;
  "parent.document.getElementById('$id').value = $taxnum;".
  "parent.document.getElementById('${id}_description').value = '$desc';".
  "parent.$onclick();";
}
  if $id;

my $selected_part_pkg_taxproduct;
if ($taxproductnum) {
  $selected_part_pkg_taxproduct =
    qsearchs('part_pkg_taxproduct', { 'taxproductnum' => $taxproductnum });
}

my $hashref = {};
my $extra_sql = '';
if ( $data_vendor ) {
  $extra_sql .= ' WHERE data_vendor = '. dbh->quote($data_vendor);
}

if ($tax_group || $tax_item || $tax_customer || $tax_provider) {
  my $compare = "LIKE '". ( $tax_group || "%" ). " : ". ( $tax_item || "%" ). " : ".
                ( $tax_provider || "%" ). " : ". ( $tax_customer || "%" ). "'";
  $compare = "= '$tax_group:$tax_item:$tax_provider:$tax_customer'"
    if ($tax_group && $tax_item && $tax_provider && $tax_customer);

  $extra_sql .= ($extra_sql =~ /WHERE/ ? ' AND ' : ' WHERE ').
                "description $compare";

}
$cgi->delete('tax_group');
$cgi->delete('tax_item');
$cgi->delete('tax_provider');
$cgi->delete('tax_customer');


if ( $tax_group || $tax_item || $tax_provider || $tax_customer ) {
  push @menubar, 'View all tax products' => $p.'browse/part_pkg_taxproduct.cgi';
}

$cgi->param('dummy', 1);

#restore this so pagination works
$cgi->param('data_vendor',  $data_vendor) if $data_vendor;
$cgi->param('tax_group',  $tax_group) if $tax_group;
$cgi->param('tax_item', $tax_item ) if $tax_item;
$cgi->param('tax_provider', $tax_provider ) if $tax_provider;
$cgi->param('tax_customer', $tax_customer ) if $tax_customer;
$cgi->param('onclick', $onclick ) if $onclick;

my $count_query = "SELECT COUNT(*) FROM part_pkg_taxproduct $extra_sql";

my @header        = ( 'Data Vendor', 'Group', 'Item', 'Provider', 'Customer' );
my @links         = ( $select_link,
                      $select_link,
                      $select_link,
                      $select_link,
                      $select_link,
                    );
my @link_onclicks = ( $select_onclick,
                      $select_onclick,
                      $select_onclick,
                      $select_onclick,
                      $select_onclick,
                    );
my $align = 'lllll';

my @fields = (
  'data_vendor',
  sub { shift->description =~ /^(.*):.*:.*:.*$/; $1;},
  sub { shift->description =~ /^.*:(.*):.*:.*$/; $1;},
  sub { shift->description =~ /^.*:.*:(.*):.*$/; $1;},
  sub { shift->description =~ /^.*:.*:.*:(.*)$/; $1;},
);

my $html_init = '';

my $select_link = [ 'javascript:void(0);', sub { ''; } ];
$html_init = '<TABLE><TR><TD><A HREF="javascript:void(0)" '.
                qq!onClick="$remove_onclick">(remove)</A>&nbsp;!.
                'Current tax product: </TD><TD>'.
                $selected_part_pkg_taxproduct->description.
                '</TD></TR></TABLE><BR><BR>'
  if $selected_part_pkg_taxproduct;

my $type = $cgi->param('_type');
$html_init .= qq(
  <FORM>
    <INPUT NAME="_type" TYPE="hidden" VALUE="$type">
    <INPUT NAME="taxproductnum" TYPE="hidden" VALUE="$taxproductnum">
    <INPUT NAME="onclick" TYPE="hidden" VALUE="$onclick">
    <INPUT NAME="id" TYPE="hidden" VALUE="$id">
    <TABLE>
      <TR>
        <TD><SELECT NAME="data_vendor" onChange="this.form.submit()">
);

my $sql = "SELECT DISTINCT data_vendor FROM part_pkg_taxproduct ORDER BY data_vendor";
my $dbh = dbh;
my $sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (['(choose data vendor)'], @{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                ($_->[0] eq $data_vendor ? " SELECTED" : "").
                '">'.  $_->[0];
}
$html_init .= qq(
        </SELECT>

<!-- cch specific -->
        <TD><SELECT NAME="tax_group" onChange="this.form.submit()">
);

$sql = "SELECT DISTINCT ".
       qq!substring(description from '#"%#" : % : % : %' for '#'),!.
       qq!substring(description from '#"%#" : % : % : %' for '#')!.
       "FROM part_pkg_taxproduct ORDER BY 1";

$sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (['', '(choose group)'], @{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                 ($_->[0] eq $tax_group ? " SELECTED" : "").
                 '">'. $_->[1];
}

$html_init .= qq(
        </SELECT>

        <TD><SELECT NAME="tax_item" onChange="this.form.submit()">
);

$sql = "SELECT DISTINCT ".
       qq!substring(description from '% : #"%#" : %: %' for '#'),!.
       qq!substring(description from '% : #"%#" : %: %' for '#')!.
       "FROM part_pkg_taxproduct ORDER BY 1";

$sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (@{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                 ($_->[0] eq $tax_item ? " SELECTED" : "").
                 '">'.  ($_->[0] ? $_->[1] : '(choose item)');
}

$html_init .= qq(
        </SELECT>

        <TD><SELECT NAME="tax_provider" onChange="this.form.submit()">
);

$sql = "SELECT DISTINCT ".
       qq!substring(description from '% : % : #"%#" : %' for '#'),!.
       qq!substring(description from '% : % : #"%#" : %' for '#')!.
       "FROM part_pkg_taxproduct ORDER BY 1";

$sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (@{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                 ($_->[0] eq $tax_provider ? " SELECTED" : "").
                 '">'.  ($_->[0] ? $_->[1] : '(choose provider type)');
}

$html_init .= qq(
        </SELECT>

        <TD><SELECT NAME="tax_customer" onChange="this.form.submit()">
);

$sql = "SELECT DISTINCT ".
       qq!substring(description from '% : % : % : #"%#"' for '#'),!.
       qq!substring(description from '% : % : % : #"%#"' for '#')!.
       "FROM part_pkg_taxproduct ORDER BY 1";

$sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute or die $sth->errstr;
for (@{$sth->fetchall_arrayref}) {
  $html_init .= '<OPTION VALUE="'. $_->[0]. '"'.
                 ($_->[0] eq $tax_customer ? " SELECTED" : "").
                 '">'.  ($_->[0] ? $_->[1] : '(choose customer type)');
}

$html_init .= qq(
        </SELECT>

      </TR>
    </TABLE>
  </FORM>

);

</%init>
