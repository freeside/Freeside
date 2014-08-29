package FS::svc_phone;
use base qw( FS::svc_Domain_Mixin FS::svc_PBX_Mixin 
             FS::location_Mixin
             FS::svc_Common
           );

use strict;
use vars qw( $DEBUG $me @pw_set $conf $phone_name_max
             $passwordmin $passwordmax
           );
use Data::Dumper;
use Scalar::Util qw( blessed );
use List::Util qw( min );
use Tie::IxHash;
use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh );
use FS::PagedSearch qw( psearch );
use FS::Msgcat qw(gettext);
use FS::part_svc;
use FS::svc_pbx;
use FS::svc_domain;
use FS::cust_location;
use FS::phone_avail;

$me = '[' . __PACKAGE__ . ']';
$DEBUG = 0;

#avoid l 1 and o O 0
@pw_set = ( 'a'..'k', 'm','n', 'p-z', 'A'..'N', 'P'..'Z' , '2'..'9' );

#ask FS::UID to run this stuff for us later
FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $phone_name_max = $conf->config('svc_phone-phone_name-max_length');
  $passwordmin = $conf->config('sip_passwordmin') || 0;
  $passwordmax = $conf->config('sip_passwordmax') || 80;
}
);

=head1 NAME

FS::svc_phone - Object methods for svc_phone records

