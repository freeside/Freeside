package FS::part_export;

use strict;
use vars qw( @ISA @EXPORT_OK %exports );
use Exporter;
use Tie::IxHash;
use FS::Record qw( qsearch qsearchs dbh );
use FS::part_svc;
use FS::part_export_option;
use FS::export_svc;

@ISA = qw(FS::Record);
@EXPORT_OK = qw(export_info);

=head1 NAME

FS::part_export - Object methods for part_export records

=head1 SYNOPSIS

  use FS::part_export;

  $record = new FS::part_export \%hash;
  $record = new FS::part_export { 'column' => 'value' };

  #($new_record, $options) = $template_recored->clone( $svcpart );

  $error = $record->insert( { 'option' => 'value' } );
  $error = $record->insert( \%options );

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_export object represents an export of Freeside data to an external
provisioning system.  FS::part_export inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item exportnum - primary key

=item machine - Machine name 

=item exporttype - Export type

=item nodomain - blank or "Y" : usernames are exported to this service with no domain

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new export.  To add the export to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_export'; }

=cut

#=item clone SVCPART
#
#An alternate constructor.  Creates a new export by duplicating an existing
#export.  The given svcpart is assigned to the new export.
#
#Returns a list consisting of the new export object and a hashref of options.
#
#=cut
#
#sub clone {
#  my $self = shift;
#  my $class = ref($self);
#  my %hash = $self->hash;
#  $hash{'exportnum'} = '';
#  $hash{'svcpart'} = shift;
#  ( $class->new( \%hash ),
#    { map { $_->optionname => $_->optionvalue }
#        qsearch('part_export_option', { 'exportnum' => $self->exportnum } )
#    }
#  );
#}

=item insert HASHREF

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a hash reference of options is supplied, part_export_option records are
created (see L<FS::part_export_option>).

=cut

