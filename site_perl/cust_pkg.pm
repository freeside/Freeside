package FS::cust_pkg;

use strict;
use vars qw(@ISA);
use Exporter;
use FS::UID qw(getotaker);
use FS::Record qw(fields qsearch qsearchs);
use FS::cust_svc;

@ISA = qw(FS::Record Exporter);

=head1 NAME

FS::cust_pkg - Object methods for cust_pkg objects

=head1 SYNOPSIS

  use FS::cust_pkg;

  $record = create FS::cust_pkg \%hash;
  $record = create FS::cust_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->cancel;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = FS::cust_pkg::order( $custnum, \@pkgparts );
  $error = FS::cust_pkg::order( $custnum, \@pkgparts, \@remove_pkgnums ] );

=head1 DESCRIPTION

An FS::cust_pkg object represents a customer billing item.  FS::cust_pkg
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item pkgnum - primary key (assigned automatically for new billing items)

=item custnum - Customer (see L<FS::cust_main>)

=item pkgpart - Billing item definition (see L<FS::part_pkg>)

=item setup - date

=item bill - date

=item susp - date

=item expire - date

=item cancel - date

=item otaker - order taker (assigned automatically if null, see L<FS::UID>)

=back

Note: setup, bill, susp, expire and cancel are specified as UNIX timestamps;
see L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for
conversion functions.

=head1 METHODS

=over 4

=item create HASHREF

Create a new billing item.  To add the item to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('cust_pkg')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('cust_pkg',$hashref);
}

=item insert

Adds this billing item to the database ("Orders" the item).  If there is an
error, returns the error, otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Currently unimplemented.  You don't want to delete billing items, because there
would then be no record the customer ever purchased the item.  Instead, see
the cancel method.

sub delete {
  return "Can't delete cust_pkg records!";
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Currently, custnum, setup, bill, susp, expire, and cancel may be changed.

pkgpart may not be changed, but see the order subroutine.

setup and bill are normally updated by calling the bill method of a customer
object (see L<FS::cust_main>).

suspend is normally updated by the suspend and unsuspend methods.

cancel is normally updated by the cancel method (and also the order subroutine
in some cases).

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a cust_pkg record!" if $old->table ne "cust_pkg";
  return "Can't change pkgnum!"
    if $old->getfield('pkgnum') ne $new->getfield('pkgnum');
  return "Can't (yet?) change pkgpart!"
    if $old->getfield('pkgpart') ne $new->getfield('pkgpart');
  return "Can't change otaker!"
    if $old->getfield('otaker') ne $new->getfield('otaker');
  return "Can't change setup once it exists!"
    if $old->getfield('setup') &&
       $old->getfield('setup') != $new->getfield('setup');
  #some logic for bill, susp, cancel?

  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid billing item.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my($self)=@_;
  return "Not a cust_pkg record!" if $self->table ne "cust_pkg";
  my($recref) = $self->hashref;

  $recref->{pkgnum} =~ /^(\d*)$/ or return "Illegal pkgnum";
  $recref->{pkgnum}=$1;

  $recref->{custnum} =~ /^(\d+)$/ or return "Illegal custnum";
  $recref->{custnum}=$1;
  return "Unknown customer"
    unless qsearchs('cust_main',{'custnum'=>$recref->{custnum}});

  $recref->{pkgpart} =~ /^(\d+)$/ or return "Illegal pkgpart";
  $recref->{pkgpart}=$1;
  return "Unknown pkgpart"
    unless qsearchs('part_pkg',{'pkgpart'=>$recref->{pkgpart}});

  $recref->{otaker} ||= &getotaker;
  $recref->{otaker} =~ /^(\w{0,8})$/ or return "Illegal otaker";
  $recref->{otaker}=$1;

  $recref->{setup} =~ /^(\d*)$/ or return "Illegal setup date";
  $recref->{setup}=$1;

  $recref->{bill} =~ /^(\d*)$/ or return "Illegal bill date";
  $recref->{bill}=$1;

  $recref->{susp} =~ /^(\d*)$/ or return "Illegal susp date";
  $recref->{susp}=$1;

  $recref->{cancel} =~ /^(\d*)$/ or return "Illegal cancel date";
  $recref->{cancel}=$1;

  ''; #no error
}

