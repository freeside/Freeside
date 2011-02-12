package FS::part_pkg;

use strict;
use vars qw( @ISA %plans $DEBUG $setup_hack $skip_pkg_svc_hack );
use Carp qw(carp cluck confess);
use Scalar::Util qw( blessed );
use Time::Local qw( timelocal_nocheck );
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
use FS::part_pkg_taxrate;
use FS::part_pkg_taxoverride;
use FS::part_pkg_taxproduct;
use FS::part_pkg_link;
use FS::part_pkg_discount;
use FS::part_pkg_vendor;

@ISA = qw( FS::m2m_Common FS::option_Common );
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
      my($exportnum,$vendor_pkg_id);
      my %options_part_pkg_vendor = $options{'part_pkg_vendor'};
      while(($exportnum,$vendor_pkg_id) = each %options_part_pkg_vendor){
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

Currently available options are: I<pkg_svc>, I<hidden_svc>, I<primary_svc> 
and I<options>

If I<pkg_svc> is set to a hashref with svcparts as keys and quantities as
values, the appropriate FS::pkg_svc records will be replaced.  I<hidden_svc>
can be set to a hashref of svcparts and flag values ('Y' or '') to set the 
'hidden' field in these records.

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
  my $hidden_svc = $options->{'hidden_svc'} || {};
  foreach my $part_svc ( qsearch('part_svc', {} ) ) {
    my $quantity = $pkg_svc->{$part_svc->svcpart} || 0;
    my $hidden = $hidden_svc->{$part_svc->svcpart} || '';
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
    if ( $old_pkg_svc ) {
      $old_quantity = $old_pkg_svc->quantity;
      $old_primary_svc = $old_pkg_svc->primary_svc 
        if $old_pkg_svc->dbdef_table->column('primary_svc'); # is this needed?
      $old_hidden = $old_pkg_svc->hidden;
    }
 
    next unless $old_quantity != $quantity || 
                $old_primary_svc ne $primary_svc ||
                $old_hidden ne $hidden;
  
    my $new_pkg_svc = new FS::pkg_svc( {
      'pkgsvcnum'   => ( $old_pkg_svc ? $old_pkg_svc->pkgsvcnum : '' ),
      'pkgpart'     => $new->pkgpart,
      'svcpart'     => $part_svc->svcpart,
      'quantity'    => $quantity, 
      'primary_svc' => $primary_svc,
      'hidden'      => $hidden,
    } );
    my $error = $old_pkg_svc
                  ? $new_pkg_svc->replace($old_pkg_svc)
                  : $new_pkg_svc->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  
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

  my @null_agentnum_right = ( 'Edit global package definitions' );
  push @null_agentnum_right, 'One-time charge'
    if $self->freq =~ /^0/;
  push @null_agentnum_right, 'Customize customer package'
    if $self->disabled eq 'Y'; #good enough

  my $error = $self->ut_numbern('pkgpart')
    || $self->ut_text('pkg')
    || $self->ut_text('comment')
    || $self->ut_textn('promo_code')
    || $self->ut_alphan('plan')
    || $self->ut_enum('setuptax', [ '', 'Y' ] )
    || $self->ut_enum('recurtax', [ '', 'Y' ] )
    || $self->ut_textn('taxclass')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_enum('custom', [ '', 'Y' ] )
    || $self->ut_enum('no_auto', [ '', 'Y' ])
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
  $pre. $self->pkg. ' - '. $self->custom_comment;
}

sub price_info { # safety, in case a part_pkg hasn't defined price_info
    '';
}

sub custom_comment {
  my $self = shift;
  ( $self->custom ? '(CUSTOM) ' : '' ). $self->comment . ' ' . $self->price_info;
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

=item type_pkgs

Returns all FS::type_pkgs objects (see L<FS::type_pkgs>) for this package
definition.

=cut

sub type_pkgs {
  my $self = shift;
  qsearch('type_pkgs', { 'pkgpart' => $self->pkgpart } );
}

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

sub can_discount { 0; }

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

=cut

sub part_pkg_vendor {
  my $self = shift;
  qsearch('part_pkg_vendor', { 'pkgpart' => $self->pkgpart } );
}

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

=item option OPTIONNAME [ QUIET ]

Returns the option value for the given name, or the empty string.  If a true
value is passed as the second argument, warnings about missing the option
will be suppressed.

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

=item part_pkg_taxrate DATA_PROVIDER, GEOCODE, [ CLASS ]

Returns the package to taxrate m2m records for this package in the location
specified by GEOCODE (see L<FS::part_pkg_taxrate>) and usage class CLASS.
CLASS may be one of 'setup', 'recur', or one of the usage classes numbers
(see L<FS::usage_class>).

=cut

sub _expand_cch_taxproductnum {
  my $self = shift;
  my $class = shift;
  my $part_pkg_taxproduct = $self->taxproduct($class);

  my ($a,$b,$c,$d) = ( $part_pkg_taxproduct
                         ? ( split ':', $part_pkg_taxproduct->taxproduct )
                         : ()
                     );
  $a = '' unless $a; $b = '' unless $b; $c = '' unless $c; $d = '' unless $d;
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
  my ($data_vendor, $geocode, $class) = @_;

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
  my @tpnums = $self->_expand_cch_taxproductnum($class);
  if (scalar(@tpnums)) {
    $extra_sql .= ' AND ('.
                            join(' OR ', map{ "taxproductnum = $_" } @tpnums ).
                       ')';
  } else {
    $extra_sql .= ' AND ( 0 = 1 )';
  }

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

=item part_pkg_discount

Returns the package to discount m2m records (see L<FS::part_pkg_discount>)
for this package.

=cut

sub part_pkg_discount {
  my $self = shift;
  qsearch('part_pkg_discount', { 'pkgpart' => $self->pkgpart });
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

#fallback for everything except bulk.pm
sub hide_svc_detail { 0; }

=item recur_cost_permonth CUST_PKG

recur_cost divided by freq (only supported for monthly and longer frequencies)

=cut

sub recur_cost_permonth {
  my($self, $cust_pkg) = @_;
  return 0 unless $self->freq =~ /^\d+$/ && $self->freq > 0;
  sprintf('%.2f', $self->recur_cost / $self->freq );
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
                     ( map "($_ IS NOT NULL AND $_ != '' )",
                           qw( plandata setup recur ) ),
                     'plan IS NULL', "plan = '' ",
                   ),
  });

  foreach my $part_pkg (@part_pkg) {

    unless ( $part_pkg->plan ) {
      $part_pkg->plan('flat');
    }

    if ( length($part_pkg->option('setup_fee')) == 0 
         && $part_pkg->setup =~ /^\s*([\d\.]+)\s*$/ ) {

      my $opt = new FS::part_pkg_option {
        'pkgpart'     => $part_pkg->pkgpart,
        'optionname'  => 'setup_fee',
        'optionvalue' => $1,
      };
      my $error = $opt->insert;
      die $error if $error;


      #} else {
      #  die "Can't parse part_pkg.setup for fee; convert pkgnum ".
      #      $part_pkg->pkgnum. " manually: ". $part_pkg->setup. "\n";
    }
    $part_pkg->setup('');

    if ( length($part_pkg->option('recur_fee')) == 0
         && $part_pkg->recur =~ /^\s*([\d\.]+)\s*$/ ) {

        my $opt = new FS::part_pkg_option {
          'pkgpart'     => $part_pkg->pkgpart,
          'optionname'  => 'recur_fee',
          'optionvalue' => $1,
        };
        my $error = $opt->insert;
        die $error if $error;


      #} else {
      #  die "Can't parse part_pkg.setup for fee; convert pkgnum ".
      #      $part_pkg->pkgnum. " manually: ". $part_pkg->setup. "\n";
    }
    $part_pkg->recur('');

    $part_pkg->replace; #this should take care of plandata, right?

  }

  # now upgrade to the explicit custom flag

  @part_pkg = qsearch({
    'table'     => 'part_pkg',
    'hashref'   => { disabled => 'Y', custom => '' },
    'extra_sql' => "AND comment LIKE '(CUSTOM) %'",
  });

  foreach my $part_pkg (@part_pkg) {
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
    die $error if $error;
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
    %fields = ( # avoid replacing existing fields
      %{ $info{$parent}->{'fields'} || {} },
      %fields
    );
    foreach (@{ $info{$parent}->{'fieldorder'} || [] }) {
      # avoid duplicates
      next if $field_exists{$_};
      $field_exists{$_} = 1;
      # allow inheritors to remove inherited fields from the fieldorder
      push @fieldorder, $_ if !exists($fields{$_}->{'disabled'});
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

