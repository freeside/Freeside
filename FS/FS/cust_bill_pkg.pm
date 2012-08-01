package FS::cust_bill_pkg;

use strict;
use vars qw( @ISA $DEBUG $me );
use Carp;
use List::Util qw( sum );
use Text::CSV_XS;
use FS::Record qw( qsearch qsearchs dbdef dbh );
use FS::cust_main_Mixin;
use FS::cust_pkg;
use FS::part_pkg;
use FS::cust_bill;
use FS::cust_bill_pkg_detail;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pkg_discount;
use FS::cust_bill_pay_pkg;
use FS::cust_credit_bill_pkg;
use FS::cust_tax_exempt_pkg;
use FS::cust_bill_pkg_tax_location;
use FS::cust_bill_pkg_tax_rate_location;
use FS::cust_tax_adjustment;
use FS::cust_bill_pkg_void;
use FS::cust_bill_pkg_detail_void;
use FS::cust_bill_pkg_display_void;
use FS::cust_bill_pkg_tax_location_void;
use FS::cust_bill_pkg_tax_rate_location_void;
use FS::cust_tax_exempt_pkg_void;

@ISA = qw( FS::cust_main_Mixin FS::Record );

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
FS::cust_bill_pkg inherits from FS::Record.  The following fields are currently
supported:

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

  if ( $self->_cust_tax_exempt_pkg ) {
    foreach my $cust_tax_exempt_pkg ( @{$self->_cust_tax_exempt_pkg} ) {
      $cust_tax_exempt_pkg->billpkgnum($self->billpkgnum);
      $error = $cust_tax_exempt_pkg->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_tax_exempt_pkg: $error";
      }
    }
  }

  my $tax_location = $self->get('cust_bill_pkg_tax_location');
  if ( $tax_location ) {
    foreach my $cust_bill_pkg_tax_location ( @$tax_location ) {
      $cust_bill_pkg_tax_location->billpkgnum($self->billpkgnum);
      $error = $cust_bill_pkg_tax_location->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error inserting cust_bill_pkg_tax_location: $error";
      }
    }
  }

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

=item cust_pkg

Returns the package (see L<FS::cust_pkg>) for this invoice line item.

=cut

sub cust_pkg {
  my $self = shift;
  carp "$me $self -> cust_pkg" if $DEBUG;
  qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
}

=item part_pkg

Returns the package definition for this invoice line item.

=cut

sub part_pkg {
  my $self = shift;
  if ( $self->pkgpart_override ) {
    qsearchs('part_pkg', { 'pkgpart' => $self->pkgpart_override } );
  } else {
    my $part_pkg;
    my $cust_pkg = $self->cust_pkg;
    $part_pkg = $cust_pkg->part_pkg if $cust_pkg;
    $part_pkg;
  }
}

=item cust_bill

Returns the invoice (see L<FS::cust_bill>) for this invoice line item.

=cut

sub cust_bill {
  my $self = shift;
  qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );
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

=item details [ OPTION => VALUE ... ]

Returns an array of detail information for the invoice line item.

Currently available options are: I<format>, I<escape_function> and
I<format_function>.

If I<format> is set to html or latex then the array members are improved
for tabular appearance in those environments if possible.

If I<escape_function> is set then the array members are processed by this
function before being returned.

I<format_function> overrides the normal HTML or LaTeX function for returning
formatted CDRs.  It can be set to a subroutine which returns an empty list
to skip usage detail:

  'format_function' => sub { () },

=cut

sub details {
  my ( $self, %opt ) = @_;
  my $escape_function = $opt{escape_function} || sub { shift };

  my $csv = new Text::CSV_XS;

  if ( $opt{format_function} ) {

    #this still expects to be passed a cust_bill_pkg_detail object as the
    #second argument, which is expensive
    carp "deprecated format_function passed to cust_bill_pkg->details";
    my $format_sub = $opt{format_function} if $opt{format_function};

    map { ( $_->format eq 'C'
              ? &{$format_sub}( $_->detail, $_ )
              : &{$escape_function}( $_->detail )
          )
        }
      qsearch ({ 'table'    => 'cust_bill_pkg_detail',
                 'hashref'  => { 'billpkgnum' => $self->billpkgnum },
                 'order_by' => 'ORDER BY detailnum',
              });

  } elsif ( $opt{'no_usage'} ) {

    my $sql = "SELECT detail FROM cust_bill_pkg_detail ".
              "  WHERE billpkgnum = ". $self->billpkgnum.
              "    AND ( format IS NULL OR format != 'C' ) ".
              "  ORDER BY detailnum";
    my $sth = dbh->prepare($sql) or die dbh->errstr;
    $sth->execute or die $sth->errstr;

    map &{$escape_function}( $_->[0] ), @{ $sth->fetchall_arrayref };

  } else {

    my $format_sub;
    my $format = $opt{format} || '';
    if ( $format eq 'html' ) {

      $format_sub = sub { my $detail = shift;
                          $csv->parse($detail) or return "can't parse $detail";
                          join('</TD><TD>', map { &$escape_function($_) }
                                            $csv->fields
                              );
                        };

    } elsif ( $format eq 'latex' ) {

      $format_sub = sub {
        my $detail = shift;
        $csv->parse($detail) or return "can't parse $detail";
        #join(' & ', map { '\small{'. &$escape_function($_). '}' }
        #            $csv->fields );
        my $result = '';
        my $column = 1;
        foreach ($csv->fields) {
          $result .= ' & ' if $column > 1;
          if ($column > 6) {                     # KLUDGE ALERT!
            $result .= '\multicolumn{1}{l}{\scriptsize{'.
                       &$escape_function($_). '}}';
          }else{
            $result .= '\scriptsize{'.  &$escape_function($_). '}';
          }
          $column++;
        }
        $result;
      };

    } else {

      $format_sub = sub { my $detail = shift;
                          $csv->parse($detail) or return "can't parse $detail";
                          join(' - ', map { &$escape_function($_) }
                                      $csv->fields
                              );
                        };

    }

    my $sql = "SELECT format, detail FROM cust_bill_pkg_detail ".
              "  WHERE billpkgnum = ". $self->billpkgnum.
              "  ORDER BY detailnum";
    my $sth = dbh->prepare($sql) or die dbh->errstr;
    $sth->execute or die $sth->errstr;

    #avoid the fetchall_arrayref and loop for less memory usage?

    map { (defined($_->[0]) && $_->[0] eq 'C')
            ? &{$format_sub}(      $_->[1] )
            : &{$escape_function}( $_->[1] );
        }
      @{ $sth->fetchall_arrayref };

  }

}

