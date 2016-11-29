package FS::cust_main::Packages;

use strict;
use List::Util qw( min );
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs );
use FS::cust_pkg;
use FS::cust_svc;
use FS::contact;       # for attach_pkgs
use FS::cust_location; #

our ($DEBUG, $me) = (0, '[FS::cust_main::Packages]');
our $skip_label_sort = 0;

=head1 NAME

FS::cust_main::Packages - Packages mixin for cust_main

=head1 SYNOPSIS

=head1 DESCRIPTION

These methods are available on FS::cust_main objects;

=head1 METHODS

=over 4

=item order_pkg HASHREF | OPTION => VALUE ... 

Orders a single package.

Note that if the package definition has supplemental packages, those will
be ordered as well.

Options may be passed as a list of key/value pairs or as a hash reference.
Options are:

=over 4

=item cust_pkg

FS::cust_pkg object

=item cust_location

Optional FS::cust_location object.  If not specified, the customer's 
ship_location will be used.

=item svcs

Optional arryaref of FS::svc_* service objects.

=item depend_jobnum

If this option is set to a job queue jobnum (see L<FS::queue>), all provisioning
jobs will have a dependancy on the supplied job (they will not run until the
specific job completes).  This can be used to defer provisioning until some
action completes (such as running the customer's credit card successfully).

=item noexport

This option is option is deprecated but still works for now (use
I<depend_jobnum> instead for new code).  If I<noexport> is set true, no
provisioning jobs (exports) are scheduled.  (You can schedule them later with
the B<reexport> method for each cust_pkg object.  Using the B<reexport> method
on the cust_main object is not recommended, as existing services will also be
reexported.)

=item ticket_subject

Optional subject for a ticket created and attached to this customer

=item ticket_queue

Optional queue name for ticket additions

=item invoice_details

Optional arrayref of invoice detail strings to add (creates cust_pkg_detail detailtype 'I')

=item package_comments

Optional arrayref of package comment strings to add (creates cust_pkg_detail detailtype 'C')

=back

=cut

sub order_pkg {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  warn "$me order_pkg called with options ".
       join(', ', map { "$_: $opt->{$_}" } keys %$opt ). "\n"
    if $DEBUG;

  local $FS::svc_Common::noexport_hack = 1 if $opt->{'noexport'};

  my $cust_pkg = $opt->{'cust_pkg'};
  my $svcs     = $opt->{'svcs'} || [];

  my %svc_options = ();
  $svc_options{'depend_jobnum'} = $opt->{'depend_jobnum'}
    if exists($opt->{'depend_jobnum'}) && $opt->{'depend_jobnum'};

  my %insert_params = map { $opt->{$_} ? ( $_ => $opt->{$_} ) : () }
                          qw( ticket_subject ticket_queue allow_pkgpart );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $opt->{'contactnum'} and $opt->{'contactnum'} != -1 ) {

    $cust_pkg->contactnum($opt->{'contactnum'});

  } elsif ( $opt->{'contact'} ) {

    if ( ! $opt->{'contact'}->contactnum ) {
      # not inserted yet
      my $error = $opt->{'contact'}->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "inserting contact (transaction rolled back): $error";
      }
    }
    $cust_pkg->contactnum($opt->{'contact'}->contactnum);

  #} else {
  #
  #  $cust_pkg->contactnum();

  }

  if ( $opt->{'locationnum'} and $opt->{'locationnum'} != -1 ) {

    $cust_pkg->locationnum($opt->{'locationnum'});

  } elsif ( $opt->{'cust_location'} ) {

    my $error = $opt->{'cust_location'}->find_or_insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting cust_location (transaction rolled back): $error";
    }
    $cust_pkg->locationnum($opt->{'cust_location'}->locationnum);

  } elsif ( ! $cust_pkg->locationnum ) {

    $cust_pkg->locationnum($self->ship_locationnum);

  }

  $cust_pkg->custnum( $self->custnum );

  my $error = $cust_pkg->insert( %insert_params );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "inserting cust_pkg (transaction rolled back): $error";
  }

  foreach my $svc_something ( @{ $opt->{'svcs'} } ) {
    if ( $svc_something->svcnum ) {
      my $old_cust_svc = $svc_something->cust_svc;
      my $new_cust_svc = new FS::cust_svc { $old_cust_svc->hash };
      $new_cust_svc->pkgnum( $cust_pkg->pkgnum);
      $error = $new_cust_svc->replace($old_cust_svc);
    } else {
      $svc_something->pkgnum( $cust_pkg->pkgnum );
      if ( $svc_something->isa('FS::svc_acct') ) {
        foreach ( grep { $opt->{$_.'_ref'} && ${ $opt->{$_.'_ref'} } }
                       qw( seconds upbytes downbytes totalbytes )      ) {
          $svc_something->$_( $svc_something->$_() + ${ $opt->{$_.'_ref'} } );
          ${ $opt->{$_.'_ref'} } = 0;
        }
      }
      $error = $svc_something->insert(%svc_options);
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting svc_ (transaction rolled back): $error";
    }
  }

  # add supplemental packages, if any are needed
  my $part_pkg = FS::part_pkg->by_key($cust_pkg->pkgpart);
  foreach my $link ($part_pkg->supp_part_pkg_link) {
    #warn "inserting supplemental package ".$link->dst_pkgpart;
    my $pkg = FS::cust_pkg->new({
        'pkgpart'       => $link->dst_pkgpart,
        'pkglinknum'    => $link->pkglinknum,
        'custnum'       => $self->custnum,
        'main_pkgnum'   => $cust_pkg->pkgnum,
        # try to prevent as many surprises as possible
        'allow_pkgpart' => $opt->{'allow_pkgpart'},
        map { $_ => $cust_pkg->$_() }
          qw( pkgbatch
              start_date order_date expire adjourn contract_end
              refnum setup_discountnum recur_discountnum waive_setup
            )
    });
    $error = $self->order_pkg('cust_pkg'    => $pkg,
                              'locationnum' => $cust_pkg->locationnum);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "inserting supplemental package: $error";
    }
  }

  # add details/comments
  if ($opt->{'invoice_details'}) {
    $error = $cust_pkg->set_cust_pkg_detail('I', @{$opt->{'invoice_details'}});
  }
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "setting invoice details: $error";
  }
  if ($opt->{'package_comments'}) {
    $error = $cust_pkg->set_cust_pkg_detail('C', @{$opt->{'package_comments'}});
  }
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "setting package comments: $error";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item order_pkgs HASHREF [ , OPTION => VALUE ... ]

