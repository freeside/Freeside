<% include( 'elements/search.html',
                 'title'         => 'Qualifications',
		 'name_singular' => 'qualification',
		 'query'         => { 'table'     => 'qual',
		                      'hashref'   => $hashref,
				      'extra_sql' => $extra_sql,
                                      'order_by'  => 'ORDER BY qualnum DESC',
				    },
		 'count_query'   => "$count_query $extra_sql",
		 'header'        => [ 'Qualification',
		                      'Status',
				      'Customer or Prospect',
				      'Service Telephone Number',
				      'Address',
		                      'Qualified Using',
				      'Vendor Qualification #',
                                    ],
		 'align'         => 'rcccccc',
		 'fields'        => [ 'qualnum',
				      sub {
					my $self = shift;
					$self->status_long;
				      },
				      sub {
					  my $self = shift;
					  my $cust_or_prospect = $self->cust_or_prospect;
					  return $cust_or_prospect->name 
					    if $cust_or_prospect->get('custnum');
					  return "Prospect #".$cust_or_prospect->prospectnum
					    if $cust_or_prospect->get('prospectnum');
					  '';
				      },
				      'phonenum',
				      sub {
					my $self = shift;
					my %location_hash = $self->location;
					# ugh...
					if ( %location_hash ) {
					    my $loc = new FS::cust_location(\%location_hash); 
					    return $loc->location_label;
					}
					'';
				      },
				      sub {
					  my $self = shift;
					  my $export = $self->part_export;
					  my $result = '(manual)';
					  $result = $export->exportname if $export;
					  $result;
				      },
				      'vendor_qual_id',
				    ],
		 'links'         => [
		                      [ "${p}view/qual.cgi?qualnum=", 'qualnum' ],
				      '',
				      '',
				      '',
				      '',
				      '',
				      '',
				    ],
      )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Qualify service');

my $hashref = {};
my $count_query = 'SELECT COUNT(*) FROM qual';

my $extra_sql = '';
if ( $cgi->param('custnum') && $cgi->param('custnum') =~ /^(\d+)$/ ) {
    $extra_sql = " where custnum = $1 or locationnum in "
	    . " (select locationnum from cust_location where custnum = $1)";
} elsif ( $cgi->param('prospectnum') 
	&& $cgi->param('prospectnum') =~ /^(\d+)$/ ) {
    $extra_sql = " where prospectnum = $1 or locationnum in "
	    . " (select locationnum from cust_location where prospectnum = $1)";
}

</%init>
