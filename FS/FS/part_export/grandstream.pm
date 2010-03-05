package FS::part_export::grandstream;

use base 'FS::part_export';
use vars qw($DEBUG $me %info $GAPSLITE_HOME $JAVA_HOME);
use URI;
use MIME::Base64;
use Tie::IxHash;
use IPC::Run qw(run);
use FS::CGI qw(rooturl);

$DEBUG = 1;

$me = '[' . __PACKAGE__ . ']';
$GAPSLITE_HOME = '/usr/local/src/GS_CFG_GEN/';

my @java = qw( /usr/lib/jvm/default-java/ /usr/java/default/
               /usr/lib/jvm/java-6-sun/
               /usr/lib/jvm/java-1.4.2-gcj-4.1-1.4.2.0/
             ); #add more common places distros and people put their JREs

$JAVA_HOME = (grep { -e $_ } @java)[0];

tie my %options, 'Tie::IxHash',
  'upload'          => { label=>'Enable upload to TFTP server via SSH',
                         type=>'checkbox',
                       },
  'user'            => { label=>'User name for SSH to TFTP server' },
  'tftproot'        => { label=>'Directory in which to upload configuration' },
  'java_home'       => { label=>'Path to java to be used',
                         default=>$JAVA_HOME,
                       },
  'gapslite_home'   => { label=>'Path to grandstream configuration tool',
                         default=>$GAPSLITE_HOME,
                       },
  'template'        => { label=>'Configuration template',
                         type=>'textarea',
                         notes=>'Type or paste the configuration template here',
                       },
;

%info = (
  'svc'      => [ qw( part_device ) ], # svc_phone
  'desc'     => 'Provision phone numbers to Grandstream Networks phones/ATAs',
  'options'  => \%options,
  'notes'    => 'Provision phone numbers to Grandstream Networks phones/ATAs.  Requires a Java runtime environment and the Grandstream configuration tool to be installed.',
);

sub rebless { shift; }

sub gs_create_config {
  my($self, $mac, %opt) = (@_);

  eval "use Net::SCP;";
  die $@ if $@;

  warn "gs_create_config called with mac of $mac\n" if $DEBUG;
  $mac = sprintf('%012s', lc($mac));
  my $dir = '%%%FREESIDE_CONF%%%/cache.'. $FS::UID::datasrc;

  my $fh = new File::Temp(
    TEMPLATE => "grandstream.$mac.XXXXXXXX",
    DIR      => $dir,
    UNLINK   => 0,
  );

  my $filename = $fh->filename;

  #my $template = new Text::Template (
  #  TYPE       => 'ARRAY',
  #  SOURCE     => $self->option('template'),
  #  DELIMITERS => $delimiters,
  #  OUTPUT     => $fh,
  #);

  #$template->compile or die "Can't compile template: $Text::Template::ERROR\n";

  #my $config = $template->fill_in( HASH => { mac_addr => $mac } );

  print $fh $self->option('template') or die "print failed: $!";
  close $fh;

  #system( "export GAPSLITE_HOME=$GAPSLITE_HOME; export JAVA_HOME=$JAVA_HOME; ".
  #        "cd $dir; $GAPSLITE_HOME/bin/encode.sh $mac $filename $dir/cfg$mac"
  #      ) == 0
  #  or die "grandstream encode failed: $!";
  my $out_and_err = '';
  my @cmd = ( "$JAVA_HOME/bin/java",
              '-classpath', "$GAPSLITE_HOME/lib/gapslite.jar:$GAPSLITE_HOME/lib/bcprov-jdk14-124.jar:$GAPSLITE_HOME/config",
              'com.grandstream.cmd.TextEncoder',
              $mac, $filename, "$dir/cfg$mac",
            );
  run \@cmd, '>&', \$out_and_err,
      },
    or die "grandstream encode failed: $out_and_err";

  unlink $filename;

  open my $encoded, "$dir/cfg$mac"  or die "open cfg$mac failed: $!";
  
  my $content;

  if ($opt{upload}) {
    if ($self->option('upload')) {
      my $scp = new Net::SCP ( {
        'host' => $self->machine,
        'user' => $self->option('user'),
        'cwd'  => $self->option('tftproot'),
      } );

      $scp->put( "$dir/cfg$mac" ) or die "upload failed: ". $scp->errstr;
    }
  } else {
    local $/;
    $content = <$encoded>;
  }

  close $encoded;
  unlink "$dir/cfg$mac";

  $content;
}

