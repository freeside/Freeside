package FS::quotation;
use base qw( FS::Template_Mixin FS::cust_main_Mixin FS::otaker_Mixin FS::Record
           );

use strict;
use FS::CurrentUser;

=head1 NAME

FS::quotation - Object methods for quotation records

=head1 SYNOPSIS

  use FS::quotation;

  $record = new FS::quotation \%hash;
  $record = new FS::quotation { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation object represents a quotation.  FS::quotation inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item quotationnum

primary key

=item prospectnum

prospectnum

=item custnum

custnum

=item _date

_date

=item disabled

disabled

=item usernum

usernum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new quotation.  To add the quotation to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'quotation'; }
sub notice_name { 'Quotation'; }
sub template_conf { 'quotation_'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid quotation.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('quotationnum')
    || $self->ut_foreign_keyn('prospectnum', 'prospect_main', 'prospectnum' )
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'custnum' )
    || $self->ut_numbern('_date')
    || $self->ut_enum('disabled', [ '', 'Y' ])
    || $self->ut_numbern('usernum')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  $self->SUPER::check;
}

=item prospect_main

=item cust_main

=item cust_bill_pkg

=cut

sub cust_bill_pkg { #actually quotation_pkg objects
  shift->quotation_pkg(@_);
}

=item total_setup

=cut

sub total_setup {
  my $self = shift;
  $self->_total('setup');
}

=item total_recur [ FREQ ]

=cut

sub total_recur {
  my $self = shift;
#=item total_recur [ FREQ ]
  #my $freq = @_ ? shift : '';
  $self->_total('recur');
}

sub _total {
  my( $self, $method ) = @_;

  my $total = 0;
  $total += $_->$method() for $self->cust_bill_pkg;
  sprintf('%.2f', $total);

}

#prevent things from falsely showing up as taxes, at least until we support
# quoting tax amounts..
sub _items_tax {
  return ();
}
sub _items_nontax {
  shift->cust_bill_pkg;
}

sub _items_total {
  my( $self, $total_items ) = @_;

  if ( $self->total_setup > 0 ) {
    push @$total_items, {
      'total_item'   => $self->mt( $self->total_recur > 0 ? 'Total Setup' : 'Total' ),
      'total_amount' => $self->total_setup,
    };
  }

  #could/should add up the different recurring frequencies on lines of their own
  # but this will cover the 95% cases for now
  if ( $self->total_recur > 0 ) {
    push @$total_items, {
      'total_item'   => $self->mt('Total Recurring'),
      'total_amount' => $self->total_recur,
    };
  }

}

=item enable_previous

=cut

sub enable_previous { 0 }

=back

=head1 CLASS METHODS

=over 4


=item search_sql_where HASHREF

Class method which returns an SQL WHERE fragment to search for parameters
specified in HASHREF.  Valid parameters are

=over 4

=item _date

List reference of start date, end date, as UNIX timestamps.

=item invnum_min

=item invnum_max

=item agentnum

=item charged

List reference of charged limits (exclusive).

=item owed

List reference of charged limits (exclusive).

=item open

flag, return open invoices only

=item net

flag, return net invoices only

=item days

=item newest_percust

=back

Note: validates all passed-in data; i.e. safe to use with unchecked CGI params.

=cut

sub search_sql_where {
  my($class, $param) = @_;
  #if ( $DEBUG ) {
  #  warn "$me search_sql_where called with params: \n".
  #       join("\n", map { "  $_: ". $param->{$_} } keys %$param ). "\n";
  #}

  my @search = ();

  #agentnum
  if ( $param->{'agentnum'} =~ /^(\d+)$/ ) {
    push @search, "( prospect_main.agentnum = $1 OR cust_main.agentnum = $1 )";
  }

#  #refnum
#  if ( $param->{'refnum'} =~ /^(\d+)$/ ) {
#    push @search, "cust_main.refnum = $1";
#  }

  #prospectnum
  if ( $param->{'prospectnum'} =~ /^(\d+)$/ ) {
    push @search, "quotation.prospectnum = $1";
  }

  #custnum
  if ( $param->{'custnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_bill.custnum = $1";
  }

  #_date
  if ( $param->{_date} ) {
    my($beginning, $ending) = @{$param->{_date}};

    push @search, "quotation._date >= $beginning",
                  "quotation._date <  $ending";
  }

  #quotationnum
  if ( $param->{'quotationnum_min'} =~ /^(\d+)$/ ) {
    push @search, "quotation.quotationnum >= $1";
  }
  if ( $param->{'quotationnum_max'} =~ /^(\d+)$/ ) {
    push @search, "quotation.quotationnum <= $1";
  }

#  #charged
#  if ( $param->{charged} ) {
#    my @charged = ref($param->{charged})
#                    ? @{ $param->{charged} }
#                    : ($param->{charged});
#
#    push @search, map { s/^charged/cust_bill.charged/; $_; }
#                      @charged;
#  }

  my $owed_sql = FS::cust_bill->owed_sql;

  #days
  push @search, "quotation._date < ". (time-86400*$param->{'days'})
    if $param->{'days'};

  #agent virtualization
  my $curuser = $FS::CurrentUser::CurrentUser;
  #false laziness w/search/quotation.html
  push @search,' (    '. $curuser->agentnums_sql( table=>'prospect_main' ).
               '   OR '. $curuser->agentnums_sql( table=>'cust_main' ).
               ' )    ';

  join(' AND ', @search );

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