=item cancel

Cancels and removes all services (see L<FS::cust_svc> and L<FS::part_svc>)
in this package, then cancels the package itself (sets the cancel field to
now).

If there is an error, returns the error, otherwise returns false.

=cut

sub cancel {
  my($self)=@_;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  my($cust_svc);
  foreach $cust_svc (
    qsearch('cust_svc',{'pkgnum'=> $self->pkgnum } )
  ) {
    my($part_svc)=
      qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );

    $part_svc->getfield('svcdb') =~ /^([\w\-]+)$/
      or return "Illegal svcdb value in part_svc!";
    my($svcdb) = $1;
    require "FS/$svcdb.pm";

    my($svc) = qsearchs($svcdb,{'svcnum' => $cust_svc->svcnum } );
    if ($svc) {
      bless($svc,"FS::$svcdb");
      $error = $svc->cancel;
      return "Error cancelling service: $error" if $error;
      $error = $svc->delete;
      return "Error deleting service: $error" if $error;
    }

    bless($cust_svc,"FS::cust_svc");
    $error = $cust_svc->delete;
    return "Error deleting cust_svc: $error" if $error;

  }

  unless ( $self->getfield('cancel') ) {
    my(%hash) = $self->hash;
    $hash{'cancel'}=$^T;
    my($new) = create FS::cust_pkg ( \%hash );
    $error=$new->replace($self);
    return $error if $error;
  }

  ''; #no errors
}

=item suspend

Suspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then suspends the package itself (sets the susp field to now).

If there is an error, returns the error, otherwise returns false.

=cut

sub suspend {
  my($self)=@_;
  my($error);
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  my($cust_svc);
  foreach $cust_svc (
    qsearch('cust_svc',{'pkgnum'=> $self->getfield('pkgnum') } )
  ) {
    my($part_svc)=
      qsearchs('part_svc',{'svcpart'=> $cust_svc->getfield('svcpart') } );

    $part_svc->getfield('svcdb') =~ /^([\w\-]+)$/
      or return "Illegal svcdb value in part_svc!";
    my($svcdb) = $1;
    require "FS/$svcdb.pm";

    my($svc) = qsearchs($svcdb,{'svcnum' => $cust_svc->getfield('svcnum') } );

    if ($svc) {
      bless($svc,"FS::$svcdb");
      $error = $svc->suspend;
      return $error if $error;
    }

  }

  unless ( $self->getfield('susp') ) {
    my(%hash) = $self->hash;
    $hash{'susp'}=$^T;
    my($new) = create FS::cust_pkg ( \%hash );
    $error=$new->replace($self);
    return $error if $error;
  }

  ''; #no errors
}

=item unsuspend

Unsuspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then unsuspends the package itself (clears the susp field).

If there is an error, returns the error, otherwise returns false.

=cut

sub unsuspend {
  my($self)=@_;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  my($cust_svc);
  foreach $cust_svc (
    qsearch('cust_svc',{'pkgnum'=> $self->getfield('pkgnum') } )
  ) {
    my($part_svc)=
      qsearchs('part_svc',{'svcpart'=> $cust_svc->getfield('svcpart') } );

    $part_svc->getfield('svcdb') =~ /^([\w\-]+)$/
      or return "Illegal svcdb value in part_svc!";
    my($svcdb) = $1;
    require "FS/$svcdb.pm";

    my($svc) = qsearchs($svcdb,{'svcnum' => $cust_svc->getfield('svcnum') } );
    if ($svc) {
      bless($svc,"FS::$svcdb");
      $error = $svc->unsuspend;
      return $error if $error;
    }

  }

  unless ( ! $self->getfield('susp') ) {
    my(%hash) = $self->hash;
    $hash{'susp'}='';
    my($new) = create FS::cust_pkg ( \%hash );
    $error=$new->replace($self);
    return $error if $error;
  }

  ''; #no errors
}

=back

=head1 SUBROUTINES

=over 4

=item order CUSTNUM, PKGPARTS_ARYREF, [ REMOVE_PKGNUMS_ARYREF ]

CUSTNUM is a customer (see L<FS::cust_main>)

PKGPARTS is a list of pkgparts specifying the the billing item definitions (see
L<FS::part_pkg>) to order for this customer.  Duplicates are of course
permitted.

