package FS::cust_bill_pkg;
use base qw( FS::TemplateItem_Mixin FS::cust_main_Mixin FS::Record );

use strict;
use vars qw( @ISA $DEBUG $me );
use Carp;
use List::Util qw( sum min );
use Text::CSV_XS;
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_pkg;
use FS::cust_bill;
use FS::cust_bill_pkg_detail;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pkg_discount;
use FS::cust_bill_pkg_fee;
use FS::cust_bill_pay_pkg;
use FS::cust_credit_bill_pkg;
use FS::cust_tax_exempt_pkg;
use FS::cust_bill_pkg_tax_location;
use FS::cust_bill_pkg_tax_rate_location;
use FS::cust_tax_adjustment;
use FS::cust_bill_pkg_void;
use FS::cust_bill_pkg_detail_void;
use FS::cust_bill_pkg_display_void;
use FS::cust_bill_pkg_discount_void;
use FS::cust_bill_pkg_tax_location_void;
use FS::cust_bill_pkg_tax_rate_location_void;
use FS::cust_tax_exempt_pkg_void;
use FS::part_fee;

use FS::Cursor;

$DEBUG = 0;
$me = '[FS::cust_bill_pkg]';

=head1 NAME

FS::cust_bill_pkg - Object methods for cust_bill_pkg records

=head1 SYNOPSIS

  use FS::cust_bill_pkg;

  $record = new FS::cust_bill_pkg \%hash;
  $record = new FS::cust_bill_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg object represents an invoice line item.
FS::cust_bill_pkg inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item billpkgnum

primary key

=item invnum

invoice (see L<FS::cust_bill>)

=item pkgnum

package (see L<FS::cust_pkg>) or 0 for the special virtual sales tax package, or -1 for the virtual line item (itemdesc is used for the line)

=item pkgpart_override

optional package definition (see L<FS::part_pkg>) override

=item setup

setup fee

=item recur

recurring fee

=item sdate

starting date of recurring fee

=item edate

ending date of recurring fee

=item itemdesc

Line item description (overrides normal package description)

=item quantity

If not set, defaults to 1

=item unitsetup

If not set, defaults to setup

=item unitrecur

If not set, defaults to recur

=item hidden

If set to Y, indicates data should not appear as separate line item on invoice

=back

sdate and edate are specified as UNIX timestamps; see L<perlfunc/"time">.  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new line item.  To add the line item to the database, see
L<"insert">.  Line items are normally created by calling the bill method of a
customer object (see L<FS::cust_main>).

=cut

sub table { 'cust_bill_pkg'; }

sub detail_table            { 'cust_bill_pkg_detail'; }
sub display_table           { 'cust_bill_pkg_display'; }
sub discount_table          { 'cust_bill_pkg_discount'; }
#sub tax_location_table      { 'cust_bill_pkg_tax_location'; }
#sub tax_rate_location_table { 'cust_bill_pkg_tax_rate_location'; }
#sub tax_exempt_pkg_table    { 'cust_tax_exempt_pkg'; }

=item insert

