package FS::part_pkg;

use strict;
use vars qw( @ISA %freq %plans $DEBUG );
use Carp;
use Tie::IxHash;
use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh dbdef );
use FS::pkg_svc;
use FS::agent_type;
use FS::type_pkgs;
use FS::part_pkg_option;

@ISA = qw( FS::Record );

$DEBUG = 0;

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

An FS::part_pkg object represents a package definition.  FS::part_pkg
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item pkgpart - primary key (assigned automatically for new package definitions)

=item pkg - Text name of this package definition (customer-viewable)

=item comment - Text name of this package definition (non-customer-viewable)

=item setup - Setup fee expression (deprecated)

=item freq - Frequency of recurring fee

=item recur - Recurring fee expression (deprecated)

=item setuptax - Setup fee tax exempt flag, empty or `Y'

=item recurtax - Recurring fee tax exempt flag, empty or `Y'

=item taxclass - Tax class 

=item plan - Price plan

=item plandata - Price plan data (deprecated - see L<FS::part_pkg_option> instead)

=item disabled - Disabled flag, empty or `Y'

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new package definition.  To add the package definition to
the database, see L<"insert">.

=cut

sub table { 'part_pkg'; }

=item clone

An alternate constructor.  Creates a new package definition by duplicating
an existing definition.  A new pkgpart is assigned and `(CUSTOM) ' is prepended
to the comment field.  To add the package definition to the database, see
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

