package FS::part_export::ikano;

use vars qw(@ISA %info);
use Tie::IxHash;
use Date::Format qw( time2str );
use FS::Record qw(qsearch dbh);
use FS::part_export;
use FS::svc_dsl;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'keyid'         => { label=>'Ikano keyid' },
  'username'      => { label=>'Ikano username',
			default => 'admin',
			},
  'password'      => { label=>'Ikano password' },
  'check_networks' => { label => 'Check Networks',
		    default => 'ATT,BELLCA',
		    },
;

%info = (
  'svc'     => 'svc_dsl',
  'desc'    => 'Provision DSL to Ikano',
  'options' => \%options,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-Ikano">Net::Ikano</a> from CPAN.
END
);

sub rebless { shift; }

sub dsl_pull {
    '';
}

sub status_line {
    my($self,$svc_dsl) = (shift,shift,shift,shift);
    my %orderTypes = ( 'N' => 'New', 'X' => 'Cancel', 'C' => 'Change' );
    my %orderStatus = ( 'N' => 'New', 'P' => 'Pending', 'X' => 'Cancelled',
			'C' => 'Completed', 'E' => 'Error' );
    return "Ikano ".$orderTypes{$svc_dsl->vendor_order_type}." order #"
	. $svc_dsl->vendor_order_id . " (Status: " 
	. $orderStatus{$svc_dsl->vendor_order_status} . ")";
}

sub loop_type_long {
    my($svc_dsl) = shift;
    return "Standalone" if $svc_dsl->loop_type eq '0';
    return "Line-share";
}

sub ikano_command {
  my( $self, $command, @args ) = @_;

  eval "use Net::Ikano;";
  die $@ if $@;

  my $ikano = Net::Ikano->new(
    'keyid' => $self->option('keyid'),
    'username'  => $self->option('username'),
    'password'  => $self->option('password'),
    #'debug'    => 1,
  );

  $ikano->$command(@args);
}

sub _export_insert {
  my( $self, $svc_dsl ) = (shift, shift);
  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  '';
}

sub _export_delete {
  my( $self, $svc_dsl ) = (shift, shift);
  '';
}

sub _export_suspend {
  my( $self, $svc_dsl ) = (shift, shift);
  '';
}

sub _export_unsuspend {
  my( $self, $svc_dsl ) = (shift, shift);
  '';
}

1;