Adds this line item to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
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

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->get('details') ) {
    foreach my $detail ( @{$self->get('details')} ) {
      $detail->billpkgnum($self->billpkgnum);
      $error = $detail->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_bill_pkg_detail: $error";
      }
    }
  }

  if ( $self->get('display') ) {
    foreach my $cust_bill_pkg_display ( @{ $self->get('display') } ) {
      $cust_bill_pkg_display->billpkgnum($self->billpkgnum);
      $error = $cust_bill_pkg_display->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_bill_pkg_display: $error";
      }
    }
  }

  if ( $self->get('discounts') ) {
    foreach my $cust_bill_pkg_discount ( @{$self->get('discounts')} ) {
      $cust_bill_pkg_discount->billpkgnum($self->billpkgnum);
      $error = $cust_bill_pkg_discount->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_bill_pkg_discount: $error";
      }
    }
  }

  foreach my $cust_tax_exempt_pkg ( @{$self->cust_tax_exempt_pkg} ) {
    $cust_tax_exempt_pkg->billpkgnum($self->billpkgnum);
    $error = $cust_tax_exempt_pkg->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error inserting cust_tax_exempt_pkg: $error";
    }
  }

  my $tax_location = $self->get('cust_bill_pkg_tax_location');
  if ( $tax_location ) {
    foreach my $link ( @$tax_location ) {
      next if $link->billpkgtaxlocationnum; # don't try to double-insert
      # This cust_bill_pkg can be linked on either side (i.e. it can be the
      # tax or the taxed item).  If the other side is already inserted, 
      # then set billpkgnum to ours, and insert the link.  Otherwise,
      # set billpkgnum to ours and pass the link off to the cust_bill_pkg
      # on the other side, to be inserted later.

      my $tax_cust_bill_pkg = $link->get('tax_cust_bill_pkg');
      if ( $tax_cust_bill_pkg && $tax_cust_bill_pkg->billpkgnum ) {
        $link->set('billpkgnum', $tax_cust_bill_pkg->billpkgnum);
        # break circular links when doing this
        $link->set('tax_cust_bill_pkg', '');
      }
      my $taxable_cust_bill_pkg = $link->get('taxable_cust_bill_pkg');
      if ( $taxable_cust_bill_pkg && $taxable_cust_bill_pkg->billpkgnum ) {
        $link->set('taxable_billpkgnum', $taxable_cust_bill_pkg->billpkgnum);
        # XXX if we ever do tax-on-tax for these, this will have to change
        # since pkgnum will be zero
        $link->set('pkgnum', $taxable_cust_bill_pkg->pkgnum);
        $link->set('locationnum', $taxable_cust_bill_pkg->tax_locationnum);
        $link->set('taxable_cust_bill_pkg', '');
      }

      if ( $link->billpkgnum and $link->taxable_billpkgnum ) {
        $error = $link->insert;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return "error inserting cust_bill_pkg_tax_location: $error";
        }
      } else { # handoff
        my $other;
        $other = $link->billpkgnum ? $link->get('taxable_cust_bill_pkg')
                                   : $link->get('tax_cust_bill_pkg');
        my $link_array = $other->get('cust_bill_pkg_tax_location') || [];
        push @$link_array, $link;
        $other->set('cust_bill_pkg_tax_location' => $link_array);
      }
    } #foreach my $link
  }

  # someday you will be as awesome as cust_bill_pkg_tax_location...
  # but not today
  my $tax_rate_location = $self->get('cust_bill_pkg_tax_rate_location');
  if ( $tax_rate_location ) {
    foreach my $cust_bill_pkg_tax_rate_location ( @$tax_rate_location ) {
      $cust_bill_pkg_tax_rate_location->billpkgnum($self->billpkgnum);
      $error = $cust_bill_pkg_tax_rate_location->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_bill_pkg_tax_rate_location: $error";
      }
    }
  }

  my $fee_links = $self->get('cust_bill_pkg_fee');
  if ( $fee_links ) {
    foreach my $link ( @$fee_links ) {
      # very similar to cust_bill_pkg_tax_location, for obvious reasons
      next if $link->billpkgfeenum; # don't try to double-insert

      my $target = $link->get('cust_bill_pkg'); # the line item of the fee
      my $base = $link->get('base_cust_bill_pkg'); # line item it was based on

      if ( $target and $target->billpkgnum ) {
        $link->set('billpkgnum', $target->billpkgnum);
        # base_invnum => null indicates that the fee is based on its own
        # invoice
        $link->set('base_invnum', $target->invnum) unless $link->base_invnum;
        $link->set('cust_bill_pkg', '');
      }

      if ( $base and $base->billpkgnum ) {
        $link->set('base_billpkgnum', $base->billpkgnum);
        $link->set('base_cust_bill_pkg', '');
      } elsif ( $base ) {
        # it's based on a line item that's not yet inserted
        my $link_array = $base->get('cust_bill_pkg_fee') || [];
        push @$link_array, $link;
        $base->set('cust_bill_pkg_fee' => $link_array);
        next; # don't insert the link yet
      }

      $error = $link->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_bill_pkg_fee: $error";
      }
    } # foreach my $link
  }

  my $cust_event_fee = $self->get('cust_event_fee');
  if ( $cust_event_fee ) {
    $cust_event_fee->set('billpkgnum' => $self->billpkgnum);
    $error = $cust_event_fee->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error updating cust_event_fee: $error";
    }
  }

  my $cust_tax_adjustment = $self->get('cust_tax_adjustment');
  if ( $cust_tax_adjustment ) {
    $cust_tax_adjustment->billpkgnum($self->billpkgnum);
    $error = $cust_tax_adjustment->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error replacing cust_tax_adjustment: $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item void

Voids this line item: deletes the line item and adds a record of the voided
line item to the FS::cust_bill_pkg_void table (and related tables).

=cut

sub void {
  my $self = shift;
  my $reason = scalar(@_) ? shift : '';

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_bill_pkg_void = new FS::cust_bill_pkg_void ( {
    map { $_ => $self->get($_) } $self->fields
  } );
  $cust_bill_pkg_void->reason($reason);
  my $error = $cust_bill_pkg_void->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $table (qw(
    cust_bill_pkg_detail
    cust_bill_pkg_display
    cust_bill_pkg_discount
    cust_bill_pkg_tax_location
    cust_bill_pkg_tax_rate_location
    cust_tax_exempt_pkg
  )) {

    foreach my $linked ( qsearch($table, { billpkgnum=>$self->billpkgnum }) ) {

      my $vclass = 'FS::'.$table.'_void';
      my $void = $vclass->new( {
        map { $_ => $linked->get($_) } $linked->fields
      });
      my $error = $void->insert || $linked->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    }

  }

  $error = $self->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Not recommended.

=cut

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

  foreach my $table (qw(
    cust_bill_pkg_detail
    cust_bill_pkg_display
    cust_bill_pkg_discount
    cust_bill_pkg_tax_location
    cust_bill_pkg_tax_rate_location
    cust_tax_exempt_pkg
    cust_bill_pay_pkg
    cust_credit_bill_pkg
  )) {

    foreach my $linked ( qsearch($table, { billpkgnum=>$self->billpkgnum }) ) {
      my $error = $linked->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }

  }

  foreach my $cust_tax_adjustment (
    qsearch('cust_tax_adjustment', { billpkgnum=>$self->billpkgnum })
  ) {
    $cust_tax_adjustment->billpkgnum(''); #NULL
    my $error = $cust_tax_adjustment->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

#alas, bin/follow-tax-rename
#
#=item replace OLD_RECORD
#
#Currently unimplemented.  This would be even more of an accounting nightmare
#than deleteing the items.  Just don't do it.
#
#=cut
#
#sub replace {
#  return "Can't modify cust_bill_pkg records!";
#}

=item check

Checks all fields to make sure this is a valid line item.  If there is an
error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error =
         $self->ut_numbern('billpkgnum')
      || $self->ut_snumber('pkgnum')
      || $self->ut_number('invnum')
      || $self->ut_money('setup')
      || $self->ut_money('recur')
      || $self->ut_numbern('sdate')
      || $self->ut_numbern('edate')
      || $self->ut_textn('itemdesc')
      || $self->ut_textn('itemcomment')
      || $self->ut_enum('hidden', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->regularize_details;

  #if ( $self->pkgnum != 0 ) { #allow unchecked pkgnum 0 for tax! (add to part_pkg?)
  if ( $self->pkgnum > 0 ) { #allow -1 for non-pkg line items and 0 for tax (add to part_pkg?)
    return "Unknown pkgnum ". $self->pkgnum
      unless qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
  }

  return "Unknown invnum"
    unless qsearchs( 'cust_bill' ,{ 'invnum' => $self->invnum } );

  $self->SUPER::check;
}

=item regularize_details

Converts the contents of the 'details' pseudo-field to 
L<FS::cust_bill_pkg_detail> objects, if they aren't already.

=cut

sub regularize_details {
  my $self = shift;
  if ( $self->get('details') ) {
    foreach my $detail ( @{$self->get('details')} ) {
      if ( ref($detail) ne 'FS::cust_bill_pkg_detail' ) {
        # then turn it into one
        my %hash = ();
        if ( ! ref($detail) ) {
          $hash{'detail'} = $detail;
        }
        elsif ( ref($detail) eq 'HASH' ) {
          %hash = %$detail;
        }
        elsif ( ref($detail) eq 'ARRAY' ) {
          carp "passing invoice details as arrays is deprecated";
          #carp "this way sucks, use a hash"; #but more useful/friendly
          $hash{'format'}      = $detail->[0];
          $hash{'detail'}      = $detail->[1];
          $hash{'amount'}      = $detail->[2];
          $hash{'classnum'}    = $detail->[3];
          $hash{'phonenum'}    = $detail->[4];
          $hash{'accountcode'} = $detail->[5];
          $hash{'startdate'}   = $detail->[6];
          $hash{'duration'}    = $detail->[7];
          $hash{'regionname'}  = $detail->[8];
        }
        else {
          die "unknown detail type ". ref($detail);
        }
        $detail = new FS::cust_bill_pkg_detail \%hash;
      }
      $detail->billpkgnum($self->billpkgnum) if $self->billpkgnum;
    }
  }
  return;
}

=item cust_bill

Returns the invoice (see L<FS::cust_bill>) for this invoice line item.

=cut

sub cust_bill {
  my $self = shift;
  qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );
}

=item cust_main

Returns the customer (L<FS::cust_main> object) for this line item.

=cut

sub cust_main {
  # required for cust_main_Mixin equivalence
  # and use cust_bill instead of cust_pkg because this might not have a 
  # cust_pkg
  my $self = shift;
  my $cust_bill = $self->cust_bill or return '';
  $cust_bill->cust_main;
}

=item previous_cust_bill_pkg

Returns the previous cust_bill_pkg for this package, if any.

=cut

sub previous_cust_bill_pkg {
  my $self = shift;
  return unless $self->sdate;
  qsearchs({
    'table'    => 'cust_bill_pkg',
    'hashref'  => { 'pkgnum' => $self->pkgnum,
                    'sdate'  => { op=>'<', value=>$self->sdate },
                  },
    'order_by' => 'ORDER BY sdate DESC LIMIT 1',
  });
}

=item owed_setup

Returns the amount owed (still outstanding) on this line item's setup fee,
which is the amount of the line item minus all payment applications (see
L<FS::cust_bill_pay_pkg> and credit applications (see
L<FS::cust_credit_bill_pkg>).

=cut

sub owed_setup {
  my $self = shift;
  $self->owed('setup', @_);
}

=item owed_recur

Returns the amount owed (still outstanding) on this line item's recurring fee,
which is the amount of the line item minus all payment applications (see
L<FS::cust_bill_pay_pkg> and credit applications (see
L<FS::cust_credit_bill_pkg>).

=cut

sub owed_recur {
  my $self = shift;
  $self->owed('recur', @_);
}

# modeled after cust_bill::owed...
sub owed {
  my( $self, $field ) = @_;
  my $balance = $self->$field();
  $balance -= $_->amount foreach ( $self->cust_bill_pay_pkg($field) );
  $balance -= $_->amount foreach ( $self->cust_credit_bill_pkg($field) );
  $balance = sprintf( '%.2f', $balance );
  $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
  $balance;
}

#modeled after owed
sub payable {
  my( $self, $field ) = @_;
  my $balance = $self->$field();
  $balance -= $_->amount foreach ( $self->cust_credit_bill_pkg($field) );
  $balance = sprintf( '%.2f', $balance );
  $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
  $balance;
}

sub cust_bill_pay_pkg {
  my( $self, $field ) = @_;
  qsearch( 'cust_bill_pay_pkg', { 'billpkgnum' => $self->billpkgnum,
                                  'setuprecur' => $field,
                                }
         );
}

sub cust_credit_bill_pkg {
  my( $self, $field ) = @_;
  qsearch( 'cust_credit_bill_pkg', { 'billpkgnum' => $self->billpkgnum,
                                     'setuprecur' => $field,
                                   }
         );
}

=item units

Returns the number of billing units (for tax purposes) represented by this,
line item.

=cut

sub units {
  my $self = shift;
  $self->pkgnum ? $self->part_pkg->calc_units($self->cust_pkg) : 0; # 1?
}


=item set_display OPTION => VALUE ...

A helper method for I<insert>, populates the pseudo-field B<display> with
appropriate FS::cust_bill_pkg_display objects.

Options are passed as a list of name/value pairs.  Options are:

part_pkg: FS::part_pkg object from this line item's package.

real_pkgpart: if this line item comes from a bundled package, the pkgpart 
of the owning package.  Otherwise the same as the part_pkg's pkgpart above.

=cut

sub set_display {
  my( $self, %opt ) = @_;
  my $part_pkg = $opt{'part_pkg'};
  my $cust_pkg = new FS::cust_pkg { pkgpart => $opt{real_pkgpart} };

  my $conf = new FS::Conf;

  # whether to break this down into setup/recur/usage
  my $separate = $conf->exists('separate_usage');

  my $usage_mandate =            $part_pkg->option('usage_mandate', 'Hush!')
                    || $cust_pkg->part_pkg->option('usage_mandate', 'Hush!');

  # or use the category from $opt{'part_pkg'} if its not bundled?
  my $categoryname = $cust_pkg->part_pkg->categoryname;

  # if we don't have to separate setup/recur/usage, or put this in a 
  # package-specific section, or display a usage summary, then don't 
  # even create one of these.  The item will just display in the unnamed
  # section as a single line plus details.
  return $self->set('display', [])
    unless $separate || $categoryname || $usage_mandate;
  
  my @display = ();

  my %hash = ( 'section' => $categoryname );

  # whether to put usage details in a separate section, and if so, which one
  my $usage_section =            $part_pkg->option('usage_section', 'Hush!')
                    || $cust_pkg->part_pkg->option('usage_section', 'Hush!');

  # whether to show a usage summary line (total usage charges, no details)
  my $summary =            $part_pkg->option('summarize_usage', 'Hush!')
              || $cust_pkg->part_pkg->option('summarize_usage', 'Hush!');

  if ( $separate ) {
    # create lines for setup and (non-usage) recur, in the main section
    push @display, new FS::cust_bill_pkg_display { type => 'S', %hash };
    push @display, new FS::cust_bill_pkg_display { type => 'R', %hash };
  } else {
    # display everything in a single line
    push @display, new FS::cust_bill_pkg_display
                     { type => '',
                       %hash,
                       # and if usage_mandate is enabled, hide details
                       # (this only works on multisection invoices...)
                       ( ( $usage_mandate ) ? ( 'summary' => 'Y' ) : () ),
                     };
  }

  if ($separate && $usage_section && $summary) {
    # create a line for the usage summary in the main section
    push @display, new FS::cust_bill_pkg_display { type    => 'U',
                                                   summary => 'Y',
                                                   %hash,
                                                 };
  }

  if ($usage_mandate || ($usage_section && $summary) ) {
    $hash{post_total} = 'Y';
  }

  if ($separate || $usage_mandate) {
    # show call details for this line item in the usage section.
    # if usage_mandate is on, this will display below the section subtotal.
    # this also happens if usage is in a separate section and there's a 
    # summary in the main section, though I'm not sure why.
    $hash{section} = $usage_section if $usage_section;
    push @display, new FS::cust_bill_pkg_display { type => 'U', %hash };
  }

  $self->set('display', \@display);

}

=item disintegrate

Returns a hash: keys are "setup", "recur" or usage classnum, values are
FS::cust_bill_pkg objects, each with no more than a single class (setup or
recur) of charge.

=cut

sub disintegrate {
  my $self = shift;
  # XXX this goes away with cust_bill_pkg refactor

  my $cust_bill_pkg = new FS::cust_bill_pkg { $self->hash };
  my %cust_bill_pkg = ();

  $cust_bill_pkg{setup} = $cust_bill_pkg if $cust_bill_pkg->setup;
  $cust_bill_pkg{recur} = $cust_bill_pkg if $cust_bill_pkg->recur;


  #split setup and recur
  if ($cust_bill_pkg->setup && $cust_bill_pkg->recur) {
    my $cust_bill_pkg_recur = new FS::cust_bill_pkg { $cust_bill_pkg->hash };
    $cust_bill_pkg->set('details', []);
    $cust_bill_pkg->recur(0);
    $cust_bill_pkg->unitrecur(0);
    $cust_bill_pkg->type('');
    $cust_bill_pkg_recur->setup(0);
    $cust_bill_pkg_recur->unitsetup(0);
    $cust_bill_pkg{recur} = $cust_bill_pkg_recur;

  }

  #split usage from recur
  my $usage = sprintf( "%.2f", $cust_bill_pkg{recur}->usage )
    if exists($cust_bill_pkg{recur});
  warn "usage is $usage\n" if $DEBUG > 1;
  if ($usage) {
    my $cust_bill_pkg_usage =
        new FS::cust_bill_pkg { $cust_bill_pkg{recur}->hash };
    $cust_bill_pkg_usage->recur( $usage );
    $cust_bill_pkg_usage->type( 'U' );
    my $recur = sprintf( "%.2f", $cust_bill_pkg{recur}->recur - $usage );
    $cust_bill_pkg{recur}->recur( $recur );
    $cust_bill_pkg{recur}->type( '' );
    $cust_bill_pkg{recur}->set('details', []);
    $cust_bill_pkg{''} = $cust_bill_pkg_usage;
  }

  #subdivide usage by usage_class
  if (exists($cust_bill_pkg{''})) {
    foreach my $class (grep { $_ } $self->usage_classes) {
      my $usage = sprintf( "%.2f", $cust_bill_pkg{''}->usage($class) );
      my $cust_bill_pkg_usage =
          new FS::cust_bill_pkg { $cust_bill_pkg{''}->hash };
      $cust_bill_pkg_usage->recur( $usage );
      $cust_bill_pkg_usage->set('details', []);
      my $classless = sprintf( "%.2f", $cust_bill_pkg{''}->recur - $usage );
      $cust_bill_pkg{''}->recur( $classless );
      $cust_bill_pkg{$class} = $cust_bill_pkg_usage;
    }
    warn "Unexpected classless usage value: ". $cust_bill_pkg{''}->recur
      if ($cust_bill_pkg{''}->recur && $cust_bill_pkg{''}->recur < 0);
    delete $cust_bill_pkg{''}
      unless ($cust_bill_pkg{''}->recur && $cust_bill_pkg{''}->recur > 0);
  }

#  # sort setup,recur,'', and the rest numeric && return
#  my @result = map { $cust_bill_pkg{$_} }
#               sort { my $ad = ($a=~/^\d+$/); my $bd = ($b=~/^\d+$/);
#                      ( $ad cmp $bd ) || ( $ad ? $a<=>$b : $b cmp $a )
#                    }
#               keys %cust_bill_pkg;
#
#  return (@result);

   %cust_bill_pkg;
}

=item usage CLASSNUM

Returns the amount of the charge associated with usage class CLASSNUM if
CLASSNUM is defined.  Otherwise returns the total charge associated with
usage.
  
=cut

sub usage {
  my( $self, $classnum ) = @_;
  $self->regularize_details;

  if ( $self->get('details') ) {

    return sum( 0, 
      map { $_->amount || 0 }
      grep { !defined($classnum) or $classnum eq $_->classnum }
      @{ $self->get('details') }
    );

  } else {

    my $sql = 'SELECT SUM(COALESCE(amount,0)) FROM cust_bill_pkg_detail '.
              ' WHERE billpkgnum = '. $self->billpkgnum;
    $sql .= " AND classnum = $classnum" if defined($classnum);

    my $sth = dbh->prepare($sql) or die dbh->errstr;
    $sth->execute or die $sth->errstr;

    return $sth->fetchrow_arrayref->[0] || 0;

  }

}

=item usage_classes

Returns a list of usage classnums associated with this invoice line's
details.
  
=cut

sub usage_classes {
  my( $self ) = @_;
  $self->regularize_details;

  if ( $self->get('details') ) {

    my %seen = ( map { $_->classnum => 1 } @{ $self->get('details') } );
    keys %seen;

  } else {

    map { $_->classnum }
        qsearch({ table   => 'cust_bill_pkg_detail',
                  hashref => { billpkgnum => $self->billpkgnum },
                  select  => 'DISTINCT classnum',
               });

  }

}

sub cust_tax_exempt_pkg {
  my ( $self ) = @_;

  $self->{Hash}->{cust_tax_exempt_pkg} ||= [];
}

=item cust_bill_pkg_fee

Returns the list of associated cust_bill_pkg_fee objects, if this is 
a fee-type item.

=cut

sub cust_bill_pkg_fee {
  my $self = shift;
  qsearch('cust_bill_pkg_fee', { billpkgnum => $self->billpkgnum });
}

=item cust_bill_pkg_tax_Xlocation

Returns the list of associated cust_bill_pkg_tax_location and/or
cust_bill_pkg_tax_rate_location objects

=cut

sub cust_bill_pkg_tax_Xlocation {
  my $self = shift;

  my %hash = ( 'billpkgnum' => $self->billpkgnum );

  (
    qsearch ( 'cust_bill_pkg_tax_location', { %hash  } ),
    qsearch ( 'cust_bill_pkg_tax_rate_location', { %hash } )
  );

}

=item recur_show_zero

=cut

sub recur_show_zero { shift->_X_show_zero('recur'); }
sub setup_show_zero { shift->_X_show_zero('setup'); }

sub _X_show_zero {
  my( $self, $what ) = @_;

  return 0 unless $self->$what() == 0 && $self->pkgnum;

  $self->cust_pkg->_X_show_zero($what);
}

=item credited [ BEFORE, AFTER, OPTIONS ]

Returns the sum of credits applied to this item.  Arguments are the same as
owed_sql/paid_sql/credited_sql.

=cut

sub credited {
  my $self = shift;
  $self->scalar_sql('SELECT '. $self->credited_sql(@_).' FROM cust_bill_pkg WHERE billpkgnum = ?', $self->billpkgnum);
}

=item tax_locationnum

Returns the L<FS::cust_location> number that this line item is in for tax
purposes.  For package sales, it's the package tax location; for fees, 
it's the customer's default service location.

=cut

sub tax_locationnum {
  my $self = shift;
  if ( $self->pkgnum ) { # normal sales
    return $self->cust_pkg->tax_locationnum;
  } elsif ( $self->feepart ) { # fees
    return $self->cust_bill->cust_main->ship_locationnum;
  } else { # taxes
    return '';
  }
}

sub tax_location {
  my $self = shift;
  if ( $self->pkgnum ) { # normal sales
    return $self->cust_pkg->tax_location;
  } elsif ( $self->feepart ) { # fees
    return $self->cust_bill->cust_main->ship_location;
  } else { # taxes
    return;
  }
}

=item part_X

Returns the L<FS::part_pkg> or L<FS::part_fee> object that defines this
charge.  If called on a tax line, returns nothing.

=cut

sub part_X {
  my $self = shift;
  if ( $self->pkgpart_override ) {
    return FS::part_pkg->by_key($self->pkgpart_override);
  } elsif ( $self->pkgnum ) {
    return $self->cust_pkg->part_pkg;
  } elsif ( $self->feepart ) {
    return $self->part_fee;
  } else {
    return;
  }
}

# stubs

sub part_fee {
  my $self = shift;
  $self->feepart
    ? FS::part_fee->by_key($self->feepart)
    : undef;
}

=back

=head1 CLASS METHODS

=over 4

=item usage_sql

Returns an SQL expression for the total usage charges in details on
an item.

=cut

my $usage_sql =
  '(SELECT COALESCE(SUM(cust_bill_pkg_detail.amount),0) 
    FROM cust_bill_pkg_detail 
    WHERE cust_bill_pkg_detail.billpkgnum = cust_bill_pkg.billpkgnum)';

sub usage_sql { $usage_sql }

# this makes owed_sql, etc. much more concise
sub charged_sql {
  my ($class, $start, $end, %opt) = @_;
  my $setuprecur = $opt{setuprecur} || '';
  my $charged = 
    $setuprecur =~ /^s/ ? 'cust_bill_pkg.setup' :
    $setuprecur =~ /^r/ ? 'cust_bill_pkg.recur' :
    'cust_bill_pkg.setup + cust_bill_pkg.recur';

  if ($opt{no_usage} and $charged =~ /recur/) { 
    $charged = "$charged - $usage_sql"
  }

  $charged;
}


=item owed_sql [ BEFORE, AFTER, OPTIONS ]

Returns an SQL expression for the amount owed.  BEFORE and AFTER specify
a date window.  OPTIONS may include 'no_usage' (excludes usage charges)
and 'setuprecur' (set to "setup" or "recur" to limit to one or the other).

=cut

sub owed_sql {
  my $class = shift;
  '(' . $class->charged_sql(@_) . 
  ' - ' . $class->paid_sql(@_) .
  ' - ' . $class->credited_sql(@_) . ')'
}

=item paid_sql [ BEFORE, AFTER, OPTIONS ]

Returns an SQL expression for the sum of payments applied to this item.

=cut

sub paid_sql {
  my ($class, $start, $end, %opt) = @_;
  my $s = $start ? "AND cust_pay._date <= $start" : '';
  my $e = $end   ? "AND cust_pay._date >  $end"   : '';
  my $setuprecur = $opt{setuprecur} || '';
  $setuprecur = 'setup' if $setuprecur =~ /^s/;
  $setuprecur = 'recur' if $setuprecur =~ /^r/;
  $setuprecur &&= "AND setuprecur = '$setuprecur'";

  my $paid = "( SELECT COALESCE(SUM(cust_bill_pay_pkg.amount),0)
     FROM cust_bill_pay_pkg JOIN cust_bill_pay USING (billpaynum)
                            JOIN cust_pay      USING (paynum)
     WHERE cust_bill_pay_pkg.billpkgnum = cust_bill_pkg.billpkgnum
           $s $e $setuprecur )";

  if ( $opt{no_usage} ) {
    # cap the amount paid at the sum of non-usage charges, 
    # minus the amount credited against non-usage charges
    "LEAST($paid, ". 
      $class->charged_sql($start, $end, %opt) . ' - ' .
      $class->credited_sql($start, $end, %opt).')';
  }
  else {
    $paid;
  }

}

sub credited_sql {
  my ($class, $start, $end, %opt) = @_;
  my $s = $start ? "AND cust_credit._date <= $start" : '';
  my $e = $end   ? "AND cust_credit._date >  $end"   : '';
  my $setuprecur = $opt{setuprecur} || '';
  $setuprecur = 'setup' if $setuprecur =~ /^s/;
  $setuprecur = 'recur' if $setuprecur =~ /^r/;
  $setuprecur &&= "AND setuprecur = '$setuprecur'";

  my $credited = "( SELECT COALESCE(SUM(cust_credit_bill_pkg.amount),0)
     FROM cust_credit_bill_pkg JOIN cust_credit_bill USING (creditbillnum)
                               JOIN cust_credit      USING (crednum)
     WHERE cust_credit_bill_pkg.billpkgnum = cust_bill_pkg.billpkgnum
           $s $e $setuprecur )";

  if ( $opt{no_usage} ) {
    # cap the amount credited at the sum of non-usage charges
    "LEAST($credited, ". $class->charged_sql($start, $end, %opt).')';
  }
  else {
    $credited;
  }

}

sub upgrade_tax_location {
  # For taxes that were calculated/invoiced before cust_location refactoring
  # (May-June 2012), there are no cust_bill_pkg_tax_location records unless
  # they were calculated on a package-location basis.  Create them here, 
  # along with any necessary cust_location records and any tax exemption 
  # records.

  my ($class, %opt) = @_;
  # %opt may include 's' and 'e': start and end date ranges
  # and 'X': abort on any error, instead of just rolling back changes to 
  # that invoice
  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  eval {
    use FS::h_cust_main;
    use FS::h_cust_bill;
    use FS::h_part_pkg;
    use FS::h_cust_main_exemption;
  };

  local $FS::cust_location::import = 1;

  my $conf = FS::Conf->new; # h_conf?
  return if $conf->exists('enable_taxproducts'); #don't touch this case
  my $use_ship = $conf->exists('tax-ship_address');
  my $use_pkgloc = $conf->exists('tax-pkg_address');

  my $date_where = '';
  if ($opt{s}) {
    $date_where .= " AND cust_bill._date >= $opt{s}";
  }
  if ($opt{e}) {
    $date_where .= " AND cust_bill._date < $opt{e}";
  }

  my $commit_each_invoice = 1 unless $opt{X};

  # if an invoice has either of these kinds of objects, then it doesn't
  # need to be upgraded...probably
  my $sub_has_tax_link = 'SELECT 1 FROM cust_bill_pkg_tax_location'.
  ' JOIN cust_bill_pkg USING (billpkgnum)'.
  ' WHERE cust_bill_pkg.invnum = cust_bill.invnum';
  my $sub_has_exempt = 'SELECT 1 FROM cust_tax_exempt_pkg'.
  ' JOIN cust_bill_pkg USING (billpkgnum)'.
  ' WHERE cust_bill_pkg.invnum = cust_bill.invnum'.
  ' AND exempt_monthly IS NULL';

  my %all_tax_names = (
    '' => 1,
    'Tax' => 1,
    map { $_->taxname => 1 }
      qsearch('h_cust_main_county', { taxname => { op => '!=', value => '' }})
  );

  my $search = FS::Cursor->new({
      table => 'cust_bill',
      hashref => {},
      extra_sql => "WHERE NOT EXISTS($sub_has_tax_link) ".
                   "AND NOT EXISTS($sub_has_exempt) ".
                    $date_where,
  });

#print "Processing ".scalar(@invnums)." invoices...\n";

  my $committed;
  INVOICE:
  while (my $cust_bill = $search->fetch) {
    my $invnum = $cust_bill->invnum;
    $committed = 0;
    print STDERR "Invoice #$invnum\n";
    my $pre = '';
    my %pkgpart_taxclass; # pkgpart => taxclass
    my %pkgpart_exempt_setup;
    my %pkgpart_exempt_recur;
    my $h_cust_bill = qsearchs('h_cust_bill',
      { invnum => $invnum,
        history_action => 'insert' });
    if (!$h_cust_bill) {
      warn "no insert record for invoice $invnum; skipped\n";
      #$date = $cust_bill->_date as a fallback?
      # We're trying to avoid using non-real dates (-d/-y invoice dates)
      # when looking up history records in other tables.
      next INVOICE;
    }
    my $custnum = $h_cust_bill->custnum;

    # Determine the address corresponding to this tax region.
    # It's either the bill or ship address of the customer as of the
    # invoice date-of-insertion.  (Not necessarily the invoice date.)
    my $date = $h_cust_bill->history_date;
    my $h_cust_main = qsearchs('h_cust_main',
        { custnum   => $custnum },
        FS::h_cust_main->sql_h_searchs($date)
      );
    if (!$h_cust_main ) {
      warn "no historical address for cust#".$h_cust_bill->custnum."; skipped\n";
      next INVOICE;
      # fallback to current $cust_main?  sounds dangerous.
    }

    # This is a historical customer record, so it has a historical address.
    # If there's no cust_location matching this custnum and address (there 
    # probably isn't), create one.
    my %tax_loc; # keys are pkgnums, values are cust_location objects
    my $default_tax_loc;
    if ( $h_cust_main->bill_locationnum ) {
      # the location has already been upgraded
      if ($use_ship) {
        $default_tax_loc = $h_cust_main->ship_location;
      } else {
        $default_tax_loc = $h_cust_main->bill_location;
      }
    } else {
      $pre = 'ship_' if $use_ship and length($h_cust_main->get('ship_last'));
      my %hash = map { $_ => $h_cust_main->get($pre.$_) }
                    FS::cust_main->location_fields;
      # not really needed for this, and often result in duplicate locations
      delete @hash{qw(censustract censusyear latitude longitude coord_auto)};

      $hash{custnum} = $h_cust_main->custnum;
      $default_tax_loc = FS::cust_location->new(\%hash);
      my $error = $default_tax_loc->find_or_insert || $default_tax_loc->disable_if_unused;
      if ( $error ) {
        warn "couldn't create historical location record for cust#".
        $h_cust_main->custnum.": $error\n";
        next INVOICE;
      }
    }
    my $exempt_cust;
    $exempt_cust = 1 if $h_cust_main->tax;

    # classify line items
    my @tax_items;
    my %nontax_items; # taxclass => array of cust_bill_pkg
    foreach my $item ($h_cust_bill->cust_bill_pkg) {
      my $pkgnum = $item->pkgnum;

      if ( $pkgnum == 0 ) {

        push @tax_items, $item;

      } else {
        # (pkgparts really shouldn't change, right?)
        my $h_cust_pkg = qsearchs('h_cust_pkg', { pkgnum => $pkgnum },
          FS::h_cust_pkg->sql_h_searchs($date)
        );
        if ( !$h_cust_pkg ) {
          warn "no historical package #".$item->pkgpart."; skipped\n";
          next INVOICE;
        }
        my $pkgpart = $h_cust_pkg->pkgpart;

        if ( $use_pkgloc and $h_cust_pkg->locationnum ) {
          # then this package already had a locationnum assigned, and that's 
          # the one to use for tax calculation
          $tax_loc{$pkgnum} = FS::cust_location->by_key($h_cust_pkg->locationnum);
        } else {
          # use the customer's bill or ship loc, which was inserted earlier
          $tax_loc{$pkgnum} = $default_tax_loc;
        }

        if (!exists $pkgpart_taxclass{$pkgpart}) {
          my $h_part_pkg = qsearchs('h_part_pkg', { pkgpart => $pkgpart },
            FS::h_part_pkg->sql_h_searchs($date)
          );
          if ( !$h_part_pkg ) {
            warn "no historical package def #$pkgpart; skipped\n";
            next INVOICE;
          }
          $pkgpart_taxclass{$pkgpart} = $h_part_pkg->taxclass || '';
          $pkgpart_exempt_setup{$pkgpart} = 1 if $h_part_pkg->setuptax;
          $pkgpart_exempt_recur{$pkgpart} = 1 if $h_part_pkg->recurtax;
        }
        
        # mark any exemptions that apply
        if ( $pkgpart_exempt_setup{$pkgpart} ) {
          $item->set('exempt_setup' => 1);
        }

        if ( $pkgpart_exempt_recur{$pkgpart} ) {
          $item->set('exempt_recur' => 1);
        }

        my $taxclass = $pkgpart_taxclass{ $pkgpart };

        $nontax_items{$taxclass} ||= [];
        push @{ $nontax_items{$taxclass} }, $item;
      }
    }

    printf("%d tax items: \$%.2f\n", scalar(@tax_items), map {$_->setup} @tax_items)
      if @tax_items;

    # Get any per-customer taxname exemptions that were in effect.
    my %exempt_cust_taxname;
    foreach (keys %all_tax_names) {
      my $h_exemption = qsearchs('h_cust_main_exemption', {
          'custnum' => $custnum,
          'taxname' => $_,
        },
        FS::h_cust_main_exemption->sql_h_searchs($date, $date)
      );
      if ($h_exemption) {
        $exempt_cust_taxname{ $_ } = 1;
      }
    }

    # Use a variation on the procedure in 
    # FS::cust_main::Billing::_handle_taxes to identify taxes that apply 
    # to this bill.
    my @loc_keys = qw( district city county state country );
    my %taxdef_by_name; # by name, and then by taxclass
    my %est_tax; # by name, and then by taxclass
    my %taxable_items; # by taxnum, and then an array

    foreach my $taxclass (keys %nontax_items) {
      foreach my $orig_item (@{ $nontax_items{$taxclass} }) {
        my $my_tax_loc = $tax_loc{ $orig_item->pkgnum };
        my %myhash = map { $_ => $my_tax_loc->get($pre.$_) } @loc_keys;
        my @elim = qw( district city county state );
        my @taxdefs; # because there may be several with different taxnames
        do {
          $myhash{taxclass} = $taxclass;
          @taxdefs = qsearch('cust_main_county', \%myhash);
          if ( !@taxdefs ) {
            $myhash{taxclass} = '';
            @taxdefs = qsearch('cust_main_county', \%myhash);
          }
          $myhash{ shift @elim } = '';
        } while scalar(@elim) and !@taxdefs;

        foreach my $taxdef (@taxdefs) {
          next if $taxdef->tax == 0;
          $taxdef_by_name{$taxdef->taxname}{$taxdef->taxclass} = $taxdef;

          $taxable_items{$taxdef->taxnum} ||= [];
          # clone the item so that taxdef-dependent changes don't
          # change it for other taxdefs
          my $item = FS::cust_bill_pkg->new({ $orig_item->hash });

          # these flags are already set if the part_pkg declares itself exempt
          $item->set('exempt_setup' => 1) if $taxdef->setuptax;
          $item->set('exempt_recur' => 1) if $taxdef->recurtax;

          my @new_exempt;
          my $taxable = $item->setup + $item->recur;
          # credits
          # h_cust_credit_bill_pkg?
          # NO.  Because if these exemptions HAD been created at the time of 
          # billing, and then a credit applied later, the exemption would 
          # have been adjusted by the amount of the credit.  So we adjust
          # the taxable amount before creating the exemption.
          # But don't deduct the credit from taxable, because the tax was 
          # calculated before the credit was applied.
          foreach my $f (qw(setup recur)) {
            my $credited = FS::Record->scalar_sql(
              "SELECT SUM(amount) FROM cust_credit_bill_pkg ".
              "WHERE billpkgnum = ? AND setuprecur = ?",
              $item->billpkgnum,
              $f
            );
            $item->set($f, $item->get($f) - $credited) if $credited;
          }
          my $existing_exempt = FS::Record->scalar_sql(
            "SELECT SUM(amount) FROM cust_tax_exempt_pkg WHERE ".
            "billpkgnum = ? AND taxnum = ?",
            $item->billpkgnum, $taxdef->taxnum
          ) || 0;
          $taxable -= $existing_exempt;

          if ( $taxable and $exempt_cust ) {
            push @new_exempt, { exempt_cust => 'Y',  amount => $taxable };
            $taxable = 0;
          }
          if ( $taxable and $exempt_cust_taxname{$taxdef->taxname} ){
            push @new_exempt, { exempt_cust_taxname => 'Y', amount => $taxable };
            $taxable = 0;
          }
          if ( $taxable and $item->exempt_setup ) {
            push @new_exempt, { exempt_setup => 'Y', amount => $item->setup };
            $taxable -= $item->setup;
          }
          if ( $taxable and $item->exempt_recur ) {
            push @new_exempt, { exempt_recur => 'Y', amount => $item->recur };
            $taxable -= $item->recur;
          }

          $item->set('taxable' => $taxable);
          push @{ $taxable_items{$taxdef->taxnum} }, $item
            if $taxable > 0;

          # estimate the amount of tax (this is necessary because different
          # taxdefs with the same taxname may have different tax rates) 
          # and sum that for each taxname/taxclass combination
          # (in cents)
          $est_tax{$taxdef->taxname} ||= {};
          $est_tax{$taxdef->taxname}{$taxdef->taxclass} ||= 0;
          $est_tax{$taxdef->taxname}{$taxdef->taxclass} += 
            $taxable * $taxdef->tax;

          foreach (@new_exempt) {
            next if $_->{amount} == 0;
            my $cust_tax_exempt_pkg = FS::cust_tax_exempt_pkg->new({
                %$_,
                billpkgnum  => $item->billpkgnum,
                taxnum      => $taxdef->taxnum,
              });
            my $error = $cust_tax_exempt_pkg->insert;
            if ($error) {
              my $pkgnum = $item->pkgnum;
              warn "error creating tax exemption for inv$invnum pkg$pkgnum:".
                "\n$error\n\n";
              next INVOICE;
            }
          } #foreach @new_exempt
        } #foreach $taxdef
      } #foreach $item
    } #foreach $taxclass

    # Now go through the billed taxes and match them up with the line items.
    TAX_ITEM: foreach my $tax_item ( @tax_items )
    {
      my $taxname = $tax_item->itemdesc;
      $taxname = '' if $taxname eq 'Tax';

      if ( !exists( $taxdef_by_name{$taxname} ) ) {
        # then we didn't find any applicable taxes with this name
        warn "no definition found for tax item '$taxname', custnum $custnum\n";
        # possibly all of these should be "next TAX_ITEM", but whole invoices
        # are transaction protected and we can go back and retry them.
        next INVOICE;
      }
      # classname => cust_main_county
      my %taxdef_by_class = %{ $taxdef_by_name{$taxname} };

      # Divide the tax item among taxclasses, if necessary
      # classname => estimated tax amount
      my $this_est_tax = $est_tax{$taxname};
      if (!defined $this_est_tax) {
        warn "no taxable sales found for inv#$invnum, tax item '$taxname'.\n";
        next INVOICE;
      }
      my $est_total = sum(values %$this_est_tax);
      if ( $est_total == 0 ) {
        # shouldn't happen
        warn "estimated tax on invoice #$invnum is zero.\n";
        next INVOICE;
      }

      my $real_tax = $tax_item->setup;
      printf ("Distributing \$%.2f tax:\n", $real_tax);
      my $cents_remaining = $real_tax * 100; # for rounding error
      my @tax_links; # partial CBPTL hashrefs
      foreach my $taxclass (keys %taxdef_by_class) {
        my $taxdef = $taxdef_by_class{$taxclass};
        # these items already have "taxable" set to their charge amount
        # after applying any credits or exemptions
        my @items = @{ $taxable_items{$taxdef->taxnum} };
        my $subtotal = sum(map {$_->get('taxable')} @items);
        printf("\t$taxclass: %.2f\n", $this_est_tax->{$taxclass}/$est_total);

        foreach my $nontax (@items) {
          my $my_tax_loc = $tax_loc{ $nontax->pkgnum };
          my $part = int($real_tax
                            # class allocation
                         * ($this_est_tax->{$taxclass}/$est_total) 
                            # item allocation
                         * ($nontax->get('taxable'))/$subtotal
                            # convert to cents
                         * 100
                       );
          $cents_remaining -= $part;
          push @tax_links, {
            taxnum      => $taxdef->taxnum,
            pkgnum      => $nontax->pkgnum,
            locationnum => $my_tax_loc->locationnum,
            billpkgnum  => $nontax->billpkgnum,
            cents       => $part,
          };
        } #foreach $nontax
      } #foreach $taxclass
      # Distribute any leftover tax round-robin style, one cent at a time.
      my $i = 0;
      my $nlinks = scalar(@tax_links);
      if ( $nlinks ) {
        # ensure that it really is an integer
        $cents_remaining = sprintf('%.0f', $cents_remaining);
        while ($cents_remaining > 0) {
          $tax_links[$i % $nlinks]->{cents} += 1;
          $cents_remaining--;
          $i++;
        }
      } else {
        warn "Can't create tax links--no taxable items found.\n";
        next INVOICE;
      }

      # Gather credit/payment applications so that we can link them
      # appropriately.
      my @unlinked = (
        qsearch( 'cust_credit_bill_pkg',
          { billpkgnum => $tax_item->billpkgnum, billpkgtaxlocationnum => '' }
        ),
        qsearch( 'cust_bill_pay_pkg',
          { billpkgnum => $tax_item->billpkgnum, billpkgtaxlocationnum => '' }
        )
      );

      # grab the first one
      my $this_unlinked = shift @unlinked;
      my $unlinked_cents = int($this_unlinked->amount * 100) if $this_unlinked;

      # Create tax links (yay!)
      printf("Creating %d tax links.\n",scalar(@tax_links));
      foreach (@tax_links) {
        my $link = FS::cust_bill_pkg_tax_location->new({
            billpkgnum  => $tax_item->billpkgnum,
            taxtype     => 'FS::cust_main_county',
            locationnum => $_->{locationnum},
            taxnum      => $_->{taxnum},
            pkgnum      => $_->{pkgnum},
            amount      => sprintf('%.2f', $_->{cents} / 100),
            taxable_billpkgnum => $_->{billpkgnum},
        });
        my $error = $link->insert;
        if ( $error ) {
          warn "Can't create tax link for inv#$invnum: $error\n";
          next INVOICE;
        }

        my $link_cents = $_->{cents};
        # update/create subitem links
        #
        # If $this_unlinked is undef, then we've allocated all of the
        # credit/payment applications to the tax item.  If $link_cents is 0,
        # then we've applied credits/payments to all of this package fraction,
        # so go on to the next.
        while ($this_unlinked and $link_cents) {
          # apply as much as possible of $link_amount to this credit/payment
          # link
          my $apply_cents = min($link_cents, $unlinked_cents);
          $link_cents -= $apply_cents;
          $unlinked_cents -= $apply_cents;
          # $link_cents or $unlinked_cents or both are now zero
          $this_unlinked->set('amount' => sprintf('%.2f',$apply_cents/100));
          $this_unlinked->set('billpkgtaxlocationnum' => $link->billpkgtaxlocationnum);
          my $pkey = $this_unlinked->primary_key; #creditbillpkgnum or billpaypkgnum
          if ( $this_unlinked->$pkey ) {
            # then it's an existing link--replace it
            $error = $this_unlinked->replace;
          } else {
            $this_unlinked->insert;
          }
          # what do we do with errors at this stage?
          if ( $error ) {
            warn "Error creating tax application link: $error\n";
            next INVOICE; # for lack of a better idea
          }
          
          if ( $unlinked_cents == 0 ) {
            # then we've allocated all of this payment/credit application, 
            # so grab the next one
            $this_unlinked = shift @unlinked;
            $unlinked_cents = int($this_unlinked->amount * 100) if $this_unlinked;
          } elsif ( $link_cents == 0 ) {
            # then we've covered all of this package tax fraction, so split
            # off a new application from this one
            $this_unlinked = $this_unlinked->new({
                $this_unlinked->hash,
                $pkey     => '',
            });
            # $unlinked_cents is still what it is
          }

        } #while $this_unlinked and $link_cents
      } #foreach (@tax_links)
    } #foreach $tax_item

    $dbh->commit if $commit_each_invoice and $oldAutoCommit;
    $committed = 1;

  } #foreach $invnum
  continue {
    if (!$committed) {
      $dbh->rollback if $oldAutoCommit;
      die "Upgrade halted.\n" unless $commit_each_invoice;
    }
  }

  $dbh->commit if $oldAutoCommit and !$commit_each_invoice;
  '';
}

sub _upgrade_data {
  # Create a queue job to run upgrade_tax_location from January 1, 2012 to 
  # the present date.
  eval {
    use FS::queue;
    use Date::Parse 'str2time';
  };
  my $class = shift;
  my $upgrade = 'tax_location_2012';
  return if FS::upgrade_journal->is_done($upgrade);
  my $job = FS::queue->new({
      'job' => 'FS::cust_bill_pkg::upgrade_tax_location'
  });
  # call it kind of like a class method, not that it matters much
  $job->insert($class, 's' => str2time('2012-01-01'));
  # if there's a customer location upgrade queued also, wait for it to 
  # finish
  my $location_job = qsearchs('queue', {
      job => 'FS::cust_main::Location::process_upgrade_location'
    });
  if ( $location_job ) {
    $job->depend_insert($location_job->jobnum);
  }
  # Then mark the upgrade as done, so that we don't queue the job twice
  # and somehow run two of them concurrently.
  FS::upgrade_journal->set_done($upgrade);
  # This upgrade now does the job of assigning taxable_billpkgnums to 
  # cust_bill_pkg_tax_location, so set that task done also.
  FS::upgrade_journal->set_done('tax_location_taxable_billpkgnum');
}

=back

=head1 BUGS

setup and recur shouldn't be separate fields.  There should be one "amount"
field and a flag to tell you if it is a setup/one-time fee or a recurring fee.

A line item with both should really be two separate records (preserving
sdate and edate for setup fees for recurring packages - that information may
be valuable later).  Invoice generation (cust_main::bill), invoice printing
(cust_bill), tax reports (report_tax.cgi) and line item reports 
(cust_bill_pkg.cgi) would need to be updated.

owed_setup and owed_recur could then be repaced by just owed, and
cust_bill::open_cust_bill_pkg and
cust_bill_ApplicationCommon::apply_to_lineitems could be simplified.

The upgrade procedure is pretty sketchy.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill>, L<FS::cust_pkg>, L<FS::cust_main>, schema.html
from the base documentation.

=cut

1;

