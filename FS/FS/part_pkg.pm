package FS::part_pkg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch dbh );
use FS::pkg_svc;
use FS::agent_type;
use FS::type_pkgs;
use FS::Conf;

@ISA = qw( FS::Record );

=head1 NAME

FS::part_pkg - Object methods for part_pkg objects

=head1 SYNOPSIS

  use FS::part_pkg;

  $record = new FS::part_pkg \%hash
  $record = new FS::part_pkg { 'column' => 'value' };

  $custom_record = $template_record->clone;

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  @pkg_svc = $record->pkg_svc;

  $svcnum = $record->svcpart;
  $svcnum = $record->svcpart( 'svc_acct' );

=head1 DESCRIPTION

An FS::part_pkg object represents a billing item definition.  FS::part_pkg
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item pkgpart - primary key (assigned automatically for new billing item definitions)

=item pkg - Text name of this billing item definition (customer-viewable)

=item comment - Text name of this billing item definition (non-customer-viewable)

=item setup - Setup fee expression

=item freq - Frequency of recurring fee

=item recur - Recurring fee expression

=item setuptax - Setup fee tax exempt flag, empty or `Y'

=item recurtax - Recurring fee tax exempt flag, empty or `Y'

=item taxclass - Tax class flag

=item plan - Price plan

=item plandata - Price plan data

=item disabled - Disabled flag, empty or `Y'

=back

setup and recur are evaluated as Safe perl expressions.  You can use numbers
just as you would normally.  More advanced semantics are not yet defined.

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new billing item definition.  To add the billing item definition to
the database, see L<"insert">.

=cut

sub table { 'part_pkg'; }

=item clone

An alternate constructor.  Creates a new billing item definition by duplicating
an existing definition.  A new pkgpart is assigned and `(CUSTOM) ' is prepended
to the comment field.  To add the billing item definition to the database, see
L<"insert">.

=cut

sub clone {
  my $self = shift;
  my $class = ref($self);
  my %hash = $self->hash;
  $hash{'pkgpart'} = '';
  $hash{'comment'} = "(CUSTOM) ". $hash{'comment'}
    unless $hash{'comment'} =~ /^\(CUSTOM\) /;
  #new FS::part_pkg ( \%hash ); # ?
  new $class ( \%hash ); # ?
}

=item insert

