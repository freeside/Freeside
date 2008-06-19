package FS::part_pkg;

use strict;
use vars qw( @ISA %plans $DEBUG );
use Carp qw(carp cluck confess);
use Scalar::Util qw( blessed );
use Tie::IxHash;
use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh dbdef );
use FS::pkg_svc;
use FS::part_svc;
use FS::cust_pkg;
use FS::agent_type;
use FS::type_pkgs;
use FS::part_pkg_option;
use FS::pkg_class;
use FS::agent;
use FS::part_pkg_taxoverride;
use FS::part_pkg_taxproduct;
use FS::part_pkg_link;

@ISA = qw( FS::m2m_Common FS::option_Common );
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

=item classnum - Optional package class (see L<FS::pkg_class>)

=item promo_code - Promotional code

=item setup - Setup fee expression (deprecated)

=item freq - Frequency of recurring fee

=item recur - Recurring fee expression (deprecated)

=item setuptax - Setup fee tax exempt flag, empty or `Y'

=item recurtax - Recurring fee tax exempt flag, empty or `Y'

=item taxclass - Tax class 

=item plan - Price plan

=item plandata - Price plan data (deprecated - see L<FS::part_pkg_option> instead)

=item disabled - Disabled flag, empty or `Y'

=item pay_weight - Weight (relative to credit_weight and other package definitions) that controls payment application to specific line items.

=item credit_weight - Weight (relative to other package definitions) that controls credit application to specific line items.

=item agentnum - Optional agentnum (see L<FS::agent>)

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

=item insert [ , OPTION => VALUE ... ]

Adds this package definition to the database.  If there is an error,
returns the error, otherwise returns false.

Currently available options are: I<pkg_svc>, I<primary_svc>, I<cust_pkg>, 
I<custnum_ref> and I<options>.

If I<pkg_svc> is set to a hashref with svcparts as keys and quantities as
values, appropriate FS::pkg_svc records will be inserted.

If I<primary_svc> is set to the svcpart of the primary service, the appropriate
FS::pkg_svc record will be updated.

If I<cust_pkg> is set to a pkgnum of a FS::cust_pkg record (or the FS::cust_pkg
record itself), the object will be updated to point to this package definition.

In conjunction with I<cust_pkg>, if I<custnum_ref> is set to a scalar reference,
the scalar will be updated with the custnum value from the cust_pkg record.

If I<options> is set to a hashref of options, appropriate FS::part_pkg_option
records will be inserted.

=cut

sub insert {
  my $self = shift;
  my %options = @_;
  warn "FS::part_pkg::insert called on $self with options ".
       join(', ', map "$_=>$options{$_}", keys %options)
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  warn "  inserting part_pkg record" if $DEBUG;
  my $error = $self->SUPER::insert( $options{options} );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
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

  warn "  inserting pkg_svc records" if $DEBUG;
  my $pkg_svc = $options{'pkg_svc'} || {};
  foreach my $part_svc ( qsearch('part_svc', {} ) ) {
    my $quantity = $pkg_svc->{$part_svc->svcpart} || 0;
    my $primary_svc =
      ( $options{'primary_svc'} && $options{'primary_svc'}==$part_svc->svcpart )
        ? 'Y'
        : '';

    my $pkg_svc = new FS::pkg_svc( {
      'pkgpart'     => $self->pkgpart,
      'svcpart'     => $part_svc->svcpart,
      'quantity'    => $quantity, 
      'primary_svc' => $primary_svc,
    } );
    my $error = $pkg_svc->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $options{'cust_pkg'} ) {
    warn "  updating cust_pkg record " if $DEBUG;
    my $old_cust_pkg =
      ref($options{'cust_pkg'})
        ? $options{'cust_pkg'}
        : qsearchs('cust_pkg', { pkgnum => $options{'cust_pkg'} } );
    ${ $options{'custnum_ref'} } = $old_cust_pkg->custnum
      if $options{'custnum_ref'};
    my %hash = $old_cust_pkg->hash;
    $hash{'pkgpart'} = $self->pkgpart,
    my $new_cust_pkg = new FS::cust_pkg \%hash;
    local($FS::cust_pkg::disable_agentcheck) = 1;
    my $error = $new_cust_pkg->replace($old_cust_pkg);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error modifying cust_pkg record: $error";
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

=item replace OLD_RECORD [ , OPTION => VALUE ... ]

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Currently available options are: I<pkg_svc>, I<primary_svc> and I<options>

If I<pkg_svc> is set to a hashref with svcparts as keys and quantities as
values, the appropriate FS::pkg_svc records will be replaced.

If I<primary_svc> is set to the svcpart of the primary service, the appropriate
FS::pkg_svc record will be updated.

If I<options> is set to a hashref, the appropriate FS::part_pkg_option records
will be replaced.

=cut

sub replace {
  my $new = shift;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $new->replace_old;

  my $options = 
    ( ref($_[0]) eq 'HASH' )
      ? shift
      : { @_ };

  $options->{options} = {} unless defined($options->{options});

  warn "FS::part_pkg::replace called on $new to replace $old with options".
       join(', ', map "$_ => ". $options->{$_}, keys %$options)
    if $DEBUG;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #plandata shit stays in replace for upgrades until after 2.0 (or edit
  #_upgrade_data)
  warn "  saving legacy plandata" if $DEBUG;
  my $plandata = $new->get('plandata');
  $new->set('plandata', '');

  warn "  deleting old part_pkg_option records" if $DEBUG;
  foreach my $part_pkg_option ( $old->part_pkg_option ) {
    my $error = $part_pkg_option->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  warn "  replacing part_pkg record" if $DEBUG;
  my $error = $new->SUPER::replace($old, $options->{options} );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  warn "  inserting part_pkg_option records for plandata: $plandata|" if $DEBUG;
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

  warn "  replacing pkg_svc records" if $DEBUG;
  my $pkg_svc = $options->{'pkg_svc'} || {};
  foreach my $part_svc ( qsearch('part_svc', {} ) ) {
    my $quantity = $pkg_svc->{$part_svc->svcpart} || 0;
    my $primary_svc = $options->{'primary_svc'} == $part_svc->svcpart ? 'Y' : '';

    my $old_pkg_svc = qsearchs('pkg_svc', {
      'pkgpart' => $old->pkgpart,
      'svcpart' => $part_svc->svcpart,
    } );
    my $old_quantity = $old_pkg_svc ? $old_pkg_svc->quantity : 0;
    my $old_primary_svc =
      ( $old_pkg_svc && $old_pkg_svc->dbdef_table->column('primary_svc') )
        ? $old_pkg_svc->primary_svc
        : '';
    next unless $old_quantity != $quantity || $old_primary_svc ne $primary_svc;
  
    my $new_pkg_svc = new FS::pkg_svc( {
      'pkgsvcnum'   => ( $old_pkg_svc ? $old_pkg_svc->pkgsvcnum : '' ),
      'pkgpart'     => $new->pkgpart,
      'svcpart'     => $part_svc->svcpart,
      'quantity'    => $quantity, 
      'primary_svc' => $primary_svc,
    } );
    my $error = $old_pkg_svc
                  ? $new_pkg_svc->replace($old_pkg_svc)
                  : $new_pkg_svc->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  warn "  commiting transaction" if $DEBUG;
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
    return "Use of $_ field is deprecated; set a plan and options: ".
           $self->get($_)
      if length($self->get($_));
    $self->set($_, '');
  }

  if ( $self->dbdef_table->column('freq')->type =~ /(int)/i ) {
    my $error = $self->ut_number('freq');
    return $error if $error;
  } else {
    $self->freq =~ /^(\d+[hdw]?)$/
      or return "Illegal or empty freq: ". $self->freq;
    $self->freq($1);
  }

  my $error = $self->ut_numbern('pkgpart')
    || $self->ut_text('pkg')
    || $self->ut_text('comment')
    || $self->ut_textn('promo_code')
    || $self->ut_alphan('plan')
    || $self->ut_enum('setuptax', [ '', 'Y' ] )
    || $self->ut_enum('recurtax', [ '', 'Y' ] )
    || $self->ut_textn('taxclass')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_floatn('pay_weight')
    || $self->ut_floatn('credit_weight')
    || $self->ut_numbern('taxproductnum')
    || $self->ut_foreign_keyn('taxproductnum',
                              'part_pkg_taxproduct',
                              'taxproductnum'
                             )
    || $self->ut_agentnum_acl('agentnum', 'Edit global package definitions')
    || $self->SUPER::check
  ;
  return $error if $error;

  if ( $self->classnum !~ /^$/ ) {
    my $error = $self->ut_foreign_key('classnum', 'pkg_class', 'classnum');
    return $error if $error;
  } else {
    $self->classnum('');
  }

  return 'Unknown plan '. $self->plan
    unless exists($plans{$self->plan});

  my $conf = new FS::Conf;
  return 'Taxclass is required'
    if ! $self->taxclass && $conf->exists('require_taxclasses');

  '';
}

=item pkg_comment

Returns an (internal) string representing this package.  Currently,
"pkgpart: pkg - comment", is returned.  "pkg - comment" may be returned in the
future, omitting pkgpart.

=cut

sub pkg_comment {
  my $self = shift;

  #$self->pkg. ' - '. $self->comment;
  #$self->pkg. ' ('. $self->comment. ')';
  $self->pkgpart. ': '. $self->pkg. ' - '. $self->comment;
}

=item pkg_class

Returns the package class, as an FS::pkg_class object, or the empty string
if there is no package class.

=cut

sub pkg_class {
  my $self = shift;
  if ( $self->classnum ) {
    qsearchs('pkg_class', { 'classnum' => $self->classnum } );
  } else {
    return '';
  }
}

=item categoryname 

Returns the package category name, or the empty string if there is no package
category.

=cut

sub categoryname {
  my $self = shift;
  my $pkg_class = $self->pkg_class;
  $pkg_class
    ? $pkg_class->categoryname
    : '';
}

=item classname 

Returns the package class name, or the empty string if there is no package
class.

=cut

sub classname {
  my $self = shift;
  my $pkg_class = $self->pkg_class;
  $pkg_class
    ? $pkg_class->classname
    : '';
}

=item agent 

Returns the associated agent for this event, if any, as an FS::agent object.

=cut

sub agent {
  my $self = shift;
  qsearchs('agent', { 'agentnum' => $self->agentnum } );
}

=item pkg_svc [ HASHREF | OPTION => VALUE ]

Returns all FS::pkg_svc objects (see L<FS::pkg_svc>) for this package
definition (with non-zero quantity).

One option is available, I<disable_linked>.  If set true it will return the
services for this package definition alone, omitting services from any add-on
packages.

=cut

sub pkg_svc {
  my $self = shift;

#  #sort { $b->primary cmp $a->primary } 
#    grep { $_->quantity }
#      qsearch( 'pkg_svc', { 'pkgpart' => $self->pkgpart } );

  my $opt = ref($_[0]) ? $_[0] : { @_ };
  my %pkg_svc = map  { $_->svcpart => $_ }
                grep { $_->quantity }
                qsearch( 'pkg_svc', { 'pkgpart' => $self->pkgpart } );

  unless ( $opt->{disable_linked} ) {
    foreach my $dst_pkg ( map $_->dst_pkg, $self->svc_part_pkg_link ) {
      my @pkg_svc = grep { $_->quantity }
                    qsearch( 'pkg_svc', { pkgpart=>$dst_pkg->pkgpart } );
      foreach my $pkg_svc ( @pkg_svc ) {
        if ( $pkg_svc{$pkg_svc->svcpart} ) {
          my $quantity = $pkg_svc{$pkg_svc->svcpart}->quantity;
          $pkg_svc{$pkg_svc->svcpart}->quantity($quantity + $pkg_svc->quantity);
        } else {
          $pkg_svc{$pkg_svc->svcpart} = $pkg_svc;
        }
      }
    }
  }

  values(%pkg_svc);

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
following logic instead:

If the package is free, the single item B<BILL> is
returned, otherwise, the single item B<CARD> is returned.

(CHEK?  LEC?  Probably shouldn't accept those by default, prone to abuse)

=cut

sub payby {
  my $self = shift;
  if ( $self->is_free ) {
    ( 'BILL' );
  } else {
    ( 'CARD' );
  }
}

=item is_free

Returns true if this package is free.  

=cut

sub is_free {
  my $self = shift;
  unless ( $self->plan ) {
    $self->setup =~ /^\s*0+(\.0*)?\s*$/
      && $self->recur =~ /^\s*0+(\.0*)?\s*$/;
  } elsif ( $self->can('is_free_options') ) {
    not grep { $_ !~ /^\s*0*(\.0*)?\s*$/ }
         map { $self->option($_) } 
             $self->is_free_options;
  } else {
    warn "FS::part_pkg::is_free: FS::part_pkg::". $self->plan. " subclass ".
         "provides neither is_free_options nor is_free method; returning false";
    0;
  }
}


sub freqs_href {
  #method, class method or sub? #my $self = shift;

  tie my %freq, 'Tie::IxHash', 
    '0'    => '(no recurring fee)',
    '1h'   => 'hourly',
    '1d'   => 'daily',
    '2d'   => 'every two days',
    '3d'   => 'every three days',
    '1w'   => 'weekly',
    '2w'   => 'biweekly (every 2 weeks)',
    '1'    => 'monthly',
    '45d'  => 'every 45 days',
    '2'    => 'bimonthly (every 2 months)',
    '3'    => 'quarterly (every 3 months)',
    '4'    => 'every 4 months',
    '137d' => 'every 4 1/2 months (137 days)',
    '6'    => 'semiannually (every 6 months)',
    '12'   => 'annually',
    '13'   => 'every 13 months (annually +1 month)',
    '24'   => 'biannually (every 2 years)',
    '36'   => 'triannually (every 3 years)',
    '48'   => '(every 4 years)',
    '60'   => '(every 5 years)',
    '120'  => '(every 10 years)',
  ;

  \%freq;

}

=item freq_pretty

Returns an english representation of the I<freq> field, such as "monthly",
"weekly", "semi-annually", etc.

=cut

sub freq_pretty {
  my $self = shift;
  my $freq = $self->freq;

  #my $freqs_href = $self->freqs_href;
  my $freqs_href = freqs_href();

  if ( exists($freqs_href->{$freq}) ) {
    $freqs_href->{$freq};
  } else {
    my $interval = 'month';
    if ( $freq =~ /^(\d+)([hdw])$/ ) {
      my %interval = ( 'h' => 'hour', 'd'=>'day', 'w'=>'week' );
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
  my( $self, $opt, $ornull ) = @_;
  my $part_pkg_option =
    qsearchs('part_pkg_option', {
      pkgpart    => $self->pkgpart,
      optionname => $opt,
  } );
  return $part_pkg_option->optionvalue if $part_pkg_option;
  my %plandata = map { /^(\w+)=(.*)$/; ( $1 => $2 ); }
                     split("\n", $self->get('plandata') );
  return $plandata{$opt} if exists $plandata{$opt};
  cluck "WARNING: (pkgpart ". $self->pkgpart. ") Package def option $opt ".
        "not found in options or plandata!\n"
    unless $ornull;
  '';
}

=item bill_part_pkg_link

Returns the associated part_pkg_link records (see L<FS::part_pkg_link).

=cut

sub bill_part_pkg_link {
  shift->_part_pkg_link('bill', @_);
}

=item svc_part_pkg_link

=cut

sub svc_part_pkg_link {
  shift->_part_pkg_link('svc', @_);
}

sub _part_pkg_link {
  my( $self, $type ) = @_;
  qsearch('part_pkg_link', { 'src_pkgpart' => $self->pkgpart,
                             'link_type'   => $type,
                           }
         );
}

sub self_and_bill_linked {
  shift->_self_and_linked('bill', @_);
}

sub _self_and_linked {
  my( $self, $type ) = @_;

  ( $self,
    map { $_->dst_pkg->_self_and_linked($type) }
        $self->_part_pkg_link($type)
  );
}

=item part_pkg_taxoverride

Returns all associated FS::part_pkg_taxoverride objects (see
L<FS::part_pkg_taxoverride>).

=cut

sub part_pkg_taxoverride {
  my $self = shift;
  qsearch('part_pkg_taxoverride', { 'pkgpart' => $self->pkgpart } );
}

=item taxproduct_description

Returns the description of the associated tax product for this package
definition (see L<FS::part_pkg_taxproduct>).

=cut

sub taxproduct_description {
  my $self = shift;
  my $part_pkg_taxproduct =
    qsearchs( 'part_pkg_taxproduct',
              { 'taxproductnum' => $self->taxproductnum }
            );
  $part_pkg_taxproduct ? $part_pkg_taxproduct->description : '';
}

=item part_pkg_taxrate DATA_PROVIDER, GEOCODE

Returns the package to taxrate m2m records for this package in the location
specified by GEOCODE (see L<FS::part_pkg_taxrate> and ).

=cut

sub _expand_cch_taxproductnum {
  my $self = shift;
  my $part_pkg_taxproduct =
    qsearchs( 'part_pkg_taxproduct',
              { 'taxproductnum' => $self->taxproductnum }
            );
  my ($a,$b,$c,$d) = ( $part_pkg_taxproduct
                         ? ( split ':', $part_pkg_taxproduct->taxproduct )
                         : ()
                     );
  my $extra_sql = "AND ( taxproduct = '$a:$b:$c:$d'
                      OR taxproduct = '$a:$b:$c:'
                      OR taxproduct = '$a:$b:".":$d'
                      OR taxproduct = '$a:$b:".":' )";
  map { $_->taxproductnum } qsearch( { 'table'     => 'part_pkg_taxproduct',
                                       'hashref'   => { 'data_vendor'=>'cch' },
                                       'extra_sql' => $extra_sql,
                                   } );
                                     
}

sub part_pkg_taxrate {
  my $self = shift;
  my ($data_vendor, $geocode) = @_;

  my $dbh = dbh;
  my $extra_sql = 'WHERE part_pkg_taxproduct.data_vendor = '.
                  dbh->quote($data_vendor);
  
  # CCH oddness in m2m
  $extra_sql .= ' AND ('.
    join(' OR ', map{ 'geocode = '. $dbh->quote(substr($geocode, 0, $_)) }
                 qw(10 5 2)
        ).
    ')';
  # much more CCH oddness in m2m -- this is kludgy
  $extra_sql .= ' AND ('.
    join(' OR ', map{ "taxproductnum = $_" } $self->_expand_cch_taxproductnum).
    ')';

  my $addl_from = 'LEFT JOIN part_pkg_taxproduct USING ( taxproductnum )';
  my $order_by = 'ORDER BY taxclassnum, length(geocode) desc, length(taxproduct) desc';
  my $select   = 'DISTINCT ON(taxclassnum) *, taxproduct';

  # should qsearch preface columns with the table to facilitate joins?
  qsearch( { 'table'     => 'part_pkg_taxrate',
             'select'    => $select,
             'hashref'   => { # 'data_vendor'   => $data_vendor,
                              # 'taxproductnum' => $self->taxproductnum,
                            },
             'addl_from' => $addl_from,
             'extra_sql' => $extra_sql,
             'order_by'  => $order_by,
         } );
}

=item _rebless

Reblesses the object into the FS::part_pkg::PLAN class (if available), where
PLAN is the object's I<plan> field.  There should be better docs
on how to create new price plans, but until then, see L</NEW PLAN CLASSES>.

=cut

sub _rebless {
  my $self = shift;
  my $plan = $self->plan;
  unless ( $plan ) {
    cluck "no price plan found for pkgpart ". $self->pkgpart. "\n"
      if $DEBUG;
    return $self;
  }
  return $self if ref($self) =~ /::$plan$/; #already blessed into plan subclass
  my $class = ref($self). "::$plan";
  warn "reblessing $self into $class" if $DEBUG;
  eval "use $class;";
  die $@ if $@;
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

#fallback that return 0 for old legacy packages with no plan

sub calc_remain { 0; }
sub calc_cancel { 0; }
sub calc_units  { 0; }

=back

=cut

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data { # class method
  my($class, %opts) = @_;

  warn "[FS::part_pkg] upgrading $class\n" if $DEBUG;

  my @part_pkg = qsearch({
    'table'     => 'part_pkg',
    'extra_sql' => "WHERE ". join(' OR ',
                     ( map "($_ IS NOT NULL AND $_ != '' )",
                           qw( plandata setup recur ) ),
                     'plan IS NULL', "plan = '' ",
                   ),
  });

  foreach my $part_pkg (@part_pkg) {

    unless ( $part_pkg->plan ) {

      $part_pkg->plan('flat');

      if ( $part_pkg->setup =~ /^\s*([\d\.]+)\s*$/ ) {

        my $opt = new FS::part_pkg_option {
          'pkgpart'     => $part_pkg->pkgpart,
          'optionname'  => 'setup_fee',
          'optionvalue' => $1,
        };
        my $error = $opt->insert;
        die $error if $error;

        $part_pkg->setup('');

      } else {
        die "Can't parse part_pkg.setup for fee; convert pkgnum ".
            $part_pkg->pkgnum. " manually: ". $part_pkg->setup. "\n";
      }

      if ( $part_pkg->recur =~ /^\s*([\d\.]+)\s*$/ ) {

        my $opt = new FS::part_pkg_option {
          'pkgpart'     => $part_pkg->pkgpart,
          'optionname'  => 'recur_fee',
          'optionvalue' => $1,
        };
        my $error = $opt->insert;
        die $error if $error;

        $part_pkg->recur('');

      } else {
        die "Can't parse part_pkg.setup for fee; convert pkgnum ".
            $part_pkg->pkgnum. " manually: ". $part_pkg->setup. "\n";
      }

    }

    $part_pkg->replace; #this should take care of plandata, right?

  }

}

=head1 SUBROUTINES

=over 4

=item plan_info

=cut

my %info;
foreach my $INC ( @INC ) {
  warn "globbing $INC/FS/part_pkg/*.pm\n" if $DEBUG;
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

=item format OPTION DATA

Returns data formatted according to the function 'format' described
in the plan info.  Returns DATA if no such function exists.

=cut

sub format {
  my ($self, $option, $data) = (shift, shift, shift);
  if (exists($plans{$self->plan}->{fields}->{$option}{format})) {
    &{$plans{$self->plan}->{fields}->{$option}{format}}($data);
  }else{
    $data;
  }
}

=item parse OPTION DATA

Returns data parsed according to the function 'parse' described
in the plan info.  Returns DATA if no such function exists.

=cut

sub parse {
  my ($self, $option, $data) = (shift, shift, shift);
  if (exists($plans{$self->plan}->{fields}->{$option}{parse})) {
    &{$plans{$self->plan}->{fields}->{$option}{parse}}($data);
  }else{
    $data;
  }
}


=back

=head1 NEW PLAN CLASSES

A module should be added in FS/FS/part_pkg/  Eventually, an example may be
found in eg/plan_template.pm.  Until then, it is suggested that you use the
other modules in FS/FS/part_pkg/ as a guide.

=head1 BUGS

The delete method is unimplemented.

setup and recur semantics are not yet defined (and are implemented in
FS::cust_bill.  hmm.).  now they're deprecated and need to go.

plandata should go

part_pkg_taxrate is Pg specific

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::type_pkgs>, L<FS::pkg_svc>, L<Safe>.
schema.html from the base documentation.

=cut

1;

