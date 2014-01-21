package FS::invoice_conf;

use strict;
use base qw( FS::Record FS::Conf );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::invoice_conf - Object methods for invoice_conf records

=head1 SYNOPSIS

  use FS::invoice_conf;

  $record = new FS::invoice_conf \%hash;
  $record = new FS::invoice_conf { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::invoice_conf object represents a set of localized invoice 
configuration values.  FS::invoice_conf inherits from FS::Record and FS::Conf,
and supports the FS::Conf interface.  The following fields are supported:

=over 4

=item confnum - primary key

=item modenum - L<FS::invoice_mode> foreign key

=item locale - locale string (see L<FS::Locales>)

=item notice_name - the title to display on the invoice

=item subject - subject line of the email

=item htmlnotes - "notes" section (HTML)

=item htmlfooter - footer (HTML)

=item htmlsummary - summary header, for invoices in summary format (HTML)

=item htmlreturnaddress - return address (HTML)

=item latexnotes - "notes" section (LaTeX)

=item latexfooter - footer (LaTeX)

=item latexsummary - summary header, for invoices in summary format (LaTeX)

=item latexreturnaddress - return address (LaTeX)

=item latexsmallfooter - footer for pages after the first (LaTeX)

=item with_latexcoupon - 'Y' to print the payment coupon (LaTeX)

=item lpr - command to print the invoice (passed on stdin as a PDF)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice configuration.  To add it to the database, see 
L<"insert">.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'invoice_conf'; }

# fields (prefixed with 'with_') that turn on certain conf variables 
# (set them to their conf values, rather than to null)
my %flags = (
  latexcoupon => 1
);

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# slightly special: you can insert/replace the invoice mode this way

sub insert {
  my $self = shift;
  if (!$self->modenum) {
    my $invoice_mode = FS::invoice_mode->new({
        'modename' => $self->modename,
        'agentnum' => $self->agentnum,
    });
    my $error = $invoice_mode->insert;
    return $error if $error;
    $self->set('modenum' => $invoice_mode->modenum);
  } else {
    my $invoice_mode = FS::invoice_mode->by_key($self->modenum);
    my $changed = 0;
    foreach (qw(agentnum modename)) {
      $changed ||= ($invoice_mode->get($_) eq $self->get($_));
      $invoice_mode->set($_, $self->get($_));
    }
    my $error = $invoice_mode->replace if $changed;
    return $error if $error;
  }
  $self->SUPER::insert(@_);
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  my $error = $self->FS::Record::delete; # not Conf::delete
  return $error if $error;
  my $invoice_mode = FS::invoice_mode->by_key($self->modenum);
  if ( $invoice_mode and
       FS::invoice_conf->count('modenum = '.$invoice_mode->modenum) == 0 ) {
    $error = $invoice_mode->delete;
    return $error if $error;
  }
  '';
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $self = shift;
  my $error = $self->SUPER::replace(@_);
  return $error if $error;

  my $invoice_mode = FS::invoice_mode->by_key($self->modenum);
  my $changed = 0;
  foreach (qw(agentnum modename)) {
    $changed ||= ($invoice_mode->get($_) eq $self->get($_));
    $invoice_mode->set($_, $self->get($_));
  }
  $error = $invoice_mode->replace if $changed;
  return $error if $error;
}

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('confnum')
    # core properties
    || $self->ut_number('modenum')
    || $self->ut_textn('locale')
    # direct overrides of conf variables
    || $self->ut_anything('notice_name')
    || $self->ut_anything('subject')
    || $self->ut_anything('htmlnotes')
    || $self->ut_anything('htmlfooter')
    || $self->ut_anything('htmlsummary')
    || $self->ut_anything('htmlreturnaddress')
    || $self->ut_anything('latexnotes')
    || $self->ut_anything('latexfooter')
    || $self->ut_anything('latexsummary')
    || $self->ut_anything('latexsmallfooter')
    || $self->ut_anything('latexreturnaddress')
    # flags
    || $self->ut_flag('with_latexcoupon')
  ;
  return $error if $error;

  $self->SUPER::check;
}

# hook _config to substitute our own values; let FS::Conf do the rest of 
# the interface

sub _config {
  my $self = shift;
  # if we fall back, we still want FS::Conf to respect our locale
  $self->{locale} = $self->get('locale');
  my ($key, $agentnum, $nodefault) = @_;
  # some fields, but not all, start with invoice_
  my $colname = $key;
  if ( $key =~ /^invoice_(.*)$/ ) {
    $colname = $1;
  }
  if ( $flags{$colname} and !$self->get("with_$colname") ) {
    # then a flag field is defined, and the flag is off, so act as though
    # the config entry doesn't exist
    # (currently only used for "latexcoupon", to allow invoice modes
    # where the coupon is not printed)
    return undef;
  }
  if ( length($self->get($colname)) ) {
    return FS::conf->new({ 'name'   => $key,
                           'value'  => $self->get($colname) });
  } else {
    return $self->FS::Conf::_config(@_);
  }
}

# disambiguation
sub set {
  my $self = shift;
  $self->FS::Record::set(@_);
}

sub exists {
  my $self = shift;
  $self->FS::Conf::exists(@_);
}

=back

=head1 SEE ALSO

L<FS::Template_Mixin>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

