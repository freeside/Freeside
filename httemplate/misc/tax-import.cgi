<& /elements/header.html,'Batch Tax Rate Import' &>

Import a CSV file set containing tax rate records.
<BR><BR>

<& /elements/form-file_upload.html,
     'name'      => 'TaxRateUpload',
     'action'    => 'process/tax-import.cgi', 
     'fields'    => [ 'format', 'reload' ],
     'num_files' => $vendor_info{$data_vendor}->{num_files},
     'message'   => 'Tax rates imported',
     'onsubmit'  => "document.TaxRateUpload.submitButton.disabled=true;",
&>

<& /elements/table-grid.html &>

  <TR>
    <TH ALIGN="right">Format</TH>
    <TD>
      <SELECT NAME="format">
% my @formats = @{ $vendor_info{$data_vendor}->{formats} };
% while (@formats) {
        <OPTION VALUE="<% shift @formats %>"><% shift @formats %></OPTION>
% }
      </SELECT>
    </TD>
  </TR>

  <TR>
    <TH ALIGN="right">Replace existing data from this vendor</TH>
    <TD>
      <INPUT NAME="reload" TYPE="checkbox" VALUE="1" CHECKED>
    </TD>
  </TR>

  <& /elements/file-upload.html,
                'field' => $vendor_info{$data_vendor}->{field},
                'label' => $vendor_info{$data_vendor}->{label},
                'debug'    => 0,
  &>

  <TR>
    <TD COLSPAN=2 ALIGN="center" STYLE="padding-top:6px">
      <INPUT TYPE  = "submit"
             NAME  = "submitButton"
             ID    = "submitButton"
             VALUE = "Import CSV files"
      >
    </TD>
  </TR>

</TABLE>

</FORM>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $conf = FS::Conf->new;
my $data_vendor = $conf->config('tax_data_vendor');

my %vendor_info = (
  cch => {
    'num_files' => 6,
    'formats' => [ 'cch'        => 'CCH import (CSV)',
                   'cch-fixed'  => 'CCH import (fixed length)' ],
    'field'   => [ 'geocodefile',
                   'codefile',
                   'plus4file',
                   'zipfile',
                   'txmatrixfile',
                   'detailfile',
                 ],
    'label'   => [ 'geocode filename',
                   'code filename',
                   'plus4 filename',
                   'zip filename',
                   'txmatrix filename',
                   'detail filename',
                 ],
  },
  billsoft => {
    'num_files' => 1,
    'formats' => [ 'billsoft-pcode' => 'Billsoft PCodes',
                   'billsoft-taxclass' => 'Tax classes',
                   'billsoft-taxproduct' => 'Tax products' ],
    'field'   => [ 'file' ],
    'label'   => [ 'Filename' ],
  },
);
    
</%init>