REMOVE_PKGNUMS is an optional list of pkgnums specifying the billing items to
remove for this customer.  The services (see L<FS::cust_svc>) are moved to the
new billing items.  An error is returned if this is not possible (see
L<FS::pkg_svc>).

=cut

sub order {
  my($custnum,$pkgparts,$remove_pkgnums)=@_;

  my(%part_pkg);
  # generate %part_pkg
  # $part_pkg{$pkgpart} is true iff $custnum may purchase $pkgpart
    my($cust_main)=qsearchs('cust_main',{'custnum'=>$custnum});
    my($agent)=qsearchs('agent',{'agentnum'=> $cust_main->agentnum });

    my($type_pkgs);
    foreach $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
      my($pkgpart)=$type_pkgs->pkgpart;
      $part_pkg{$pkgpart}++;
    }
  #

  my(%svcnum);
  # generate %svcnum
  # for those packages being removed:
  #@{ $svcnum{$svcpart} } goes from a svcpart to a list of FS::Record
  # objects (table eq 'cust_svc')
  my($pkgnum);
  foreach $pkgnum ( @{$remove_pkgnums} ) {
    my($cust_svc);
    foreach $cust_svc (qsearch('cust_svc',{'pkgnum'=>$pkgnum})) {
      push @{ $svcnum{$cust_svc->getfield('svcpart')} }, $cust_svc;
    }
  }
  
  my(@cust_svc);
  #generate @cust_svc
  # for those packages the customer is purchasing:
  # @{$pkgparts} is a list of said packages, by pkgpart
  # @cust_svc is a corresponding list of lists of FS::Record objects
  my($pkgpart);
  foreach $pkgpart ( @{$pkgparts} ) {
    return "Customer not permitted to purchase pkgpart $pkgpart!"
      unless $part_pkg{$pkgpart};
    push @cust_svc, [
      map {
        ( $svcnum{$_} && @{ $svcnum{$_} } ) ? shift @{ $svcnum{$_} } : ();
      } (split(/,/,
       qsearchs('part_pkg',{'pkgpart'=>$pkgpart})->getfield('services')
      ))
    ];
  }

  #check for leftover services
  foreach (keys %svcnum) {
    next unless @{ $svcnum{$_} };
    return "Leftover services!";
  }

  #no leftover services, let's make changes.
 
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE'; 
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE'; 

  #first cancel old packages
#  my($pkgnum);
  foreach $pkgnum ( @{$remove_pkgnums} ) {
    my($old) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
    return "Package $pkgnum not found to remove!" unless $old;
    my(%hash) = $old->hash;
    $hash{'cancel'}=$^T;   
    my($new) = create FS::cust_pkg ( \%hash );
    my($error)=$new->replace($old);
    return $error if $error;
  }

  #now add new packages, changing cust_svc records if necessary
#  my($pkgpart);
  while ($pkgpart=shift @{$pkgparts} ) {
 
    my($new) = create FS::cust_pkg ( {
                                       'custnum' => $custnum,
                                       'pkgpart' => $pkgpart,
                                    } );
    my($error) = $new->insert;
    return $error if $error; 
    my($pkgnum)=$new->getfield('pkgnum');
 
    my($cust_svc);
    foreach $cust_svc ( @{ shift @cust_svc } ) {
      my(%hash) = $cust_svc->hash;
      $hash{'pkgnum'}=$pkgnum;
      my($new) = create FS::cust_svc ( \%hash );
      my($error)=$new->replace($cust_svc);
      return $error if $error;
    }
  }  

  ''; #no errors
}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

sub order is not OO.  Perhaps it should be moved to FS::cust_main and made so?

In sub order, the @pkgparts array (passed by reference) is clobbered.

Also in sub order, no money is adjusted.  Once FS::part_pkg defines a standard
method to pass dates to the recur_prog expression, it should do so.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::part_pkg>, L<FS::cust_svc>
, L<FS::pkg_svc>, schema.html from the base documentation

=head1 HISTORY

ivan@voicenet.com 97-jul-1 - 21

fixed for new agent->agent_type->type_pkgs in &order ivan@sisd.com 98-mar-7

pod ivan@sisd.com 98-sep-21

=cut

1;

