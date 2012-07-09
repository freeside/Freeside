package FS::part_export::acct_xmlrpc;
use base qw( FS::part_export );

use vars qw( %info ); # $DEBUG );
#use Data::Dumper;
use Tie::IxHash;
use Frontier::Client; #to avoid adding a dependency on RPC::XML just now
#use FS::Record qw( qsearch qsearchs );
use FS::Schema qw( dbdef );

#$DEBUG = 1;

tie my %options, 'Tie::IxHash',
  'xmlrpc_url'       => { label => 'XML-RPC URL', },
  'param_style'      => { label   => 'Parameter style',
                          type    => 'select',
                          options => [ 'Individual values',
                                       'Struct of name/value pairs',
                                     ],
                        },
  'insert_method'    => { label => 'Insert method', },
  'insert_params'    => { label => 'Insert parameters', type=>'textarea', },
  'replace_method'   => { label => 'Replace method', },
  'replace_params'   => { label => 'Replace parameters', type=>'textarea', },
  'delete_method'    => { label => 'Delete method', },
  'delete_params'    => { label => 'Delete parameters', type=>'textarea', },
  'suspend_method'   => { label => 'Suspend method', },
  'suspend_params'   => { label => 'Suspend parameters', type=>'textarea', },
  'unsuspend_method' => { label => 'Unsuspend method', },
  'unsuspend_params' => { label => 'Unsuspend parameters', type=>'textarea', },
;

%info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Configurable provisioning of accounts via the XML-RPC protocol',
  'options' => \%options,
  'notes'   => <<'END',
Configurable, real-time export of accounts via the XML-RPC protocol.<BR>
<BR>
If using "Individual values" parameter style, specfify one parameter per line.<BR>
<BR>
If using "Struct of name/value pairs" parameter style, specify one name and
value on each line, separated by whitespace.<BR>
<BR>
The following variables are available for interpolation (prefixed with new_ or
old_ for replace operations):
<UL>
  <LI><code>$username</code>
  <LI><code>$_password</code>
  <LI><code>$crypt_password</code> - encrypted password
  <LI><code>$ldap_password</code> - Password in LDAP/RFC2307 format (for example, "{PLAIN}himom", "{CRYPT}94pAVyK/4oIBk" or "{MD5}5426824942db4253f87a1009fd5d2d4")
  <LI><code>$uid</code>
  <LI><code>$gid</code>
  <LI><code>$finger</code> - Real name
  <LI><code>$dir</code> - home directory
  <LI><code>$shell</code>
  <LI><code>$quota</code>
  <LI><code>@radius_groups</code>
<!--  <LI><code>$reasonnum (when suspending)</code>
  <LI><code>$reasontext (when suspending)</code>
  <LI><code>$reasontypenum (when suspending)</code>
  <LI><code>$reasontypetext (when suspending)</code>
-->
<!--
  <LI><code>$pkgnum</code>
  <LI><code>$custnum</code>
-->
  <LI>All other fields in <b>svc_acct</b> are also available.
<!--  <LI>The following fields from <b>cust_main</b> are also available (except during replace): company, address1, address2, city, state, zip, county, daytime, night, fax, otaker, agent_custid, locale. -->
</UL>

END
);

sub _export_insert    { shift->_export_command('insert',    @_) }
sub _export_delete    { shift->_export_command('delete',    @_) }
sub _export_suspend   { shift->_export_command('suspend',   @_) }
sub _export_unsuspend { shift->_export_command('unsuspend', @_) }

sub _export_command {
  my ( $self, $action, $svc_acct) = (shift, shift, shift);
  my $method = $self->option($action.'_method');
  return '' if $method =~ /^\s*$/;

  my @params = split("\n", $self->option($action.'_params') );

  my( @x_param ) = ();
  my( %x_struct ) = ();
  foreach my $param (@params) {

    my($name, $value) = ('', '');
    if ($self->option('param_style') eq 'Struct of name/value pairs' ) {
      ($name, $value) = split(/\s+/, $param);
    } else { #'Individual values'
      $value = $param;
    }

    if ( $value =~ /^\s*(\$|\@)(\w+)\s*$/ ) {
      $value = $self->_export_value($2, $svc_acct);
    }

    if ($self->option('param_style') eq 'Struct of name/value pairs' ) {
      $x_struct{$name} = $value;
    } else { #'Individual values'
      push @x_param, $value;
    }

  }

  my @x = ();
  if ($self->option('param_style') eq 'Struct of name/value pairs' ) {
    @x = ( \%x_struct );
  } else { #'Individual values'
    @x = @x_param;
  }

  #option to queue (or not) ?

  my $conn = Frontier::Client->new( url => $self->option('xmlrpc_url') );

  my $result = $conn->call($method, @x);

  #XXX error checking?  $result?  from the call?
  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $method = $self->option($action.'_method');
  return '' if $method =~ /^\s*$/;

  my @params = split("\n", $self->option($action.'_params') );

  my( @x_param ) = ();
  my( %x_struct ) = ();
  foreach my $param (@params) {

    my($name, $value) = ('', '');
    if ($self->option('param_style') eq 'Struct of name/value pairs' ) {
      ($name, $value) = split(/\s+/, $param);
    } else { #'Individual values'
      $value = $param;
    }

    if ( $value =~ /^\s*(\$|\@)(old|new)_(\w+)\s*$/ ) {
      if ($2 eq 'old' ) {
        $value = $self->_export_value($3, $old);
      } elsif ( $2 eq 'new' ) {
        $value = $self->_export_value($3, $new);
      } else {
        die 'guru meditation stella blue';
      }
    }

    if ($self->option('param_style') eq 'Struct of name/value pairs' ) {
      $x_struct{$name} = $value;
    } else { #'Individual values'
      push @x_param, $value;
    }

  }

  my @x = ();
  if ($self->option('param_style') eq 'Struct of name/value pairs' ) {
    @x = ( \%x_struct );
  } else { #'Individual values'
    @x = @x_param;
  }

  #option to queue (or not) ?

  my $conn = Frontier::Client->new( url => $self->option('xmlrpc_url') );

  my $result = $conn->call($method, @x);

  #XXX error checking?  $result?  from the call?
  '';

}

