package FS::part_export::www_shellcommands;

use strict;
use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'mkdir $homedir/$zone; chown $username $homedir/$zone; ln -s $homedir/$zone /var/www/$zone',
               },
  'userdel'  => { label=>'Delete command',
                  default=>'[ -n "$zone" ] && rm -rf /var/www/$zone; rm -rf $homedir/$zone',
                },
  'usermod'  => { label=>'Modify command',
                  default=>'[ -n "$old_zone" ] && rm /var/www/$old_zone; [ "$old_zone" != "$new_zone" -a -n "$new_zone" ] && ( mv $old_homedir/$old_zone $new_homedir/$new_zone; ln -sf $new_homedir/$new_zone /var/www/$new_zone ); [ "$old_username" != "$new_username" ] && chown -R $new_username $new_homedir/$new_zone; ln -sf $new_homedir/$new_zone /var/www/$new_zone',
                },
  'suspend'  => { label=>'Suspension command',
                  default=>'[ -n "$zone" ] && chmod 0 /var/www/$zone',
                },
  'unsuspend'=> { label=>'Unsuspension command',
                  default=>'[ -n "$zone" ] && chmod 755 /var/www/$zone',
                },
;

%info = (
  'svc'     => 'svc_www',
  'desc'    => 'Run remote commands via SSH, for virtual web sites (directory maintenance, FrontPage, ISPMan)',
  'options' => \%options,
  'notes'   => <<'END'
Run remote commands via SSH, for virtual web sites.  You will need to
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Administration:SSH_Keys">setup SSH for unattended operation</a>.
<BR><BR>Use these buttons for some useful presets:
<UL>
  <LI>
    <INPUT TYPE="button" VALUE="Maintain directories" onClick='
      this.form.user.value = "root";
      this.form.useradd.value = "mkdir $homedir/$zone; chown $username $homedir/$zone; ln -s $homedir/$zone /var/www/$zone";
      this.form.userdel.value = "[ -n \"$zone\" ] && rm -rf /var/www/$zone; rm -rf $homedir/$zone";
      this.form.usermod.value = "[ -n \"$old_zone\" ] && rm /var/www/$old_zone; [ \"$old_zone\" != \"$new_zone\" -a -n \"$new_zone\" ] && ( mv $old_homedir/$old_zone $new_homedir/$new_zone; ln -sf $new_homedir/$new_zone /var/www/$new_zone ); [ \"$old_username\" != \"$new_username\" ] && chown -R $new_username $new_homedir/$new_zone; ln -sf $new_homedir/$new_zone /var/www/$new_zone";
      this.form.suspend.value = "[ -n \"$zone\" ] && chmod 0 /var/www/$zone";
      this.form.unsuspend.value = "[ -n \"$zone\" ] && chmod 755 /var/www/$zone";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="FrontPage extensions" onClick='
      this.form.user.value = "root";
      this.form.useradd.value = "/usr/local/frontpage/version5.0/bin/owsadm.exe -o install -p 80 -m $zone -xu $username -xg www-data -s /etc/apache/httpd.conf -u $username -pw $_password";
      this.form.userdel.value = "/usr/local/frontpage/version5.0/bin/owsadm.exe -o uninstall -p 80 -m $zone -s /etc/apache/httpd.conf";
      this.form.usermod.value = "";
      this.form.suspend.value = "";
      this.form.unsuspend.value = "";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="ISPMan CLI" onClick='
      this.form.user.value = "root";
      this.form.useradd.value = "/usr/local/ispman/bin/ispman.addvhost -d $domain $bare_zone";
      this.form.userdel.value = "/usr/local/ispman/bin/ispman.deletevhost -d $domain $bare_zone";
      this.form.usermod.value = "";
      this.form.suspend.value = "";
      this.form.unsuspend.value = "";
    '></UL>
The following variables are available for interpolation (prefixed with
<code>new_</code> or <code>old_</code> for replace operations):
<UL>
  <LI><code>$zone</code> - fully-qualified zone of this virtual host
  <LI><code>$bare_zone</code> - just the zone of this virtual host, without the domain portion
  <LI><code>$domain</code> - base domain
  <LI><code>$username</code>
  <LI><code>$_password</code>
  <LI><code>$homedir</code>
  <LI>All other fields in <a href="../docs/schema.html#svc_www">svc_www</a>
    are also available.
</UL>
END
);


