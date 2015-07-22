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
  my $search = " AND cust_contact.selfservice_access IS NOT NULL ".
               " AND cust_contact.selfservice_access = 'Y' ".
               " AND ( disabled IS NULL OR disabled = '' )".
               " AND cust_contact.custnum IS NOT NULL AND cust_contact.custnum = $1";
#  $search .= " AND agentnum = ". $session->{'agentnum'} if $context eq 'agent';

  qsearchs( {
    'table'     => 'contact',
    #'addl_from' => 'LEFT JOIN cust_main USING ( custnum ) ',
    'addl_from' => ' LEFT JOIN cust_contact USING ( contactnum ) '.
                   ' LEFT JOIN cust_main ON ( cust_contact.custnum = cust_main.custnum ) ',
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
    my @contact_email = $contact->contact_email;
    { 'contactnum'         => $contact->contactnum,
      'class'              => $_->contact_classname,
      'first'              => $contact->first,
      'last'               => $contact->get('last'),
      'title'              => $contact->title,
      'emailaddress'       => join(',', map $_->emailaddress, @contact_email),
      #TODO: contact phone numbers
      'comment'            => $_->comment,
      'selfservice_access' => $_->selfservice_access,
      #'disabled'           => $contact->disabled,
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

  return { error => "Can't edit a multi-customer contact unless logged in as that contact" }
    if $contactnum != $session->{'contactnum'}
    && scalar( $contact->cust_contact ) > 1;

  #my $cust_contact = qsearchs('cust_contact', { contactnum => $contactnum,
  #                                              custnum    => $custnum,    } )
  #  or die "guru meditation #4200";

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

  return { 'error' => 'Cannot delete the currently-logged in contact.' }
    if $p->{contactnum} == $session->{contactnum};

  my $cust_contact = qsearchs('cust_contact', { contactnum => $p->{contactnum},
                                                custnum    => $custnum,       })
    or return { 'error' => 'Unknown contactnum' };

  my $contact = $cust_contact->contact;

  my $error = $cust_contact->delete;
  return { 'error' => $error } if $error;

  unless ( $contact->cust_contact ) {
    $contact->delete;
  }

  return { 'error' => '', };
}

sub new_contact {
  my $p = shift;

  my($context, $session, $custnum) = _custoragent_session_custnum($p);
  return { 'error' => $session } if $context eq 'error';

  #TODO: add phone numbers too
  #TODO: specify a classnum by name and/or list_contact_classes method

  my $contact = new FS::contact {
    'custnum' => $custnum,
    map { $_ => $p->{$_} }
      qw( first last emailaddress classnum comment selfservice_access )
  };

  $contact->change_password_fields($p->{_password}) if length($p->{_password});

  my $error = $contact->insert;
  return { 'error' => $error, };
}

1;