=head1 SYNOPSIS

  use FS::svc_phone;

  $record = new FS::svc_phone \%hash;
  $record = new FS::svc_phone { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_phone object represents a phone number.  FS::svc_phone inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item svcnum

primary key

=item countrycode

=item phonenum

=item sim_imsi

SIM IMSI (http://en.wikipedia.org/wiki/International_mobile_subscriber_identity)

=item sip_password

=item pin

Voicemail PIN

=item phone_name

=item pbxsvc

Optional svcnum from svc_pbx

=item forwarddst

Forwarding destination

=item email

Email address for virtual fax (fax-to-email) services

=item lnp_status

LNP Status (can be null, native, portedin, portingin, portin-reject,
portingout, portout-reject)

=item portable

=item lrn

=item lnp_desired_due_date

=item lnp_due_date

=item lnp_other_provider

If porting the number in or out, name of the losing or winning provider, 
respectively.

=item lnp_other_provider_account

Account number of other provider. See lnp_other_provider.

=item lnp_reject_reason

See lnp_status. If lnp_status is portin-reject or portout-reject, this is an
optional reject reason.

=item e911_class

Class of Service for E911 service (per the NENA 2.1 standard).

=item e911_type

Type of Service for E911 service.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new phone number.  To add the number to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined
#
sub table_info {
 my %dis2 = ( disable_inventory=>1, disable_select=>1 );
  {
    'name' => 'Phone number',
    'sorts' => 'phonenum',
    'display_weight' => 60,
    'cancel_weight'  => 80,
    'fields' => {
        'svcnum'       => 'Service',
        'countrycode'  => { label => 'Country code',
                            type  => 'text',
                            disable_inventory => 1,
                            disable_select => 1,
                          },
        'phonenum'     => 'Phone number',
        'sim_imsi'     => 'IMSI', #http://en.wikipedia.org/wiki/International_mobile_subscriber_identity
        'pin'          => { label => 'Voicemail PIN', #'Personal Identification Number',
                            type  => 'text',
                            disable_inventory => 1,
                            disable_select => 1,
                          },
        'sip_password' => 'SIP password',
        'phone_name'   => 'Name',
        'pbxsvc'       => { label => 'PBX',
                            type  => 'select-svc_pbx.html',
                            disable_inventory => 1,
                            disable_select => 1, #UI wonky, pry works otherwise
                          },
        'domsvc'    => {
                         label     => 'Domain',
                         type      => 'select',
                         select_table => 'svc_domain',
                         select_key   => 'svcnum',
                         select_label => 'domain',
                         disable_inventory => 1,
                       },
        'sms_carrierid'    => { label             => 'SMS Carrier',
                                type              => 'select',
                                select_table      => 'cdr_carrier',
                                select_key        => 'carrierid',
                                select_label      => 'carriername',
                                disable_inventory => 1,
                              },
        'sms_account'      => { label => 'SMS Carrier Account', },
        'max_simultaneous' => { label=>'Maximum number of simultaneous users' },
        'locationnum' => {
                           label => 'E911 location',
                           disable_inventory => 1,
                           disable_select    => 1,
                         },
	'forwarddst' => {	label => 'Forward Destination', 
				%dis2,
			},
	'email' => {		label => 'Email',
				%dis2,
		    },
	'lnp_status' => {   	label => 'LNP Status',
				type => 'select-lnp_status.html',
				%dis2,
			},
	'lnp_reject_reason' => { 
				label => 'LNP Reject Reason',
				%dis2,
			},
	'portable' => 	{	label => 'Portable?', %dis2, },
	'lrn' 	=>	{	label => 'LRN', 
				disable_inventory => 1, 
			},
	'lnp_desired_due_date' =>
			{ label => 'LNP Desired Due Date', %dis2 },
	'lnp_due_date' =>
			{ label => 'LNP Due Date', %dis2 },
	'lnp_other_provider' =>
			{ 	label => 'LNP Other Provider', 
				disable_inventory => 1, 
			},
	'lnp_other_provider_account' =>
			{	label => 'LNP Other Provider Account #', 
				%dis2 
			},
        'e911_class' => {
                                label => 'E911 Service Class',
                                type  => 'select-e911_class',
                                disable_inventory => 1,
                                multiple => 1,
                        },
        'e911_type' => {
                                label => 'E911 Service Type',
                                type  => 'select-e911_type',
                                disable_inventory => 1,
                                multiple => 1,
                        },
    },
  };
}

sub table { 'svc_phone'; }

sub table_dupcheck_fields { ( 'countrycode', 'phonenum' ); }

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

sub search_sql {
  my( $class, $string ) = @_;

  #my $conf = new FS::Conf;

  if ( $conf->exists('svc_phone-allow_alpha_phonenum') ) {
    $string =~ s/\W//g;
  } else {
    $string =~ s/\D//g;
  }

  my $ccode = (    $conf->exists('default_phone_countrycode')
                && $conf->config('default_phone_countrycode')
              )
                ? $conf->config('default_phone_countrycode') 
                : '1';

  $string =~ s/^$ccode//;

  $class->search_sql_field('phonenum', $string );
}

=item label

Returns the phone number.

=cut

sub label {
  my $self = shift;
  my $phonenum = $self->phonenum; #XXX format it better
  my $label = $phonenum;
  $label .= '@'.$self->domain if $self->domsvc;
  $label .= ' ('.$self->phone_name.')' if $self->phone_name;
  $label;
}

=item insert

Adds this phone number to the database.  If there is an error, returns the
error, otherwise returns false.

=cut

sub insert {
  my $self = shift;
  my %options = @_;

  if ( $DEBUG ) {
    warn "[$me] insert called on $self: ". Dumper($self).
         "\nwith options: ". Dumper(%options);
  }

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #false laziness w/cust_pkg.pm... move this to location_Mixin?  that would
  #make it more of a base class than a mixin... :)
  if ( $options{'cust_location'} ) {
    my $error = $options{'cust_location'}->find_or_insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting cust_location (transaction rolled back): $error";
    }
    $self->locationnum( $options{'cust_location'}->locationnum );
  }
  #what about on-the-fly edits?  if the ui supports it?

  my $error = $self->SUPER::insert(%options);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $phone_device ( $self->phone_device ) {
    my $error = $phone_device->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my @phone_avail = qsearch('phone_avail', { 'svcnum' => $self->svcnum } );
  foreach my $phone_avail ( @phone_avail ) {
    $phone_avail->svcnum('');
    my $error = $phone_avail->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $new = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $new->replace_old;

  my %options = @_;

  if ( $DEBUG ) {
    warn "[$me] replacing $old with $new\n".
         "\nwith options: ". Dumper(%options);
  }

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #false laziness w/cust_pkg.pm... move this to location_Mixin?  that would
  #make it more of a base class than a mixin... :)
  if ( $options{'cust_location'}
         && ( ! $new->locationnum || $new->locationnum == -1 ) ) {
    my $error = $options{'cust_location'}->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting cust_location (transaction rolled back): $error";
    }
    $new->locationnum( $options{'cust_location'}->locationnum );
  }
  #what about on-the-fly edits?  if the ui supports it?

  # LNP data validation
 return 'Invalid LNP status' # if someone does really stupid stuff
    if (  ($old->lnp_status eq 'portingout' && $new->lnp_status eq 'portingin')
	|| ($old->lnp_status eq 'portout-reject' && $new->lnp_status eq 'portingin')
	|| ($old->lnp_status eq 'portin-reject' && $new->lnp_status eq 'portingout')
	|| ($old->lnp_status eq 'portingin' && $new->lnp_status eq 'native')
	|| ($old->lnp_status eq 'portin-reject' && $new->lnp_status eq 'native')
	|| ($old->lnp_status eq 'portingin' && $new->lnp_status eq 'portingout')
	|| ($old->lnp_status eq 'portingout' && $new->lnp_status eq 'portin-reject')
	);

  my $error = $new->SUPER::replace($old, %options);

  # if this changed the e911 location, notify exports
  if ($new->locationnum ne $old->locationnum) {
    my $new_location = $new->cust_location_or_main;
    my $old_location = $new->cust_location_or_main;
    $error ||= $new->export('relocate', $new_location, $old_location);
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error if $error;
  }


  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid phone number.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  #my $conf = new FS::Conf;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $phonenum = $self->phonenum;
  my $phonenum_check_method;
  if ( $conf->exists('svc_phone-allow_alpha_phonenum') ) {
    $phonenum =~ s/\W//g;
    $phonenum_check_method = 'ut_alpha';
  } else {
    $phonenum =~ s/\D//g;
    $phonenum_check_method = 'ut_number';
  }
  $self->phonenum($phonenum);

  $self->locationnum('') if !$self->locationnum || $self->locationnum == -1;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('countrycode')
    || $self->$phonenum_check_method('phonenum')
    || $self->ut_numbern('sim_imsi')
    || $self->ut_anything('sip_password')
    || $self->ut_numbern('pin')
    || $self->ut_textn('phone_name')
    || $self->ut_foreign_keyn('pbxsvc', 'svc_pbx',    'svcnum' )
    || $self->ut_foreign_keyn('domsvc', 'svc_domain', 'svcnum' )
    || $self->ut_foreign_keyn('sms_carrierid', 'cdr_carrier', 'carrierid' )
    || $self->ut_alphan('sms_account')
    || $self->ut_numbern('max_simultaneous')
    || $self->ut_foreign_keyn('locationnum', 'cust_location', 'locationnum')
    || $self->ut_numbern('forwarddst')
    || $self->ut_textn('email')
    || $self->ut_numbern('lrn')
    || $self->ut_numbern('lnp_desired_due_date')
    || $self->ut_numbern('lnp_due_date')
    || $self->ut_textn('lnp_other_provider')
    || $self->ut_textn('lnp_other_provider_account')
    || $self->ut_enumn('lnp_status', ['','portingin','portingout','portedin',
				'native', 'portin-reject', 'portout-reject'])
    || $self->ut_enumn('portable', ['','Y'])
    || $self->ut_textn('lnp_reject_reason')
  ;
  return $error if $error;

  return 'Illegal IMSI (not 14-15 digits)' #shorter?
    if length($self->sim_imsi)
    && ( length($self->sim_imsi) < 14 || length($self->sim_imsi) > 15 );

    # LNP data validation
    return 'Cannot set LNP fields: no LNP in progress'
	if ( ($self->lnp_desired_due_date || $self->lnp_due_date 
	    || $self->lnp_other_provider || $self->lnp_other_provider_account
	    || $self->lnp_reject_reason) 
	    && (!$self->lnp_status || $self->lnp_status eq 'native') );
    return 'Cannot set LNP reject reason: no LNP in progress or status is not reject'
	if ($self->lnp_reject_reason && (!$self->lnp_status 
			    || $self->lnp_status !~ /^port(in|out)-reject$/) );
    return 'Cannot port-out a non-portable number' 
	if (!$self->portable && $self->lnp_status eq 'portingout');


  return 'Name ('. $self->phone_name.
         ") is longer than $phone_name_max characters"
    if $phone_name_max && length($self->phone_name) > $phone_name_max;

  $self->countrycode(1) unless $self->countrycode;

  unless ( length($self->pin) ) {
    my $random_pin = $conf->config('svc_phone-random_pin');
    if ( defined($random_pin) && $random_pin =~ /^\d+$/ ) {
      $self->pin(
        join('', map int(rand(10)), 0..($random_pin-1))
      );
    }
  }

  if ( length($self->sip_password) ) {

    return "SIP password must be longer than $passwordmin characters"
      if length($self->sip_password) < $passwordmin;
    return "SIP password must be shorter than $passwordmax characters"
      if length($self->sip_password) > $passwordmax;

  } elsif ( $part_svc->part_svc_column('sip_password')->columnflag ne 'F' ) {

    # option for this?
    $self->sip_password(
      join('', map $pw_set[ int(rand $#pw_set) ], (1..min($passwordmax,16)) )
    );

  }

  if ($self->e911_class and !exists(e911_classes()->{$self->e911_class})) {
    return "undefined e911 class '".$self->e911_class."'";
  }
  if ($self->e911_type and !exists(e911_types()->{$self->e911_type})) {
    return "undefined e911 type '".$self->e911_type."'";
  }

  $self->SUPER::check;
}

=item _check duplicate

Internal method to check for duplicate phone numers.

=cut

#false laziness w/svc_acct.pm's _check_duplicate.
sub _check_duplicate {
  my $self = shift;

  my $global_unique = $conf->config('global_unique-phonenum') || 'none';
  return '' if $global_unique eq 'disabled';

  $self->lock_table;

  my @dup_ccphonenum =
    grep { !$self->svcnum || $_->svcnum != $self->svcnum }
    qsearch( 'svc_phone', {
      'countrycode' => $self->countrycode,
      'phonenum'    => $self->phonenum,
    });

  return gettext('phonenum_in_use')
    if $global_unique eq 'countrycode+phonenum' && @dup_ccphonenum;

  my $part_svc = qsearchs('part_svc', { 'svcpart' => $self->svcpart } );
  unless ( $part_svc ) {
    return 'unknown svcpart '. $self->svcpart;
  }

  if ( @dup_ccphonenum ) {

    my $exports = FS::part_export::export_info('svc_phone');
    my %conflict_ccphonenum_svcpart = ( $self->svcpart => 'SELF', );

    foreach my $part_export ( $part_svc->part_export ) {

      #this will catch to the same exact export
      my @svcparts = map { $_->svcpart } $part_export->export_svc;

      $conflict_ccphonenum_svcpart{$_} = $part_export->exportnum
        foreach @svcparts;

    }

    foreach my $dup_ccphonenum ( @dup_ccphonenum ) {
      my $dup_svcpart = $dup_ccphonenum->cust_svc->svcpart;
      if ( exists($conflict_ccphonenum_svcpart{$dup_svcpart}) ) {
        return "duplicate phone number ".
               $self->countrycode. ' '. $self->phonenum.
               ": conflicts with svcnum ". $dup_ccphonenum->svcnum.
               " via exportnum ". $conflict_ccphonenum_svcpart{$dup_svcpart};
      }
    }

  }

  return '';

}

=item check_pin

Checks the supplied PIN against the PIN in the database.  Returns true for a
sucessful authentication, false if no match.

=cut

sub check_pin {
  my($self, $check_pin) = @_;
  length($self->pin) && $check_pin eq $self->pin;
}

=item radius_reply

=cut

sub radius_reply {
  my $self = shift;
  #XXX Session-Timeout!  holy shit, need rlm_perl to ask for this in realtime
  ();
}

=item radius_check

=cut

sub radius_check {
  my $self = shift;
  my %check = ();

  #my $conf = new FS::Conf;

  my $password;
  if ( $conf->config('svc_phone-radius-password') eq 'countrycode_phonenum' ) {
    $password = $self->countrycode. $self->phonenum;
  } else {
    $password = $conf->config('svc_phone-radius-default_password');
  }
  $check{'User-Password'} = $password;

  %check;
}

sub radius_groups {
  ();
}

=item sms_cdr_carrier

=cut

sub sms_cdr_carrier {
  my $self = shift;
  return '' unless $self->sms_carrierid;
  qsearchs('cdr_carrier',  { 'carrierid' => $self->sms_carrierid } );
}

=item sms_carriername

=cut

sub sms_carriername {
  my $self = shift;
  my $cdr_carrier = $self->sms_cdr_carrier or return '';
  $cdr_carrier->carriername;
}

=item phone_device

Returns any FS::phone_device records associated with this service.

=cut

#override location_Mixin version cause we want to try the cust_pkg location
#in between us and cust_main
# XXX what to do in the unlinked case???  return a pseudo-object that returns
# empty fields?
sub cust_location_or_main {
  my $self = shift;
  return $self->cust_location if $self->locationnum;
  my $cust_pkg = $self->cust_svc->cust_pkg;
  $cust_pkg ? $cust_pkg->cust_location_or_main : '';
}

=item phone_name_or_cust

Returns the C<phone_name> field if it has a value, or the package contact
name if there is one, or the customer contact name.

=cut

sub phone_name_or_cust {
  my $self = shift;
  if ( $self->phone_name ) {
    return $self->phone_name;
  }
  my $cust_pkg = $self->cust_svc->cust_pkg or return '';
  if ( $cust_pkg->contactnum ) {
    return $cust_pkg->contact->firstlast;
  } else {
    return $cust_pkg->cust_main->name_short;
  }
}

=item psearch_cdrs OPTIONS

Returns a paged search (L<FS::PagedSearch>) for Call Detail Records 
associated with this service.  By default, "associated with" means that 
either the "src" or the "charged_party" field of the CDR matches the 
"phonenum" field of the service.  To access the CDRs themselves, call
"->fetch" on the resulting object.

=over 2

Accepts the following options:

=item for_update => 1: SELECT the CDRs "FOR UPDATE".

=item status => "" (or "processing-tiered", "done"): Return only CDRs with that processing status.

=item inbound => 1: Return CDRs for inbound calls (that is, those that match
on 'dst').  With "status", will filter on inbound processing status.

=item default_prefix => "XXX": Also accept the phone number of the service prepended 
with the chosen prefix.

=item begin, end: Start and end of a date range, as unix timestamp.

=item cdrtypenum: Only return CDRs with this type.

=item calltypenum: Only return CDRs with this call type.

=item disable_src => 1: Only match on 'charged_party', not 'src'.

=item disable_charged_party => 1: Only match on 'src', not 'charged_party'.

=item nonzero: Only return CDRs where duration > 0.

=item by_svcnum: not supported for svc_phone

=item billsec_sum: Instead of returning all of the CDRs, return a single
record (as an L<FS::cdr> object) with the sum of the 'billsec' field over 
the entire result set.

=back

=cut

sub psearch_cdrs {

  my($self, %options) = @_;
  my @fields;
  my %hash;
  my @where;

  if ( $options{'inbound'} ) {

    @fields = ( 'dst' );
    if ( exists($options{'status'}) ) {
      my $status = $options{'status'};
      if ( $status ) {
        push @where, 'EXISTS ( SELECT 1 FROM cdr_termination '.
          'WHERE cdr.acctid = cdr_termination.acctid '.
          "AND cdr_termination.status = '$status' ". #quoting kludge
          'AND cdr_termination.termpart = 1 )';
      } else {
        push @where, 'NOT EXISTS ( SELECT 1 FROM cdr_termination '.
          'WHERE cdr.acctid = cdr_termination.acctid '.
          'AND cdr_termination.termpart = 1 )';
      }
    }

  } else {

    push @fields, 'charged_party' unless $options{'disable_charged_party'};
    push @fields, 'src' unless $options{'disable_src'};
    $hash{'freesidestatus'} = $options{'status'}
      if exists($options{'status'});
  }

  if ($options{'cdrtypenum'}) {
    $hash{'cdrtypenum'} = $options{'cdrtypenum'};
  }
  if ($options{'calltypenum'}) {
    $hash{'calltypenum'} = $options{'calltypenum'};
  }
  
  my $for_update = $options{'for_update'} ? 'FOR UPDATE' : '';

  my $number = $self->phonenum;

  my $prefix = $options{'default_prefix'};

  my @orwhere =  map " $_ = '$number'        ", @fields;
  push @orwhere, map " $_ = '$prefix$number' ", @fields
    if defined($prefix) && length($prefix);
  if ( $prefix && $prefix =~ /^\+(\d+)$/ ) {
    push @orwhere, map " $_ = '$1$number' ", @fields
  }

  push @where, ' ( '. join(' OR ', @orwhere ). ' ) ';

  if ( $options{'begin'} ) {
    push @where, 'startdate >= '. $options{'begin'};
  }
  if ( $options{'end'} ) {
    push @where, 'startdate < '.  $options{'end'};
  }
  if ( $options{'nonzero'} ) {
    push @where, 'duration > 0';
  }

  my $extra_sql = ( keys(%hash) ? ' AND ' : ' WHERE ' ). join(' AND ', @where );

  psearch( {
      'table'      => 'cdr',
      'hashref'    => \%hash,
      'extra_sql'  => $extra_sql,
      'order_by'   => $options{'billsec_sum'} ? '' : "ORDER BY startdate $for_update",
      'select'     => $options{'billsec_sum'} ? 'sum(billsec) as billsec_sum' : '*',
  } );
}

=item get_cdrs (DEPRECATED)

Like psearch_cdrs, but returns all the L<FS::cdr> objects at once, in a 
single list.  Arguments are the same as for psearch_cdrs.  This can take 
an unreasonably large amount of memory and is best avoided.

=cut

sub get_cdrs {
  my $self = shift;
  my $psearch = $self->psearch_cdrs(@_);
  qsearch ( $psearch->{query} )
}

=item sum_cdrs

Takes the same options as psearch_cdrs, but returns a single row containing
"count" (the number of CDRs) and the sums of the following fields: duration,
billsec, rated_price, rated_seconds, rated_minutes.

Note that if any calls are not rated, their rated_* fields will be null.
If you want to use those fields, pass the 'status' option to limit to 
calls that have been rated.  This is intentional; please don't "fix" it.

=cut

sub sum_cdrs {
  my $self = shift;
  my $psearch = $self->psearch_cdrs(@_);
  $psearch->{query}->{'select'} = join(',',
    'COUNT(*) AS count',
    map { "SUM($_) AS $_" }
      qw(duration billsec rated_price rated_seconds rated_minutes)
  );
  # hack
  $psearch->{query}->{'extra_sql'} =~ s/ ORDER BY.*$//;
  qsearchs ( $psearch->{query} );
}

=back

=head1 CLASS METHODS

=over 4

=item e911_classes

Returns a hashref of allowed values and descriptions for the C<e911_class>
field.

=item e911_types

Returns a hashref of allowed values and descriptions for the C<e911_type>
field.

=cut

sub e911_classes {
  tie my %x, 'Tie::IxHash', (
    1 => 'Residence',
    2 => 'Business',
    3 => 'Residence PBX',
    4 => 'Business PBX',
    5 => 'Centrex',
    6 => 'Coin 1 Way out',
    7 => 'Coin 2 Way',
    8 => 'Mobile',
    9 => 'Residence OPX',
    0 => 'Business OPX',
    A => 'Customer Operated Coin Telephone',
    #B => not available
    G => 'Wireless Phase I',
    H => 'Wireless Phase II',
    I => 'Wireless Phase II with Phase I information',
    V => 'VoIP Services Default',
    C => 'VoIP Residence',
    D => 'VoIP Business',
    E => 'VoIP Coin/Pay Phone',
    F => 'VoIP Wireless',
    J => 'VoIP Nomadic',
    K => 'VoIP Enterprise Services',
    T => 'Telematics',
  );
  \%x;
}

sub e911_types {
  tie my %x, 'Tie::IxHash', (
    0 => 'Not FX nor Non-Published',
    1 => 'FX in 911 serving area',
    2 => 'FX outside 911 serving area',
    3 => 'Non-Published',
    4 => 'Non-Published FX in serving area',
    5 => 'Non-Published FX outside serving area',
    6 => 'Local Ported Number',
    7 => 'Interim Ported Number',
  );
  \%x;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