sub rebless { shift; }

sub _export_insert {
  my($self) = shift;
  $self->_export_command('useradd', @_);
}

sub _export_delete {
  my($self) = shift;
  $self->_export_command('userdel', @_);
}

sub _export_suspend {
  my($self) = shift;
  $self->_export_command('suspend', @_);
}

sub _export_unsuspend {
  my($self) = shift;
  $self->_export_command('unsuspend', @_);
}

sub _export_command {
  my ( $self, $action, $svc_www) = (shift, shift, shift);
  my $command = $self->option($action);
  return '' if $command =~ /^\s*$/;

  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${$_} = $svc_www->getfield($_) foreach $svc_www->fields;
  }
  my $domain_record = $svc_www->domain_record; # or die ?
  my $zone = $domain_record->zone; # or die ?
  my $domain = $domain_record->svc_domain->domain;
  ( my $bare_zone = $zone ) =~ s/\.$domain$//;
  my $svc_acct = $svc_www->svc_acct; # or die ?
  my $username = $svc_acct->username;
  my $_password = $svc_acct->_password;
  my $homedir = $svc_acct->dir; # or die ?

  #done setting variables for the command

  $self->shellcommands_queue( $svc_www->svcnum,
    user         => $self->option('user')||'root',
    host         => $self->machine,
    command      => eval(qq("$command")),
  );
}

sub _export_replace {
  my($self, $new, $old ) = (shift, shift, shift);
  my $command = $self->option('usermod');
  
  #set variable for the command
  no strict 'vars';
  {
    no strict 'refs';
    ${"old_$_"} = $old->getfield($_) foreach $old->fields;
    ${"new_$_"} = $new->getfield($_) foreach $new->fields;
  }
  my $old_domain_record = $old->domain_record; # or die ?
  my $old_zone = $old_domain_record->zone; # or die ?
  my $old_domain = $old_domain_record->svc_domain->domain;
  ( my $old_bare_zone = $old_zone ) =~ s/\.$old_domain$//;
  my $old_svc_acct = $old->svc_acct; # or die ?
  my $old_username = $old_svc_acct->username;
  my $old_homedir = $old_svc_acct->dir; # or die ?

  my $new_domain_record = $new->domain_record; # or die ?
  my $new_zone = $new_domain_record->zone; # or die ?
  my $new_domain = $new_domain_record->svc_domain->domain;
  ( my $new_bare_zone = $new_zone ) =~ s/\.$new_domain$//;
  my $new_svc_acct = $new->svc_acct; # or die ?
  my $new_username = $new_svc_acct->username;
  #my $new__password = $new_svc_acct->_password;
  my $new_homedir = $new_svc_acct->dir; # or die ?

  #done setting variables for the command

  $self->shellcommands_queue( $new->svcnum,
    user         => $self->option('user')||'root',
    host         => $self->machine,
    command      => eval(qq("$command")),
  );
}

#a good idea to queue anything that could fail or take any time
sub shellcommands_queue {
  my( $self, $svcnum ) = (shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::www_shellcommands::ssh_cmd",
  };
  $queue->insert( @_ );
}

sub ssh_cmd { #subroutine, not method
  use Net::OpenSSH;
  my $opt = { @_ };
  my $ssh = Net::OpenSSH->new($opt->{'user'}.'@'.$opt->{'host'});
  die "Couldn't establish SSH connection: ". $ssh->error if $ssh->error;
  my ($output, $errput) = $ssh->capture2($opt->{'command'});
  die "Error running SSH command: ". $ssh->error if $ssh->error;
  die $errput if $errput;
  die $output if $output;
  '';
}

