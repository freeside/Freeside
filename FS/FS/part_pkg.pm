package FS::part_pkg;
use base qw( FS::part_pkg::API
             FS::m2m_Common FS::o2m_Common FS::option_Common
           );

use strict;
use vars qw( %plans $DEBUG $setup_hack $skip_pkg_svc_hack );
use Carp qw(carp cluck confess);
use Scalar::Util qw( blessed );
use DateTime;
use Time::Local qw( timelocal timelocal_nocheck ); # eventually replace with DateTime
use Tie::IxHash;
use FS::Conf;
use FS::Record qw( qsearch qsearchs dbh dbdef );
use FS::Cursor; # for upgrade
use FS::pkg_svc;
use FS::part_svc;
use FS::cust_pkg;
use FS::agent_type;
use FS::type_pkgs;
use FS::part_pkg_option;
use FS::part_pkg_fcc_option;
use FS::pkg_class;
use FS::agent;
use FS::part_pkg_msgcat;
use FS::part_pkg_taxrate;
use FS::part_pkg_taxoverride;
use FS::part_pkg_taxproduct;
use FS::part_pkg_link;
use FS::part_pkg_discount;
use FS::part_pkg_vendor;
use FS::part_pkg_currency;

$DEBUG = 0;
$setup_hack = 0;
$skip_pkg_svc_hack = 0;

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