#comceptual false laziness w/shellcommands.pm
sub _export_value {
  my( $self, $value, $svc_acct) = (shift, shift, shift);

  my %fields = map { $_=>1 } $svc_acct->fields;

  if ( $fields{$value} ) {
    my $type = dbdef->table('svc_acct')->column($value)->type;
    if ( $type =~ /^(int|serial)/i ) {
      return Frontier::Client->new->int( $svc_acct->$value() );
    } elsif ( $value =~ /^last_log/ ) {
      return Frontier::Client->new->date_time( $svc_acct->$value() ); #conversion?
    } else {
      return Frontier::Client->new->string( $svc_acct->$value() );
    }
  } elsif ( $value eq 'domain' ) {
    return Frontier::Client->new->string( $svc_acct->domain );
  } elsif ( $value eq 'crypt_password' ) {
    return Frontier::Client->new->string( $svc_acct->crypt_password( $self->option('crypt') ) );
  } elsif ( $value eq 'ldap_password' ) {
    return Frontier::Client->new->string( $svc_acct->ldap_password($self->option('crypt') ) );
  } elsif ( $value eq 'radius_groups' ) {
    my @radius_groups = $svc_acct->radius_groups;
    #XXX
  }

#  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
#  if ( $cust_pkg ) {
#    no strict 'vars';
#    {
#      no strict 'refs';
#      foreach my $custf (qw( company address1 address2 city state zip country
#                             daytime night fax otaker agent_custid locale
#                        ))
#      {
#        ${$custf} = $cust_pkg->cust_main->$custf();
#      }
#    }
#    $email = ( grep { $_ !~ /^(POST|FAX)$/ } $cust_pkg->cust_main->invoicing_list )[0];
#  } else {
#    $email = '';
#  }

#  my ($reasonnum, $reasontext, $reasontypenum, $reasontypetext);
#  if ( $cust_pkg && $action eq 'suspend' &&
#       (my $r = $cust_pkg->last_reason('susp')) )
#  {
#    $reasonnum = $r->reasonnum;
#    $reasontext = $r->reason;
#    $reasontypenum = $r->reason_type;
#    $reasontypetext = $r->reasontype->type;
#
#    my %reasonmap = $self->_groups_susp_reason_map;
#    my $userspec = '';
#    $userspec = $reasonmap{$reasonnum}
#      if exists($reasonmap{$reasonnum});
#    $userspec = $reasonmap{$reasontext}
#      if (!$userspec && exists($reasonmap{$reasontext}));
#
#    my $suspend_user;
#    if ( $userspec =~ /^\d+$/ ) {
#      $suspend_user = qsearchs( 'svc_acct', { 'svcnum' => $userspec } );
#    } elsif ( $userspec =~ /^\S+\@\S+$/ ) {
#      my ($username,$domain) = split(/\@/, $userspec);
#      for my $user (qsearch( 'svc_acct', { 'username' => $username } )){
#        $suspend_user = $user if $userspec eq $user->email;
#      }
#    } elsif ($userspec) {
#      $suspend_user = qsearchs( 'svc_acct', { 'username' => $userspec } );
#    }
#  
#  @radius_groups = $suspend_user->radius_groups
#    if $suspend_user;  
#  
#  } else {
#    $reasonnum = $reasontext = $reasontypenum = $reasontypetext = '';
#  }

#  $pkgnum = $cust_pkg ? $cust_pkg->pkgnum : '';
#  $custnum = $cust_pkg ? $cust_pkg->custnum : '';

  '';

}

1;