sub gs_create {
  my($self, $mac) = (shift, shift);

  return unless $mac;  # be more alarmed?  Or check upstream?

  $self->gs_create_config($mac, 'upload' => 1);
  '';
}

sub gs_delete {
  my($self, $mac) = (shift, shift);

  $mac = sprintf('%012s', lc($mac));

  ssh_cmd( user => $self->option('user'),
           host => $self->machine,
           command => 'rm',
           args    => [ '-f', $self->option('tftproot'). "/cfg$mac" ],
         );
  '';

}

sub ssh_cmd { #subroutine, not method
  use Net::SSH '0.08';
  &Net::SSH::ssh_cmd( { @_ } );
}

sub _export_insert {
#  my( $self, $svc_phone ) = (shift, shift);
#  $self->gs_create($svc_phone->mac_addr);
  '';
}

sub _export_replace {
#  my( $self, $new_svc, $old_svc ) = (shift, shift, shift);
#  $self->gs_delete($old_svc->mac_addr);
#  $self->gs_create($new_svc->mac_addr);
  '';
}

sub _export_delete {
#  my( $self, $svc_phone ) = (shift, shift);
#  $self->gs_delete($svc_phone->mac_addr);
  '';
}

sub _export_suspend {
  '';
}

sub _export_unsuspend {
  '';
}

sub export_device_insert {
  my( $self, $svc_phone, $phone_device ) = (shift, shift, shift);
  $self->gs_create($phone_device->mac_addr);
  '';
}

sub export_device_delete {
  my( $self, $svc_phone, $phone_device ) = (shift, shift, shift);
  $self->gs_delete($phone_device->mac_addr);
  '';
}

sub export_device_config {
  my( $self, $svc_phone, $phone_device ) = (shift, shift, shift);

  my $mac;
#  if ($phone_device) {
    $mac = $phone_device->mac_addr;
#  } else {
#    $mac = $svc_phone->mac_addr;
#  }

  return '' unless $mac;  # be more alarmed?  Or check upstream?

  $self->gs_create_config($mac);
}


sub export_device_replace {
  my( $self, $svc_phone, $new_svc_or_device, $old_svc_or_device ) =
    (shift, shift, shift, shift);

  $self->gs_delete($old_svc_or_device->mac_addr);
  $self->gs_create($new_svc_or_device->mac_addr);
  '';
}

# bad overloading?
sub export_links {
  my($self, $svc_phone, $arrayref) = (shift, shift, shift);

  return;  # remove if we actually support being an export for svc_phone;

  my @deviceparts = map { $_->devicepart } $self->export_device;
  my @devices = grep { my $part = $_->devicepart;
                       scalar( grep { $_ == $part } @deviceparts );
                     } $svc_phone->phone_device;

  my $export = $self->exportnum;
  my $fsurl = rooturl();
  if (@devices) {
    foreach my $device ( @devices ) {
      next unless $device->mac_addr;
      my $num = $device->devicenum;
      push @$arrayref,
        qq!<A HREF="$fsurl/misc/phone_device_config.html?exportnum=$export;devicenum=$num">!.
        qq! Phone config </A>!;
      }
  } elsif ($svc_phone->mac_addr) {
    my $num = $svc_phone->svcnum;
    push @$arrayref,
      qq!<A HREF="$fsurl/misc/phone_device_config.html?exportnum=$export;svcnum=$num">!.
      qq! Phone config </A>!;
  } #else
  '';
}

sub export_device_links {
  my($self, $svc_phone, $device, $arrayref) = (shift, shift, shift, shift);
  warn "export_device_links $self $svc_phone $device $arrayref\n" if $DEBUG;
  return unless $device && $device->mac_addr;
  my $export = $self->exportnum;
  my $fsurl = rooturl();
  my $num = $device->devicenum;
  push @$arrayref,
    qq!<A HREF="$fsurl/misc/phone_device_config.html?exportnum=$export;devicenum=$num">!.
    qq! Phone config </A>!;
  '';
}

1;
