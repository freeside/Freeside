package FS::part_event::Action::cust_bill_fsinc_print;

use strict;
use base qw( FS::part_event::Action );
use LWP::UserAgent;
use HTTP::Request::Common qw( POST );
use JSON::XS;
use CAM::PDF;
use FS::Conf;

sub description { 'Send invoice to Freeside Inc. for printing and mailing'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'modenum'     => { label  => 'Invoice mode',
                       type   => 'select-invoice_mode',
                     },
  );
}

sub default_weight { 52; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  $cust_bill->set('mode' => $self->option('modenum'));

  my $url = 'https://ws.freeside.biz/print';

  my $cust_main = $cust_bill->cust_main;
  my $bill_location = $cust_main->bill_location;

  die 'Extra charges for international mailing; contact support@freeside.biz to enable'
    if $bill_location->country ne 'US';

  my $conf = new FS::Conf;

  my @company_address = $conf->config('company_address', $agentnum);
  my ( $company_address1, $company_address2, $company_city, $company_state, $company_zip );
  if ( $company_address[2] =~ /^\s*(\S.*\S)\s*[\s,](\w\w),?\s*(\d{5}(-\d{4})?)\s*$/ ) {
    $company_address1 = $company_address[0];
    $company_address2 = $company_address[1];
    $company_city  = $1;
    $company_state = $2;
    $company_zip   = $3;
  } elsif ( $company_address[1] =~ /^\s*(\S.*\S)\s*[\s,](\w\w),?\s*(\d{5}(-\d{4})?)\s*$/ ) {
    $company_address1 = $company_address[0];
    $company_address2 = '';
    $company_city  = $1;
    $company_state = $2;
    $company_zip   = $3;
  } else {
    die 'Unparsable company_address; contact support@freeside.biz';
  }

  my $file = $cust_bill->print_pdf;
  my $pages = CAM::PDF->new($file)->numPages;

  my $ua = LWP::UserAgent->new( 'ssl_opts' => { 'verify_hostname'=>0 });
  my $response = $ua->request( POST $url, [
    'support-key'      => scalar($conf->config('support-key')),
    'file'             => $file,
    'pages'            => $pages,

    #from:
    'company_name'     => scalar( $conf->config('company_name', $agentnum) ),
    'company_address1' => $company_address1,
    'company_address2' => $company_address2,
    'company_city'     => $company_city
    'company_state'    => $company_state,
    'company_zip'      => $company_zip,
    'company_country'  => 'US',
    'company_phonenum' => scalar($conf->config('company_phonenum', $agentnum)),
    'company_email'    => scalar($conf->config('invoice_from', $agentnum)),

    #to:
    'name'             => ( $cust_main->payname
                              && $cust_main->payby !~ /^(CARD|DCRD|CHEK|DCHK)$/
                                ? $cust_main->payname
                                : $cust_main->contact_firstlast
                          )
    'address1'         => $bill_location->address1,
    'address2'         => $bill_location->address2,
    'city'             => $bill_location->city,
    'state'            => $bill_location->state,
    'zip'              => $bill_location->zip,
    'country'          => $bill_location->country,
  ]);

  die "Print connection error: ". $response->message
    unless $response->is_success;

  local $@;
  my $content = eval { decode_json($response->content) };
  die "Print JSON error : $@\n" if $@;

  die $content->{error}."\n"
    if $content->{error};
}

1;