=item custom - Custom flag, empty or `Y'

=item setup_cost - for cost tracking

=item recur_cost - for cost tracking

=item pay_weight - Weight (relative to credit_weight and other package definitions) that controls payment application to specific line items.

=item credit_weight - Weight (relative to other package definitions) that controls credit application to specific line items.

=item agentnum - Optional agentnum (see L<FS::agent>)

=item fcc_ds0s - Optional DS0 equivalency number for FCC form 477

=item fcc_voip_class - Which column of FCC form 477 part II.B this package 
belongs in.

=item successor - Foreign key for the part_pkg that replaced this record.
If this record is not obsolete, will be null.

=item family_pkgpart - Foreign key for the part_pkg that was the earliest
ancestor of this record.  If this record is not a successor to another 
part_pkg, will be equal to pkgpart.

=item delay_start - Number of days to delay package start, by default

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
an existing definition.  A new pkgpart is assigned and the custom flag is
set to Y.  To add the package definition to the database, see L<"insert">.

=cut

sub clone {
  my $self = shift;
  my $class = ref($self);
  my %hash = $self->hash;
  $hash{'pkgpart'} = '';
  $hash{'custom'} = 'Y';
  #new FS::part_pkg ( \%hash ); # ?
  new $class ( \%hash ); # ?
}

=item insert [ , OPTION => VALUE ... ]

Adds this package definition to the database.  If there is an error,
returns the error, otherwise returns false.

Currently available options are: I<pkg_svc>, I<primary_svc>, I<cust_pkg>, 
I<custnum_ref> and I<options>.

If I<pkg_svc> is set to a hashref with svcparts as keys and quantities as
values, appropriate FS::pkg_svc records will be inserted.  I<hidden_svc> can 
be set to a hashref of svcparts and flag values ('Y' or '') to set the 
'hidden' field in these records.

If I<primary_svc> is set to the svcpart of the primary service, the appropriate
FS::pkg_svc record will be updated.

If I<cust_pkg> is set to a pkgnum of a FS::cust_pkg record (or the FS::cust_pkg
record itself), the object will be updated to point to this package definition.

In conjunction with I<cust_pkg>, if I<custnum_ref> is set to a scalar reference,
the scalar will be updated with the custnum value from the cust_pkg record.

If I<tax_overrides> is set to a hashref with usage classes as keys and comma
separated tax class numbers as values, appropriate FS::part_pkg_taxoverride
records will be inserted.

If I<options> is set to a hashref of options, appropriate FS::part_pkg_option
records will be inserted.

If I<part_pkg_currency> is set to a hashref of options (with the keys as
option_CURRENCY), appropriate FS::part_pkg::currency records will be inserted.

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

  # set family_pkgpart
  if ( $self->get('family_pkgpart') eq '' ) {
    $self->set('family_pkgpart' => $self->pkgpart);
    $error = $self->SUPER::replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  warn "  inserting part_pkg_taxoverride records" if $DEBUG;
  my %overrides = %{ $options{'tax_overrides'} || {} };
  foreach my $usage_class ( keys %overrides ) {
    my $override =
      ( exists($overrides{$usage_class}) && defined($overrides{$usage_class}) )
        ? $overrides{$usage_class}
        : '';
    my @overrides = (grep "$_", split(',', $override) );
    my $error = $self->process_m2m (
                  'link_table'   => 'part_pkg_taxoverride',
                  'target_table' => 'tax_class',
                  'hashref'      => { 'usage_class' => $usage_class },
                  'params'       => \@overrides,
                );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  warn "  inserting part_pkg_currency records" if $DEBUG;
  my %part_pkg_currency = %{ $options{'part_pkg_currency'} || {} };
  foreach my $key ( keys %part_pkg_currency ) {
    $key =~ /^(.+)_([A-Z]{3})$/ or next;
    my( $optionname, $currency ) = ( $1, $2 );
    if ( $part_pkg_currency{$key} =~ /^\s*$/ ) {
      if ( $self->option($optionname) == 0 ) {
        $part_pkg_currency{$key} = '0';
      } else {
        $dbh->rollback if $oldAutoCommit;
        ( my $thing = $optionname ) =~ s/_/ /g;
        return ucfirst($thing). " $currency is required";
      }
    }
    my $part_pkg_currency = new FS::part_pkg_currency {
      'pkgpart'     => $self->pkgpart,
      'optionname'  => $optionname,
      'currency'    => $currency,
      'optionvalue' => $part_pkg_currency{$key},
    };
    my $error = $part_pkg_currency->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  unless ( $skip_pkg_svc_hack ) {

    warn "  inserting pkg_svc records" if $DEBUG;
    my $pkg_svc = $options{'pkg_svc'} || {};
    my $hidden_svc = $options{'hidden_svc'} || {};
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
        'hidden'      => $hidden_svc->{$part_svc->svcpart},
      } );
      my $error = $pkg_svc->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
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

  if ( $options{'part_pkg_vendor'} ) {
      while ( my ($exportnum, $vendor_pkg_id) =
                each %{ $options{part_pkg_vendor} }
            )
      {
            my $ppv = new FS::part_pkg_vendor( {
                    'pkgpart' => $self->pkgpart,
                    'exportnum' => $exportnum,
                    'vendor_pkg_id' => $vendor_pkg_id, 
                } );
            my $error = $ppv->insert;
            if ( $error ) {
              $dbh->rollback if $oldAutoCommit;
              return "Error inserting part_pkg_vendor record: $error";
            }
      }
  }

  if ( $options{fcc_options} ) {
    warn "  updating fcc options " if $DEBUG;
    $self->set_fcc_options( $options{fcc_options} );
  }

  warn "  committing transaction" if $DEBUG and $oldAutoCommit;
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

Currently available options are: I<pkg_svc>, I<hidden_svc>, I<primary_svc> 
and I<options>

If I<pkg_svc> is set to a hashref with svcparts as keys and quantities as
values, the appropriate FS::pkg_svc records will be replaced.  I<hidden_svc>
can be set to a hashref of svcparts and flag values ('Y' or '') to set the 
'hidden' field in these records.  I<bulk_skip> can be set to a hashref of
svcparts and flag values ('Y' or '') to set the 'bulk_skip' field in those
records.

If I<primary_svc> is set to the svcpart of the primary service, the appropriate
FS::pkg_svc record will be updated.

If I<options> is set to a hashref, the appropriate FS::part_pkg_option records
will be replaced.

If I<part_pkg_currency> is set to a hashref of options (with the keys as
option_CURRENCY), appropriate FS::part_pkg::currency records will be replaced.

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

  $options->{options} = { $old->options } unless defined($options->{options});

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
  
  my $conf = new FS::Conf;
  if ( $conf->exists('part_pkg-lineage') ) {
    if ( grep { $options->{options}->{$_} ne $old->option($_, 1) }
          qw(setup_fee recur_fee) #others? config?
        ) { 
    
      warn "  superseding package" if $DEBUG;

      my $error = $new->supersede($old, %$options);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      else {
        warn "  committing transaction" if $DEBUG and $oldAutoCommit;
        $dbh->commit if $oldAutoCommit;
        return $error;
      }
    }
    #else nothing
  }

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

  #trivial nit: not the most efficient to delete and reinsert
  warn "  deleting old part_pkg_currency records" if $DEBUG;
  foreach my $part_pkg_currency ( $old->part_pkg_currency ) {
    my $error = $part_pkg_currency->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error deleting part_pkg_currency record: $error";
    }
  }

  warn "  inserting new part_pkg_currency records" if $DEBUG;
  my %part_pkg_currency = %{ $options->{'part_pkg_currency'} || {} };
  foreach my $key ( keys %part_pkg_currency ) {
    $key =~ /^(.+)_([A-Z]{3})$/ or next;
    my $part_pkg_currency = new FS::part_pkg_currency {
      'pkgpart'     => $new->pkgpart,
      'optionname'  => $1,
      'currency'    => $2,
      'optionvalue' => $part_pkg_currency{$key},
    };
    my $error = $part_pkg_currency->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error inserting part_pkg_currency record: $error";
    }
  }


  warn "  replacing pkg_svc records" if $DEBUG;
  my $pkg_svc = $options->{'pkg_svc'};
  my $hidden_svc = $options->{'hidden_svc'} || {};
  my $bulk_skip  = $options->{'bulk_skip'} || {};
  if ( $pkg_svc ) { # if it wasn't passed, don't change existing pkg_svcs
    foreach my $part_svc ( qsearch('part_svc', {} ) ) {
      my $quantity  = $pkg_svc->{$part_svc->svcpart} || 0;
      my $hidden    = $hidden_svc->{$part_svc->svcpart} || '';
      my $bulk_skip = $bulk_skip->{$part_svc->svcpart} || '';
      my $primary_svc =
        ( defined($options->{'primary_svc'}) && $options->{'primary_svc'}
          && $options->{'primary_svc'} == $part_svc->svcpart
        )
          ? 'Y'
          : '';

      my $old_pkg_svc = qsearchs('pkg_svc', {
          'pkgpart' => $old->pkgpart,
          'svcpart' => $part_svc->svcpart,
        }
      );
      my $old_quantity = 0;
      my $old_primary_svc = '';
      my $old_hidden = '';
      my $old_bulk_skip = '';
      if ( $old_pkg_svc ) {
        $old_quantity = $old_pkg_svc->quantity;
        $old_primary_svc = $old_pkg_svc->primary_svc 
          if $old_pkg_svc->dbdef_table->column('primary_svc'); # is this needed?
        $old_hidden = $old_pkg_svc->hidden;
        $old_bulk_skip = $old_pkg_svc->old_bulk_skip;
      }
   
      next unless $old_quantity    != $quantity
               || $old_primary_svc ne $primary_svc
               || $old_hidden      ne $hidden
               || $old_bulk_skip   ne $bulk_skip;
    
      my $new_pkg_svc = new FS::pkg_svc( {
        'pkgsvcnum'   => ( $old_pkg_svc ? $old_pkg_svc->pkgsvcnum : '' ),
        'pkgpart'     => $new->pkgpart,
        'svcpart'     => $part_svc->svcpart,
        'quantity'    => $quantity, 
        'primary_svc' => $primary_svc,
        'hidden'      => $hidden,
        'bulk_skip'   => $bulk_skip,
      } );
      my $error = $old_pkg_svc
                    ? $new_pkg_svc->replace($old_pkg_svc)
                    : $new_pkg_svc->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    } #foreach $part_svc
  } #if $options->{pkg_svc}
  
  my @part_pkg_vendor = $old->part_pkg_vendor;
  my @current_exportnum = ();
  if ( $options->{'part_pkg_vendor'} ) {
      my($exportnum,$vendor_pkg_id);
      while ( ($exportnum,$vendor_pkg_id) 
                                = each %{$options->{'part_pkg_vendor'}} ) {
          my $noinsert = 0;
          foreach my $part_pkg_vendor ( @part_pkg_vendor ) {
            if($exportnum == $part_pkg_vendor->exportnum
                && $vendor_pkg_id ne $part_pkg_vendor->vendor_pkg_id) {
                $part_pkg_vendor->vendor_pkg_id($vendor_pkg_id);
                my $error = $part_pkg_vendor->replace;
                if ( $error ) {
                  $dbh->rollback if $oldAutoCommit;
                  return "Error replacing part_pkg_vendor record: $error";
                }
                $noinsert = 1;
                last;
            }
            elsif($exportnum == $part_pkg_vendor->exportnum
                && $vendor_pkg_id eq $part_pkg_vendor->vendor_pkg_id) {
                $noinsert = 1;
                last;
            }
          }
          unless ( $noinsert ) {
            my $ppv = new FS::part_pkg_vendor( {
                    'pkgpart' => $new->pkgpart,
                    'exportnum' => $exportnum,
                    'vendor_pkg_id' => $vendor_pkg_id, 
                } );
            my $error = $ppv->insert;
            if ( $error ) {
              $dbh->rollback if $oldAutoCommit;
              return "Error inserting part_pkg_vendor record: $error";
            }
          }
          push @current_exportnum, $exportnum;
      }
  }
  foreach my $part_pkg_vendor ( @part_pkg_vendor ) {
      unless ( grep($_ eq $part_pkg_vendor->exportnum, @current_exportnum) ) {
        my $error = $part_pkg_vendor->delete;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return "Error deleting part_pkg_vendor record: $error";
        }
      }
  }
  
  # propagate changes to certain core fields
  if ( $conf->exists('part_pkg-lineage') ) {
    warn "  propagating changes to family" if $DEBUG;
    my $error = $new->propagate($old);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  if ( $options->{fcc_options} ) {
    warn "  updating fcc options " if $DEBUG;
    $new->set_fcc_options( $options->{fcc_options} );
  }

  warn "  committing transaction" if $DEBUG and $oldAutoCommit;
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

  my @null_agentnum_right = ( 'Edit global package definitions' );
  push @null_agentnum_right, 'One-time charge'
    if $self->freq =~ /^0/;
  push @null_agentnum_right, 'Customize customer package'
    if $self->disabled eq 'Y'; #good enough

  my $error = $self->ut_numbern('pkgpart')
    || $self->ut_text('pkg')
    || $self->ut_textn('comment')
    || $self->ut_textn('promo_code')
    || $self->ut_alphan('plan')
    || $self->ut_enum('setuptax', [ '', 'Y' ] )
    || $self->ut_enum('recurtax', [ '', 'Y' ] )
    || $self->ut_textn('taxclass')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_enum('custom', [ '', 'Y' ] )
    || $self->ut_enum('no_auto', [ '', 'Y' ])
    || $self->ut_enum('recur_show_zero', [ '', 'Y' ])
    || $self->ut_enum('setup_show_zero', [ '', 'Y' ])
    #|| $self->ut_moneyn('setup_cost')
    #|| $self->ut_moneyn('recur_cost')
    || $self->ut_floatn('setup_cost')
    || $self->ut_floatn('recur_cost')
    || $self->ut_floatn('pay_weight')
    || $self->ut_floatn('credit_weight')
    || $self->ut_numbern('taxproductnum')
    || $self->ut_foreign_keyn('classnum',       'pkg_class', 'classnum')
    || $self->ut_foreign_keyn('addon_classnum', 'pkg_class', 'classnum')
    || $self->ut_foreign_keyn('taxproductnum',
                              'part_pkg_taxproduct',
                              'taxproductnum'
                             )
    || ( $setup_hack
           ? $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum' )
           : $self->ut_agentnum_acl('agentnum', \@null_agentnum_right)
       )
    || $self->ut_numbern('fcc_ds0s')
    || $self->ut_numbern('fcc_voip_class')
    || $self->ut_numbern('delay_start')
    || $self->ut_foreign_keyn('successor', 'part_pkg', 'pkgpart')
    || $self->ut_foreign_keyn('family_pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_alphan('agent_pkgpartid')
    || $self->SUPER::check
  ;
  return $error if $error;

  return 'Unknown plan '. $self->plan
    unless exists($plans{$self->plan});

  my $conf = new FS::Conf;
  return 'Taxclass is required'
    if ! $self->taxclass && $conf->exists('require_taxclasses');

  '';
}

=item supersede OLD [, OPTION => VALUE ... ]

Inserts this package as a successor to the package OLD.  All options are as
for C<insert>.  After inserting, disables OLD and sets the new package as its
successor.

=cut

sub supersede {
  my ($new, $old, %options) = @_;
  my $error;

  $new->set('pkgpart' => '');
  $new->set('family_pkgpart' => $old->family_pkgpart);
  warn "    inserting successor package\n" if $DEBUG;
  $error = $new->insert(%options);
  return $error if $error;
 
  warn "    disabling superseded package\n" if $DEBUG; 
  $old->set('successor' => $new->pkgpart);
  $old->set('disabled' => 'Y');
  $error = $old->SUPER::replace; # don't change its options/pkg_svc records
  return $error if $error;

  warn "  propagating changes to family" if $DEBUG;
  $new->propagate($old);
}

=item propagate OLD

If any of certain fields have changed from OLD to this package, then,
for all packages in the same lineage as this one, sets those fields 
to their values in this package.

=cut

my @propagate_fields = (
  qw( pkg classnum setup_cost recur_cost taxclass
  setuptax recurtax pay_weight credit_weight
  )
);

sub propagate {
  my $new = shift;
  my $old = shift;
  my %fields = (
    map { $_ => $new->get($_) }
    grep { $new->get($_) ne $old->get($_) }
    @propagate_fields
  );

  my @part_pkg = qsearch('part_pkg', { 
      'family_pkgpart' => $new->family_pkgpart 
  });
  my @error;
  foreach my $part_pkg ( @part_pkg ) {
    my $pkgpart = $part_pkg->pkgpart;
    next if $pkgpart == $new->pkgpart; # don't modify $new
    warn "    propagating to pkgpart $pkgpart\n" if $DEBUG;
    foreach ( keys %fields ) {
      $part_pkg->set($_, $fields{$_});
    }
    # SUPER::replace to avoid changing non-core fields
    my $error = $part_pkg->SUPER::replace;
    push @error, "pkgpart $pkgpart: $error"
      if $error;
  }
  join("\n", @error);
}

=item set_fcc_options HASHREF

Sets the FCC options on this package definition to the values specified
in HASHREF.

=cut

sub set_fcc_options {
  my $self = shift;
  my $pkgpart = $self->pkgpart;
  my $options;
  if (ref $_[0]) {
    $options = shift;
  } else {
    $options = { @_ };
  }

  my %existing_num = map { $_->fccoptionname => $_->num }
                     qsearch('part_pkg_fcc_option', { pkgpart => $pkgpart });

  local $FS::Record::nowarn_identical = 1;
  # set up params for process_o2m
  my $i = 0;
  my $params = {};
  foreach my $name (keys %$options ) {
    $params->{ "num$i" } = $existing_num{$name} || '';
    $params->{ "num$i".'_fccoptionname' } = $name;
    $params->{ "num$i".'_optionvalue'   } = $options->{$name};
    $i++;
  }

  $self->process_o2m(
    table   => 'part_pkg_fcc_option',
    fields  => [qw( fccoptionname optionvalue )],
    params  => $params,
  );
}

=item pkg_locale LOCALE

Returns a customer-viewable string representing this package for the given
locale, from the part_pkg_msgcat table.  If the given locale is empty or no
localized string is found, returns the base pkg field.

=cut

sub pkg_locale {
  my( $self, $locale ) = @_;
  return $self->pkg unless $locale;
  my $part_pkg_msgcat = $self->part_pkg_msgcat($locale) or return $self->pkg;
  $part_pkg_msgcat->pkg;
}

=item part_pkg_msgcat LOCALE

Like pkg_locale, but returns the FS::part_pkg_msgcat object itself.

=cut

sub part_pkg_msgcat {
  my( $self, $locale ) = @_;
  qsearchs( 'part_pkg_msgcat', {
    pkgpart => $self->pkgpart,
    locale  => $locale,
  });
}

=item pkg_comment [ OPTION => VALUE... ]

Returns an (internal) string representing this package.  Currently,
"pkgpart: pkg - comment", is returned.  "pkg - comment" may be returned in the
future, omitting pkgpart.  The comment will have '(CUSTOM) ' prepended if
custom is Y.

If the option nopkgpart is true then the "pkgpart: ' is omitted.

=cut

sub pkg_comment {
  my $self = shift;
  my %opt = @_;

  #$self->pkg. ' - '. $self->comment;
  #$self->pkg. ' ('. $self->comment. ')';
  my $pre = $opt{nopkgpart} ? '' : $self->pkgpart. ': ';
  my $custom_comment = $self->custom_comment(%opt);
  $pre. $self->pkg. ( $custom_comment ? " - $custom_comment" : '' );
}

#without price info (so without hitting the DB again)
sub pkg_comment_only {
  my $self = shift;
  my %opt = @_;

  my $pre = $opt{nopkgpart} ? '' : $self->pkgpart. ': ';
  my $comment = $self->comment;
  $pre. $self->pkg. ( $comment ? " - $comment" : '' );
}

sub price_info { # safety, in case a part_pkg hasn't defined price_info
    '';
}

sub custom_comment {
  my $self = shift;
  my $price_info = $self->price_info(@_);
  ( $self->custom ? '(CUSTOM) ' : '' ).
    $self->comment.
    ( ($self->custom || $self->comment) ? ' - ' : '' ).
    ($price_info || 'No charge');
}

sub pkg_price_info {
  my $self = shift;
  $self->pkg. ' - '. ($self->price_info || 'No charge');
}

=item pkg_class

Returns the package class, as an FS::pkg_class object, or the empty string
if there is no package class.

=item addon_pkg_class

Returns the add-on package class, as an FS::pkg_class object, or the empty
string if there is no add-on package class.

=cut

sub addon_pkg_class {
  my $self = shift;
  if ( $self->addon_classnum ) {
    qsearchs('pkg_class', { 'classnum' => $self->addon_classnum } );
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

=item addon_classname 

Returns the add-on package class name, or the empty string if there is no
add-on package class.

=cut

sub addon_classname {
  my $self = shift;
  my $pkg_class = $self->addon_pkg_class;
  $pkg_class
    ? $pkg_class->classname
    : '';
}

=item agent 

Returns the associated agent for this event, if any, as an FS::agent object.

=item pkg_svc [ HASHREF | OPTION => VALUE ]

Returns all FS::pkg_svc objects (see L<FS::pkg_svc>) for this package
definition (with non-zero quantity).

One option is available, I<disable_linked>.  If set true it will return the
services for this package definition alone, omitting services from any add-on
packages.

=cut

=item type_pkgs

Returns all FS::type_pkgs objects (see L<FS::type_pkgs>) for this package
definition.

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
svcdb of the service definition.  SVCDB can be specified as a scalar table
name, such as 'svc_acct', or as an arrayref of possible table names.

=cut

sub svcpart {
  my $pkg_svc = shift->_primary_pkg_svc(@_);
  $pkg_svc ? $pkg_svc->svcpart : '';
}

=item part_svc [ SVCDB ]

Like the B<svcpart> method, but returns the FS::part_svc object (see
L<FS::part_svc>).

=cut

sub part_svc {
  my $pkg_svc = shift->_primary_pkg_svc(@_);
  $pkg_svc ? $pkg_svc->part_svc : '';
}

sub _primary_pkg_svc {
  my $self = shift;

  my $svcdb = scalar(@_) ? shift : [];
  $svcdb = ref($svcdb) ? $svcdb : [ $svcdb ];
  my %svcdb = map { $_=>1 } @$svcdb;

  my @svcdb_pkg_svc =
    grep { !scalar(@$svcdb) || $svcdb{ $_->part_svc->svcdb } }
         $self->pkg_svc;

  my @pkg_svc = grep { $_->primary_svc =~ /^Y/i } @svcdb_pkg_svc;
  @pkg_svc = grep {$_->quantity == 1 } @svcdb_pkg_svc
    unless @pkg_svc;
  return '' if scalar(@pkg_svc) != 1;
  $pkg_svc[0];
}

=item svcpart_unique_svcdb SVCDB

Returns the svcpart of a service definition (see L<FS::part_svc>) matching
SVCDB associated with this package definition (see L<FS::pkg_svc>).  Returns
false if there not a primary service definition for SVCDB or there are multiple
service definitions for SVCDB.

=cut

sub svcpart_unique_svcdb {
  my( $self, $svcdb ) = @_;
  my @svcdb_pkg_svc = grep { ( $svcdb eq $_->part_svc->svcdb ) } $self->pkg_svc;
  return '' if scalar(@svcdb_pkg_svc) != 1;
  $svcdb_pkg_svc[0]->svcpart;
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
  if ( $self->can('is_free_options') ) {
    not grep { $_ !~ /^\s*0*(\.0*)?\s*$/ }
         map { $self->option($_) } 
             $self->is_free_options;
  } else {
    warn "FS::part_pkg::is_free: FS::part_pkg::". $self->plan. " subclass ".
         "provides neither is_free_options nor is_free method; returning false";
    0;
  }
}

# whether the plan allows discounts to be applied to this package
sub can_discount { 0; }
 
# whether the plan allows changing the start date
sub can_start_date { 1; }

# whether the plan supports part_pkg_usageprice add-ons (a specific kind of
#  pre-selectable usage pricing, there's others this doesn't refer to)
sub can_usageprice { 0; }
  
# the delay start date if present
sub delay_start_date {
  my $self = shift;

  my $delay = $self->delay_start or return '';

  # avoid timelocal silliness  
  my $dt = DateTime->today(time_zone => 'local');
  $dt->add(days => $delay);
  $dt->epoch;
}

sub can_currency_exchange { 0; }

sub freqs_href {
  # moved to FS::Misc to make this accessible to other packages
  # at initialization
  FS::Misc::pkg_freqs();
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

=item add_freq TIMESTAMP [ FREQ ]

Adds a billing period of some frequency to the provided timestamp and 
returns the resulting timestamp, or -1 if the frequency could not be 
parsed (shouldn't happen).  By default, the frequency of this package 
will be used; to override this, pass a different frequency as a second 
argument.

=cut

sub add_freq {
  my( $self, $date, $freq ) = @_;
  $freq = $self->freq unless $freq;

  #change this bit to use Date::Manip? CAREFUL with timezones (see
  # mailing list archive)
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($date) )[0,1,2,3,4,5];

  if ( $freq =~ /^\d+$/ ) {
    $mon += $freq;
    until ( $mon < 12 ) { $mon -= 12; $year++; }

    $mday = 28 if $mday > 28 && FS::Conf->new->exists('anniversary-rollback');

  } elsif ( $freq =~ /^(\d+)w$/ ) {
    my $weeks = $1;
    $mday += $weeks * 7;
  } elsif ( $freq =~ /^(\d+)d$/ ) {
    my $days = $1;
    $mday += $days;
  } elsif ( $freq =~ /^(\d+)h$/ ) {
    my $hours = $1;
    $hour += $hours;
  } else {
    return -1;
  }

  timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year);
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

=item part_pkg_vendor

Returns all vendor/external package ids as FS::part_pkg_vendor objects (see
L<FS::part_pkg_vendor>).

=item vendor_pkg_ids

Returns a list of vendor/external package ids by exportnum

=cut

sub vendor_pkg_ids {
  my $self = shift;
  map { $_->exportnum => $_->vendor_pkg_id } $self->part_pkg_vendor;
}

=item part_pkg_option

Returns all options as FS::part_pkg_option objects (see
L<FS::part_pkg_option>).

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=cut

sub options {
  my $self = shift;
  map { $_->optionname => $_->optionvalue } $self->part_pkg_option;
}

=item option OPTIONNAME [ QUIET ]

Returns the option value for the given name, or the empty string.  If a true
value is passed as the second argument, warnings about missing the option
will be suppressed.

=cut

sub option {
  my( $self, $opt, $ornull ) = @_;

  #cache: was pulled up in the original part_pkg query
  if ( $opt =~ /^(setup|recur)_fee$/ && defined($self->hashref->{"_$opt"}) ) {
    return $self->hashref->{"_$opt"};
  }

  cluck "$self -> option: searching for $opt"
    if $DEBUG;
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

=item part_pkg_currency [ CURRENCY ]

Returns all currency options as FS::part_pkg_currency objects (see
L<FS::part_pkg_currency>), or, if a currency is specified, only return the
objects for that currency.

=cut

sub part_pkg_currency {
  my $self = shift;
  my %hash = ( 'pkgpart' => $self->pkgpart );
  $hash{'currency'} = shift if @_;
  qsearch('part_pkg_currency', \%hash );
}

=item part_pkg_currency_options CURRENCY

Returns a list of option names and values from FS::part_pkg_currency for the
specified currency.

=cut

sub part_pkg_currency_options {
  my $self = shift;
  map { $_->optionname => $_->optionvalue } $self->part_pkg_currency(shift);
}

=item part_pkg_currency_option CURRENCY OPTIONNAME

Returns the option value for the given name and currency.

=cut

sub part_pkg_currency_option {
  my( $self, $currency, $optionname ) = @_; 
  my $part_pkg_currency =
    qsearchs('part_pkg_currency', { 'pkgpart'    => $self->pkgpart,
                                    'currency'   => $currency,
                                    'optionname' => $optionname,
                                  }
            )#;
  #fatal if not found?  that works for our use cases from
  #part_pkg/currency_fixed, but isn't how we would typically/expect the method
  #to behave.  have to catch it there if we change it here...
    or die "Unknown price for ". $self->pkg_comment. " in $currency\n";

  $part_pkg_currency->optionvalue;
}

=item fcc_option OPTIONNAME

Returns the FCC 477 report option value for the given name, or the empty 
string.

=cut

sub fcc_option {
  my ($self, $name) = @_;
  my $part_pkg_fcc_option =
    qsearchs('part_pkg_fcc_option', {
        pkgpart => $self->pkgpart,
        fccoptionname => $name,
    });
  $part_pkg_fcc_option ? $part_pkg_fcc_option->optionvalue : '';
}

=item fcc_options

Returns all FCC 477 report options for this package, as a hash-like list.

=cut

sub fcc_options {
  my $self = shift;
  map { $_->fccoptionname => $_->optionvalue }
    qsearch('part_pkg_fcc_option', { pkgpart => $self->pkgpart });
}

=item bill_part_pkg_link

Returns the associated part_pkg_link records (see L<FS::part_pkg_link>).

=cut

sub bill_part_pkg_link {
  shift->_part_pkg_link('bill', @_);
}

=item svc_part_pkg_link

Returns the associated part_pkg_link records (see L<FS::part_pkg_link>).

=cut

sub svc_part_pkg_link {
  shift->_part_pkg_link('svc', @_);
}

=item supp_part_pkg_link

Returns the associated part_pkg_link records of type 'supp' (supplemental
packages).

=cut

sub supp_part_pkg_link {
  shift->_part_pkg_link('supp', @_);
}

sub _part_pkg_link {
  my( $self, $type ) = @_;
  qsearch({ table    => 'part_pkg_link',
            hashref  => { 'src_pkgpart' => $self->pkgpart,
                          'link_type'   => $type,
                          #protection against infinite recursive links
                          'dst_pkgpart' => { op=>'!=', value=> $self->pkgpart },
                        },
            order_by => "ORDER BY hidden",
         });
}

sub self_and_bill_linked {
  shift->_self_and_linked('bill', @_);
}

sub self_and_svc_linked {
  shift->_self_and_linked('svc', @_);
}

sub _self_and_linked {
  my( $self, $type, $hidden ) = @_;
  $hidden ||= '';

  my @result = ();
  foreach ( ( $self, map { $_->dst_pkg->_self_and_linked($type, $_->hidden) }
                     $self->_part_pkg_link($type) ) )
  {
    $_->hidden($hidden) if $hidden;
    push @result, $_;
  }

  (@result);
}

=item part_pkg_taxoverride [ CLASS ]

Returns all associated FS::part_pkg_taxoverride objects (see
L<FS::part_pkg_taxoverride>).  Limits the returned set to those
of class CLASS if defined.  Class may be one of 'setup', 'recur',
the empty string (default), or a usage class number (see L<FS::usage_class>).
When a class is specified, the empty string class (default) is returned
if no more specific values exist.

=cut

sub part_pkg_taxoverride {
  my $self = shift;
  my $class = shift;

  my $hashref = { 'pkgpart' => $self->pkgpart };
  $hashref->{'usage_class'} = $class if defined($class);
  my @overrides = qsearch('part_pkg_taxoverride', $hashref );

  unless ( scalar(@overrides) || !defined($class) || !$class ){
    $hashref->{'usage_class'} = '';
    @overrides = qsearch('part_pkg_taxoverride', $hashref );
  }

  @overrides;
}

=item has_taxproduct

Returns true if this package has any taxproduct associated with it.  

=cut

sub has_taxproduct {
  my $self = shift;

  $self->taxproductnum ||
  scalar( grep { $_ =~/^usage_taxproductnum_/ && $self->option($_) } 
          keys %{ {$self->options} }
  )

}


=item taxproduct [ CLASS ]

Returns the associated tax product for this package definition (see
L<FS::part_pkg_taxproduct>).  CLASS may be one of 'setup', 'recur' or
the usage classnum (see L<FS::usage_class>).  Returns the default
tax product for this record if the more specific CLASS value does
not exist.

=cut

sub taxproduct {
  my $self = shift;
  my $class = shift;

  my $part_pkg_taxproduct;

  my $taxproductnum = $self->taxproductnum;
  if ($class) { 
    my $class_taxproductnum = $self->option("usage_taxproductnum_$class", 1);
    $taxproductnum = $class_taxproductnum
      if $class_taxproductnum
  }
  
  $part_pkg_taxproduct =
    qsearchs( 'part_pkg_taxproduct', { 'taxproductnum' => $taxproductnum } );

  unless ($part_pkg_taxproduct || $taxproductnum eq $self->taxproductnum ) {
    $taxproductnum = $self->taxproductnum;
    $part_pkg_taxproduct =
      qsearchs( 'part_pkg_taxproduct', { 'taxproductnum' => $taxproductnum } );
  }

  $part_pkg_taxproduct;
}

=item taxproduct_description [ CLASS ]

Returns the description of the associated tax product for this package
definition (see L<FS::part_pkg_taxproduct>).

=cut

sub taxproduct_description {
  my $self = shift;
  my $part_pkg_taxproduct = $self->taxproduct(@_);
  $part_pkg_taxproduct ? $part_pkg_taxproduct->description : '';
}


=item tax_rates DATA_PROVIDER, GEOCODE, [ CLASS ]

Returns the tax table entries (L<FS::tax_rate> objects) that apply to this
package in the location specified by GEOCODE, for usage class CLASS (one of
'setup', 'recur', null, or a C<usage_class> number).

=cut

sub tax_rates {
  my $self = shift;
  my ($vendor, $geocode, $class) = @_;
  my @taxclassnums = map { $_->taxclassnum } 
                     $self->part_pkg_taxoverride($class);
  if (!@taxclassnums) {
    my $part_pkg_taxproduct = $self->taxproduct($class);
    # If this isn't defined, then the class has no taxproduct designation,
    # so return no tax rates.
    return () if !$part_pkg_taxproduct;

    # convert the taxproduct to the tax classes that might apply to it in 
    # $geocode
    @taxclassnums = map { $_->taxclassnum }
                    grep { $_->taxable eq 'Y' } # why do we need this?
                    $part_pkg_taxproduct->part_pkg_taxrate($geocode);
  }
  return unless @taxclassnums;

  # then look up the actual tax_rate entries
  warn "Found taxclassnum values of ". join(',', @taxclassnums) ."\n"
      if $DEBUG;
  my $extra_sql = "AND taxclassnum IN (". join(',', @taxclassnums) . ")";
  my @taxes = qsearch({ 'table'     => 'tax_rate',
                        'hashref'   => { 'geocode'     => $geocode,
                                         'data_vendor' => $vendor },
                        'extra_sql' => $extra_sql,
                      });
  warn "Found taxes ". join(',', map {$_->taxnum} @taxes) ."\n"
      if $DEBUG;

  return @taxes;
}

=item part_pkg_discount

Returns the package to discount m2m records (see L<FS::part_pkg_discount>)
for this package.

=item part_pkg_usage

Returns the voice usage pools (see L<FS::part_pkg_usage>) defined for 
this package.

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
  warn "reblessing $self into $class" if $DEBUG > 1;
  eval "use $class;";
  die $@ if $@;
  bless($self, $class) unless $@;
  $self;
}

#fatal fallbacks
sub calc_setup { die 'no calc_setup for '. shift->plan. "\n"; }
sub calc_recur { die 'no calc_recur for '. shift->plan. "\n"; }

#fallback that return 0 for old legacy packages with no plan
sub calc_remain { 0; }
sub calc_units  { 0; }

#fallback for everything not based on flat.pm
sub recur_temporality { 'upcoming'; }
sub calc_cancel { 0; }

#fallback for everything except bulk.pm
sub hide_svc_detail { 0; }

#fallback for packages that can't/won't summarize usage
sub sum_usage { 0; }

=item recur_cost_permonth CUST_PKG

recur_cost divided by freq (only supported for monthly and longer frequencies)

=cut

sub recur_cost_permonth {
  my($self, $cust_pkg) = @_;
  return 0 unless $self->freq =~ /^\d+$/ && $self->freq > 0;
  sprintf('%.2f', $self->recur_cost / $self->freq );
}

=item cust_bill_pkg_recur CUST_PKG

Actual recurring charge for the specified customer package from customer's most
recent invoice

=cut

sub cust_bill_pkg_recur {
  my($self, $cust_pkg) = @_;
  my $cust_bill_pkg = qsearchs({
    'table'     => 'cust_bill_pkg',
    'addl_from' => 'LEFT JOIN cust_bill USING ( invnum )',
    'hashref'   => { 'pkgnum' => $cust_pkg->pkgnum,
                     'recur'  => { op=>'>', value=>'0' },
                   },
    'order_by'  => 'ORDER BY cust_bill._date     DESC,
                             cust_bill_pkg.sdate DESC
                     LIMIT 1
                   ',
  }) or return 0; #die "use cust_bill_pkg_recur credits with once_perinv condition";
  $cust_bill_pkg->recur;
}

=item unit_setup CUST_PKG

Returns the setup fee for one unit of the package.

=cut

sub unit_setup {
  my ($self, $cust_pkg) = @_;
  $self->option('setup_fee') || 0;
}

=item setup_margin

unit_setup minus setup_cost

=cut

sub setup_margin {
  my $self = shift;
  $self->unit_setup(@_) - $self->setup_cost;
}

=item recur_margin_permonth

base_recur_permonth minus recur_cost_permonth

=cut

sub recur_margin_permonth {
  my $self = shift;
  $self->base_recur_permonth(@_) - $self->recur_cost_permonth(@_);
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

=cut

=head1 CLASS METHODS

=over 4

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
                     'plan IS NULL', "plan = '' ",
                   ),
  });

  foreach my $part_pkg (@part_pkg) {

    unless ( $part_pkg->plan ) {
      $part_pkg->plan('flat');
    }

    $part_pkg->replace;

  }
  # the rest can be done asynchronously
}

sub queueable_upgrade {
  # now upgrade to the explicit custom flag

  my $search = FS::Cursor->new({
    'table'     => 'part_pkg',
    'hashref'   => { disabled => 'Y', custom => '' },
    'extra_sql' => "AND comment LIKE '(CUSTOM) %'",
  });
  my $dbh = dbh;

  while (my $part_pkg = $search->fetch) {
    my $new = new FS::part_pkg { $part_pkg->hash };
    $new->custom('Y');
    my $comment = $part_pkg->comment;
    $comment =~ s/^\(CUSTOM\) //;
    $comment = '(none)' unless $comment =~ /\S/;
    $new->comment($comment);

    my $pkg_svc = { map { $_->svcpart => $_->quantity } $part_pkg->pkg_svc };
    my $primary = $part_pkg->svcpart;
    my $options = { $part_pkg->options };

    my $error = $new->replace( $part_pkg,
                               'pkg_svc'     => $pkg_svc,
                               'primary_svc' => $primary,
                               'options'     => $options,
                             );
    if ($error) {
      warn "pkgpart#".$part_pkg->pkgpart.": $error\n";
      $dbh->rollback;
    } else {
      $dbh->commit;
    }
  }

  # set family_pkgpart on any packages that don't have it
  $search = FS::Cursor->new('part_pkg', { 'family_pkgpart' => '' });
  while (my $part_pkg = $search->fetch) {
    $part_pkg->set('family_pkgpart' => $part_pkg->pkgpart);
    my $error = $part_pkg->SUPER::replace;
    if ($error) {
      warn "pkgpart#".$part_pkg->pkgpart.": $error\n";
      $dbh->rollback;
    } else {
      $dbh->commit;
    }
  }

  my @part_pkg_option = qsearch('part_pkg_option',
    { 'optionname'  => 'unused_credit',
      'optionvalue' => 1,
    });
  foreach my $old_opt (@part_pkg_option) {
    my $pkgpart = $old_opt->pkgpart;
    my $error = $old_opt->delete;
    die $error if $error;

    foreach (qw(unused_credit_cancel unused_credit_change)) {
      my $new_opt = new FS::part_pkg_option {
        'pkgpart'     => $pkgpart,
        'optionname'  => $_,
        'optionvalue' => 1,
      };
      $error = $new_opt->insert;
      die $error if $error;
    }
  }

  # migrate use_disposition_taqua and use_disposition to disposition_in
  @part_pkg_option = qsearch('part_pkg_option',
    { 'optionname'  => { op => 'LIKE',
                         value => 'use_disposition%',
                       },
      'optionvalue' => 1,
    });
  my %newopts = map { $_->pkgpart => $_ } 
    qsearch('part_pkg_option',  { 'optionname'  => 'disposition_in', } );
  foreach my $old_opt (@part_pkg_option) {
        my $pkgpart = $old_opt->pkgpart;
        my $newval = $old_opt->optionname eq 'use_disposition_taqua' ? '100' 
                                                                  : 'ANSWERED';
        my $error = $old_opt->delete;
        die $error if $error;

        if ( exists($newopts{$pkgpart}) ) {
            my $opt = $newopts{$pkgpart};
            $opt->optionvalue($opt->optionvalue.",$newval");
            $error = $opt->replace;
            die $error if $error;
        } else {
            my $new_opt = new FS::part_pkg_option {
                'pkgpart'     => $pkgpart,
                'optionname'  => 'disposition_in',
                'optionvalue' => $newval,
              };
              $error = $new_opt->insert;
              die $error if $error;
              $newopts{$pkgpart} = $new_opt;
        }
  }

  # set any package with FCC voice lines to the "VoIP with broadband" category
  # for backward compatibility
  #
  # recover from a bad upgrade bug
  my $upgrade = 'part_pkg_fcc_voip_class_FIX';
  if (!FS::upgrade_journal->is_done($upgrade)) {
    my $bad_upgrade = qsearchs('upgrade_journal', 
      { upgrade => 'part_pkg_fcc_voip_class' }
    );
    if ( $bad_upgrade ) {
      my $where = 'WHERE history_date <= '.$bad_upgrade->_date.
                  ' AND  history_date >  '.($bad_upgrade->_date - 3600);
      my @h_part_pkg_option = map { FS::part_pkg_option->new($_->hashref) }
        qsearch({
          'select'    => '*',
          'table'     => 'h_part_pkg_option',
          'hashref'   => {},
          'extra_sql' => "$where AND history_action = 'delete'",
          'order_by'  => 'ORDER BY history_date ASC',
        });
      my @h_pkg_svc = map { FS::pkg_svc->new($_->hashref) }
        qsearch({
          'select'    => '*',
          'table'     => 'h_pkg_svc',
          'hashref'   => {},
          'extra_sql' => "$where AND history_action = 'replace_old'",
          'order_by'  => 'ORDER BY history_date ASC',
        });
      my %opt;
      foreach my $deleted (@h_part_pkg_option, @h_pkg_svc) {
        my $pkgpart ||= $deleted->pkgpart;
        $opt{$pkgpart} ||= {
          options => {},
          pkg_svc => {},
          primary_svc => '',
          hidden_svc => {},
        };
        if ( $deleted->isa('FS::part_pkg_option') ) {
          $opt{$pkgpart}{options}{ $deleted->optionname } = $deleted->optionvalue;
        } else { # pkg_svc
          my $svcpart = $deleted->svcpart;
          $opt{$pkgpart}{pkg_svc}{$svcpart} = $deleted->quantity;
          $opt{$pkgpart}{hidden_svc}{$svcpart} ||= $deleted->hidden;
          $opt{$pkgpart}{primary_svc} = $svcpart if $deleted->primary_svc;
        }
      }
      foreach my $pkgpart (keys %opt) {
        my $part_pkg = FS::part_pkg->by_key($pkgpart);
        my $error = $part_pkg->replace( $part_pkg->replace_old, $opt{$pkgpart} );
        if ( $error ) {
          die "error recovering damaged pkgpart $pkgpart:\n$error\n";
        }
      }
    } # $bad_upgrade exists
    else { # do the original upgrade, but correctly this time
      my @part_pkg = qsearch('part_pkg', {
          fcc_ds0s        => { op => '>', value => 0 },
          fcc_voip_class  => ''
      });
      foreach my $part_pkg (@part_pkg) {
        $part_pkg->set(fcc_voip_class => 2);
        my @pkg_svc = $part_pkg->pkg_svc;
        my %quantity = map {$_->svcpart, $_->quantity} @pkg_svc;
        my %hidden   = map {$_->svcpart, $_->hidden  } @pkg_svc;
        my $error = $part_pkg->replace(
          $part_pkg->replace_old,
          options     => { $part_pkg->options },
          pkg_svc     => \%quantity,
          hidden_svc  => \%hidden,
          primary_svc => ($part_pkg->svcpart || ''),
        );
        die $error if $error;
      }
    }
    FS::upgrade_journal->set_done($upgrade);
  }

}

=item curuser_pkgs_sql

Returns an SQL fragment for searching for packages the current user can
use, either via part_pkg.agentnum directly, or via agent type (see
L<FS::type_pkgs>).

=cut

sub curuser_pkgs_sql {
  my $class = shift;

  $class->_pkgs_sql( $FS::CurrentUser::CurrentUser->agentnums );

}

=item agent_pkgs_sql AGENT | AGENTNUM, ...

Returns an SQL fragment for searching for packages the provided agent or agents
can use, either via part_pkg.agentnum directly, or via agent type (see
L<FS::type_pkgs>).

=cut

sub agent_pkgs_sql {
  my $class = shift;  #i'm a class method, not a sub (the question is... why??)
  my @agentnums = map { ref($_) ? $_->agentnum : $_ } @_;

  $class->_pkgs_sql(@agentnums); #is this why

}

sub _pkgs_sql {
  my( $class, @agentnums ) = @_;
  my $agentnums = join(',', @agentnums);

  "
    (
      ( agentnum IS NOT NULL AND agentnum IN ($agentnums) )
      OR ( agentnum IS NULL
           AND EXISTS ( SELECT 1
                          FROM type_pkgs
                            LEFT JOIN agent_type USING ( typenum )
                            LEFT JOIN agent AS typeagent USING ( typenum )
                          WHERE type_pkgs.pkgpart = part_pkg.pkgpart
                            AND typeagent.agentnum IN ($agentnums)
                      )
         )
    )
  ";

}

=back

=head1 SUBROUTINES

=over 4

=item plan_info

=cut

#false laziness w/part_export & cdr
my %info;
foreach my $INC ( @INC ) {
  warn "globbing $INC/FS/part_pkg/[a-z]*.pm\n" if $DEBUG;
  foreach my $file ( glob("$INC/FS/part_pkg/[a-z]*.pm") ) {
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
      warn "no %info hash found in FS::part_pkg::$mod, skipping\n";
      next;
    }
    warn "got plan info from FS::part_pkg::$mod: $info\n" if $DEBUG;
    #if ( exists($info->{'disabled'}) && $info->{'disabled'} ) {
    #  warn "skipping disabled plan FS::part_pkg::$mod" if $DEBUG;
    #  next;
    #}
    $info{$mod} = $info;
    $info->{'weight'} ||= 0; # quiet warnings
  }
}

# copy one level deep to allow replacement of fields and fieldorder
tie %plans, 'Tie::IxHash',
  map  { my %infohash = %{ $info{$_} }; 
          $_ => \%infohash }
  sort { $info{$a}->{'weight'} <=> $info{$b}->{'weight'} }
  keys %info;

# inheritance of plan options
foreach my $name (keys(%info)) {
  if (exists($info{$name}->{'disabled'}) and $info{$name}->{'disabled'}) {
    warn "skipping disabled plan FS::part_pkg::$name" if $DEBUG;
    delete $plans{$name};
    next;
  }
  my $parents = $info{$name}->{'inherit_fields'} || [];
  my (%fields, %field_exists, @fieldorder);
  foreach my $parent ($name, @$parents) {
    if ( !exists($info{$parent}) ) {
      warn "$name tried to inherit from nonexistent '$parent'\n";
      next;
    }
    %fields = ( # avoid replacing existing fields
      %{ $info{$parent}->{'fields'} || {} },
      %fields
    );
    foreach (@{ $info{$parent}->{'fieldorder'} || [] }) {
      # avoid duplicates
      next if $field_exists{$_};
      $field_exists{$_} = 1;
      # allow inheritors to remove inherited fields from the fieldorder
      push @fieldorder, $_ if !exists($fields{$_}) or
                              !exists($fields{$_}->{'disabled'});
    }
  }
  $plans{$name}->{'fields'} = \%fields;
  $plans{$name}->{'fieldorder'} = \@fieldorder;
}

sub plan_info {
  \%plans;
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

replace should be smarter about managing the related tables (options, pkg_svc)

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::type_pkgs>, L<FS::pkg_svc>, L<Safe>.
schema.html from the base documentation.

=cut

1;

