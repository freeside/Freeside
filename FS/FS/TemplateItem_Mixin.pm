package FS::TemplateItem_Mixin;

use strict;
use vars qw( $DEBUG $me $conf $date_format );
use Carp;
use Date::Format;
use FS::UID;
use FS::Record qw( qsearch qsearchs dbh );
use FS::Conf;
use FS::part_pkg;
use FS::cust_pkg;

$DEBUG = 0;
$me = '[FS::TemplateItem_Mixin]';
FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $date_format      = $conf->config('date_format')      || '%x'; #/YY
} );

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

=item desc

Returns a description for this line item.  For typical line items, this is the
I<pkg> field of the corresponding B<FS::part_pkg> object (see L<FS::part_pkg>).
For one-shot line items and named taxes, it is the I<itemdesc> field of this
line item, and for generic taxes, simply returns "Tax".

=cut

sub desc {
  my( $self, $locale ) = @_;

  if ( $self->pkgnum > 0 ) {
    $self->itemdesc || $self->part_pkg->pkg_locale($locale);
  } else {
    my $desc = $self->itemdesc || 'Tax';
    $desc .= ' '. $self->itemcomment if $self->itemcomment =~ /\S/;
    $desc;
  }
}

=item time_period_pretty PART_PKG, AGENTNUM

Returns a formatted time period for this line item.

=cut

sub time_period_pretty {
  my( $self, $part_pkg, $agentnum ) = @_;

  #more efficient to look some of this conf stuff up outside the
  # invoice/template display loop we're called from
  # (Template_Mixin::_invoice_cust_bill_pkg) and pass them in as options

  return '' if $conf->exists('disable_line_item_date_ranges')
            || $part_pkg->option('disable_line_item_date_ranges',1)
            || ! $self->sdate
            || ! $self->edate;

  my $date_style = '';
  $date_style = $conf->config( 'cust_bill-line_item-date_style-non_monhtly',
                               $agentnum
                             )
    if $part_pkg && $part_pkg->freq !~ /^1m?$/;
  $date_style ||= $conf->config( 'cust_bill-line_item-date_style',
                                  $agentnum
                               );

  my $time_period;
  if ( defined($date_style) && $date_style eq 'month_of' ) {
    # (now watch, someone's going to make us do Chinese)
    $time_period = $self->mt('The month of [_1]',
                      $self->time2str_local('The month of %B', $self->sdate)
                   );
  } elsif ( defined($date_style) && $date_style eq 'X_month' ) {
    my $desc = $conf->config( 'cust_bill-line_item-date_description',
                               $agentnum
                            );
    $desc .= ' ' unless $desc =~ /\s$/;
    $time_period = $desc. $self->time2str_local('%B', $self->sdate);
  } else {
    $time_period =      $self->time2str_local($date_format, $self->sdate).
                 " - ". $self->time2str_local($date_format, $self->edate);
  }

  " ($time_period)";

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
      qsearch ({ 'table'    => $self->detail_table,
                 'hashref'  => { 'billpkgnum' => $self->billpkgnum },
                 'order_by' => 'ORDER BY detailnum',
              });

  } elsif ( $opt{'no_usage'} ) {

    my $sql = "SELECT detail FROM ". $self->detail_table.
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

    my $sql = "SELECT format, detail FROM ". $self->detail_table.
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

  my $csv = new Text::CSV_XS;

  my @detail = 
    qsearch ({ 'table'    => $self->detail_table,
               'hashref'  => { 'billpkgnum' => $self->billpkgnum,
                               'format'     => 'C',
                             },
               'order_by' => 'ORDER BY detailnum LIMIT 1',
            });
  return() unless scalar(@detail);
  $csv->parse($detail[0]->detail) or return ();
  $csv->fields;
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

=item cust_bill_pkg_display [ type => TYPE ]

Returns an array of display information for the invoice line item optionally
limited to 'TYPE'.

=cut

sub cust_bill_pkg_display {
  my ( $self, %opt ) = @_;

  my $class = 'FS::'. $self->display_table;

  my $default = $class->new( { billpkgnum =>$self->billpkgnum } );

  my $type = $opt{type} if exists $opt{type};
  my @result;

  if ( $self->get('display') ) {
    @result = grep { defined($type) ? ($type eq $_->type) : 1 }
              @{ $self->get('display') };
  } else {
    my $hashref = { 'billpkgnum' => $self->billpkgnum };
    $hashref->{type} = $type if defined($type);

    my $order_by = $self->display_table_orderby || 'billpkgdisplaynum';
    
    @result = qsearch ({ 'table'    => $self->display_table,
                         'hashref'  => $hashref,
                         'order_by' => "ORDER BY $order_by",
                      });
  }

  push @result, $default unless ( scalar(@result) || $type );

  @result;

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

  qsearch( $self->detail_table, \%hash ),

}

=item cust_bill_pkg_discount 

Returns the list of associated cust_bill_pkg_discount objects.

=cut

sub cust_bill_pkg_discount {
  my $self = shift;
  qsearch( $self->discount_table, { 'billpkgnum' => $self->billpkgnum } );
}

1;
