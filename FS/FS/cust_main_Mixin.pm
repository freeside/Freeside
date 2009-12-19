package FS::cust_main_Mixin;

use strict;
use vars qw( $DEBUG $me );
use Carp qw( confess );
use FS::UID qw(dbh);
use FS::cust_main;

$DEBUG = 0;
$me = '[FS::cust_main_Mixin]';

=head1 NAME

FS::cust_main_Mixin - Mixin class for records that contain fields from cust_main

=head1 SYNOPSIS

package FS::some_table;
use vars qw(@ISA);
@ISA = qw( FS::cust_main_Mixin FS::Record );

=head1 DESCRIPTION

This is a mixin class for records that contain fields from the cust_main table,
for example, from a JOINed search.  See httemplate/search/ for examples.

=head1 METHODS

=over 4

=cut

sub cust_unlinked_msg { '(unlinked)'; }
sub cust_linked { $_[0]->custnum; }

=item display_custnum

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<name> method, or "(unlinked)" if this object is not linked to
a customer.

=cut

sub display_custnum {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::display_custnum($self)
    : $self->cust_unlinked_msg;
}

=item name

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<name> method, or "(unlinked)" if this object is not linked to
a customer.

=cut

sub name {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::name($self)
    : $self->cust_unlinked_msg;
}

=item ship_name

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ship_name> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ship_name {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::ship_name($self)
    : $self->cust_unlinked_msg;
}

=item contact

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<contact> method, or "(unlinked)" if this object is not linked
to a customer.

=cut

sub contact {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::contact($self)
    : $self->cust_unlinked_msg;
}

=item ship_contact

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ship_contact> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ship_contact {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::ship_contact($self)
    : $self->cust_unlinked_msg;
}

=item country_full

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<country_full> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub country_full {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::country_full($self)
    : $self->cust_unlinked_msg;
}

=item invoicing_list_emailonly

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<invoicing_list_emailonly> method, or "(unlinked)" if this
object is not linked to a customer.

=cut

sub invoicing_list_emailonly {
  my $self = shift;
  warn "invoicing_list_email only called on $self, ".
       "custnum ". $self->custnum. "\n"
    if $DEBUG;
  $self->cust_linked
    ? FS::cust_main::invoicing_list_emailonly($self)
    : $self->cust_unlinked_msg;
}

=item invoicing_list_emailonly_scalar

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<invoicing_list_emailonly_scalar> method, or "(unlinked)" if
this object is not linked to a customer.

=cut

sub invoicing_list_emailonly_scalar {
  my $self = shift;
  warn "invoicing_list_emailonly called on $self, ".
       "custnum ". $self->custnum. "\n"
    if $DEBUG;
  $self->cust_linked
    ? FS::cust_main::invoicing_list_emailonly_scalar($self)
    : $self->cust_unlinked_msg;
}

=item invoicing_list

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<invoicing_list> method, or "(unlinked)" if this object is not
linked to a customer.

Note: this method is read-only.

=cut

#read-only
sub invoicing_list {
  my $self = shift;
  $self->cust_linked
    ? FS::cust_main::invoicing_list($self)
    : ();
}

=item status

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<status> method, or "(unlinked)" if this object is not linked to
a customer.

=cut

sub cust_status {
  my $self = shift;
  return $self->cust_unlinked_msg unless $self->cust_linked;

  #FS::cust_main::status($self)
  #false laziness w/actual cust_main::status
  # (make sure FS::cust_main methods are called)
  for my $status (qw( prospect active inactive suspended cancelled )) {
    my $method = $status.'_sql';
    my $sql = FS::cust_main->$method();;
    my $numnum = ( $sql =~ s/cust_main\.custnum/?/g );
    my $sth = dbh->prepare("SELECT $sql") or die dbh->errstr;
    $sth->execute( ($self->custnum) x $numnum )
      or die "Error executing 'SELECT $sql': ". $sth->errstr;
    return $status if $sth->fetchrow_arrayref->[0];
  }
}

=item ucfirst_cust_status

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<ucfirst_status> method, or "(unlinked)" if this object is not
linked to a customer.

=cut

sub ucfirst_cust_status {
  my $self = shift;
  $self->cust_linked
    ? ucfirst( $self->cust_status(@_) ) 
    : $self->cust_unlinked_msg;
}

=item cust_statuscolor

Given an object that contains fields from cust_main (say, from a JOINed
search; see httemplate/search/ for examples), returns the equivalent of the
FS::cust_main I<statuscol> method, or "000000" if this object is not linked to
a customer.

=cut

sub cust_statuscolor {
  my $self = shift;

  $self->cust_linked
    ? FS::cust_main::cust_statuscolor($self)
    : '000000';
}

=item prospect_sql

=item active_sql

=item inactive_sql

=item suspended_sql

=item cancelled_sql

Class methods that return SQL framents, equivalent to the corresponding
FS::cust_main method.

=cut

#      my \$self = shift;
#      \$self->cust_linked
#        ? FS::cust_main::${sub}_sql(\$self)
#        : '0';

foreach my $sub (qw( prospect active inactive suspended cancelled )) {
  eval "
    sub ${sub}_sql {
      confess 'cust_main_Mixin ${sub}_sql called with object' if ref(\$_[0]);
      'cust_main.custnum IS NOT NULL AND '. FS::cust_main->${sub}_sql();
    }
  ";
  die $@ if $@;
}

=item cust_search_sql

Returns a list of SQL WHERE fragments to search for parameters specified
in HASHREF.  Valid parameters are:

=over 4

=item agentnum

=item status

=item payby

=back

=cut

sub cust_search_sql {
  my($class, $param) = @_;

  if ( $DEBUG ) {
    warn "$me cust_search_sql called with params: \n".
         join("\n", map { "  $_: ". $param->{$_} } keys %$param ). "\n";
  }

  my @search = ();

  if ( $param->{'agentnum'} && $param->{'agentnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_main.agentnum = $1";
  }

  #status (prospect active inactive suspended cancelled)
  if ( grep { $param->{'status'} eq $_ } FS::cust_main->statuses() ) {
    my $method = $param->{'status'}. '_sql';
    push @search, $class->$method();
  }

  #payby
  my @payby = ref($param->{'payby'})
                ? @{ $param->{'payby'} }
                : split(',', $param->{'payby'});
  @payby = grep /^([A-Z]{4})$/, @payby;
  if ( @payby ) {
    push @search, 'cust_main.payby IN ('. join(',', map "'$_'", @payby). ')';
  }

  #here is the agent virtualization
  push @search,
    $FS::CurrentUser::CurrentUser->agentnums_sql( 'table' => 'cust_main' );
  
  return @search;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