Like the insert method on an existing record, this method orders multiple
packages and included services atomicaly.  Pass a Tie::RefHash data structure
to this method containing FS::cust_pkg and FS::svc_I<tablename> objects.
There should be a better explanation of this, but until then, here's an
example:

  use Tie::RefHash;
  tie %hash, 'Tie::RefHash'; #this part is important
  %hash = (
    $cust_pkg => [ $svc_acct ],
    ...
  );
  $cust_main->order_pkgs( \%hash, 'noexport'=>1 );

Services can be new, in which case they are inserted, or existing unaudited
services, in which case they are linked to the newly-created package.

Currently available options are: I<depend_jobnum>, I<noexport>, I<seconds_ref>,
I<upbytes_ref>, I<downbytes_ref>, I<totalbytes_ref>, and I<allow_pkgpart>.

If I<depend_jobnum> is set, all provisioning jobs will have a dependancy
on the supplied jobnum (they will not run until the specific job completes).
This can be used to defer provisioning until some action completes (such
as running the customer's credit card successfully).

The I<noexport> option is deprecated but still works for now (use
I<depend_jobnum> instead for new code).  If I<noexport> is set true, no
provisioning jobs (exports) are scheduled.  (You can schedule them later with
the B<reexport> method for each cust_pkg object.  Using the B<reexport> method
on the cust_main object is not recommended, as existing services will also be
reexported.)

If I<seconds_ref>, I<upbytes_ref>, I<downbytes_ref>, or I<totalbytes_ref> is
provided, the scalars (provided by references) will be incremented by the
values of the prepaid card.`

I<allow_pkgpart> is passed to L<FS::cust_pkg>->insert.

=cut

sub order_pkgs {
  my $self = shift;
  my $cust_pkgs = shift;
  my %options = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  warn "$me order_pkgs called with options ".
       join(', ', map { "$_: $options{$_}" } keys %options ). "\n"
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

  local $FS::svc_Common::noexport_hack = 1 if $options{'noexport'};

  foreach my $cust_pkg ( keys %$cust_pkgs ) {

    my $error = $self->order_pkg(
      'cust_pkg'     => $cust_pkg,
      'svcs'         => $cust_pkgs->{$cust_pkg},
      map { $_ => $options{$_} }
        qw( seconds_ref upbytes_ref downbytes_ref totalbytes_ref depend_jobnum allow_pkgpart )
    );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}

=item attach_pkgs 

Merges this customer's package's into the target customer and then cancels them.

=cut

sub attach_pkgs {
  my( $self, $new_custnum ) = @_;

  #mostly false laziness w/ merge

  return "Can't attach packages to self" if $self->custnum == $new_custnum;

  my $new_cust_main = qsearchs( 'cust_main', { 'custnum' => $new_custnum } )
    or return "Invalid new customer number: $new_custnum";

  return 'Access denied: "Merge customer across agents" access right required to merge into a customer of a different agent'
    if $self->agentnum != $new_cust_main->agentnum 
    && ! $FS::CurrentUser::CurrentUser->access_right('Merge customer across agents');

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( qsearch('agent', { 'agent_custnum' => $self->custnum } ) ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't merge a master agent customer";
  }

  #use FS::access_user
  if ( qsearch('access_user', { 'user_custnum' => $self->custnum } ) ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't merge a master employee customer";
  }

  if ( qsearch('cust_pay_pending', { 'custnum' => $self->custnum,
                                     'status'  => { op=>'!=', value=>'done' },
                                   }
              )
  ) {
     $dbh->rollback if $oldAutoCommit;
     return "Can't merge a customer with pending payments";
  }

  #end of false laziness

  #pull in contact

  my %contact_hash = ( 'first'    => $self->first,
                       'last'     => $self->get('last'),
                       'custnum'  => $new_custnum,
                       'disabled' => '',
                     );

  my $contact = qsearchs(  'contact', \%contact_hash)
                 || new FS::contact   \%contact_hash;
  unless ( $contact->contactnum ) {
    my $error = $contact->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $cust_pkg ( $self->ncancelled_pkgs ) {

    my $cust_location = $cust_pkg->cust_location || $self->ship_location;
    my %loc_hash = $cust_location->hash;
    $loc_hash{'locationnum'} = '';
    $loc_hash{'custnum'}     = $new_custnum;
    $loc_hash{'disabled'}    = '';
    my $new_cust_location = qsearchs(  'cust_location', \%loc_hash)
                             || new FS::cust_location   \%loc_hash;

    my $pkg_or_error = $cust_pkg->change( {
      'keep_dates'    => 1,
      'cust_main'     => $new_cust_main,
      'contactnum'    => $contact->contactnum,
      'cust_location' => $new_cust_location,
    } );

    my $error = ref($pkg_or_error) ? '' : $pkg_or_error;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item all_pkgs [ OPTION => VALUE... | EXTRA_QSEARCH_PARAMS_HASHREF ]

Returns all packages (see L<FS::cust_pkg>) for this customer.

=cut

sub all_pkgs {
  my $self = shift;
  my $extra_qsearch = ref($_[0]) ? shift : { @_ };

  return $self->num_pkgs($extra_qsearch) unless wantarray;

  my @cust_pkg = ();
  if ( $self->{'_pkgnum'} && ! keys %$extra_qsearch ) {
    @cust_pkg = values %{ $self->{'_pkgnum'}->cache };
  } else {
    @cust_pkg = $self->_cust_pkg($extra_qsearch);
  }

  local($skip_label_sort) = 1 if $extra_qsearch->{skip_label_sort};
  map { $_ } sort sort_packages @cust_pkg;

}

=item cust_pkg

Synonym for B<all_pkgs>.

=cut

sub cust_pkg {
  shift->all_pkgs(@_);
}

=item ncancelled_pkgs [ EXTRA_QSEARCH_PARAMS_HASHREF ]

Returns all non-cancelled packages (see L<FS::cust_pkg>) for this customer.

=cut

sub ncancelled_pkgs {
  my $self = shift;
  my $extra_qsearch = ref($_[0]) ? shift : { @_ };

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  return $self->num_ncancelled_pkgs($extra_qsearch) unless wantarray;

  my @cust_pkg = ();
  if ( $self->{'_pkgnum'} ) {

    warn "$me ncancelled_pkgs: returning cached objects"
      if $DEBUG > 1;

    @cust_pkg = grep { ! $_->getfield('cancel') }
                values %{ $self->{'_pkgnum'}->cache };

  } else {

    warn "$me ncancelled_pkgs: searching for packages with custnum ".
         $self->custnum. "\n"
      if $DEBUG > 1;

    $extra_qsearch->{'extra_sql'} .=
      ' AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 ) ';

    @cust_pkg = $self->_cust_pkg($extra_qsearch);

  }

  local($skip_label_sort) = 1 if $extra_qsearch->{skip_label_sort};
  sort sort_packages @cust_pkg;

}

=item cancelled_pkgs [ EXTRA_QSEARCH_PARAMS_HASHREF ]

Returns all cancelled packages (see L<FS::cust_pkg>) for this customer.

=cut

sub cancelled_pkgs {
  my $self = shift;
  my $extra_qsearch = ref($_[0]) ? shift : { @_ };

  return $self->num_cancelled_pkgs($extra_qsearch) unless wantarray;

  $extra_qsearch->{'extra_sql'} .=
    ' AND cust_pkg.cancel IS NOT NULL AND cust_pkg.cancel > 0 ';

  local($skip_label_sort) = 1 if $extra_qsearch->{skip_label_sort};

  sort sort_packages $self->_cust_pkg($extra_qsearch);
}

sub _cust_pkg {
  my $self = shift;
  my $extra_qsearch = ref($_[0]) ? shift : {};

  $extra_qsearch->{'select'} ||= '*';
  $extra_qsearch->{'select'} .=
   ',( SELECT COUNT(*) FROM cust_svc WHERE cust_pkg.pkgnum = cust_svc.pkgnum )
     AS _num_cust_svc';

  map {
        $_->{'_num_cust_svc'} = $_->get('_num_cust_svc');
        $_;
      }
  qsearch({
    %$extra_qsearch,
    'table'   => 'cust_pkg',
    'hashref' => { 'custnum' => $self->custnum },
  });

}

# This should be generalized to use config options to determine order.
sub sort_packages {
  
  my $locationsort = ( $a->locationnum || 0 ) <=> ( $b->locationnum || 0 );
  return $locationsort if $locationsort;

  if ( $a->get('cancel') xor $b->get('cancel') ) {
    return -1 if $b->get('cancel');
    return  1 if $a->get('cancel');
    #shouldn't get here...
    return 0;
  } else {
    my $a_num_cust_svc = $a->num_cust_svc;
    my $b_num_cust_svc = $b->num_cust_svc;
    return 0  if !$a_num_cust_svc && !$b_num_cust_svc;
    return -1 if  $a_num_cust_svc && !$b_num_cust_svc;
    return 1  if !$a_num_cust_svc &&  $b_num_cust_svc;
    return 0 if $skip_label_sort
             || $a_num_cust_svc + $b_num_cust_svc > 20; #for perf, just give up
    my @a_cust_svc = $a->cust_svc_unsorted;
    my @b_cust_svc = $b->cust_svc_unsorted;
    return 0  if !scalar(@a_cust_svc) && !scalar(@b_cust_svc);
    return -1 if  scalar(@a_cust_svc) && !scalar(@b_cust_svc);
    return 1  if !scalar(@a_cust_svc) &&  scalar(@b_cust_svc);
    $a_cust_svc[0]->svc_x->label cmp $b_cust_svc[0]->svc_x->label;
  }

}

=item suspended_pkgs

Returns all suspended packages (see L<FS::cust_pkg>) for this customer.

=cut

sub suspended_pkgs {
  my $self = shift;
  return $self->num_suspended_pkgs unless wantarray;
  grep { $_->susp } $self->ncancelled_pkgs;
}

=item unsuspended_pkgs

Returns all unsuspended (and uncancelled) packages (see L<FS::cust_pkg>) for
this customer.

=cut

sub unsuspended_pkgs {
  my $self = shift;
  return $self->num_unsuspended_pkgs unless wantarray;
  grep { ! $_->susp } $self->ncancelled_pkgs;
}

=item active_pkgs

Returns all unsuspended (and uncancelled) packages (see L<FS::cust_pkg>) for
this customer that are active (recurring).

=cut

sub active_pkgs {
  my $self = shift; 
  grep { my $part_pkg = $_->part_pkg;
         $part_pkg->freq ne '' && $part_pkg->freq ne '0';
       }
       $self->unsuspended_pkgs;
}

=item ncancelled_active_pkgs

Returns all non-cancelled packages (see L<FS::cust_pkg>) for this customer that
are active (recurring).

=cut

sub ncancelled_active_pkgs {
  my $self = shift; 
  grep { my $part_pkg = $_->part_pkg;
         $part_pkg->freq ne '' && $part_pkg->freq ne '0';
       }
       $self->ncancelled_pkgs;
}

=item billing_pkgs

Returns active packages, and also any suspended packages which are set to
continue billing while suspended.

=cut

sub billing_pkgs {
  my $self = shift;
  grep { my $part_pkg = $_->part_pkg;
         $part_pkg->freq ne '' && $part_pkg->freq ne '0'
           && ( ! $_->susp || $_->option('suspend_bill',1)
                           || ( $part_pkg->option('suspend_bill', 1)
                                  && ! $_->option('no_suspend_bill',1)
                              )
              );
       }
       $self->ncancelled_pkgs;
}

=item next_bill_date

Returns the next date this customer will be billed, as a UNIX timestamp, or
undef if no billing package has a next bill date.

=cut

sub next_bill_date {
  my $self = shift;

#  super inefficient with lots of packages
#  min( map $_->get('bill'), grep $_->get('bill'), $self->billing_pkgs );

  my $custnum = $self->custnum;

  $self->scalar_sql("
    SELECT MIN(bill) FROM cust_pkg
      LEFT JOIN cust_pkg_option AS cust_suspend_bill_option
        ON (     cust_pkg.pkgnum = cust_suspend_bill_option.pkgnum
             AND cust_suspend_bill_option.optionname = 'suspend_bill' )
      LEFT JOIN cust_pkg_option AS cust_no_suspend_bill_option
        ON (     cust_pkg.pkgnum = cust_no_suspend_bill_option.pkgnum
             AND cust_no_suspend_bill_option.optionname = 'no_suspend_bill' )
      LEFT JOIN part_pkg USING (pkgpart)
        LEFT JOIN part_pkg_option AS part_suspend_bill_option
          ON (     part_pkg.pkgpart = part_suspend_bill_option.pkgpart
               AND part_suspend_bill_option.optionname = 'suspend_bill' )
    WHERE custnum = $custnum
      AND bill IS NOT NULL AND bill != 0
      AND ( cancel IS NULL OR cancel = 0 )
      AND part_pkg.freq != '' AND part_pkg.freq != '0'
      AND (    ( susp IS NULL OR susp = 0 )
            OR COALESCE(cust_suspend_bill_option.optionvalue,'0') = '1'
            OR (     COALESCE(part_suspend_bill_option.optionvalue,'0') = '1'
                 AND COALESCE(cust_no_suspend_bill_option.optionvalue,'0') = '0'
               )
          )
  ");

}

=item num_cancelled_pkgs

Returns the number of cancelled packages (see L<FS::cust_pkg>) for this
customer.

=cut

sub num_cancelled_pkgs {
  my $self = shift;
  my $opt = shift || {};
  $opt->{extra_sql} .= ' AND ' if $opt->{extra_sql};
  $opt->{extra_sql} .= "cust_pkg.cancel IS NOT NULL AND cust_pkg.cancel != 0";
  $self->num_pkgs($opt);
}

=item num_ncancelled_pkgs

Returns the number of packages that have not been cancelled (see L<FS::cust_pkg>) for this
customer.

=cut

sub num_ncancelled_pkgs {
  my $self = shift;
  my $opt = shift || {};
  $opt->{extra_sql} .= ' AND ' if $opt->{extra_sql};
  $opt->{extra_sql} .= "( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )";
  $self->num_pkgs($opt);
}

=item num_billing_pkgs

Returns the number of packages that have not been cancelled 
and have a non-zero billing frequency (see L<FS::cust_pkg>)
for this customer.

=cut

sub num_billing_pkgs {
  my $self = shift;
  my $opt = shift || {};
  $opt->{addl_from} .= ' LEFT JOIN part_pkg USING (pkgpart)';
  $opt->{extra_sql} .= ' AND ' if $opt->{extra_sql};
  $opt->{extra_sql} .= "freq IS NOT NULL AND freq != '0'";
  $self->num_ncancelled_pkgs($opt);
}

sub num_suspended_pkgs {
  my $self = shift;
  my $opt = shift || {};
  $opt->{extra_sql} .= ' AND ' if $opt->{extra_sql};
  $opt->{extra_sql} .= "    ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
                        AND cust_pkg.susp IS NOT NULL AND cust_pkg.susp != 0  ";
  $self->num_pkgs($opt);
}

sub num_unsuspended_pkgs {
  my $self = shift;
  my $opt = shift || {};
  $opt->{extra_sql} .= ' AND ' if $opt->{extra_sql};
  $opt->{extra_sql} .= "    ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
                        AND ( cust_pkg.susp   IS NULL OR cust_pkg.susp   = 0 )";
  $self->num_pkgs($opt);
}

sub num_pkgs {
  my( $self ) = shift;
  my $addl_from = '';
  my $sql = '';
  if ( @_ ) {
    if ( ref($_[0]) ) {
      my $opt = shift;
      $sql       = $opt->{extra_sql} if exists($opt->{extra_sql});
      $addl_from = $opt->{addl_from} if exists($opt->{addl_from});
    } else {
      $sql = shift;
    }
  }
  $sql = "AND $sql" if $sql && $sql !~ /^\s*$/ && $sql !~ /^\s*AND/i;
  my $sth = dbh->prepare(
    "SELECT COUNT(*) FROM cust_pkg $addl_from WHERE cust_pkg.custnum = ? $sql"
  ) or die dbh->errstr;
  $sth->execute($self->custnum) or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=item num_usage_pkgs

Returns the number of packages for this customer that have services that
can have RADIUS usage statistics.

=cut

sub num_usage_pkgs {
  my $self = shift;
  # have to enumerate exportnums but it's not bad
  my @exportnums = map { $_->exportnum }
                   grep { $_->can('usage_sessions') }
                   qsearch('part_export');
  return 0 if !@exportnums;
  my $in_exportnums = join(',', @exportnums);
  my $sql = "SELECT COUNT(DISTINCT pkgnum) FROM cust_pkg
    JOIN cust_svc USING (pkgnum)
    JOIN export_svc USING (svcpart)
    WHERE exportnum IN( $in_exportnums ) AND custnum = ?";
  FS::Record->scalar_sql($sql, $self->custnum);
}

=item display_recurring

Returns an array of hash references, one for each recurring freq
on billable customer packages, with keys of freq, freq_pretty and amount
(the amount that this customer will next be charged at the given frequency.)

Results will be numerically sorted by freq.

Only intended for display purposes, not used for actual billing.

=cut

sub display_recurring {
  my $cust_main = shift;

  my $sth = dbh->prepare("
    SELECT DISTINCT freq FROM cust_pkg LEFT JOIN part_pkg USING (pkgpart)
      WHERE freq IS NOT NULL AND freq != '0'
        AND ( cancel IS NULL OR cancel = 0 )
        AND custnum = ?
  ") or die $DBI::errstr;

  $sth->execute($cust_main->custnum) or die $sth->errstr;

  #not really a numeric sort because freqs can actually be all sorts of things
  # but good enough for the 99% cases of ordering monthly quarterly annually
  my @freqs = sort { $a <=> $b } map { $_->[0] } @{ $sth->fetchall_arrayref };

  $sth->finish;

  my @out;

  foreach my $freq (@freqs) {

    my @cust_pkg = qsearch({
      'table'     => 'cust_pkg',
      'addl_from' => 'LEFT JOIN part_pkg USING (pkgpart)',
      'hashref'   => { 'custnum' => $cust_main->custnum, },
      'extra_sql' => 'AND ( cancel IS NULL OR cancel = 0 )
                      AND freq = '. dbh->quote($freq),
      'order_by'  => 'ORDER BY COALESCE(start_date,0), pkgnum', # to ensure old pkgs come before change_to_pkg
    }) or next;

    my $freq_pretty = $cust_pkg[0]->part_pkg->freq_pretty;

    my $amount = 0;
    my $skip_pkg = {};
    foreach my $cust_pkg (@cust_pkg) {
      my $part_pkg = $cust_pkg->part_pkg;
      next if $cust_pkg->susp
           && ! $cust_pkg->option('suspend_bill')
           && ( ! $part_pkg->option('suspend_bill')
                || $cust_pkg->option('no_suspend_bill')
              );

      #pkg change handling
      next if $skip_pkg->{$cust_pkg->pkgnum};
      if ($cust_pkg->change_to_pkgnum) {
        #if change is on or before next bill date, use new pkg
        next if $cust_pkg->expire <= $cust_pkg->bill;
        #if change is after next bill date, use old (this) pkg
        $skip_pkg->{$cust_pkg->change_to_pkgnum} = 1;
      }

      my $pkg_amount = 0;

      #add recurring amounts for this package and its billing add-ons
      foreach my $l_part_pkg ( $part_pkg->self_and_bill_linked ) {
        $pkg_amount += $l_part_pkg->base_recur($cust_pkg);
      }

      #subtract amounts for any active discounts
      #(there should only be one at the moment, otherwise this makes no sense)
      foreach my $cust_pkg_discount ( $cust_pkg->cust_pkg_discount_active ) {
        my $discount = $cust_pkg_discount->discount;
        #and only one of these for each
        $pkg_amount -= $discount->amount;
        $pkg_amount -= $amount * $discount->percent/100;
      }

      $pkg_amount *= ( $cust_pkg->quantity || 1 );

      $amount += $pkg_amount;

    } #foreach $cust_pkg

    next unless $amount;
    push @out, {
      'freq'        => $freq,
      'freq_pretty' => $freq_pretty,
      'amount'      => $amount,
    };

  } #foreach $freq

  return @out;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::cust_pkg>

=cut

1;

