package FS::cust_bill_pkg;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Record qw( qsearch qsearchs dbdef dbh );
use FS::cust_main_Mixin;
use FS::cust_pkg;
use FS::part_pkg;
use FS::cust_bill;
use FS::cust_bill_pkg_detail;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pay_pkg;
use FS::cust_credit_bill_pkg;
use FS::cust_tax_exempt_pkg;

@ISA = qw( FS::cust_main_Mixin FS::Record );

$DEBUG = 0;

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

=item billpkgnum - primary key

=item invnum - invoice (see L<FS::cust_bill>)

=item pkgnum - package (see L<FS::cust_pkg>) or 0 for the special virtual sales tax package, or -1 for the virtual line item (itemdesc is used for the line)

=item pkgpart_override - optional package definition (see L<FS::part_pkg>) override
=item setup - setup fee

=item recur - recurring fee

=item sdate - starting date of recurring fee

=item edate - ending date of recurring fee

=item itemdesc - Line item description (overrides normal package description)

=item quantity - If not set, defaults to 1

=item unitsetup - If not set, defaults to setup

=item unitrecur - If not set, defaults to recur

=item hidden - If set to Y, indicates data should not appear as separate line item on invoice

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
      my $cust_bill_pkg_detail = new FS::cust_bill_pkg_detail {
        'billpkgnum' => $self->billpkgnum,
        'format'     => (ref($detail) ? $detail->[0] : '' ),
        'detail'     => (ref($detail) ? $detail->[1] : $detail ),
        'amount'     => (ref($detail) ? $detail->[2] : '' ),
        'classnum'   => (ref($detail) ? $detail->[3] : '' ),
        'phonenum'   => (ref($detail) ? $detail->[4] : '' ),
      };
      $error = $cust_bill_pkg_detail->insert;
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
      warn $cust_bill_pkg_tax_location;
      $error = $cust_bill_pkg_tax_location->insert;
      warn $error;
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
      warn $error;
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
    warn $error;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error replacing cust_tax_adjustment: $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Currently unimplemented.  I don't remove line items because there would then be
no record the items ever existed (which is bad, no?)

=cut

sub delete {
  return "Can't delete cust_bill_pkg records!";
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

  #if ( $self->pkgnum != 0 ) { #allow unchecked pkgnum 0 for tax! (add to part_pkg?)
  if ( $self->pkgnum > 0 ) { #allow -1 for non-pkg line items and 0 for tax (add to part_pkg?)
    return "Unknown pkgnum ". $self->pkgnum
      unless qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
  }

  return "Unknown invnum"
    unless qsearchs( 'cust_bill' ,{ 'invnum' => $self->invnum } );

  $self->SUPER::check;
}

=item cust_pkg

Returns the package (see L<FS::cust_pkg>) for this invoice line item.

=cut

sub cust_pkg {
  my $self = shift;
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
    $self->cust_pkg->part_pkg;
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

Currently available options are: I<format> I<escape_function>

If I<format> is set to html or latex then the array members are improved
for tabular appearance in those environments if possible.

If I<escape_function> is set then the array members are processed by this
function before being returned.

=cut

sub details {
  my ( $self, %opt ) = @_;
  my $format = $opt{format} || '';
  my $escape_function = $opt{escape_function} || sub { shift };
  return () unless defined dbdef->table('cust_bill_pkg_detail');

  eval "use Text::CSV_XS;";
  die $@ if $@;
  my $csv = new Text::CSV_XS;

  my $format_sub = sub { my $detail = shift;
                         $csv->parse($detail) or return "can't parse $detail";
                         join(' - ', map { &$escape_function($_) }
                                     $csv->fields
                             );
                       };

  $format_sub = sub { my $detail = shift;
                      $csv->parse($detail) or return "can't parse $detail";
                      join('</TD><TD>', map { &$escape_function($_) }
                                        $csv->fields
                          );
                    }
    if $format eq 'html';

  $format_sub = sub { my $detail = shift;
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
                    }
    if $format eq 'latex';

  $format_sub = $opt{format_function} if $opt{format_function};

  map { ( $_->format eq 'C'
          ? &{$format_sub}( $_->detail, $_ )
          : &{$escape_function}( $_->detail )
        )
      }
    qsearch ({ 'table'    => 'cust_bill_pkg_detail',
               'hashref'  => { 'billpkgnum' => $self->billpkgnum },
               'order_by' => 'ORDER BY detailnum',
            });
    #qsearch ( 'cust_bill_pkg_detail', { 'lineitemnum' => $self->lineitemnum });
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
  my $usage = sprintf( "%.2f", $cust_bill_pkg{recur}->usage );
  warn "usage is $usage\n" if $DEBUG;
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
    delete $cust_bill_pkg{''} unless $cust_bill_pkg{''}->recur;
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
  my $sum = 0;
  my @values = ();

  if ( $self->get('details') ) {

    @values = 
      map { $_->[2] }
      grep { ref($_) && ( defined($classnum) ? $_->[3] eq $classnum : 1 ) }
      @{ $self->get('details') };

  }else{

    my $hashref = { 'billpkgnum' => $self->billpkgnum };
    $hashref->{ 'classnum' } = $classnum if defined($classnum);
    @values = map { $_->amount } qsearch('cust_bill_pkg_detail', $hashref);

  }

  foreach ( @values ) {
    $sum += $_ if $_;
  }
  $sum;
}

=item usage_classes

Returns a list of usage classnums associated with this invoice line's
details.
  
=cut

sub usage_classes {
  my( $self ) = @_;

  if ( $self->get('details') ) {

    my %seen = ();
    foreach my $detail ( grep { ref($_) } @{$self->get('details')} ) {
      $seen{ $detail->[3] } = 1;
    }
    keys %seen;

  }else{

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

  return ( $default ) unless defined dbdef->table('cust_bill_pkg_display');#hmmm

  my $type = $opt{type} if exists $opt{type};
  my @result;

  if ( scalar( $self->get('display') ) ) {
    @result = grep { defined($type) ? ($type eq $_->type) : 1 }
              @{ $self->get('display') };
  }else{
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

