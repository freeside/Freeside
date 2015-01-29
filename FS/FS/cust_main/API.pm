package FS::cust_main::API;

use strict;
use FS::Conf;
use FS::part_tag;
use FS::Record qw( qsearchs );

=item API_getinfo FIELD => VALUE, ...

=cut

#some false laziness w/ClientAPI::Myaccount customer_info/customer_info_short

use vars qw(
  @cust_main_addl_fields @cust_main_editable_fields @location_editable_fields
);
@cust_main_addl_fields = qw(
  agentnum salesnum refnum classnum usernum referral_custnum
);
@cust_main_editable_fields = qw(
  first last company daytime night fax mobile
);
#  locale
#  payby payinfo payname paystart_month paystart_year payissue payip
#  ss paytype paystate stateid stateid_state
@location_editable_fields = qw(
  address1 address2 city county state zip country
);

sub API_getinfo {
  my( $self, %opt ) = @_;

  my %return = (
    'error'           => '',
    'display_custnum' => $self->display_custnum,
    'name'            => $self->first. ' '. $self->get('last'),
    'balance'         => $self->balance,
    'status'          => $self->status,
    'statuscolor'     => $self->statuscolor,
  );

  $return{$_} = $self->get($_)
    foreach @cust_main_editable_fields;

  unless ( $opt{'selfservice'} ) {
    $return{$_} = $self->get($_)
      foreach @cust_main_addl_fields;
  }

  for (@location_editable_fields) {
    $return{$_} = $self->bill_location->get($_)
      if $self->bill_locationnum;
    $return{'ship_'.$_} = $self->ship_location->get($_)
      if $self->ship_locationnum;
  }

  my @invoicing_list = $self->invoicing_list;
  $return{'invoicing_list'} =
    join(', ', grep { $_ !~ /^(POST|FAX)$/ } @invoicing_list );
  $return{'postal_invoicing'} =
    0 < ( grep { $_ eq 'POST' } @invoicing_list );

  #generally, the more useful data from the cust_main record the better.
  # well, tell me what you want

  return \%return;

}


#or maybe all docs go in FS::API ?  argh

=item API_insert

Class method (constructor).

Example:

  use FS::cust_main;
  FS::cust_main->API_insert(
    'agentnum' => 1,
    'refnum'   => 1,
    'first'    => 'Harvey',
    'last'     => 'Black',
    'address1' => '5354 Pink Rabbit Lane',
    'city'     => 'Farscape',
    'state'    => 'CA',
    'zip'      => '54144',

    'invoicing_list' => 'harvey2@example.com',
  );

=cut

#certainly false laziness w/ClientAPI::Signup new_customer/new_customer_minimal
# but approaching this from a clean start / back-office perspective
#  i.e. no package/service, no immediate credit card run, etc.

sub API_insert {
  my( $class, %opt ) = @_;

  my $conf = new FS::Conf;

  #default agentnum like signup_server-default_agentnum?
 
  #same for refnum like signup_server-default_refnum?

  my $cust_main = new FS::cust_main ( { # $class->new( {
      'payby'  => 'BILL',
      'tagnum' => [ FS::part_tag->default_tags ],

      map { $_ => $opt{$_} } qw(
        agentnum salesnum refnum agent_custid referral_custnum
        last first company 
        daytime night fax mobile
        payby payinfo paydate paycvv payname
      ),

  } );

  my @invoicing_list = $opt{'invoicing_list'}
                         ? split( /\s*\,\s*/, $opt{'invoicing_list'} )
                         : ();
  push @invoicing_list, 'POST' if $opt{'postal_invoicing'};

  my ($bill_hash, $ship_hash);
  foreach my $f (FS::cust_main->location_fields) {
    # avoid having to change this in front-end code
    $bill_hash->{$f} = $opt{"bill_$f"} || $opt{$f};
    $ship_hash->{$f} = $opt{"ship_$f"};
  }

  my $bill_location = FS::cust_location->new($bill_hash);
  my $ship_location;
  # we don't have an equivalent of the "same" checkbox in selfservice^Wthis API
  # so is there a ship address, and if so, is it different from the billing 
  # address?
  if ( length($ship_hash->{address1}) > 0 and
          grep { $bill_hash->{$_} ne $ship_hash->{$_} } keys(%$ship_hash)
         ) {

    $ship_location = FS::cust_location->new( $ship_hash );
  
  } else {
    $ship_location = $bill_location;
  }

  $cust_main->set('bill_location' => $bill_location);
  $cust_main->set('ship_location' => $ship_location);

  my $error = $cust_main->insert( {}, \@invoicing_list );
  return { 'error'   => $error } if $error;
  
  return { 'error'   => '',
           'custnum' => $cust_main->custnum,
         };

}

sub API_update {

  my( $class, %opt ) = @_;

  my $conf = new FS::Conf;


  my $custnum = $opt{'custnum'}
    or return { 'error' => "no customer record" };

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my $new = new FS::cust_main { $cust_main->hash };

  $new->set( $_ => $opt{$_} )
    foreach grep { exists $opt{$_} } qw(
        agentnum salesnum refnum agent_custid referral_custnum
        last first company
        daytime night fax mobile
        payby payinfo paydate paycvv payname
      ),

  
  my @invoicing_list = $opt{'invoicing_list'}
                         ? split( /\s*\,\s*/, $opt{'invoicing_list'} )
                         : ();
  push @invoicing_list, 'POST' if $opt{'postal_invoicing'};

  my ($bill_hash, $ship_hash);
  foreach my $f (FS::cust_main->location_fields) {
    # avoid having to change this in front-end code
    $bill_hash->{$f} = $opt{"bill_$f"} || $opt{$f};
    $ship_hash->{$f} = $opt{"ship_$f"};
  }

  my $bill_location = FS::cust_location->new($bill_hash);
  my $ship_location;
  # we don't have an equivalent of the "same" checkbox in selfservice^Wthis API
  # so is there a ship address, and if so, is it different from the billing 
  # address?
  if ( length($ship_hash->{address1}) > 0 and
          grep { $bill_hash->{$_} ne $ship_hash->{$_} } keys(%$ship_hash)
         ) {

    $ship_location = FS::cust_location->new( $ship_hash );
  
  } else {
    $ship_location = $bill_location;
  }

  $new->set('bill_location' => $bill_location);
  $new->set('ship_location' => $ship_location);

  my $error = $new->replace( $cust_main, \@invoicing_list );
  return { 'error'   => $error } if $error;
  
  return { 'error'   => '',
         };
  
}

1;