=item details_header [ OPTION => VALUE ... ]

Returns a list representing an invoice line item detail header, if any.
This relies on the behavior of voip_cdr in that it expects the header
to be the first CSV formatted detail (as is expected by invoice generation
routines).  Returns the empty list otherwise.

=cut

sub details_header {
  my $self = shift;
  return '' unless defined dbdef->table('cust_bill_pkg_detail');

  my $csv = new Text::CSV_XS;

  my @detail = 
    qsearch ({ 'table'    => 'cust_bill_pkg_detail',
               'hashref'  => { 'billpkgnum' => $self->billpkgnum,
                               'format'     => 'C',
                             },
               'order_by' => 'ORDER BY detailnum LIMIT 1',
            });
  return() unless scalar(@detail);
  $csv->parse($detail[0]->detail) or return ();
  $csv->fields;
}

=item desc

Returns a description for this line item.  For typical line items, this is the
I<pkg> field of the corresponding B<FS::part_pkg> object (see L<FS::part_pkg>).
For one-shot line items and named taxes, it is the I<itemdesc> field of this
line item, and for generic taxes, simply returns "Tax".

=cut

sub desc {
  my $self = shift;

  if ( $self->pkgnum > 0 ) {
    $self->itemdesc || $self->part_pkg->pkg;
  } else {
    my $desc = $self->itemdesc || 'Tax';
    $desc .= ' '. $self->itemcomment if $self->itemcomment =~ /\S/;
    $desc;
  }
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

=item quantity

=cut

sub quantity {
  my( $self, $value ) = @_;
  if ( defined($value) ) {
    $self->setfield('quantity', $value);
  }
  $self->getfield('quantity') || 1;
}

=item unitsetup

=cut

sub unitsetup {
  my( $self, $value ) = @_;
  if ( defined($value) ) {
    $self->setfield('unitsetup', $value);
  }
  $self->getfield('unitsetup') eq ''
    ? $self->getfield('setup')
    : $self->getfield('unitsetup');
}

=item unitrecur

=cut

sub unitrecur {
  my( $self, $value ) = @_;
  if ( defined($value) ) {
    $self->setfield('unitrecur', $value);
  }
  $self->getfield('unitrecur') eq ''
    ? $self->getfield('recur')
    : $self->getfield('unitrecur');
}

=item set_display OPTION => VALUE ...

A helper method for I<insert>, populates the pseudo-field B<display> with
appropriate FS::cust_bill_pkg_display objects.

Options are passed as a list of name/value pairs.  Options are:

part_pkg: FS::part_pkg object from the 

real_pkgpart: if this line item comes from a bundled package, the pkgpart of the owning package.  Otherwise the same as the part_pkg's pkgpart above.

=cut

sub set_display {
  my( $self, %opt ) = @_;
  my $part_pkg = $opt{'part_pkg'};
  my $cust_pkg = new FS::cust_pkg { pkgpart => $opt{real_pkgpart} };

  my $conf = new FS::Conf;

  my $separate = $conf->exists('separate_usage');
  my $usage_mandate =            $part_pkg->option('usage_mandate', 'Hush!')
                    || $cust_pkg->part_pkg->option('usage_mandate', 'Hush!');

  # or use the category from $opt{'part_pkg'} if its not bundled?
  my $categoryname = $cust_pkg->part_pkg->categoryname;

  return $self->set('display', [])
    unless $separate || $categoryname || $usage_mandate;
  
  my @display = ();

  my %hash = ( 'section' => $categoryname );

  my $usage_section =            $part_pkg->option('usage_section', 'Hush!')
                    || $cust_pkg->part_pkg->option('usage_section', 'Hush!');

  my $summary =            $part_pkg->option('summarize_usage', 'Hush!')
              || $cust_pkg->part_pkg->option('summarize_usage', 'Hush!');

  if ( $separate ) {
    push @display, new FS::cust_bill_pkg_display { type => 'S', %hash };
    push @display, new FS::cust_bill_pkg_display { type => 'R', %hash };
  } else {
    push @display, new FS::cust_bill_pkg_display
                     { type => '',
                       %hash,
                       ( ( $usage_mandate ) ? ( 'summary' => 'Y' ) : () ),
                     };
  }

  if ($separate && $usage_section && $summary) {
    push @display, new FS::cust_bill_pkg_display { type    => 'U',
                                                   summary => 'Y',
                                                   %hash,
                                                 };
  }
  if ($usage_mandate || ($usage_section && $summary) ) {
    $hash{post_total} = 'Y';
  }

  if ($separate || $usage_mandate) {
    $hash{section} = $usage_section if $usage_section;
    push @display, new FS::cust_bill_pkg_display { type => 'U', %hash };
  }

  $self->set('display', \@display);

}

=item disintegrate

Returns a list of cust_bill_pkg objects each with no more than a single class
(including setup or recur) of charge.

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

=item cust_bill_pkg_display [ type => TYPE ]

Returns an array of display information for the invoice line item optionally
limited to 'TYPE'.

=cut

sub cust_bill_pkg_display {
  my ( $self, %opt ) = @_;

  my $default =
    new FS::cust_bill_pkg_display { billpkgnum =>$self->billpkgnum };

  my $type = $opt{type} if exists $opt{type};
  my @result;

  if ( $self->get('display') ) {
    @result = grep { defined($type) ? ($type eq $_->type) : 1 }
              @{ $self->get('display') };
  } else {
    my $hashref = { 'billpkgnum' => $self->billpkgnum };
    $hashref->{type} = $type if defined($type);
    
    @result = qsearch ({ 'table'    => 'cust_bill_pkg_display',
                         'hashref'  => { 'billpkgnum' => $self->billpkgnum },
                         'order_by' => 'ORDER BY billpkgdisplaynum',
                      });
  }

  push @result, $default unless ( scalar(@result) || $type );

  @result;

}

# reserving this name for my friends FS::{tax_rate|cust_main_county}::taxline
# and FS::cust_main::bill

sub _cust_tax_exempt_pkg {
  my ( $self ) = @_;

  $self->{Hash}->{_cust_tax_exempt_pkg} or
  $self->{Hash}->{_cust_tax_exempt_pkg} = [];

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

=item cust_bill_pkg_detail [ CLASSNUM ]

Returns the list of associated cust_bill_pkg_detail objects
The optional CLASSNUM argument will limit the details to the specified usage
class.

=cut

sub cust_bill_pkg_detail {
  my $self = shift;
  my $classnum = shift || '';

  my %hash = ( 'billpkgnum' => $self->billpkgnum );
  $hash{classnum} = $classnum if $classnum;

  qsearch( 'cust_bill_pkg_detail', \%hash ),

}

=item cust_bill_pkg_discount 

Returns the list of associated cust_bill_pkg_discount objects.

=cut

sub cust_bill_pkg_discount {
  my $self = shift;
  qsearch( 'cust_bill_pkg_discount', { 'billpkgnum' => $self->billpkgnum } );
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
  my $charged = 
    $opt{setuprecur} =~ /^s/ ? 'cust_bill_pkg.setup' :
    $opt{setuprecur} =~ /^r/ ? 'cust_bill_pkg.recur' :
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
  my $s = $start ? "AND cust_bill_pay._date <= $start" : '';
  my $e = $end   ? "AND cust_bill_pay._date >  $end"   : '';
  my $setuprecur = 
    $opt{setuprecur} =~ /^s/ ? 'setup' :
    $opt{setuprecur} =~ /^r/ ? 'recur' :
    '';
  $setuprecur &&= "AND setuprecur = '$setuprecur'";

  my $paid = "( SELECT COALESCE(SUM(cust_bill_pay_pkg.amount),0)
     FROM cust_bill_pay_pkg JOIN cust_bill_pay USING (billpaynum)
     WHERE cust_bill_pay_pkg.billpkgnum = cust_bill_pkg.billpkgnum
           $s $e$setuprecur )";

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
  my $s = $start ? "AND cust_credit_bill._date <= $start" : '';
  my $e = $end   ? "AND cust_credit_bill._date >  $end"   : '';
  my $setuprecur = 
    $opt{setuprecur} =~ /^s/ ? 'setup' :
    $opt{setuprecur} =~ /^r/ ? 'recur' :
    '';
  $setuprecur &&= "AND setuprecur = '$setuprecur'";

  my $credited = "( SELECT COALESCE(SUM(cust_credit_bill_pkg.amount),0)
     FROM cust_credit_bill_pkg JOIN cust_credit_bill USING (creditbillnum)
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

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill>, L<FS::cust_pkg>, L<FS::cust_main>, schema.html
from the base documentation.

=cut

1;

