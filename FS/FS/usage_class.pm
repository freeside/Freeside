package FS::usage_class;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::usage_class - Object methods for usage_class records

=head1 SYNOPSIS

  use FS::usage_class;

  $record = new FS::usage_class \%hash;
  $record = new FS::usage_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::usage_class object represents a usage class.  Every rate detail
(see L<FS::rate_detail>) has, optionally, a usage class.  FS::usage_class
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item classnum

Primary key (assigned automatically for new usage classes)

=item classname

Text name of this usage class

=item disabled

Disabled flag, empty or 'Y'


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new usage class.  To add the usage class to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'usage_class'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid usage class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('classnum')
    || $self->ut_numbern('weight')
    || $self->ut_text('classname')
    || $self->ut_textn('format')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item summary_formats_labelhash

Returns a list of line item format descriptions suitable for assigning to
a hash. 

=cut

# transform hashes of arrays to arrays of hashes for false laziness removal?
my %summary_formats = (
  'simple' => { 
    'label' => [ qw( Description Calls Minutes Amount ) ],
    'fields' => [
                  sub { shift->{description} },
                  sub { shift->{calls} },
                  sub { sprintf( '%.1f', shift->{duration}/60 ) },
                  sub { shift->{amount} },
                ],
    'align'  => [ qw( l r r r ) ],
    'span'   => [ qw( 4 1 1 1 ) ],            # unitprices?
    'width'  => [ qw( 8.2cm 2.5cm 1.4cm 1.6cm ) ],   # don't like this
  },
  'simpler' => { 
    'label' =>  [ qw( Description Calls Amount ) ],
    'fields' => [
                  sub { shift->{description} },
                  sub { shift->{calls} },
                  sub { shift->{amount} },
                ],
    'align'  => [ qw( l r r ) ],
    'span'   => [ qw( 5 1 1 ) ],
    'width'  => [ qw( 10.7cm 1.4cm 1.6cm ) ],   # don't like this
  },
  'minimal' => { 
    'label' => [ qw( Amount ) ],
    'fields' => [
                  sub { '' },
                ],
    'align'  => [ qw( r ) ],
    'span'   => [ qw( 7 ) ],            # unitprices?
    'width'  => [ qw( 13.8cm ) ],   # don't like this
  },
);

sub summary_formats_labelhash {
  map { $_ => join(',', @{$summary_formats{$_}{label}}) } keys %summary_formats;
}

=item header_generator FORMAT

Returns a coderef used for generation of an invoice line item header for this
usage_class. FORMAT is either html or latex

=cut

my %html_align = (
  'c' => 'center',
  'l' => 'left',
  'r' => 'right',
);

sub _generator_defaults {
  my ( $self, $format ) = ( shift, shift );
  return ( $summary_formats{$self->format}, ' ', ' ', ' ', sub { shift } );
}

sub header_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    $self->_generator_defaults($format);

  if ($format eq 'latex') {
    $prefix = "\\hline\n\\rule{0pt}{2.5ex}\n\\makebox[1.4cm]{}&\n";
    $suffix = "\\\\\n\\hline";
    $separator = "&\n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{\\textbf{$d}}}";
          };
  } elsif ( $format eq 'html' ) {
    $prefix = '<th></th>';
    $suffix = '';
    $separator = '';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<th align="$html_align{$a}">$d</th>!;
      };
  }

  sub {
    my @args = @_;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( map { $f->{$_}->[$i] } qw(label align span width) );
    }

    $prefix. join($separator, @result). $suffix;  
  };

}

=item description_generator FORMAT

Returns a coderef used for generation of invoice line items for this
usage_class.  FORMAT is either html or latex

=cut

sub description_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    $self->_generator_defaults($format);

  if ($format eq 'latex') {
    $prefix = "\\hline\n\\multicolumn{1}{c}{\\rule{0pt}{2.5ex}~} &\n";
    $suffix = '\\\\';
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{\\textbf{$d}}}";
          };
  }elsif ( $format eq 'html' ) {
    $prefix = '"><td align="center"></td>';
    $suffix = '';
    $separator = '';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}">$d</td>!;
      };
  }

  sub {
    my @args = @_;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result, &{$column}( &{$f->{fields}->[$i]}(@args),
                                map { $f->{$_}->[$i] } qw(align span width)
                              );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}

=item total_generator FORMAT

Returns a coderef used for generation of invoice total lines for this
usage_class.  FORMAT is either html or latex

=cut

sub total_generator {
  my ( $self, $format ) = ( shift, shift );

#  $OUT .= '\FStotaldesc{' . $section->{'description'} . ' Total}' .
#          '{' . $section->{'subtotal'} . '}' . "\n";

  my ( $f, $prefix, $suffix, $separator, $column ) =
    $self->_generator_defaults($format);
  my $style = '';

  if ($format eq 'latex') {
    $prefix = "& ";
    $suffix = "\\\\\n";
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{$d}}";
          };
  }elsif ( $format eq 'html' ) {
    $prefix = '';
    $suffix = '';
    $separator = '';
    $style = 'border-top: 3px solid #000000;border-bottom: 3px solid #000000;';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}" style="$style">$d</td>!;
      };
  }
  

  sub {
    my @args = @_;
    my @result = ();

    #  my $r = &{$f->{fields}->[$i]}(@args);
    #  $r .= ' Total' unless $i;

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( &{$f->{fields}->[$i]}(@args). ($i ? '' : ' Total'),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}

=item total_line_generator FORMAT

Returns a coderef used for generation of invoice total line items for this
usage_class.  FORMAT is either html or latex

=cut

# not used: will have issues with hash element names (description vs
# total_item and amount vs total_amount -- another array of functions?

sub total_line_generator {
  my ( $self, $format ) = ( shift, shift );

#     $OUT .= '\FStotaldesc{' . $line->{'total_item'} . '}' .
#             '{' . $line->{'total_amount'} . '}' . "\n";

  my ( $f, $prefix, $suffix, $separator, $column ) =
    $self->_generator_defaults($format);
  my $style = '';

  if ($format eq 'latex') {
    $prefix = "& ";
    $suffix = "\\\\\n";
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{$d}}";
          };
  }elsif ( $format eq 'html' ) {
    $prefix = '';
    $suffix = '';
    $separator = '';
    $style = 'border-top: 3px solid #000000;border-bottom: 3px solid #000000;';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}" style="$style">$d</td>!;
      };
  }
  

  sub {
    my @args = @_;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( &{$f->{fields}->[$i]}(@args),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}



sub _populate_initial_data {
  my ($class, %opts) = @_;

  foreach ("Intrastate", "Interstate", "International") {
    my $object = $class->new( { 'classname' => $_ } );
    my $error = $object->insert;
    die "error inserting $class into database: $error\n"
      if $error;
  }

  '';

}

sub _upgrade_data {
  my $class = shift;

  return $class->_populate_initial_data(@_)
    unless scalar( qsearch( 'usage_class', {} ) );

  '';

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