Adds this package definition to the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub insert {
  my $self = shift;
  warn "FS::part_pkg::insert called on $self" if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  warn "  saving legacy plandata" if $DEBUG;
  my $plandata = $self->get('plandata');
  $self->set('plandata', '');

  warn "  inserting part_pkg record" if $DEBUG;
  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $plandata ) {
  warn "  inserting part_pkg_option records for plandata" if $DEBUG;
    foreach my $part_pkg_option ( 
      map { /^(\w+)=(.*)$/ or do { $dbh->rollback if $oldAutoCommit;
                                   return "illegal plandata: $plandata";
                                 };
            new FS::part_pkg_option {
              'pkgpart'     => $self->pkgpart,
              'optionname'  => $1,
              'optionvalue' => $2,
            };
          }
      split("\n", $plandata)
    ) {
      my $error = $part_pkg_option->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  my $conf = new FS::Conf;
  if ( $conf->exists('agent_defaultpkg') ) {
    warn "  agent_defaultpkg set; allowing all agents to purchase package"
      if $DEBUG;
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

  warn "  commiting transaction" if $DEBUG;
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

=cut

sub replace {
  my( $new, $old ) = ( shift, shift );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $plandata = $new->get('plandata');
  $new->set('plandata', '');

  foreach my $part_pkg_option ( $old->part_pkg_option ) {
    my $error = $part_pkg_option->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $new->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $part_pkg_option ( 
    map { /^(\w+)=(.*)$/ or do { $dbh->rollback if $oldAutoCommit;
                                 return "illegal plandata: $plandata";
                               };
          new FS::part_pkg_option {
            'pkgpart'     => $new->pkgpart,
            'optionname'  => $1,
            'optionvalue' => $2,
          };
        }
    split("\n", $plandata)
  ) {
    my $error = $part_pkg_option->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item check

Checks all fields to make sure this is a valid package definition.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

sub check {
  my $self = shift;
  warn "FS::part_pkg::check called on $self" if $DEBUG;

  for (qw(setup recur plandata)) {
    #$self->set($_=>0) if $self->get($_) =~ /^\s*$/; }
    return "Use of $_ field is deprecated; set a plan and options"
      if length($self->get($_));
    $self->set($_, '');
  }

  if ( $self->dbdef_table->column('freq')->type =~ /(int)/i ) {
    my $error = $self->ut_number('freq');
    return $error if $error;
  } else {
    $self->freq =~ /^(\d+[dw]?)$/
      or return "Illegal or empty freq: ". $self->freq;
    $self->freq($1);
  }

  my $error = $self->ut_numbern('pkgpart')
    || $self->ut_text('pkg')
    || $self->ut_text('comment')
    || $self->ut_alphan('plan')
    || $self->ut_enum('setuptax', [ '', 'Y' ] )
    || $self->ut_enum('recurtax', [ '', 'Y' ] )
    || $self->ut_textn('taxclass')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->SUPER::check
  ;
  return $error if $error;

  return 'Unknown plan '. $self->plan
    unless exists($plans{$self->plan});

  '';
}

=item pkg_svc

Returns all FS::pkg_svc objects (see L<FS::pkg_svc>) for this package
definition (with non-zero quantity).

=cut

sub pkg_svc {
  my $self = shift;
  #sort { $b->primary cmp $a->primary } 
    grep { $_->quantity }
      qsearch( 'pkg_svc', { 'pkgpart' => $self->pkgpart } );
}

=item svcpart [ SVCDB ]

Returns the svcpart of the primary service definition (see L<FS::part_svc>)
associated with this package definition (see L<FS::pkg_svc>).  Returns
false if there not a primary service definition or exactly one service
definition with quantity 1, or if SVCDB is specified and does not match the
svcdb of the service definition, 

=cut

sub svcpart {
  my $self = shift;
  my $svcdb = scalar(@_) ? shift : '';
  my @svcdb_pkg_svc =
    grep { ( $svcdb eq $_->part_svc->svcdb || !$svcdb ) } $self->pkg_svc;
  my @pkg_svc = ();
  @pkg_svc = grep { $_->primary_svc =~ /^Y/i } @svcdb_pkg_svc
    if dbdef->table('pkg_svc')->column('primary_svc');
  @pkg_svc = grep {$_->quantity == 1 } @svcdb_pkg_svc
    unless @pkg_svc;
  return '' if scalar(@pkg_svc) != 1;
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

=item freq_pretty

Returns an english representation of the I<freq> field, such as "monthly",
"weekly", "semi-annually", etc.

=cut

tie %freq, 'Tie::IxHash', 
  '0'  => '(no recurring fee)',
  '1d' => 'daily',
  '1w' => 'weekly',
  '2w' => 'biweekly (every 2 weeks)',
  '1'  => 'monthly',
  '2'  => 'bimonthly (every 2 months)',
  '3'  => 'quarterly (every 3 months)',
  '6'  => 'semiannually (every 6 months)',
  '12' => 'annually',
  '24' => 'biannually (every 2 years)',
;

sub freq_pretty {
  my $self = shift;
  my $freq = $self->freq;
  if ( exists($freq{$freq}) ) {
    $freq{$freq};
  } else {
    my $interval = 'month';
    if ( $freq =~ /^(\d+)([dw])$/ ) {
      my %interval = ( 'd'=>'day', 'w'=>'week' );
      $interval = $interval{$2};
    }
    if ( $1 == 1 ) {
      "every $interval";
    } else {
      "every $freq ${interval}s";
    }
  }
}

=item plandata

For backwards compatibility, returns the plandata field as well as all options
from FS::part_pkg_option.

=cut

sub plandata {
  my $self = shift;
  carp "plandata is deprecated";
  if ( @_ ) {
    $self->SUPER::plandata(@_);
  } else {
    my $plandata = $self->get('plandata');
    my %options = $self->options;
    $plandata .= join('', map { "$_=$options{$_}\n" } keys %options );
    $plandata;
  }
}

=item part_pkg_option

Returns all options as FS::part_pkg_option objects (see
L<FS::part_pkg_option>).

=cut

sub part_pkg_option {
  my $self = shift;
  qsearch('part_pkg_option', { 'pkgpart' => $self->pkgpart } );
}

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=cut

sub options {
  my $self = shift;
  map { $_->optionname => $_->optionvalue } $self->part_pkg_option;
}

=item option OPTIONNAME

Returns the option value for the given name, or the empty string.

=cut

sub option {
  my $self = shift;
  my $part_pkg_option =
    qsearchs('part_pkg_option', {
      pkgpart    => $self->pkgpart,
      optionname => shift,
  } );
  $part_pkg_option ? $part_pkg_option->optionvalue : '';
}

=item _rebless

Reblesses the object into the FS::part_pkg::PLAN class (if available), where
PLAN is the object's I<plan> field.  There should be better docs
on how to create new price plans, but until then, see L</NEW PLAN CLASSES>.

=cut

sub _rebless {
  my $self = shift;
  my $plan = $self->plan;
  my $class = ref($self). "::$plan";
  eval "use $class;";
  #die $@ if $@;
  bless($self, $class) unless $@;
  $self;
}

#fallbacks that eval the setup and recur fields, for backwards compat

sub calc_setup {
  my $self = shift;
  warn 'no price plan class for '. $self->plan. ", eval-ing setup\n";
  $self->_calc_eval('setup', @_);
}

sub calc_recur {
  my $self = shift;
  warn 'no price plan class for '. $self->plan. ", eval-ing recur\n";
  $self->_calc_eval('recur', @_);
}

use vars qw( $sdate @details );
sub _calc_eval {
  #my( $self, $field, $cust_pkg ) = @_;
  my( $self, $field, $cust_pkg, $sdateref, $detailsref ) = @_;
  *sdate = $sdateref;
  *details = $detailsref;
  $self->$field() =~ /^(.*)$/
    or die "Illegal $field (pkgpart ". $self->pkgpart. '): '.
            $self->$field(). "\n";
  my $prog = $1;
  return 0 if $prog =~ /^\s*$/;
  my $value = eval $prog;
  die $@ if $@;
  $value;
}

=back

=head1 SUBROUTINES

=over 4

=item plan_info

=cut

my %info;
foreach my $INC ( @INC ) {
  foreach my $file ( glob("$INC/FS/part_pkg/*.pm") ) {
    warn "attempting to load plan info from $file\n" if $DEBUG;
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized file in $INC/FS/part_pkg/: $file\n";
      next;
    };
    my $mod = $1;
    my $info = eval "use FS::part_pkg::$mod; ".
                    "\\%FS::part_pkg::$mod\::info;";
    if ( $@ ) {
      die "error using FS::part_pkg::$mod (skipping): $@\n" if $@;
      next;
    }
    unless ( keys %$info ) {
      warn "no %info hash found in FS::part_pkg::$mod, skipping\n"
        unless $mod =~ /^(passwdfile|null)$/; #hack but what the heck
      next;
    }
    warn "got plan info from FS::part_pkg::$mod: $info\n" if $DEBUG;
    if ( exists($info->{'disabled'}) && $info->{'disabled'} ) {
      warn "skipping disabled plan FS::part_pkg::$mod" if $DEBUG;
      next;
    }
    $info{$mod} = $info;
  }
}

tie %plans, 'Tie::IxHash',
  map { $_ => $info{$_} }
  sort { $info{$a}->{'weight'} <=> $info{$b}->{'weight'} }
  keys %info;

sub plan_info {
  \%plans;
}

=back

=head1 NEW PLAN CLASSES

A module should be added in FS/FS/part_pkg/ (an example may be found in
eg/plan_template.pm)

=head1 BUGS

The delete method is unimplemented.

setup and recur semantics are not yet defined (and are implemented in
FS::cust_bill.  hmm.).

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::type_pkgs>, L<FS::pkg_svc>, L<Safe>.
schema.html from the base documentation.

=cut

1;

