package FS::part_export::http_status;
use base qw( FS::part_export );

use strict;
use warnings;
use vars qw( %info $DEBUG );
use URI::Escape;
use LWP::UserAgent;
use HTTP::Request::Common;
use Email::Valid;

tie my %options, 'Tie::IxHash',
  'url' => { label => 'URL', },
  'blacklist_add_url' => { label => 'Optional blacklist add URL', },
  'blacklist_del_url' => { label => 'Optional blacklist delete URL', },
  'whitelist_add_url' => { label => 'Optional whitelist add URL', },
  'whitelist_del_url' => { label => 'Optional whitelist delete URL', },
  'vacation_add_url'  => { label => 'Optional vacation message add URL', },
  'vacation_del_url'  => { label => 'Optional vacation message delete URL', },

  #'user'     => { label => 'Username', default=>'' },
  #'password' => { label => 'Password', default => '' },
;

%info = (
  'svc'     => [ 'svc_acct', 'svc_dsl', ],
  'desc'    => 'Retrieve status information via HTTP or HTTPS',
  'options' => \%options,
  'notes'   => <<'END'
Fields from the service can be substituted in the URL as $field.

Optionally, spam black/whitelist addresees and a vacation message may be
modified via HTTP or HTTPS as well.
END
);

$DEBUG = 1;

sub rebless { shift; }

our %addl_fields = (
  'svc_acct' => [qw( email ) ],
  'svc_dsl'  => [qw( gateway_access_or_phonenum ) ],
);

#some NOPs for required subroutines, to avoid throwing the exceptions in the
# part_export.pm fallbacks
sub _export_insert  { '' };
sub _export_replace { '' };
sub _export_delete  { '' };

sub export_getstatus {
  my( $self, $svc_x, $htmlref, $hashref ) = @_;

  my $url;
  my $urlopt = $self->option('url');
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_x->getfield($_) foreach $svc_x->fields;
    ${$_} = $svc_x->$_()         foreach @{ $addl_fields{ $svc_x->table } };
    $url = eval(qq("$urlopt"));
  }

  my $req = HTTP::Request::Common::GET( $url );
  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($req);

  if ( $svc_x->table eq 'svc_dsl' ) {

    $$htmlref = $response->is_error ? $response->error_as_HTML
                                    : $response->content;

    #hash data not yet implemented for svc_dsl

  } elsif ( $svc_x->table eq 'svc_acct' ) {

    #this whole section is rather specific to fibernetics and should be an
    # option or callback or something

    # to,from,wb_value

    use Text::CSV_XS;
    my $csv = Text::CSV_XS->new;

    my @lines = split("\n", $response->content);
    pop @lines if $lines[-1] eq '';
    my $header = shift @lines;
    $csv->parse($header) or return;
    my @header = $csv->fields;

    while ( my $line = shift @lines ) {
      $csv->parse($line) or next;
      my @fields = $csv->fields;
      my %hash = map { $_ => shift(@fields) } @header;

      if ( defined $hash{'wb_value'} ) {
        if ( $hash{'wb_value'} =~ /^[WA]/i ) { #Whitelist/Allow
          push @{ $hashref->{'whitelist'} }, $hash{'from'};
        } else { # if ( $hash{'wb_value'} =~ /^[BD]/i ) { #Blacklist/Deny
          push @{ $hashref->{'blacklist'} }, $hash{'from'};
        }
      }

      for (qw( created enddate )) {
        $hash{$_} = '' if $hash{$_} =~ /^0000-/;
        $hash{$_} = (split(' ', $hash{$_}))[0];
      }

      next unless $hash{'active'};
      $hashref->{"vacation_$_"} = $hash{$_} || ''
        foreach qw( active subject body created enddate );

    }

  } #else { die 'guru meditation #295'; }

}

sub export_setstatus_listadd {
  my( $self, $svc_x, $hr ) = @_;
  $self->export_setstatus_listX( $svc_x, 'add', $hr->{list}, $hr->{address} );
}

sub export_setstatus_listdel {
  my( $self, $svc_x, $hr ) = @_;
  $self->export_setstatus_listX( $svc_x, 'del', $hr->{list}, $hr->{address} );
}

sub export_setstatus_listX {
  my( $self, $svc_x, $action, $list, $address_item ) = @_;

  my $option;
  if ( $list =~ /^[WA]/i ) { #Whitelist/Allow
    $option = 'whitelist_';
  } else { # if ( $hash{'wb_value'} =~ /^[BD]/i ) { #Blacklist/Deny
    $option = 'blacklist_';
  }
  $option .= $action. '_url';

  my $address;
  unless ( $address = Email::Valid->address($address_item) ) {

    if ( $address_item =~ /^(\@[\w\-\.]+\.\w{2,63})$/ ) { # "@domain"
      $address = $1;
    } else {
      die "address failed $Email::Valid::Details check.\n";
    }

  }

  #some false laziness w/export_getstatus above
  my $url;
  my $urlopt = $self->option($option) or return; #DIFF
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_x->getfield($_) foreach $svc_x->fields;
    ${$_} = $svc_x->$_()         foreach @{ $addl_fields{ $svc_x->table } };
    $url = eval(qq("$urlopt"));
  }

  my $req = HTTP::Request::Common::GET( $url );
  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($req);

  die $response->code. ' '. $response->message if $response->is_error;

}

sub export_setstatus_vacationadd {
  my( $self, $svc_x, $hr ) = @_;
  $self->export_setstatus_vacationX( $svc_x, 'add', $hr );
}

sub export_setstatus_vacationdel {
  my( $self, $svc_x, $hr ) = @_;
  $self->export_setstatus_vacationX( $svc_x, 'del', $hr );
}

sub export_setstatus_vacationX {
  my( $self, $svc_x, $action, $hr ) = @_;

  my $option = 'vacation_'. $action. '_url';

  my $subject = uri_escape($hr->{subject});
  my $body    = uri_escape($hr->{body});
  for (qw( created enddate )) {
    if ( $hr->{$_} =~ /^(\d{4}-\d{2}-\d{2})$/ ) {
      $hr->{$_} = $1;
    } else {
      $hr->{$_} = '';
    }
  }
  my $created = $hr->{created};
  my $enddate = $hr->{enddate};

  #some false laziness w/export_getstatus above
  my $url;
  my $urlopt = $self->option($option) or return; #DIFF
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_x->getfield($_) foreach $svc_x->fields;
    ${$_} = $svc_x->$_()         foreach @{ $addl_fields{ $svc_x->table } };
    $url = eval(qq("$urlopt"));
  }

  my $req = HTTP::Request::Common::GET( $url );
  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($req);

  die $response->code. ' '. $response->message if $response->is_error;

}

1;

1;
