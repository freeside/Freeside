package FS::svc_dsl;

use strict;
use vars qw( @ISA $conf $DEBUG $me );
use FS::Record qw( qsearch qsearchs );
use FS::svc_Common;

@ISA = qw( FS::svc_Common );
$DEBUG = 0;
$me = '[FS::svc_dsl]';

FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
}
);

=head1 NAME

FS::svc_dsl - Object methods for svc_dsl records

=head1 SYNOPSIS

  use FS::svc_dsl;

  $record = new FS::svc_dsl \%hash;
  $record = new FS::svc_dsl { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;
  
  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_dsl object represents a DSL service.  FS::svc_dsl inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum

Primary key (assigned automatcially for new DSL))

=item pushed

Time the DSL order was pushed to a vendor, if exporting orders to a vendor/telco

=item desired_dd

Desired Due Date

=item dd

Due Date (e.g. once order is in Assigned status or similar by the telco)

=item vendor_order_id

Vendor/telco DSL order #

=item vendor_order_type

Vendor/telco DSL order type (e.g. (M)ove, (A)dd, (C)hange, (D)elete, or similar)

=item vendor_order_status

Vendor/telco DSL order status (e.g. (N)ew, (A)ssigned, (R)ejected, (M)revised,
(C)ompleted, (X)cancelled, or similar)

=item first

End-user first name

=item last

End-user last name

=item company

End-user company name

=item svctn

DSL Telephone Number

=item loop_type

Loop-type - vendor/telco-specific

=item lvp

Local Voice Provider's name

=item cktnum

Circuit #

=item rate_band

Rate Band

=item isp_chg

=item isp_prev

=item staticips

=item vendor_qual_id

Ikano-specific fields, do not use otherwise

=item username

If outsourced PPPoE/RADIUS, username

=item password

If outsourced PPPoE/RADIUS, password

=item monitored

Order is monitored (auto-pull/sync), either Y or blank

=item last_pull

Time of last data pull from vendor/telco

=item notes

DSL order notes placed by staff or vendor/telco on the vendor/telco order


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new DSL.  To add the DSL to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table_info {
    my %dis1 = ( disable_default=>1, disable_fixed=>1, disable_inventory=>1, disable_select=>1 );
    my %dis2 = ( disable_inventory=>1, disable_select=>1 );

    {
	'name' => 'DSL',
	'sorts' => [ 'svctn' ],
	'display_weight' => 55,
	'cancel_weight' => 75,
	'fields' => {
	    'pushed' => { 	label => 'Pushed', 
				type => 'disabled' },
	    'desired_dd' => { 	label => 'Desired Due Date', %dis2, },
	    'dd' => { 		label => 'Due Date', %dis2, },
	    'vendor_order_id' => { label => 'Vendor Order Id', %dis2, },
	    'vendor_qual_id' => { label => 'Vendor Qualification Id', 
				type => 'disabled' },
	    'vendor_order_type' => { label => 'Vendor Order Type',
				    disable_inventory => 1,
				},
	    'vendor_order_status' => { label => 'Vendor Order Status',
				    disable_inventory => 1,
				    },
	    'first' => { 	label => 'First Name', %dis2, },
	    'last' => {  	label => 'Last Name', %dis2, },
	    'company' => {	label => 'Company Name', %dis2, },
	    'svctn' => {	label => 'Service Telephone Number', },
	    'loop_type' => {	label => 'Loop Type',
				    disable_inventory => 1,
			},
	    'lvp' => {		label => 'Local Voice Provider',
				    disable_inventory => 1,
			},
	    'cktnum' => {	label => 'Circuit #',	},
	    'rate_band' => {	label => 'Rate Band',
				    disable_inventory => 1,
			},
	    'isp_chg' => {	label => 'ISP Changing?', 
				type => 'checkbox', %dis2 },
	    'isp_prev' => {	label => 'Current or Previous ISP',
				    disable_inventory => 1,
			},
	    'username' => {	label => 'PPPoE Username',
				type => 'text',
			},
	    'password' => {	label => 'PPPoE Password', %dis2 },
	    'staticips' => { 	label => 'Static IPs', %dis1 },
	    'monitored' => {	label => 'Monitored', 
				type => 'checkbox', %dis2 },
	    'last_pull' => { 	label => 'Last Pull', type => 'disabled' },
	    'notes' => { 	label => 'Order Notes', %dis1 },
	},
    };
}

sub table { 'svc_dsl'; }

sub label {
   my $self = shift;
   return $self->svctn if $self->svctn;
   return $self->username if $self->username;
   return $self->vendor_order_id if $self->vendor_order_id;
   return $self->svcnum;
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid DSL.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('pushed')
    || $self->ut_number('desired_dd')
    || $self->ut_numbern('dd')
    || $self->ut_textn('vendor_order_id')
    || $self->ut_textn('vendor_qual_id')
    || $self->ut_alpha('vendor_order_type')
    || $self->ut_alphan('vendor_order_status')
    || $self->ut_text('first')
    || $self->ut_text('last')
    || $self->ut_textn('company')
    || $self->ut_numbern('svctn')
    || $self->ut_alphasn('loop_type')
    || $self->ut_textn('lvp')
    || $self->ut_textn('cktnum')
    || $self->ut_textn('rate_band')
    || $self->ut_alphan('isp_chg')
    || $self->ut_textn('isp_prev')
    || $self->ut_textn('username')
    || $self->ut_textn('password')
    || $self->ut_textn('staticips')
    || $self->ut_enum('monitored',    [ '', 'Y' ])
    || $self->ut_numbern('last_pull')
    || $self->ut_textn('notes')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

This doesn't do anything yet.

=head1 SEE ALSO

L<FS::svc_Common>, edit/part_svc.cgi from an installed web interface,
export.html from the base documentation, L<FS::Record>, L<FS::Conf>,
L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>, L<FS::queue>,
L<freeside-queued>, schema.html from the base documentation.

=cut

1;

