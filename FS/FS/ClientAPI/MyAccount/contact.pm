package FS::ClientAPI::MyAccount::contact;

use strict;
use FS::Record qw( qsearchs );
use FS::cust_main;
use FS::cust_contact;
use FS::contact;

sub _custoragent_session_custnum {
  FS::ClientAPI::MyAccount::_custoragent_session_custnum(@_);
}

sub contact_passwd {
  my $p = shift;
  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  return { 'error' => 'Not logged in as a contact.' }
    unless $session->{'contactnum'};

  return { 'error' => 'Enter new password' }
    unless length($p->{'new_password'});

  my $contact = _contact( $session->{'contactnum'}, $custnum )
    or return { 'error' => "Email not found" };

  my $error = '';

  # use these svc_acct length restrictions??
  my $conf = new FS::Conf;
  $error = 'Password too short.'
    if length($p->{'new_password'}) < ($conf->config('passwordmin') || 6);
  $error = 'Password too long.'
    if length($p->{'new_password'}) > ($conf->config('passwordmax') || 8);

  $error ||= $contact->change_password($p->{'new_password'});

  return { 'error' => $error };

}

sub _contact {
  my( $contactnum, $custnum ) = @_;

  #my $search = { 'custnum' => $custnum };
  #$search->{'agentnum'} = $session->{'agentnum'} if $context eq 'agent';
  $custnum =~ /^(\d+)$/ or die "illegal custnum";
  my $search = " AND contact.selfservice_access IS NOT NULL ".
               " AND contact.selfservice_access = 'Y' ".
               " AND ( disabled IS NULL OR disabled = '' )".
               " AND custnum = $1";
#  $search .= " AND agentnum = ". $session->{'agentnum'} if $context eq 'agent';

  qsearchs( {
    'table'     => 'contact',
    'addl_from' => 'LEFT JOIN cust_main USING ( custnum ) ',
    'hashref'   => { 'contactnum' => $contactnum, },
    'extra_sql' => $search, #important
  } );

}

sub list_contacts {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $cust_main = qsearchs('cust_main', { custnum=>$custnum } );

  my @contacts = ( map {
    my $contact = $_->contact;
    my @contact_email = $_->contact_email;
    { 'contactnum'         => $_->contactnum,
      'class'              => $_->contact_classname,
      'first'              => $_->first,
      'last'               => $_->get('last'),
      'title'              => $_->title,
      'emailaddress'       => join(',', map $_->emailaddress, @contact_email),
      #TODO: contact phone numbers
      'comment'            => $_->comment,
      'selfservice_access' => $_->selfservice_access,
      'disabled'           => $_->disabled,
    };
  } $cust_main->cust_contact );

  return { 'error'    => '',
           'contacts' => \@contacts,
         };
}

sub edit_contact {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  #shortcut: logged in as a contact?  that must be the one you want to edit
  my $contactnum = $p->{contactnum} || $session->{'contactnum'};

  my $contact = _contact( $contactnum, $custnum )
    or return { 'error' => "Email not found" };

  #TODO: change more fields besides just these

  foreach (qw( first last title emailaddress )) {
    $contact->$_( $p->{$_} ) if length( $p->{$_} );
  }

  my $error = $contact->replace;

  return { 'error' => $error, };

}

sub delete_contact {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  my $contact = qsearchs('contact', { contactnum =>$ p->{contactnum},
                                      custnum    => $custnum,         } )
    or return { 'error' => 'Unknown contactnum' };

  my $error = $contact->delete;
  return { 'error' => $error } if $error;

  return { 'error' => '', };
}

1;
