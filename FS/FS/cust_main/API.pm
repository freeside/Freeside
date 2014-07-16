package FS::cust_main::API;

use strict;

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

1;
