package FS::part_export::freeswitch;
use base qw( FS::part_export );

use vars qw( %info ); # $DEBUG );
#use Data::Dumper;
use Tie::IxHash;
use Text::Template;
use FS::Record qw( qsearch ); #qsearchs );
use FS::svc_phone;
#use FS::Schema qw( dbdef );

#$DEBUG = 1;

tie my %options, 'Tie::IxHash',
  'user'  => { label => 'SSH username', default=>'root', },
  'directory' => { label   => 'Directory to store FreeSWITCH account XML files',
                   default => '/usr/local/freeswitch/conf/directory/',
                 },
  #'domain'    => { label => 'Optional fixed SIP domain to use, overrides svc_phone domain', },
  'reload'    => { label   => 'Reload command',
                   default => '/usr/local/freeswitch/bin/fs_cli -x reloadxml',
                 },
  'user_template' => { label   => 'User XML configuration template',
                       type    => 'textarea',
                       default => <<'END',
<domain name="<% $domain %>">
  <user id="<% $phonenum %>">
    <params>
      <param name="password" value="<% $sip_password %>"/>
      <param name="nibble_account" value="<% $phonenum %>"/>
      <param name="nibble_rate" value="<% $nibble_rate %>"/>
    </params>
  </user>
</domain>
END
                     },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone services to FreeSWITCH XML configuration files',
  'options' => \%options,
  'notes'   => <<'END',
Export XML account configuration files to FreeSWITCH, one per domain.
<br><br>
You will need to enable the svc_phone-domain configuration setting and
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Administration:SSH_Keys">setup SSH for unattended operation</a>.
END
);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_phone ) = ( shift, shift );

  $self->_export_rebuild_domain($svc_phone);

}

sub _export_replace {
  my( $self, $new, $old ) = ( shift, shift, shift );

  my $error = $self->_export_rebuild_domain($new);
  return $error if $error;

  if ( $new->domsvc ne $old->domsvc && $old->domsvc ) {
    $error = $self->_export_rebuild_domain($old);
    return $error if $error;
  }

  '';
}

sub _export_delete {
  my( $self, $svc_phone ) = ( shift, shift );

  $self->_export_rebuild_domain($svc_phone);
}

sub _export_rebuild_domain {
  my($self, $svc_phone) = ( shift, shift );

  eval "use Net::SCP;";
  die $@ if $@;

  #create and copy over file

  my $tempdir = '%%%FREESIDE_CONF%%%/cache.'. $FS::UID::datasrc;

  my $domain = $svc_phone->domain or return "domain required";

  my $fh = new File::Temp(
    TEMPLATE => "$tempdir/freeswitch.$domain.XXXXXXXX",
    DIR      => $dir,
    #UNLINK   => 0,
  );

  print $fh qq(<domain name="$domain">\n);

  my @dom_svc_phone = qsearch( 'svc_phone', { 'domsvc'=>$svc_phone->domsvc } );

  foreach my $dom_svc_phone (@dom_svc_phone) {

    print $fh $self->freeswitch_template_fillin( $dom_svc_phone, 'user' )
      or die "print to freeswitch template failed: $!";

  }

  print $fh qq(</domain>\n);
  $fh->flush;

  my $scp = new Net::SCP;
  my $user = $self->option('user')||'root';
  my $host = $self->machine;
  my $dir = $self->option('directory');

  $scp->scp( $fh->filename, "$user\@$host:$dir/$domain.xml" )
    or return $scp->{errstr};

  #signal freeswitch to reload config
  $self->freeswitch_ssh( command => $self->option('reload') );

  '';

}

sub freeswitch_template_fillin {
  my( $self, $svc_phone, $template ) = (shift, shift, shift);

  $template ||= 'user'; #?

  #cache a %tt hash?
  my $tt = new Text::Template (
    TYPE       => 'STRING',
    SOURCE     => $self->option($template.'_template'),
    DELIMITERS => [ '<%', '%>' ],
  );

  #false lazinessish w/phone_shellcommands::_export_command
  my %hash = (
    map { $_ => $svc_phone->getfield($_) } $svc_phone->fields
  );

  #might as well do em all, they're all going in an XML file as attribs
  foreach ( keys %hash ) {
    $hash{$_} =~ s/'/&apos;/g;
    $hash{$_} =~ s/"/&quot;/g;
  }

  $tt->fill_in(
    HASH => \%hash,
  );
}

##a good idea to queue anything that could fail or take any time
#sub shellcommands_queue {
#  my( $self, $svcnum ) = (shift, shift);
#  my $queue = new FS::queue {
#    'svcnum' => $svcnum,
#    'job'    => "FS::part_export::freeswitch::ssh_cmd",
#  };
#  $queue->insert( @_ );
#}

sub freeswitch_ssh { #method
  my $self = shift;
  ssh_cmd( user    => $self->option('user')||'root',
           host    => $self->machine,
           @_,
         );
}

sub ssh_cmd { #subroutine, not method
  use Net::OpenSSH;
  my $opt = { @_ };
  open my $def_in, '<', '/dev/null' or die "unable to open /dev/null";
  my $ssh = Net::OpenSSH->new( $opt->{'user'}.'@'.$opt->{'host'},
                               default_stdin_fh => $def_in,
                             );
  die "Couldn't establish SSH connection: ". $ssh->error if $ssh->error;
  my ($output, $errput) = $ssh->capture2( #{stdin_discard => 1},
                                          $opt->{'command'}
                                        );
  die "Error running SSH command: ". $ssh->error if $ssh->error;

  #who the fuck knows what freeswitch reload outputs, probably a fucking
  # ascii advertisement for cluecon
  #die $errput if $errput;
  #die $output if $output;

  '';
}

1;