Adds this billing item definition to the database.  If there is an error,
returns the error, otherwise returns false.

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

  my $conf = new FS::Conf;

  if ( $conf->exists('agent_defaultpkg') ) {
    foreach my $agent_type ( qsearch('agent_type', {} ) ) {
      my $type_pkgs = new FS::type_pkgs({
        'typenum' => $agent_type->typenum,
        'pkgpart' => $self->pkgpart,
      });
      my $error = $type_pkgs->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't (yet?) delete package definitions.";
# check & make sure the pkgpart isn't in cust_pkg or type_pkgs?
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid billing item definition.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

sub check {
  my $self = shift;

  my $conf = new FS::Conf;
  if ( $conf->exists('safe-part_pkg') ) {

    my $error = $self->ut_anything('setup')
                || $self->ut_anything('recur');
    return $error if $error;

    my $s = $self->setup;

    $s =~ /^\s*\d*\.?\d*\s*$/

      or $s =~ /^my \$d = \$cust_pkg->bill || \$time; \$d += 86400 \* \s*\d+\s*; \$cust_pkg->bill\(\$d\); \$cust_pkg_mod_flag=1; \s*\d*\.?\d*\s*$/

      or do {
        #log!
        return "illegal setup: $s";
      };

    my $r = $self->recur;

    $r =~ /^\s*\d*\.?\d*\s*$/

      #or $r =~ /^\$sdate += 86400 \* \s*\d+\s*; \s*\d*\.?\d*\s*$/

      or $r =~ /^my \$mnow = \$sdate; my \(\$sec,\$min,\$hour,\$mday,\$mon,\$year\) = \(localtime\(\$sdate\) \)\[0,1,2,3,4,5\]; my \$mstart = timelocal\(0,0,0,1,\$mon,\$year\); my \$mend = timelocal\(0,0,0,1, \$mon == 11 \? 0 : \$mon\+1, \$year\+\(\$mon==11\)\); \$sdate = \$mstart; \( \$part_pkg->freq \- 1 \) \* \d*\.?\d* \/ \$part_pkg\-\>freq \+ \d*\.?\d* \/ \$part_pkg\-\>freq \* \(\$mend\-\$mnow\) \/ \(\$mend\-\$mstart\) ;\s*$/

      or $r =~ /^my \$mnow = \$sdate; my \(\$sec,\$min,\$hour,\$mday,\$mon,\$year\) = \(localtime\(\$sdate\) \)\[0,1,2,3,4,5\]; \$sdate = timelocal\(0,0,0,1,\$mon,\$year\); \s*\d*\.?\d*\s*;\s*$/

      or $r =~ /^my \$error = \$cust_pkg\->cust_main\->credit\( \s*\d*\.?\d*\s* \* scalar\(\$cust_pkg\->cust_main\->referral_cust_main_ncancelled\(\s*\d+\s*\)\), "commission" \); die \$error if \$error; \s*\d*\.?\d*\s*;\s*$/

      or $r =~ /^my \$error = \$cust_pkg\->cust_main\->credit\( \s*\d*\.?\d*\s* \* scalar\(\$cust_pkg\->cust_main->referral_cust_pkg\(\s*\d+\s*\)\), "commission" \); die \$error if \$error; \s*\d*\.?\d*\s*;\s*$/

      or $r =~ /^my \$error = \$cust_pkg\->cust_main\->credit\( \s*\d*\.?\d*\s* \* scalar\( grep \{ my \$pkgpart = \$_\->pkgpart; grep \{ \$_ == \$pkgpart \} \(\s*(\s*\d+,\s*)*\s*\) \} \$cust_pkg\->cust_main->referral_cust_pkg\(\s*\d+\s*\)\), "commission" \); die \$error if \$error; \s*\d*\.?\d*\s*;\s*$/

      or $r =~ /^my \$hours = \$cust_pkg\->seconds_since\(\$cust_pkg\->bill \|\| 0\) \/ 3600 \- \s*\d*\.?\d*\s*; \$hours = 0 if \$hours < 0; \s*\d*\.?\d*\s* \+ \s*\d*\.?\d*\s* \* \$hours;\s*$/

      or $r =~ /^my \$min = \$cust_pkg\->seconds_since\(\$cust_pkg\->bill \|\| 0\) \/ 60 \- \s*\d*\.?\d*\s*; \$min = 0 if \$min < 0; \s*\d*\.?\d*\s* \+ \s*\d*\.?\d*\s* \* \$min;\s*$/

      or $r =~ /^my \$last_bill = \$cust_pkg\->last_bill; my \$hours = \$cust_pkg\->seconds_since_sqlradacct\(\$last_bill, \$sdate \) \/ 3600 - \s*\d\.?\d*\s*; \$hours = 0 if \$hours < 0; my \$input = \$cust_pkg\->attribute_since_sqlradacct\(\$last_bill, \$sdate, "AcctInputOctets" \) \/ 1048576; my \$output = \$cust_pkg\->attribute_since_sqlradacct\(\$last_bill, \$sdate, "AcctOutputOctets" \) \/ 1048576; my \$total = \$input \+ \$output \- \s*\d\.?\d*\s*; \$total = 0 if \$total < 0; my \$input = \$input - \s*\d\.?\d*\s*; \$input = 0 if \$input < 0; my \$output = \$output - \s*\d\.?\d*\s*; \$output = 0 if \$output < 0; \s*\d\.?\d*\s* \+ \s*\d\.?\d*\s* \* \$hours \+ \s*\d\.?\d*\s* \* \$input \+ \s*\d\.?\d*\s* \* \$output \+ \s*\d\.?\d*\s* \* \$total *;\s*$/

      or do {
        #log!
        return "illegal recur: $r";
      };

  }

    $self->ut_numbern('pkgpart')
      || $self->ut_text('pkg')
      || $self->ut_text('comment')
      || $self->ut_anything('setup')
      || $self->ut_number('freq')
      || $self->ut_anything('recur')
      || $self->ut_alphan('plan')
      || $self->ut_anything('plandata')
      || $self->ut_enum('setuptax', [ '', 'Y' ] )
      || $self->ut_enum('recurtax', [ '', 'Y' ] )
      || $self->ut_textn('taxclass')
      || $self->ut_enum('disabled', [ '', 'Y' ] )
    ;
}

=item pkg_svc

Returns all FS::pkg_svc objects (see L<FS::pkg_svc>) for this package
definition (with non-zero quantity).

=cut

sub pkg_svc {
  my $self = shift;
  grep { $_->quantity } qsearch( 'pkg_svc', { 'pkgpart' => $self->pkgpart } );
}

=item svcpart [ SVCDB ]

Returns the svcpart of a single service definition (see L<FS::part_svc>)
associated with this billing item definition (see L<FS::pkg_svc>).  Returns
false if there not exactly one service definition with quantity 1, or if 
SVCDB is specified and does not match the svcdb of the service definition, 

=cut

sub svcpart {
  my $self = shift;
  my $svcdb = shift;
  my @pkg_svc = $self->pkg_svc;
  return '' if scalar(@pkg_svc) != 1
               || $pkg_svc[0]->quantity != 1
               || ( $svcdb && $pkg_svc[0]->part_svc->svcdb ne $svcdb );
  $pkg_svc[0]->svcpart;
}

=item payby

Returns a list of the acceptable payment types for this package.  Eventually
this should come out of a database table and be editable, but currently has the
following logic instead;

If the package has B<0> setup and B<0> recur, the single item B<BILL> is
returned, otherwise, the single item B<CARD> is returned.

(CHEK?  LEC?  Probably shouldn't accept those by default, prone to abuse)

=cut

sub payby {
  my $self = shift;
  #if ( $self->setup == 0 && $self->recur == 0 ) {
  if (    $self->setup =~ /^\s*0+(\.0*)?\s*$/
       && $self->recur =~ /^\s*0+(\.0*)?\s*$/ ) {
    ( 'BILL' );
  } else {
    ( 'CARD' );
  }
}

=back

=head1 BUGS

The delete method is unimplemented.

setup and recur semantics are not yet defined (and are implemented in
FS::cust_bill.  hmm.).

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::type_pkgs>, L<FS::pkg_svc>, L<Safe>.
schema.html from the base documentation.

=cut

1;