#false laziness w/queue.pm
sub insert {
  my $self = shift;
  my $options = shift;
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $optionname ( keys %{$options} ) {
    my $part_export_option = new FS::part_export_option ( {
      'exportnum'   => $self->exportnum,
      'optionname'  => $optionname,
      'optionvalue' => $options->{$optionname},
    } );
    $error = $part_export_option->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.

=cut

#foreign keys would make this much less tedious... grr dumb mysql
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

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $part_export_option ( $self->part_export_option ) {
    my $error = $part_export_option->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $export_svc ( $self->export_svc ) {
    my $error = $export_svc->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD HASHREF

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a hash reference of options is supplied, part_export_option records are
created or modified (see L<FS::part_export_option>).

=cut

sub replace {
  my $self = shift;
  my $old = shift;
  my $options = shift;
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $optionname ( keys %{$options} ) {
    my $old = qsearchs( 'part_export_option', {
        'exportnum'   => $self->exportnum,
        'optionname'  => $optionname,
    } );
    my $new = new FS::part_export_option ( {
        'exportnum'   => $self->exportnum,
        'optionname'  => $optionname,
        'optionvalue' => $options->{$optionname},
    } );
    $new->optionnum($old->optionnum) if $old;
    my $error = $old ? $new->replace($old) : $new->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #remove extraneous old options
  foreach my $opt (
    grep { !exists $options->{$_->optionname} } $old->part_export_option
  ) {
    my $error = $opt->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

};

=item check

Checks all fields to make sure this is a valid export.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $error = 
    $self->ut_numbern('exportnum')
    || $self->ut_domain('machine')
    || $self->ut_alpha('exporttype')
  ;
  return $error if $error;

  $self->machine =~ /^([\w\-\.]*)$/
    or return "Illegal machine: ". $self->machine;
  $self->machine($1);

  $self->nodomain =~ /^(Y?)$/ or return "Illegal nodomain: ". $self->nodomain;
  $self->nodomain($1);

  $self->deprecated(1); #BLAH

  #check exporttype?

  ''; #no error
}

#=item part_svc
#
#Returns the service definition (see L<FS::part_svc>) for this export.
#
#=cut
#
#sub part_svc {
#  my $self = shift;
#  qsearchs('part_svc', { svcpart => $self->svcpart } );
#}

sub part_svc {
  use Carp;
  croak "FS::part_export::part_svc deprecated";
  #confess "FS::part_export::part_svc deprecated";
}

=item svc_x

Returns a list of associate FS::svc_* records.

=cut

sub svc_x {
  my $self = shift;
  map { $_->svc_x } $self->cust_svc;
}

=item cust_svc

Returns a list of associated FS::cust_svc records.

=cut

sub cust_svc {
  my $self = shift;
  map { qsearch('cust_svc', { 'svcpart' => $_->svcpart } ) }
    grep { qsearch('cust_svc', { 'svcpart' => $_->svcpart } ) }
      $self->export_svc;
}

=item export_svc

Returns a list of associated FS::export_svc records.

=cut

sub export_svc {
  my $self = shift;
  qsearch('export_svc', { 'exportnum' => $self->exportnum } );
}

=item part_export_option

Returns all options as FS::part_export_option objects (see
L<FS::part_export_option>).

=cut

sub part_export_option {
  my $self = shift;
  qsearch('part_export_option', { 'exportnum' => $self->exportnum } );
}

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=cut

sub options {
  my $self = shift;
  map { $_->optionname => $_->optionvalue } $self->part_export_option;
}

=item option OPTIONNAME

Returns the option value for the given name, or the empty string.

=cut

sub option {
  my $self = shift;
  my $part_export_option =
    qsearchs('part_export_option', {
      exportnum  => $self->exportnum,
      optionname => shift,
  } );
  $part_export_option ? $part_export_option->optionvalue : '';
}

=item rebless

Reblesses the object into the FS::part_export::EXPORTTYPE class, where
EXPORTTYPE is the object's I<exporttype> field.  There should be better docs
on how to create new exports (and they should live in their own files and be
autoloaded-on-demand), but until then, see L</NEW EXPORT CLASSES>.

=cut

sub rebless {
  my $self = shift;
  my $exporttype = $self->exporttype;
  my $class = ref($self). "::$exporttype";
  eval "use $class;";
  die $@ if $@;
  bless($self, $class);
}

=item export_insert SVC_OBJECT

=cut

sub export_insert {
  my $self = shift;
  $self->rebless;
  $self->_export_insert(@_);
}

#sub AUTOLOAD {
#  my $self = shift;
#  $self->rebless;
#  my $method = $AUTOLOAD;
#  #$method =~ s/::(\w+)$/::_$1/; #infinite loop prevention
#  $method =~ s/::(\w+)$/_$1/; #infinite loop prevention
#  $self->$method(@_);
#}

=item export_replace NEW OLD

=cut

sub export_replace {
  my $self = shift;
  $self->rebless;
  $self->_export_replace(@_);
}

=item export_delete

=cut

sub export_delete {
  my $self = shift;
  $self->rebless;
  $self->_export_delete(@_);
}

=item export_suspend

=cut

sub export_suspend {
  my $self = shift;
  $self->rebless;
  $self->_export_suspend(@_);
}

=item export_unsuspend

=cut

sub export_unsuspend {
  my $self = shift;
  $self->rebless;
  $self->_export_unsuspend(@_);
}

#fallbacks providing useful error messages intead of infinite loops
sub _export_insert {
  my $self = shift;
  return "_export_insert: unknown export type ". $self->exporttype;
}

sub _export_replace {
  my $self = shift;
  return "_export_replace: unknown export type ". $self->exporttype;
}

sub _export_delete {
  my $self = shift;
  return "_export_delete: unknown export type ". $self->exporttype;
}

#fallbacks providing null operations

sub _export_suspend {
  my $self = shift;
  #warn "warning: _export_suspened unimplemented for". ref($self);
  '';
}

sub _export_unsuspend {
  my $self = shift;
  #warn "warning: _export_unsuspend unimplemented for ". ref($self);
  '';
}

=back

=head1 SUBROUTINES

=over 4

=item export_info [ SVCDB ]

Returns a hash reference of the exports for the given I<svcdb>, or if no
I<svcdb> is specified, for all exports.  The keys of the hash are
I<exporttype>s and the values are again hash references containing information
on the export:

  'desc'     => 'Description',
  'options'  => {
                  'option'  => { label=>'Option Label' },
                  'option2' => { label=>'Another label' },
                },
  'nodomain' => 'Y', #or ''
  'notes'    => 'Additional notes',

=cut

sub export_info {
  #warn $_[0];
  return $exports{$_[0]} if @_;
  #{ map { %{$exports{$_}} } keys %exports };
  my $r = { map { %{$exports{$_}} } keys %exports };
}

#=item exporttype2svcdb EXPORTTYPE
#
#Returns the applicable I<svcdb> for an I<exporttype>.
#
#=cut
#
#sub exporttype2svcdb {
#  my $exporttype = $_[0];
#  foreach my $svcdb ( keys %exports ) {
#    return $svcdb if grep { $exporttype eq $_ } keys %{$exports{$svcdb}};
#  }
#  '';
#}

tie my %sysvshell_options, 'Tie::IxHash',
  'crypt' => { label=>'Password encryption',
               type=>'select', options=>[qw(crypt md5)],
               default=>'crypt',
             },
;

tie my %bsdshell_options, 'Tie::IxHash', 
  'crypt' => { label=>'Password encryption',
               type=>'select', options=>[qw(crypt md5)],
               default=>'crypt',
             },
;

tie my %shellcommands_options, 'Tie::IxHash',
  #'machine' => { label=>'Remote machine' },
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'useradd -d $dir -m -s $shell -u $uid -p $crypt_password $username'
                #default=>'cp -pr /etc/skel $dir; chown -R $uid.$gid $dir'
               },
  'useradd_stdin' => { label=>'Insert command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'userdel' => { label=>'Delete command',
                 default=>'userdel -r $username',
                 #default=>'rm -rf $dir',
               },
  'userdel_stdin' => { label=>'Delete command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'usermod' => { label=>'Modify command',
                 default=>'usermod -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -p $new_crypt_password $old_username',
                #default=>'[ -d $old_dir ] && mv $old_dir $new_dir || ( '.
                 #  'chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; '.
                 #  'find . -depth -print | cpio -pdm $new_dir; '.
                 #  'chmod u-t $new_dir; chown -R $uid.$gid $new_dir; '.
                 #  'rm -rf $old_dir'.
                 #')'
               },
  'usermod_stdin' => { label=>'Modify command STDIN',
                       type =>'textarea',
                       default=>'',
                     },
  'suspend' => { label=>'Suspension command',
                 default=>'',
               },
  'suspend_stdin' => { label=>'Suspension command STDIN',
                       default=>'',
                     },
  'unsuspend' => { label=>'Unsuspension command',
                   default=>'',
                 },
  'unsuspend_stdin' => { label=>'Unsuspension command STDIN',
                         default=>'',
                       },
;

tie my %shellcommands_withdomain_options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 #default=>''
               },
  'useradd_stdin' => { label=>'Insert command STDIN',
                       type =>'textarea',
                       #default=>"$_password\n$_password\n",
                     },
  'userdel' => { label=>'Delete command',
                 #default=>'',
               },
  'userdel_stdin' => { label=>'Delete command STDIN',
                       type =>'textarea',
                       #default=>'',
                     },
  'usermod' => { label=>'Modify command',
                 default=>'',
               },
  'usermod_stdin' => { label=>'Modify command STDIN',
                       type =>'textarea',
                       #default=>"$_password\n$_password\n",
                     },
  'suspend' => { label=>'Suspension command',
                 default=>'',
               },
  'suspend_stdin' => { label=>'Suspension command STDIN',
                       default=>'',
                     },
  'unsuspend' => { label=>'Unsuspension command',
                   default=>'',
                 },
  'unsuspend_stdin' => { label=>'Unsuspension command STDIN',
                         default=>'',
                       },
;

tie my %www_shellcommands_options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'mkdir /var/www/$zone; chown $username /var/www/$zone; ln -s /var/www/$zone $homedir/$zone',
               },
  'userdel'  => { label=>'Delete command',
                  default=>'[ -n &quot;$zone&quot; ] && rm -rf /var/www/$zone; rm $homedir/$zone',
                },
  'usermod'  => { label=>'Modify command',
                  default=>'[ -n &quot;$old_zone&quot; ] && rm $old_homedir/$old_zone; [ &quot;$old_zone&quot; != &quot;$new_zone&quot; -a -n &quot;$new_zone&quot; ] && mv /var/www/$old_zone /var/www/$new_zone; [ &quot;$old_username&quot; != &quot;$new_username&quot; ] && chown -R $new_username /var/www/$new_zone; ln -s /var/www/$new_zone $new_homedir/$new_zone',
                },
;

tie my %apache_options, 'Tie::IxHash',
  'user'       => { label=>'Remote username', default=>'root' },
  'httpd_conf' => { label=>'httpd.conf snippet location',
                    default=>'/etc/apache/httpd-freeside.conf', },
  'template'   => {
    label   => 'Template',
    type    => 'textarea',
    default => <<'END',
<VirtualHost $domain> #generic
#<VirtualHost ip.addr> #preferred, http://httpd.apache.org/docs/dns-caveats.html
DocumentRoot /var/www/$zone
ServerName $zone
ServerAlias *.$zone
#BandWidthModule On
#LargeFileLimit 4096 12288
</VirtualHost>

END
  },
;

tie my %domain_shellcommands_options, 'Tie::IxHash',
  'user' => { lable=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'',
               },
  'userdel'  => { label=>'Delete command',
                  default=>'',
                },
  'usermod'  => { label=>'Modify command',
                  default=>'',
                },
;

tie my %textradius_options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },
  'users' => { label=>'users file location', default=>'/etc/raddb/users' },
;

tie my %sqlradius_options, 'Tie::IxHash',
  'datasrc'  => { label=>'DBI data source ' },
  'username' => { label=>'Database username' },
  'password' => { label=>'Database password' },
;

tie my %cyrus_options, 'Tie::IxHash',
  'server' => { label=>'IMAP server' },
  'username' => { label=>'Admin username' },
  'password' => { label=>'Admin password' },
;

tie my %cp_options, 'Tie::IxHash',
  'host'      => { label=>'Hostname' },
  'port'      => { label=>'Port number' },
  'username'  => { label=>'Username' },
  'password'  => { label=>'Password' },
  'domain'    => { label=>'Domain' },
  'workgroup' => { label=>'Default Workgroup' },
;

tie my %infostreet_options, 'Tie::IxHash',
  'url'      => { label=>'XML-RPC Access URL', },
  'login'    => { label=>'InfoStreet login', },
  'password' => { label=>'InfoStreet password', },
  'groupID'  => { label=>'InfoStreet groupID', },
;

tie my %vpopmail_options, 'Tie::IxHash',
  #'machine' => { label=>'vpopmail machine', },
  'dir'     => { label=>'directory', }, # ?more info? default?
  'uid'     => { label=>'vpopmail uid' },
  'gid'     => { label=>'vpopmail gid' },
  'restart' => { label=> 'vpopmail restart command',
                 default=> 'cd /home/vpopmail/domains; for domain in *; do /home/vpopmail/bin/vmkpasswd $domain; done; /var/qmail/bin/qmail-newu; killall -HUP qmail-send',
               },
;

tie my %bind_options, 'Tie::IxHash',
  #'machine'     => { label=>'named machine' },
  'named_conf'   => { label  => 'named.conf location',
                      default=> '/etc/bind/named.conf' },
  'zonepath'     => { label => 'path to zone files',
                      default=> '/etc/bind/', },
  'bind_release' => { label => 'ISC BIND Release',
                      type  => 'select',
                      options => [qw(BIND8 BIND9)],
                      default => 'BIND8' },
  'bind9_minttl' => { label => 'The minttl required by bind9 and RFC1035.',
                      default => '1D' },
;

tie my %bind_slave_options, 'Tie::IxHash',
  #'machine'     => { label=> 'Slave machine' },
  'master'       => { label=> 'Master IP address(s) (semicolon-separated)' },
  'named_conf'   => { label   => 'named.conf location',
                      default => '/etc/bind/named.conf' },
  'bind_release' => { label => 'ISC BIND Release',
                      type  => 'select',
                      options => [qw(BIND8 BIND9)],
                      default => 'BIND8' },
  'bind9_minttl' => { label => 'The minttl required by bind9 and RFC1035.',
                      default => '1D' },
;

tie my %http_options, 'Tie::IxHash',
  'method' => { label   =>'Method',
                type    =>'select',
                #options =>[qw(POST GET)],
                options =>[qw(POST)],
                default =>'POST' },
  'url'    => { label   => 'URL', default => 'http://', },
  'insert_data' => {
    label   => 'Insert data',
    type    => 'textarea',
    default => join("\n",
      'DomainName $svc_x->domain',
      'Email ( grep { $_ ne "POST" } $svc_x->cust_svc->cust_pkg->cust_main->invoicing_list)[0]',
      'test 1',
      'reseller $svc_x->cust_svc->cust_pkg->part_pkg->pkg =~ /reseller/i',
    ),
  },
  'delete_data' => {
    label   => 'Delete data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
  'replace_data' => {
    label   => 'Replace data',
    type    => 'textarea',
    default => join("\n",
    ),
  },
;

tie my %sqlmail_options, 'Tie::IxHash',
  'datasrc'            => { label => 'DBI data source' },
  'username'           => { label => 'Database username' },
  'password'           => { label => 'Database password' },
  'server_type'        => {
    label   => 'Server type',
    type    => 'select',
    options => [qw(dovecot_plain dovecot_crypt dovecot_digest_md5 courier_plain
                   courier_crypt)],
    default => ['dovecot_plain'], },
  'svc_acct_table'     => { label => 'User Table', default => 'user_acct' },
  'svc_forward_table'  => { label => 'Forward Table', default => 'forward' },
  'svc_domain_table'   => { label => 'Domain Table', default => 'domain' },
  'svc_acct_fields'    => { label => 'svc_acct Export Fields',
                            default => 'username _password domsvc svcnum' },
  'svc_forward_fields' => { label => 'svc_forward Export Fields',
                            default => 'domain svcnum catchall' },
  'svc_domain_fields'  => { label => 'svc_domain Export Fields',
                            default => 'srcsvc dstsvc dst' },
  'resolve_dstsvc'     => { label => q{Resolve svc_forward.dstsvc to an email address and store it in dst. (Doesn't require that you also export dstsvc.)},
                            type => 'checkbox' },

;

tie my %ldap_options, 'Tie::IxHash',
  'dn'         => { label=>'Root DN' },
  'password'   => { label=>'Root DN password' },
  'userdn'     => { label=>'User DN' },
  'attributes' => { label=>'Attributes',
                    type=>'textarea',
                    default=>join("\n",
                      'uid $username',
                      'mail $username\@$domain',
                      'uidno $uid',
                      'gidno $gid',
                      'cn $first',
                      'sn $last',
                      'mailquota $quota',
                      'vmail',
                      'location',
                      'mailtag',
                      'mailhost',
                      'mailmessagestore $dir',
                      'userpassword $crypt_password',
                      'hint',
                      'answer $sec_phrase',
                      'objectclass top,person,inetOrgPerson',
                    ),
                  },
  'radius'     => { label=>'Export RADIUS attributes', type=>'checkbox', },
;

tie my %forward_shellcommands_options, 'Tie::IxHash',
  'user' => { lable=>'Remote username', default=>'root' },
  'useradd' => { label=>'Insert command',
                 default=>'',
               },
  'userdel'  => { label=>'Delete command',
                  default=>'',
                },
  'usermod'  => { label=>'Modify command',
                  default=>'',
                },
;

#export names cannot have dashes...
%exports = (
  'svc_acct' => {
    'sysvshell' => {
      'desc' =>
        'Batch export of /etc/passwd and /etc/shadow files (Linux/SysV).',
      'options' => \%sysvshell_options,
      'nodomain' => 'Y',
      'notes' => 'MD5 crypt requires installation of <a href="http://search.cpan.org/search?dist=Crypt-PasswdMD5">Crypt::PasswdMD5</a> from CPAN.    Run bin/sysvshell.export to export the files.',
    },
    'bsdshell' => {
      'desc' =>
        'Batch export of /etc/passwd and /etc/master.passwd files (BSD).',
      'options' => \%bsdshell_options,
      'nodomain' => 'Y',
      'notes' => 'MD5 crypt requires installation of <a href="http://search.cpan.org/search?dist=Crypt-PasswdMD5">Crypt::PasswdMD5</a> from CPAN.  Run bin/bsdshell.export to export the files.',
    },
#    'nis' => {
#      'desc' =>
#        'Batch export of /etc/global/passwd and /etc/global/shadow for NIS ',
#      'options' => {},
#    },
    'textradius' => {
      'desc' => 'Real-time export to a text /etc/raddb/users file (Livingston, Cistron)',
      'options' => \%textradius_options,
      'notes' => 'This will edit a text RADIUS users file in place on a remote server.  Requires installation of <a href="http://search.cpan.org/search?dist=RADIUS-UserFile">RADIUS::UserFile</a> from CPAN.  If using RADIUS::UserFile 1.01, make sure to apply <a href="http://rt.cpan.org/NoAuth/Bug.html?id=1210">this patch</a>.  Also make sure <a href="http://rsync.samba.org/">rsync</a> is installed on the remote machine, and <a href="../docs/ssh.html">SSH is setup for unattended operation</a>.',
    },

    'shellcommands' => {
      'desc' => 'Real-time export via remote SSH (i.e. useradd, userdel, etc.)',
      'options' => \%shellcommands_options,
      'nodomain' => 'Y',
      'notes' => 'Run remote commands via SSH.  Usernames are considered unique (also see shellcommands_withdomain).  You probably want this if the commands you are running will not accept a domain as a parameter.  You will need to <a href="../docs/ssh.html">setup SSH for unattended operation</a>.<BR><BR>Use these buttons for some useful presets:<UL><LI><INPUT TYPE="button" VALUE="Linux/NetBSD" onClick=\'this.form.useradd.value = "useradd -c $finger -d $dir -m -s $shell -u $uid -p $crypt_password $username"; this.form.useradd_stdin.value = ""; this.form.userdel.value = "userdel -r $username"; this.form.userdel_stdin.value=""; this.form.usermod.value = "usermod -c $new_finger -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -p $new_crypt_password $old_username"; this.form.usermod_stdin.value = "";\'><LI><INPUT TYPE="button" VALUE="FreeBSD" onClick=\'this.form.useradd.value = "pw useradd $username -d $dir -m -s $shell -u $uid -g $gid -c $finger -h 0"; this.form.useradd_stdin.value = "$_password\n"; this.form.userdel.value = "pw userdel $username -r"; this.form.userdel_stdin.value=""; this.form.usermod.value = "pw usermod $old_username -d $new_dir -m -l $new_username -s $new_shell -u $new_uid -c $new_finger -h 0"; this.form.usermod_stdin.value = "$new__password\n";\'><LI><INPUT TYPE="button" VALUE="Just maintain directories (use with sysvshell or bsdshell)" onClick=\'this.form.useradd.value = "cp -pr /etc/skel $dir; chown -R $uid.$gid $dir"; this.form.useradd_stdin.value = ""; this.form.usermod.value = "[ -d $old_dir ] && mv $old_dir $new_dir || ( chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; find . -depth -print | cpio -pdm $new_dir; chmod u-t $new_dir; chown -R $new_uid.$new_gid $new_dir; rm -rf $old_dir )"; this.form.usermod_stdin.value = ""; this.form.userdel.value = "rm -rf $dir"; this.form.userdel_stdin.value="";\'></UL>The following variables are available for interpolation (prefixed with new_ or old_ for replace operations): <UL><LI><code>$username</code><LI><code>$_password</code><LI><code>$quoted_password</code> - unencrypted password quoted for the shell<LI><code>$crypt_password</code> - encrypted password<LI><code>$uid</code><LI><code>$gid</code><LI><code>$finger</code> - GECOS, already quoted for the shell (do not add additional quotes)<LI><code>$dir</code> - home directory<LI><code>$shell</code><LI><code>$quota</code><LI>All other fields in <a href="../docs/schema.html#svc_acct">svc_acct</a> are also available.</UL>',
    },

    'shellcommands_withdomain' => {
      'desc' => 'Real-time export via remote SSH.',
      'options' => \%shellcommands_withdomain_options,
      'notes' => 'Run remote commands via SSH.  username@domain (rather than just usernames) are considered unique (also see shellcommands).  You probably want this if the commands you are running will accept a domain as a parameter, and will allow the same username with different domains.  You will need to <a href="../docs/ssh.html">setup SSH for unattended operation</a>.<BR><BR>The following variables are available for interpolation (prefixed with <code>new_</code> or <code>old_</code> for replace operations): <UL><LI><code>$username</code><LI><code>$domain</code><LI><code>$_password</code><LI><code>$quoted_password</code> - unencrypted password quoted for the shell<LI><code>$crypt_password</code> - encrypted password<LI><code>$uid</code><LI><code>$gid</code><LI><code>$finger</code> - GECOS, already quoted for the shell (do not add additional quotes)<LI><code>$dir</code> - home directory<LI><code>$shell</code><LI><code>$quota</code><LI>All other fields in <a href="../docs/schema.html#svc_acct">svc_acct</a> are also available.</UL>',
    },

    'ldap' => {
      'desc' => 'Real-time export to LDAP',
      'options' => \%ldap_options,
      'notes' => 'Real-time export to arbitrary LDAP attributes.  Requires installation of <a href="http://search.cpan.org/search?dist=Net-LDAP">Net::LDAP</a> from CPAN.',
    },

    'sqlradius' => {
      'desc' => 'Real-time export to SQL-backed RADIUS (ICRADIUS, FreeRADIUS)',
      'options' => \%sqlradius_options,
      'nodomain' => 'Y',
      'notes' => 'Real-time export of radcheck, radreply and usergroup tables to any SQL database for <a href="http://www.freeradius.org/">FreeRADIUS</a> or <a href="http://radius.innercite.com/">ICRADIUS</a>.  An existing RADIUS database will be updated in realtime, but you can use <a href="../docs/man/bin/freeside-sqlradius-reset">freeside-sqlradius-reset</a> to delete the entire RADIUS database and repopulate the tables from the Freeside database.  See the <a href="http://search.cpan.org/doc/TIMB/DBI-1.23/DBI.pm">DBI documentation</a> and the <a href="http://search.cpan.org/search?mode=module&query=DBD%3A%3A">documentation for your DBD</a> for the exact syntax of a DBI data source.  If using <a href="http://www.freeradius.org/">FreeRADIUS</a> 0.5 or above, make sure your <b>op</b> fields are set to allow NULL values.',
    },

    'sqlmail' => {
      'desc' => 'Real-time export to SQL-backed mail server',
      'options' => \%sqlmail_options,
      'nodomain' => '',
      'notes' => 'Database schema can be made to work with Courier IMAP and Exim.  Others could work but are untested. (...extended description from pc-intouch?...)',
    },

    'cyrus' => {
      'desc' => 'Real-time export to Cyrus IMAP server',
      'options' => \%cyrus_options,
      'nodomain' => 'Y',
      'notes' => 'Integration with <a href="http://asg.web.cmu.edu/cyrus/imapd/">Cyrus IMAP Server</a>.  Cyrus::IMAP::Admin should be installed locally and the connection to the server secured.  <B>svc_acct.quota</B>, if available, is used to set the Cyrus quota. '
    },

    'cp' => {
      'desc' => 'Real-time export to Critical Path Account Provisioning Protocol',
      'options' => \%cp_options,
      'notes' => 'Real-time export to <a href="http://www.cp.net/">Critial Path Account Provisioning Protocol</a>.  Requires installation of <a href="http://search.cpan.org/search?dist=Net-APP">Net::APP</a> from CPAN.',
    },
    
    'infostreet' => {
      'desc' => 'Real-time export to InfoStreet streetSmartAPI',
      'options' => \%infostreet_options,
      'nodomain' => 'Y',
      'notes' => 'Real-time export to <a href="http://www.infostreet.com/">InfoStreet</a> streetSmartAPI.  Requires installation of <a href="http://search.cpan.org/search?dist=Frontier-Client">Frontier::Client</a> from CPAN.',
    },

    'vpopmail' => {
      'desc' => 'Real-time export to vpopmail text files',
      'options' => \%vpopmail_options,
      'notes' => 'Real time export to <a href="http://inter7.com/vpopmail/">vpopmail</a> text files.  <a href="http://search.cpan.org/search?dist=File-Rsync">File::Rsync</a> must be installed, and you will need to <a href="../docs/ssh.html">setup SSH for unattended operation</a> to <b>vpopmail</b>@<i>export.host</i>.',
    },

  },

  'svc_domain' => {

    'bind' => {
      'desc' =>'Batch export to BIND named',
      'options' => \%bind_options,
      'notes' => 'Batch export of BIND zone and configuration files to primary nameserver.  <a href="http://search.cpan.org/search?dist=File-Rsync">File::Rsync</a> must be installed.  Run bin/bind.export to export the files.',
    },

    'bind_slave' => {
      'desc' =>'Batch export to slave BIND named',
      'options' => \%bind_slave_options,
      'notes' => 'Batch export of BIND configuration file to a secondary nameserver.  Zones are slaved from the listed masters.  <a href="http://search.cpan.org/search?dist=File-Rsync">File::Rsync</a> must be installed.  Run bin/bind.export to export the files.',
    },

    'http' => {
      'desc' => 'Send an HTTP or HTTPS GET or POST request',
      'options' => \%http_options,
      'notes' => 'Send an HTTP or HTTPS GET or POST to the specified URL.  <a href="http://search.cpan.org/search?dist=libwww-perl">libwww-perl</a> must be installed.  For HTTPS support, <a href="http://search.cpan.org/search?dist=Crypt-SSLeay">Crypt::SSLeay</a> or <a href="http://search.cpan.org/search?dist=IO-Socket-SSL">IO::Socket::SSL</a> is required.',
    },

    'sqlmail' => {
      'desc' => 'Real-time export to SQL-backed mail server',
      'options' => \%sqlmail_options,
      #'nodomain' => 'Y',
      'notes' => 'Database schema can be made to work with Courier IMAP and Exim.  Others could work but are untested. (...extended description from pc-intouch?...)',
    },

    'domain_shellcommands' => {
      'desc' => 'Run remote commands via SSH, for domains.',
      'options' => \%domain_shellcommands_options,
      'notes'    => 'Run remote commands via SSH, for domains.  You will need to <a href="../docs/ssh.html">setup SSH for unattended operation</a>.<BR><BR>Use these buttons for some useful presets:<UL><LI><INPUT TYPE="button" VALUE="qmail catchall .qmail-domain-default maintenance" onClick=\'this.form.useradd.value = "[ \"$uid\" -a \"$gid\" -a \"$dir\" -a \"$qdomain\" ] && [ -e $dir/.qmail-$qdomain-default ] || { touch $dir/.qmail-$qdomain-default; chown $uid:$gid $dir/.qmail-$qdomain-default; }"; this.form.userdel.value = ""; this.form.usermod.value = "";\'></UL>The following variables are available for interpolation (prefixed with <code>new_</code> or <code>old_</code> for replace operations): <UL><LI><code>$domain</code><LI><code>$qdomain</code> - domain with periods replaced by colons<LI><code>$uid</code> - of catchall account<LI><code>$gid</code> - of catchall account<LI><code>$dir</code> - home directory of catchall account<LI>All other fields in <a href="../docs/schema.html#svc_domain">svc_domain</a> are also available.</UL>',
    },


  },

  'svc_forward' => {
    'sqlmail' => {
      'desc' => 'Real-time export to SQL-backed mail server',
      'options' => \%sqlmail_options,
      #'nodomain' => 'Y',
      'notes' => 'Database schema can be made to work with Courier IMAP and Exim.  Others could work but are untested. (...extended description from pc-intouch?...)',
    },

    'forward_shellcommands' => {
      'desc' => 'Run remote commands via SSH, for forwards',
      'options' => \%forward_shellcommands_options,
      'notes' => 'Run remote commands via SSH, for forwards.  You will need to <a href="../docs/ssh.html">setup SSH for unattended operation</a>.<BR><BR>Use these buttons for some useful presets:<UL><LI><INPUT TYPE="button" VALUE="text vpopmail maintenance" onClick=\'this.form.useradd.value = "[ -d /home/vpopmail/domains/$domain/$username ] && { echo \"$destination\" > /home/vpopmail/domains/$domain/$username/.qmail; chown vpopmail:vchkpw /home/vpopmail/domains/$domain/$username/.qmail; }"; this.form.userdel.value = "rm /home/vpopmail/domains/$domain/$username/.qmail"; this.form.usermod.value = "mv /home/vpopmail/domains/$old_domain/$old_username/.qmail /home/vpopmail/domains/$new_domain/$new_username; [ \"$old_destination\" != \"$new_destination\" ] && { echo \"$new_destination\" > /home/vpopmail/domains/$new_domain/$new_username/.qmail; chown vpopmail:vchkpw /home/vpopmail/domains/$new_domain/$new_username/.qmail; }";\'></UL>The following variables are available for interpolation (prefixed with <code>new_</code> or <code>old_</code> for replace operations): <UL><LI><code>$username</code><LI><code>$domain</code><LI><code>$destination</code> - forward destination<LI>All other fields in <a href="../docs/schema.html#svc_forward">svc_forward</a> are also available.</UL>',
    },
  },

  'svc_www' => {
    'www_shellcommands' => {
      'desc' => 'Run remote commands via SSH, for virtual web sites.',
      'options' => \%www_shellcommands_options,
      'notes'    => 'Run remote commands via SSH, for virtual web sites.  You will need to <a href="../docs/ssh.html">setup SSH for unattended operation</a>.<BR><BR>The following variables are available for interpolation (prefixed with <code>new_</code> or <code>old_</code> for replace operations): <UL><LI><code>$zone</code><LI><code>$username</code><LI><code>$homedir</code><LI>All other fields in <a href="../docs/schema.html#svc_www">svc_www</a> are also available.</UL>',
    },

    'apache' => {
      'desc' => 'Export an Apache httpd.conf file snippet.',
      'options' => \%apache_options,
      'notes' => 'Batch export of an httpd.conf snippet from a template.  Typically used with something like <code>Include /etc/apache/httpd-freeside.conf</code> in httpd.conf.  <a href="http://search.cpan.org/search?dist=File-Rsync">File::Rsync</a> must be installed.  Run bin/apache.export to export the files.',
    },
  },

  'svc_broadband' => {
  },

);

=back

=head1 NEW EXPORT CLASSES

Should be added to the %export hash here, and a module should be added in
FS/FS/part_export/ (an example may be found in eg/export_template.pm)

=head1 BUGS

All the stuff in the %exports hash should be generated from the specific
export modules.

Hmm... cust_export class (not necessarily a database table...) ... ?

deprecated column...

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::export_svc>, L<FS::svc_acct>,
L<FS::svc_domain>,
L<FS::svc_forward>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

