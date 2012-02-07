package FS::cust_main::Billing;

use strict;
use vars qw( $conf $DEBUG $me );
use Carp;
use Data::Dumper;
use List::Util qw( min );
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs dbdef );
use FS::Misc::DateTime qw( day_end );
use FS::cust_bill;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pay;
use FS::cust_credit_bill;
use FS::cust_tax_adjustment;
use FS::tax_rate;
use FS::tax_rate_location;
use FS::cust_bill_pkg_tax_location;
use FS::cust_bill_pkg_tax_rate_location;
use FS::part_event;
use FS::part_event_condition;
use FS::pkg_category;

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;
$me = '[FS::cust_main::Billing]';

install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
};

=head1 NAME

FS::cust_main::Billing - Billing mixin for cust_main

=head1 SYNOPSIS

=head1 DESCRIPTION

These methods are available on FS::cust_main objects.

=head1 METHODS

=over 4

=item bill_and_collect 

Cancels and suspends any packages due, generates bills, applies payments and
credits, and applies collection events to run cards, send bills and notices,
etc.

By default, warns on errors and continues with the next operation (but see the
"fatal" flag below).

Options are passed as name-value pairs.  Currently available options are:

=over 4

=item time

Bills the customer as if it were that time.  Specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.  For example:

 use Date::Parse;
 ...
 $cust_main->bill( 'time' => str2time('April 20th, 2001') );

=item invoice_time

Used in conjunction with the I<time> option, this option specifies the date of for the generated invoices.  Other calculations, such as whether or not to generate the invoice in the first place, are not affected.

=item check_freq

"1d" for the traditional, daily events (the default), or "1m" for the new monthly events (part_event.check_freq)

=item resetup

If set true, re-charges setup fees.

=item fatal

If set any errors prevent subsequent operations from continusing.  If set
specifically to "return", returns the error (or false, if there is no error).
Any other true value causes errors to die.

=item debug

Debugging level.  Default is 0 (no debugging), or can be set to 1 (passed-in options), 2 (traces progress), 3 (more information), or 4 (include full search queries)

=item job

Optional FS::queue entry to receive status updates.

=back

Options are passed to the B<bill> and B<collect> methods verbatim, so all
options of those methods are also available.

=cut

sub bill_and_collect {
  my( $self, %options ) = @_;

  my $error;

  #$options{actual_time} not $options{time} because freeside-daily -d is for
  #pre-printing invoices

  $options{'actual_time'} ||= time;
  my $job = $options{'job'};

  $job->update_statustext('0,cleaning expired packages') if $job;
  $error = $self->cancel_expired_pkgs( day_end( $options{actual_time} ) );
  if ( $error ) {
    $error = "Error expiring custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $error = $self->suspend_adjourned_pkgs( day_end( $options{actual_time} ) );
  if ( $error ) {
    $error = "Error adjourning custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $error = $self->unsuspend_resumed_pkgs( day_end( $options{actual_time} ) );
  if ( $error ) {
    $error = "Error resuming custnum ".$self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $job->update_statustext('20,billing packages') if $job;
  $error = $self->bill( %options );
  if ( $error ) {
    $error = "Error billing custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $job->update_statustext('50,applying payments and credits') if $job;
  $error = $self->apply_payments_and_credits;
  if ( $error ) {
    $error = "Error applying custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $job->update_statustext('70,running collection events') if $job;
  unless ( $conf->exists('cancelled_cust-noevents')
           && ! $self->num_ncancelled_pkgs
  ) {
    $error = $self->collect( %options );
    if ( $error ) {
      $error = "Error collecting custnum ". $self->custnum. ": $error";
      if    ($options{fatal} && $options{fatal} eq 'return') { return $error; }
      elsif ($options{fatal}                               ) { die    $error; }
      else                                                   { warn   $error; }
    }
  }
  $job->update_statustext('100,finished') if $job;

  '';

}

sub cancel_expired_pkgs {
  my ( $self, $time, %options ) = @_;
  
  my @cancel_pkgs = $self->ncancelled_pkgs( { 
    'extra_sql' => " AND expire IS NOT NULL AND expire > 0 AND expire <= $time "
  } );

  my @errors = ();

  foreach my $cust_pkg ( @cancel_pkgs ) {
    my $cpr = $cust_pkg->last_cust_pkg_reason('expire');
    my $error = $cust_pkg->cancel($cpr ? ( 'reason'        => $cpr->reasonnum,
                                           'reason_otaker' => $cpr->otaker,
                                           'time'          => $time,
                                         )
                                       : ()
                                 );
    push @errors, 'pkgnum '.$cust_pkg->pkgnum.": $error" if $error;
  }

  join(' / ', @errors);

}

sub suspend_adjourned_pkgs {
  my ( $self, $time, %options ) = @_;
  
  my @susp_pkgs = $self->ncancelled_pkgs( {
    'extra_sql' =>
      " AND ( susp IS NULL OR susp = 0 )
        AND (    ( bill    IS NOT NULL AND bill    != 0 AND bill    <  $time )
              OR ( adjourn IS NOT NULL AND adjourn != 0 AND adjourn <= $time )
            )
      ",
  } );

  #only because there's no SQL test for is_prepaid :/
  @susp_pkgs = 
    grep {     (    $_->part_pkg->is_prepaid
                 && $_->bill
                 && $_->bill < $time
               )
            || (    $_->adjourn
                 && $_->adjourn <= $time
               )
           
         }
         @susp_pkgs;

  my @errors = ();

  foreach my $cust_pkg ( @susp_pkgs ) {
    my $cpr = $cust_pkg->last_cust_pkg_reason('adjourn')
      if ($cust_pkg->adjourn && $cust_pkg->adjourn < $^T);
    my $error = $cust_pkg->suspend($cpr ? ( 'reason' => $cpr->reasonnum,
                                            'reason_otaker' => $cpr->otaker
                                          )
                                        : ()
                                  );
    push @errors, 'pkgnum '.$cust_pkg->pkgnum.": $error" if $error;
  }

  join(' / ', @errors);

}

sub unsuspend_resumed_pkgs {
  my ( $self, $time, %options ) = @_;
  
  my @unsusp_pkgs = $self->ncancelled_pkgs( { 
    'extra_sql' => " AND resume IS NOT NULL AND resume > 0 AND resume <= $time "
  } );

  my @errors = ();

  foreach my $cust_pkg ( @unsusp_pkgs ) {
    my $error = $cust_pkg->unsuspend( 'time' => $time );
    push @errors, 'pkgnum '.$cust_pkg->pkgnum.": $error" if $error;
  }

  join(' / ', @errors);

}

=item bill OPTIONS

Generates invoices (see L<FS::cust_bill>) for this customer.  Usually used in
conjunction with the collect method by calling B<bill_and_collect>.

If there is an error, returns the error, otherwise returns false.

Options are passed as name-value pairs.  Currently available options are:

=over 4

=item resetup

If set true, re-charges setup fees.

=item recurring_only

If set true then only bill recurring charges, not setup, usage, one time
charges, etc.

=item freq_override

If set, then override the normal frequency and look for a part_pkg_discount
to take at that frequency.  This is appropriate only when the normal 
frequency for all packages is monthly, and is an error otherwise.  Use
C<pkg_list> to limit the set of packages included in billing.

=item time

Bills the customer as if it were that time.  Specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.  For example:

 use Date::Parse;
 ...
 $cust_main->bill( 'time' => str2time('April 20th, 2001') );

=item pkg_list

An array ref of specific packages (objects) to attempt billing, instead trying all of them.

 $cust_main->bill( pkg_list => [$pkg1, $pkg2] );

=item not_pkgpart

A hashref of pkgparts to exclude from this billing run (can also be specified as a comma-separated scalar).

=item invoice_time

Used in conjunction with the I<time> option, this option specifies the date of for the generated invoices.  Other calculations, such as whether or not to generate the invoice in the first place, are not affected.

=item cancel

This boolean value informs the us that the package is being cancelled.  This
typically might mean not charging the normal recurring fee but only usage
fees since the last billing. Setup charges may be charged.  Not all package
plans support this feature (they tend to charge 0).

=item no_usage_reset

Prevent the resetting of usage limits during this call.

=item no_commit

Do not save the generated bill in the database.  Useful with return_bill

=item return_bill

A list reference on which the generated bill(s) will be returned.

=item invoice_terms

Optional terms to be printed on this invoice.  Otherwise, customer-specific
terms or the default terms are used.

=back

=cut

sub bill {
  my( $self, %options ) = @_;

  return '' if $self->payby eq 'COMP';

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  warn "$me bill customer ". $self->custnum. "\n"
    if $DEBUG;

  my $time = $options{'time'} || time;
  my $invoice_time = $options{'invoice_time'} || $time;

  $options{'not_pkgpart'} ||= {};
  $options{'not_pkgpart'} = { map { $_ => 1 }
                                  split(/\s*,\s*/, $options{'not_pkgpart'})
                            }
    unless ref($options{'not_pkgpart'});

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  warn "$me acquiring lock on customer ". $self->custnum. "\n"
    if $DEBUG;

  $self->select_for_update; #mutex

  warn "$me running pre-bill events for customer ". $self->custnum. "\n"
    if $DEBUG;

  my $error = $self->do_cust_event(
    'debug'      => ( $options{'debug'} || 0 ),
    'time'       => $invoice_time,
    'check_freq' => $options{'check_freq'},
    'stage'      => 'pre-bill',
  )
    unless $options{no_commit};
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit && !$options{no_commit};
    return $error;
  }

  warn "$me done running pre-bill events for customer ". $self->custnum. "\n"
    if $DEBUG;

  #keep auto-charge and non-auto-charge line items separate
  my @passes = ( '', 'no_auto' );

  my %cust_bill_pkg = map { $_ => [] } @passes;

  ###
  # find the packages which are due for billing, find out how much they are
  # & generate invoice database.
  ###

  my %total_setup   = map { my $z = 0; $_ => \$z; } @passes;
  my %total_recur   = map { my $z = 0; $_ => \$z; } @passes;

  my %taxlisthash = map { $_ => {} } @passes;

  my @precommit_hooks = ();

  $options{'pkg_list'} ||= [ $self->ncancelled_pkgs ];  #param checks?
  foreach my $cust_pkg ( @{ $options{'pkg_list'} } ) {

    next if $options{'not_pkgpart'}->{$cust_pkg->pkgpart};

    warn "  bill package ". $cust_pkg->pkgnum. "\n" if $DEBUG;

    #? to avoid use of uninitialized value errors... ?
    $cust_pkg->setfield('bill', '')
      unless defined($cust_pkg->bill);
 
    #my $part_pkg = $cust_pkg->part_pkg;

    my $real_pkgpart = $cust_pkg->pkgpart;
    my %hash = $cust_pkg->hash;

    # we could implement this bit as FS::part_pkg::has_hidden, but we already
    # suffer from performance issues
    $options{has_hidden} = 0;
    my @part_pkg = $cust_pkg->part_pkg->self_and_bill_linked;
    $options{has_hidden} = 1 if ($part_pkg[1] && $part_pkg[1]->hidden);
 
    foreach my $part_pkg ( @part_pkg ) {

      $cust_pkg->set($_, $hash{$_}) foreach qw ( setup last_bill bill );

      my $pass = ($cust_pkg->no_auto || $part_pkg->no_auto) ? 'no_auto' : '';

      my $next_bill = $cust_pkg->getfield('bill') || 0;
      my $error;
      # let this run once if this is the last bill upon cancellation
      while ( $next_bill <= $time or $options{cancel} ) {
        $error =
          $self->_make_lines( 'part_pkg'            => $part_pkg,
                              'cust_pkg'            => $cust_pkg,
                              'precommit_hooks'     => \@precommit_hooks,
                              'line_items'          => $cust_bill_pkg{$pass},
                              'setup'               => $total_setup{$pass},
                              'recur'               => $total_recur{$pass},
                              'tax_matrix'          => $taxlisthash{$pass},
                              'time'                => $time,
                              'real_pkgpart'        => $real_pkgpart,
                              'options'             => \%options,
                            );

        # Stop if anything goes wrong
        last if $error;

        # or if we're not incrementing the bill date.
        last if ($cust_pkg->getfield('bill') || 0) == $next_bill;

        # or if we're letting it run only once
        last if $options{cancel};

        $next_bill = $cust_pkg->getfield('bill') || 0;

        #stop if -o was passed to freeside-daily
        last if $options{'one_recur'};
      }
      if ($error) {
        $dbh->rollback if $oldAutoCommit && !$options{no_commit};
        return $error;
      }

    } #foreach my $part_pkg

  } #foreach my $cust_pkg

  #if the customer isn't on an automatic payby, everything can go on a single
  #invoice anyway?
  #if ( $cust_main->payby !~ /^(CARD|CHEK)$/ ) {
    #merge everything into one list
  #}

  foreach my $pass (@passes) { # keys %cust_bill_pkg ) {

    my @cust_bill_pkg = _omit_zero_value_bundles(@{ $cust_bill_pkg{$pass} });

    next unless @cust_bill_pkg; #don't create an invoice w/o line items

    warn "$me billing pass $pass\n"
           #.Dumper(\@cust_bill_pkg)."\n"
      if $DEBUG > 2;

    if ( scalar( grep { $_->recur && $_->recur > 0 } @cust_bill_pkg) ||
           !$conf->exists('postal_invoice-recurring_only')
       )
    {

      my $postal_pkg = $self->charge_postal_fee();
      if ( $postal_pkg && !ref( $postal_pkg ) ) {

        $dbh->rollback if $oldAutoCommit && !$options{no_commit};
        return "can't charge postal invoice fee for customer ".
          $self->custnum. ": $postal_pkg";

      } elsif ( $postal_pkg ) {

        my $real_pkgpart = $postal_pkg->pkgpart;
        # we could implement this bit as FS::part_pkg::has_hidden, but we already
        # suffer from performance issues
        $options{has_hidden} = 0;
        my @part_pkg = $postal_pkg->part_pkg->self_and_bill_linked;
        $options{has_hidden} = 1 if ($part_pkg[1] && $part_pkg[1]->hidden);

        foreach my $part_pkg ( @part_pkg ) {
          my %postal_options = %options;
          delete $postal_options{cancel};
          my $error =
            $self->_make_lines( 'part_pkg'            => $part_pkg,
                                'cust_pkg'            => $postal_pkg,
                                'precommit_hooks'     => \@precommit_hooks,
                                'line_items'          => \@cust_bill_pkg,
                                'setup'               => $total_setup{$pass},
                                'recur'               => $total_recur{$pass},
                                'tax_matrix'          => $taxlisthash{$pass},
                                'time'                => $time,
                                'real_pkgpart'        => $real_pkgpart,
                                'options'             => \%postal_options,
                              );
          if ($error) {
            $dbh->rollback if $oldAutoCommit && !$options{no_commit};
            return $error;
          }
        }

        # it's silly to have a zero value postal_pkg, but....
        @cust_bill_pkg = _omit_zero_value_bundles(@cust_bill_pkg);

      }

    }

    my $listref_or_error =
      $self->calculate_taxes( \@cust_bill_pkg, $taxlisthash{$pass}, $invoice_time);

    unless ( ref( $listref_or_error ) ) {
      $dbh->rollback if $oldAutoCommit && !$options{no_commit};
      return $listref_or_error;
    }

    foreach my $taxline ( @$listref_or_error ) {
      ${ $total_setup{$pass} } =
        sprintf('%.2f', ${ $total_setup{$pass} } + $taxline->setup );
      push @cust_bill_pkg, $taxline;
    }

    #add tax adjustments
    warn "adding tax adjustments...\n" if $DEBUG > 2;
    foreach my $cust_tax_adjustment (
      qsearch('cust_tax_adjustment', { 'custnum'    => $self->custnum,
                                       'billpkgnum' => '',
                                     }
             )
    ) {

      my $tax = sprintf('%.2f', $cust_tax_adjustment->amount );

      my $itemdesc = $cust_tax_adjustment->taxname;
      $itemdesc = '' if $itemdesc eq 'Tax';

      push @cust_bill_pkg, new FS::cust_bill_pkg {
        'pkgnum'      => 0,
        'setup'       => $tax,
        'recur'       => 0,
        'sdate'       => '',
        'edate'       => '',
        'itemdesc'    => $itemdesc,
        'itemcomment' => $cust_tax_adjustment->comment,
        'cust_tax_adjustment' => $cust_tax_adjustment,
        #'cust_bill_pkg_tax_location' => \@cust_bill_pkg_tax_location,
      };

    }

    my $charged = sprintf('%.2f', ${ $total_setup{$pass} } + ${ $total_recur{$pass} } );

    my @cust_bill = $self->cust_bill;
    my $balance = $self->balance;
    my $previous_balance = scalar(@cust_bill)
                             ? ( $cust_bill[$#cust_bill]->billing_balance || 0 )
                             : 0;

    $previous_balance += $cust_bill[$#cust_bill]->charged
      if scalar(@cust_bill);
    #my $balance_adjustments =
    #  sprintf('%.2f', $balance - $prior_prior_balance - $prior_charged);

    warn "creating the new invoice\n" if $DEBUG;
    #create the new invoice
    my $cust_bill = new FS::cust_bill ( {
      'custnum'             => $self->custnum,
      '_date'               => $invoice_time,
      'charged'             => $charged,
      'billing_balance'     => $balance,
      'previous_balance'    => $previous_balance,
      'invoice_terms'       => $options{'invoice_terms'},
      'cust_bill_pkg'       => \@cust_bill_pkg,
    } );
    $error = $cust_bill->insert unless $options{no_commit};
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit && !$options{no_commit};
      return "can't create invoice for customer #". $self->custnum. ": $error";
    }
    push @{$options{return_bill}}, $cust_bill if $options{return_bill};

  } #foreach my $pass ( keys %cust_bill_pkg )

  foreach my $hook ( @precommit_hooks ) { 
    eval {
      &{$hook}; #($self) ?
    } unless $options{no_commit};
    if ( $@ ) {
      $dbh->rollback if $oldAutoCommit && !$options{no_commit};
      return "$@ running precommit hook $hook\n";
    }
  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit && !$options{no_commit};

  ''; #no error
}

#discard bundled packages of 0 value
sub _omit_zero_value_bundles {
  my @in = @_;

  my @cust_bill_pkg = ();
  my @cust_bill_pkg_bundle = ();
  my $sum = 0;
  my $discount_show_always = 0;

  foreach my $cust_bill_pkg ( @in ) {

    $discount_show_always = ($cust_bill_pkg->get('discounts')
				&& scalar(@{$cust_bill_pkg->get('discounts')})
				&& $conf->exists('discount-show-always'));

    warn "  pkgnum ". $cust_bill_pkg->pkgnum. " sum $sum, ".
         "setup_show_zero ". $cust_bill_pkg->setup_show_zero.
         "recur_show_zero ". $cust_bill_pkg->recur_show_zero. "\n"
      if $DEBUG > 0;

    if (scalar(@cust_bill_pkg_bundle) && !$cust_bill_pkg->pkgpart_override) {
      push @cust_bill_pkg, @cust_bill_pkg_bundle 
        if $sum > 0
        || ($sum == 0 && (    $discount_show_always
                           || grep {$_->recur_show_zero || $_->setup_show_zero}
                                   @cust_bill_pkg_bundle
                         )
           );
      @cust_bill_pkg_bundle = ();
      $sum = 0;
    }

    $sum += $cust_bill_pkg->setup + $cust_bill_pkg->recur;
    push @cust_bill_pkg_bundle, $cust_bill_pkg;

  }

  push @cust_bill_pkg, @cust_bill_pkg_bundle
    if $sum > 0
    || ($sum == 0 && (    $discount_show_always
                       || grep {$_->recur_show_zero || $_->setup_show_zero}
                               @cust_bill_pkg_bundle
                     )
       );

  warn "  _omit_zero_value_bundles: ". scalar(@in).
       '->'. scalar(@cust_bill_pkg). "\n" #. Dumper(@cust_bill_pkg). "\n"
    if $DEBUG > 2;

  (@cust_bill_pkg);

}

=item calculate_taxes LINEITEMREF TAXHASHREF INVOICE_TIME

This is a weird one.  Perhaps it should not even be exposed.

Generates tax line items (see L<FS::cust_bill_pkg>) for this customer.
Usually used internally by bill method B<bill>.

If there is an error, returns the error, otherwise returns reference to a
list of line items suitable for insertion.

=over 4

=item LINEITEMREF

An array ref of the line items being billed.

=item TAXHASHREF

A strange beast.  The keys to this hash are internal identifiers consisting
of the name of the tax object type, a space, and its unique identifier ( e.g.
 'cust_main_county 23' ).  The values of the hash are listrefs.  The first
item in the list is the tax object.  The remaining items are either line
items or floating point values (currency amounts).

The taxes are calculated on this entity.  Calculated exemption records are
transferred to the LINEITEMREF items on the assumption that they are related.

Read the source.

=item INVOICE_TIME

This specifies the date appearing on the associated invoice.  Some
jurisdictions (i.e. Texas) have tax exemptions which are date sensitive.

=back

=cut

sub calculate_taxes {
  my ($self, $cust_bill_pkg, $taxlisthash, $invoice_time) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  warn "$me calculate_taxes\n"
       #.Dumper($self, $cust_bill_pkg, $taxlisthash, $invoice_time). "\n"
    if $DEBUG > 2;

  my @tax_line_items = ();

  # keys are tax names (as printed on invoices / itemdesc )
  # values are listrefs of taxlisthash keys (internal identifiers)
  my %taxname = ();

  # keys are taxlisthash keys (internal identifiers)
  # values are (cumulative) amounts
  my %tax = ();

  # keys are taxlisthash keys (internal identifiers)
  # values are listrefs of cust_bill_pkg_tax_location hashrefs
  my %tax_location = ();

  # keys are taxlisthash keys (internal identifiers)
  # values are listrefs of cust_bill_pkg_tax_rate_location hashrefs
  my %tax_rate_location = ();

  foreach my $tax ( keys %$taxlisthash ) {
    my $tax_object = shift @{ $taxlisthash->{$tax} };
    warn "found ". $tax_object->taxname. " as $tax\n" if $DEBUG > 2;
    warn " ". join('/', @{ $taxlisthash->{$tax} } ). "\n" if $DEBUG > 2;
    my $hashref_or_error =
      $tax_object->taxline( $taxlisthash->{$tax},
                            'custnum'      => $self->custnum,
                            'invoice_time' => $invoice_time
                          );
    return $hashref_or_error unless ref($hashref_or_error);

    unshift @{ $taxlisthash->{$tax} }, $tax_object;

    my $name   = $hashref_or_error->{'name'};
    my $amount = $hashref_or_error->{'amount'};

    #warn "adding $amount as $name\n";
    $taxname{ $name } ||= [];
    push @{ $taxname{ $name } }, $tax;

    $tax{ $tax } += $amount;

    $tax_location{ $tax } ||= [];
    if ( $tax_object->get('pkgnum') || $tax_object->get('locationnum') ) {
      push @{ $tax_location{ $tax }  },
        {
          'taxnum'      => $tax_object->taxnum, 
          'taxtype'     => ref($tax_object),
          'pkgnum'      => $tax_object->get('pkgnum'),
          'locationnum' => $tax_object->get('locationnum'),
          'amount'      => sprintf('%.2f', $amount ),
        };
    }

    $tax_rate_location{ $tax } ||= [];
    if ( ref($tax_object) eq 'FS::tax_rate' ) {
      my $taxratelocationnum =
        $tax_object->tax_rate_location->taxratelocationnum;
      push @{ $tax_rate_location{ $tax }  },
        {
          'taxnum'             => $tax_object->taxnum, 
          'taxtype'            => ref($tax_object),
          'amount'             => sprintf('%.2f', $amount ),
          'locationtaxid'      => $tax_object->location,
          'taxratelocationnum' => $taxratelocationnum,
        };
    }

  }

  #move the cust_tax_exempt_pkg records to the cust_bill_pkgs we will commit
  my %packagemap = map { $_->pkgnum => $_ } @$cust_bill_pkg;
  foreach my $tax ( keys %$taxlisthash ) {
    foreach ( @{ $taxlisthash->{$tax} }[1 ... scalar(@{ $taxlisthash->{$tax} })] ) {
      next unless ref($_) eq 'FS::cust_bill_pkg';
     
      my @cust_tax_exempt_pkg = splice( @{ $_->_cust_tax_exempt_pkg } );

      next unless @cust_tax_exempt_pkg; #just avoiding the prob when irrelevant?
      die "can't distribute tax exemptions: no line item for ".  Dumper($_).
          " in packagemap ". join(',', sort {$a<=>$b} keys %packagemap). "\n"
        unless $packagemap{$_->pkgnum};

      push @{ $packagemap{$_->pkgnum}->_cust_tax_exempt_pkg },
           @cust_tax_exempt_pkg;
    }
  }

  #consolidate and create tax line items
  warn "consolidating and generating...\n" if $DEBUG > 2;
  foreach my $taxname ( keys %taxname ) {
    my $tax = 0;
    my %seen = ();
    my @cust_bill_pkg_tax_location = ();
    my @cust_bill_pkg_tax_rate_location = ();
    warn "adding $taxname\n" if $DEBUG > 1;
    foreach my $taxitem ( @{ $taxname{$taxname} } ) {
      next if $seen{$taxitem}++;
      warn "adding $tax{$taxitem}\n" if $DEBUG > 1;
      $tax += $tax{$taxitem};
      push @cust_bill_pkg_tax_location,
        map { new FS::cust_bill_pkg_tax_location $_ }
            @{ $tax_location{ $taxitem } };
      push @cust_bill_pkg_tax_rate_location,
        map { new FS::cust_bill_pkg_tax_rate_location $_ }
            @{ $tax_rate_location{ $taxitem } };
    }
    next unless $tax;

    $tax = sprintf('%.2f', $tax );
  
    my $pkg_category = qsearchs( 'pkg_category', { 'categoryname' => $taxname,
                                                   'disabled'     => '',
                                                 },
                               );

    my @display = ();
    if ( $pkg_category and
         $conf->config('invoice_latexsummary') ||
         $conf->config('invoice_htmlsummary')
       )
    {

      my %hash = (  'section' => $pkg_category->categoryname );
      push @display, new FS::cust_bill_pkg_display { type => 'S', %hash };

    }

    push @tax_line_items, new FS::cust_bill_pkg {
      'pkgnum'   => 0,
      'setup'    => $tax,
      'recur'    => 0,
      'sdate'    => '',
      'edate'    => '',
      'itemdesc' => $taxname,
      'display'  => \@display,
      'cust_bill_pkg_tax_location' => \@cust_bill_pkg_tax_location,
      'cust_bill_pkg_tax_rate_location' => \@cust_bill_pkg_tax_rate_location,
    };

  }

  \@tax_line_items;
}

sub _make_lines {
  my ($self, %params) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my $part_pkg = $params{part_pkg} or die "no part_pkg specified";
  my $cust_pkg = $params{cust_pkg} or die "no cust_pkg specified";
  my $precommit_hooks = $params{precommit_hooks} or die "no package specified";
  my $cust_bill_pkgs = $params{line_items} or die "no line buffer specified";
  my $total_setup = $params{setup} or die "no setup accumulator specified";
  my $total_recur = $params{recur} or die "no recur accumulator specified";
  my $taxlisthash = $params{tax_matrix} or die "no tax accumulator specified";
  my $time = $params{'time'} or die "no time specified";
  my (%options) = %{$params{options}};

  if ( $part_pkg->freq ne '1' and ($options{'freq_override'} || 0) > 0 ) {
    # this should never happen
    die 'freq_override billing attempted on non-monthly package '.
      $cust_pkg->pkgnum;
  }

  my $dbh = dbh;
  my $real_pkgpart = $params{real_pkgpart};
  my %hash = $cust_pkg->hash;
  my $old_cust_pkg = new FS::cust_pkg \%hash;

  my @details = ();
  my $lineitems = 0;

  $cust_pkg->pkgpart($part_pkg->pkgpart);

  ###
  # bill setup
  ###

  my $setup = 0;
  my $unitsetup = 0;
  my @setup_discounts = ();
  my %setup_param = ( 'discounts' => \@setup_discounts );
  if (     ! $options{recurring_only}
       and ! $options{cancel}
       and ( $options{'resetup'}
             || ( ! $cust_pkg->setup
                  && ( ! $cust_pkg->start_date
                       || $cust_pkg->start_date <= day_end($time)
                     )
                  && ( ! $conf->exists('disable_setup_suspended_pkgs')
                       || ( $conf->exists('disable_setup_suspended_pkgs') &&
                            ! $cust_pkg->getfield('susp')
                          )
                     )
                )
           )
     )
  {
    
    warn "    bill setup\n" if $DEBUG > 1;

    unless ( $cust_pkg->waive_setup ) {
        $lineitems++;

        $setup = eval { $cust_pkg->calc_setup( $time, \@details, \%setup_param ) };
        return "$@ running calc_setup for $cust_pkg\n"
          if $@;

        $unitsetup = $cust_pkg->part_pkg->unit_setup || $setup; #XXX uuh
    }

    $cust_pkg->setfield('setup', $time)
      unless $cust_pkg->setup;
          #do need it, but it won't get written to the db
          #|| $cust_pkg->pkgpart != $real_pkgpart;

    $cust_pkg->setfield('start_date', '')
      if $cust_pkg->start_date;

  }

  ###
  # bill recurring fee
  ### 

  #XXX unit stuff here too
  my $recur = 0;
  my $unitrecur = 0;
  my @recur_discounts = ();
  my $sdate;
  if (     ! $cust_pkg->start_date
       and ( ! $cust_pkg->susp || $part_pkg->option('suspend_bill', 1) )
       and
            ( $part_pkg->freq ne '0' && ( $cust_pkg->bill || 0 ) <= day_end($time) )
         || ( $part_pkg->plan eq 'voip_cdr'
               && $part_pkg->option('bill_every_call')
            )
         || $options{cancel}
  ) {

    # XXX should this be a package event?  probably.  events are called
    # at collection time at the moment, though...
    $part_pkg->reset_usage($cust_pkg, 'debug'=>$DEBUG)
      if $part_pkg->can('reset_usage') && !$options{'no_usage_reset'};
      #don't want to reset usage just cause we want a line item??
      #&& $part_pkg->pkgpart == $real_pkgpart;

    warn "    bill recur\n" if $DEBUG > 1;
    $lineitems++;

    # XXX shared with $recur_prog
    $sdate = ( $options{cancel} ? $cust_pkg->last_bill : $cust_pkg->bill )
             || $cust_pkg->setup
             || $time;

    #over two params!  lets at least switch to a hashref for the rest...
    my $increment_next_bill = ( $part_pkg->freq ne '0'
                                && ( $cust_pkg->getfield('bill') || 0 ) <= day_end($time)
                                && !$options{cancel}
                              );
    my %param = ( %setup_param,
                  'precommit_hooks'     => $precommit_hooks,
                  'increment_next_bill' => $increment_next_bill,
                  'discounts'           => \@recur_discounts,
                  'real_pkgpart'        => $real_pkgpart,
                  'freq_override'	=> $options{freq_override} || '',
                  'setup_fee'           => 0,
                );

    my $method = $options{cancel} ? 'calc_cancel' : 'calc_recur';

    # There may be some part_pkg for which this is wrong.  Only those
    # which can_discount are supported.
    # (the UI should prevent adding discounts to these at the moment)

    warn "calling $method on cust_pkg ". $cust_pkg->pkgnum.
         " for pkgpart ". $cust_pkg->pkgpart.
         " with params ". join(' / ', map "$_=>$param{$_}", keys %param). "\n"
      if $DEBUG > 2;
           
    $recur = eval { $cust_pkg->$method( \$sdate, \@details, \%param ) };
    return "$@ running $method for $cust_pkg\n"
      if ( $@ );

    if ( $increment_next_bill ) {

      my $next_bill = $part_pkg->add_freq($sdate, $options{freq_override} || 0);
      return "unparsable frequency: ". $part_pkg->freq
        if $next_bill == -1;
  
      #pro-rating magic - if $recur_prog fiddled $sdate, want to use that
      # only for figuring next bill date, nothing else, so, reset $sdate again
      # here
      $sdate = $cust_pkg->bill || $cust_pkg->setup || $time;
      #no need, its in $hash{last_bill}# my $last_bill = $cust_pkg->last_bill;
      $cust_pkg->last_bill($sdate);

      $cust_pkg->setfield('bill', $next_bill );

    }

    if ( $param{'setup_fee'} ) {
      # Add an additional setup fee at the billing stage.
      # Used for prorate_defer_bill.
      $setup += $param{'setup_fee'};
      $unitsetup += $param{'setup_fee'};
      $lineitems++;
    }

    if ( defined $param{'discount_left_setup'} ) {
        foreach my $discount_setup ( values %{$param{'discount_left_setup'}} ) {
            $setup -= $discount_setup;
        }
    }

  }

  warn "\$setup is undefined" unless defined($setup);
  warn "\$recur is undefined" unless defined($recur);
  warn "\$cust_pkg->bill is undefined" unless defined($cust_pkg->bill);
  
  ###
  # If there's line items, create em cust_bill_pkg records
  # If $cust_pkg has been modified, update it (if we're a real pkgpart)
  ###

  if ( $lineitems ) {

    if ( $cust_pkg->modified && $cust_pkg->pkgpart == $real_pkgpart ) {
      # hmm.. and if just the options are modified in some weird price plan?
  
      warn "  package ". $cust_pkg->pkgnum. " modified; updating\n"
        if $DEBUG >1;
  
      my $error = $cust_pkg->replace( $old_cust_pkg,
                                      'depend_jobnum'=>$options{depend_jobnum},
                                      'options' => { $cust_pkg->options },
                                    )
        unless $options{no_commit};
      return "Error modifying pkgnum ". $cust_pkg->pkgnum. ": $error"
        if $error; #just in case
    }
  
    $setup = sprintf( "%.2f", $setup );
    $recur = sprintf( "%.2f", $recur );
    if ( $setup < 0 && ! $conf->exists('allow_negative_charges') ) {
      return "negative setup $setup for pkgnum ". $cust_pkg->pkgnum;
    }
    if ( $recur < 0 && ! $conf->exists('allow_negative_charges') ) {
      return "negative recur $recur for pkgnum ". $cust_pkg->pkgnum;
    }

    my $discount_show_always = $conf->exists('discount-show-always')
                               && (    ($setup == 0 && scalar(@setup_discounts))
                                    || ($recur == 0 && scalar(@recur_discounts))
                                  );

    if (    $setup != 0
         || $recur != 0
         || (!$part_pkg->hidden && $options{has_hidden}) #include some $0 lines
         || $discount_show_always
         || ($setup == 0 && $cust_pkg->_X_show_zero('setup'))
         || ($recur == 0 && $cust_pkg->_X_show_zero('recur'))
       ) 
    {

      warn "    charges (setup=$setup, recur=$recur); adding line items\n"
        if $DEBUG > 1;

      my @cust_pkg_detail = map { $_->detail } $cust_pkg->cust_pkg_detail('I');
      if ( $DEBUG > 1 ) {
        warn "      adding customer package invoice detail: $_\n"
          foreach @cust_pkg_detail;
      }
      push @details, @cust_pkg_detail;

      my $cust_bill_pkg = new FS::cust_bill_pkg {
        'pkgnum'    => $cust_pkg->pkgnum,
        'setup'     => $setup,
        'unitsetup' => $unitsetup,
        'recur'     => $recur,
        'unitrecur' => $unitrecur,
        'quantity'  => $cust_pkg->quantity,
        'details'   => \@details,
        'discounts' => [ @setup_discounts, @recur_discounts ],
        'hidden'    => $part_pkg->hidden,
        'freq'      => $part_pkg->freq,
      };

      if ( $part_pkg->option('prorate_defer_bill',1) 
           and !$hash{last_bill} ) {
        # both preceding and upcoming, technically
        $cust_bill_pkg->sdate( $cust_pkg->setup );
        $cust_bill_pkg->edate( $cust_pkg->bill );
      } elsif ( $part_pkg->recur_temporality eq 'preceding' ) {
        $cust_bill_pkg->sdate( $hash{last_bill} );
        $cust_bill_pkg->edate( $sdate - 86399   ); #60s*60m*24h-1
        $cust_bill_pkg->edate( $time ) if $options{cancel};
      } else { #if ( $part_pkg->recur_temporality eq 'upcoming' ) {
        $cust_bill_pkg->sdate( $sdate );
        $cust_bill_pkg->edate( $cust_pkg->bill );
        #$cust_bill_pkg->edate( $time ) if $options{cancel};
      }

      $cust_bill_pkg->pkgpart_override($part_pkg->pkgpart)
        unless $part_pkg->pkgpart == $real_pkgpart;

      $$total_setup += $setup;
      $$total_recur += $recur;

      ###
      # handle taxes
      ###

      unless ( $discount_show_always ) {
	  my $error = 
	    $self->_handle_taxes($part_pkg, $taxlisthash, $cust_bill_pkg, $cust_pkg, $options{invoice_time}, $real_pkgpart, \%options);
	  return $error if $error;
      }

      push @$cust_bill_pkgs, $cust_bill_pkg;

    } #if $setup != 0 || $recur != 0
      
  } #if $line_items

  '';

}

sub _handle_taxes {
  my $self = shift;
  my $part_pkg = shift;
  my $taxlisthash = shift;
  my $cust_bill_pkg = shift;
  my $cust_pkg = shift;
  my $invoice_time = shift;
  my $real_pkgpart = shift;
  my $options = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my %cust_bill_pkg = ();
  my %taxes = ();
    
  my @classes;
  #push @classes, $cust_bill_pkg->usage_classes if $cust_bill_pkg->type eq 'U';
  push @classes, $cust_bill_pkg->usage_classes if $cust_bill_pkg->usage;
  push @classes, 'setup' if ($cust_bill_pkg->setup && !$options->{cancel});
  push @classes, 'recur' if ($cust_bill_pkg->recur && !$options->{cancel});

  if ( $self->tax !~ /Y/i && $self->payby ne 'COMP' ) {

    if ( $conf->exists('enable_taxproducts')
         && ( scalar($part_pkg->part_pkg_taxoverride)
              || $part_pkg->has_taxproduct
            )
       )
    {

      foreach my $class (@classes) {
        my $err_or_ref = $self->_gather_taxes( $part_pkg, $class, $cust_pkg );
        return $err_or_ref unless ref($err_or_ref);
        $taxes{$class} = $err_or_ref;
      }

      unless (exists $taxes{''}) {
        my $err_or_ref = $self->_gather_taxes( $part_pkg, '', $cust_pkg );
        return $err_or_ref unless ref($err_or_ref);
        $taxes{''} = $err_or_ref;
      }

    } else {

      my @loc_keys = qw( district city county state country );
      my %taxhash;
      if ( $conf->exists('tax-pkg_address') && $cust_pkg->locationnum ) {
        my $cust_location = $cust_pkg->cust_location;
        %taxhash = map { $_ => $cust_location->$_()    } @loc_keys;
      } else {
        my $prefix = 
          ( $conf->exists('tax-ship_address') && length($self->ship_last) )
          ? 'ship_'
          : '';
        %taxhash = map { $_ => $self->get("$prefix$_") } @loc_keys;
      }

      $taxhash{'taxclass'} = $part_pkg->taxclass;

      my @taxes = ();
      my %taxhash_elim = %taxhash;
      my @elim = qw( district city county state );
      do { 

        #first try a match with taxclass
        @taxes = qsearch( 'cust_main_county', \%taxhash_elim );

        if ( !scalar(@taxes) && $taxhash_elim{'taxclass'} ) {
          #then try a match without taxclass
          my %no_taxclass = %taxhash_elim;
          $no_taxclass{ 'taxclass' } = '';
          @taxes = qsearch( 'cust_main_county', \%no_taxclass );
        }

        $taxhash_elim{ shift(@elim) } = '';

      } while ( !scalar(@taxes) && scalar(@elim) );

      @taxes = grep { ! $_->taxname or ! $self->tax_exemption($_->taxname) }
                    @taxes
        if $self->cust_main_exemption; #just to be safe

      if ( $conf->exists('tax-pkg_address') && $cust_pkg->locationnum ) {
        foreach (@taxes) {
          $_->set('pkgnum',      $cust_pkg->pkgnum );
          $_->set('locationnum', $cust_pkg->locationnum );
        }
      }

      $taxes{''} = [ @taxes ];
      $taxes{'setup'} = [ @taxes ];
      $taxes{'recur'} = [ @taxes ];
      $taxes{$_} = [ @taxes ] foreach (@classes);

      # # maybe eliminate this entirely, along with all the 0% records
      # unless ( @taxes ) {
      #   return
      #     "fatal: can't find tax rate for state/county/country/taxclass ".
      #     join('/', map $taxhash{$_}, qw(state county country taxclass) );
      # }

    } #if $conf->exists('enable_taxproducts') ...

  }

  #what's this doing in the middle of _handle_taxes?  probably should split
  #this into three parts above in _make_lines
  $cust_bill_pkg->set_display(   part_pkg     => $part_pkg,
                                 real_pkgpart => $real_pkgpart,
                             );

  my %tax_cust_bill_pkg = $cust_bill_pkg->disintegrate;
  foreach my $key (keys %tax_cust_bill_pkg) {
    my @taxes = @{ $taxes{$key} || [] };
    my $tax_cust_bill_pkg = $tax_cust_bill_pkg{$key};

    my %localtaxlisthash = ();
    foreach my $tax ( @taxes ) {

      my $taxname = ref( $tax ). ' '. $tax->taxnum;
#      $taxname .= ' pkgnum'. $cust_pkg->pkgnum.
#                  ' locationnum'. $cust_pkg->locationnum
#        if $conf->exists('tax-pkg_address') && $cust_pkg->locationnum;

      $taxlisthash->{ $taxname } ||= [ $tax ];
      push @{ $taxlisthash->{ $taxname  } }, $tax_cust_bill_pkg;

      $localtaxlisthash{ $taxname } ||= [ $tax ];
      push @{ $localtaxlisthash{ $taxname  } }, $tax_cust_bill_pkg;

    }

    warn "finding taxed taxes...\n" if $DEBUG > 2;
    foreach my $tax ( keys %localtaxlisthash ) {
      my $tax_object = shift @{ $localtaxlisthash{$tax} };
      warn "found possible taxed tax ". $tax_object->taxname. " we call $tax\n"
        if $DEBUG > 2;
      next unless $tax_object->can('tax_on_tax');

      foreach my $tot ( $tax_object->tax_on_tax( $self ) ) {
        my $totname = ref( $tot ). ' '. $tot->taxnum;

        warn "checking $totname which we call ". $tot->taxname. " as applicable\n"
          if $DEBUG > 2;
        next unless exists( $localtaxlisthash{ $totname } ); # only increase
                                                             # existing taxes
        warn "adding $totname to taxed taxes\n" if $DEBUG > 2;
        my $hashref_or_error = 
          $tax_object->taxline( $localtaxlisthash{$tax},
                                'custnum'      => $self->custnum,
                                'invoice_time' => $invoice_time,
                              );
        return $hashref_or_error
          unless ref($hashref_or_error);
        
        $taxlisthash->{ $totname } ||= [ $tot ];
        push @{ $taxlisthash->{ $totname  } }, $hashref_or_error->{amount};

      }
    }

  }

  '';
}

sub _gather_taxes {
  my $self = shift;
  my $part_pkg = shift;
  my $class = shift;
  my $cust_pkg = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my $geocode;
  if ( $cust_pkg->locationnum && $conf->exists('tax-pkg_address') ) {
    $geocode = $cust_pkg->cust_location->geocode('cch');
  } else {
    $geocode = $self->geocode('cch');
  }

  my @taxes = ();

  my @taxclassnums = map { $_->taxclassnum }
                     $part_pkg->part_pkg_taxoverride($class);

  unless (@taxclassnums) {
    @taxclassnums = map { $_->taxclassnum }
                    grep { $_->taxable eq 'Y' }
                    $part_pkg->part_pkg_taxrate('cch', $geocode, $class);
  }
  warn "Found taxclassnum values of ". join(',', @taxclassnums)
    if $DEBUG;

  my $extra_sql =
    "AND (".
    join(' OR ', map { "taxclassnum = $_" } @taxclassnums ). ")";

  @taxes = qsearch({ 'table' => 'tax_rate',
                     'hashref' => { 'geocode' => $geocode, },
                     'extra_sql' => $extra_sql,
                  })
    if scalar(@taxclassnums);

  warn "Found taxes ".
       join(',', map{ ref($_). " ". $_->get($_->primary_key) } @taxes). "\n" 
   if $DEBUG;

  [ @taxes ];

}

=item collect [ HASHREF | OPTION => VALUE ... ]

(Attempt to) collect money for this customer's outstanding invoices (see
L<FS::cust_bill>).  Usually used after the bill method.

Actions are now triggered by billing events; see L<FS::part_event> and the
billing events web interface.  Old-style invoice events (see
L<FS::part_bill_event>) have been deprecated.

If there is an error, returns the error, otherwise returns false.

Options are passed as name-value pairs.

Currently available options are:

=over 4

=item invoice_time

Use this time when deciding when to print invoices and late notices on those invoices.  The default is now.  It is specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.

=item retry

Retry card/echeck/LEC transactions even when not scheduled by invoice events.

=item check_freq

"1d" for the traditional, daily events (the default), or "1m" for the new monthly events (part_event.check_freq)

=item quiet

set true to surpress email card/ACH decline notices.

=item debug

Debugging level.  Default is 0 (no debugging), or can be set to 1 (passed-in options), 2 (traces progress), 3 (more information), or 4 (include full search queries)

=back

# =item payby
#
# allows for one time override of normal customer billing method

=cut

sub collect {
  my( $self, %options ) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my $invoice_time = $options{'invoice_time'} || time;

  #put below somehow?
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  if ( $DEBUG ) {
    my $balance = $self->balance;
    warn "$me collect customer ". $self->custnum. ": balance $balance\n"
  }

  if ( exists($options{'retry_card'}) ) {
    carp 'retry_card option passed to collect is deprecated; use retry';
    $options{'retry'} ||= $options{'retry_card'};
  }
  if ( exists($options{'retry'}) && $options{'retry'} ) {
    my $error = $self->retry_realtime;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  #never want to roll back an event just because it returned an error
  local $FS::UID::AutoCommit = 1; #$oldAutoCommit;

  $self->do_cust_event(
    'debug'      => ( $options{'debug'} || 0 ),
    'time'       => $invoice_time,
    'check_freq' => $options{'check_freq'},
    'stage'      => 'collect',
  );

}

=item retry_realtime

Schedules realtime / batch  credit card / electronic check / LEC billing
events for for retry.  Useful if card information has changed or manual
retry is desired.  The 'collect' method must be called to actually retry
the transaction.

Implementation details: For either this customer, or for each of this
customer's open invoices, changes the status of the first "done" (with
statustext error) realtime processing event to "failed".

=cut

sub retry_realtime {
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

  #a little false laziness w/due_cust_event (not too bad, really)

  my $join = FS::part_event_condition->join_conditions_sql;
  my $order = FS::part_event_condition->order_conditions_sql;
  my $mine = 
  '( '
   . join ( ' OR ' , map { 
    my $cust_join = FS::part_event->eventtables_cust_join->{$_} || '';
    my $custnum = FS::part_event->eventtables_custnum->{$_};
    "( part_event.eventtable = " . dbh->quote($_) 
    . " AND tablenum IN( SELECT " . dbdef->table($_)->primary_key 
    . " from $_ $cust_join"
    . " where $custnum = " . dbh->quote( $self->custnum ) . "))" ;
   } FS::part_event->eventtables)
   . ') ';

  #here is the agent virtualization
  my $agent_virt = " (    part_event.agentnum IS NULL
                       OR part_event.agentnum = ". $self->agentnum. ' )';

  #XXX this shouldn't be hardcoded, actions should declare it...
  my @realtime_events = qw(
    cust_bill_realtime_card
    cust_bill_realtime_check
    cust_bill_realtime_lec
    cust_bill_batch
  );

  my $is_realtime_event = ' ( '. join(' OR ', map "part_event.action = '$_'",
                                                  @realtime_events
                                     ).
                          ' ) ';

  my @cust_event = qsearch({
    'table'     => 'cust_event',
    'select'    => 'cust_event.*',
    'addl_from' => "LEFT JOIN part_event USING ( eventpart ) $join",
    'hashref'   => { 'status' => 'done' },
    'extra_sql' => " AND statustext IS NOT NULL AND statustext != '' ".
                   " AND $mine AND $is_realtime_event AND $agent_virt $order" # LIMIT 1"
  });

  my %seen_invnum = ();
  foreach my $cust_event (@cust_event) {

    #max one for the customer, one for each open invoice
    my $cust_X = $cust_event->cust_X;
    next if $seen_invnum{ $cust_event->part_event->eventtable eq 'cust_bill'
                          ? $cust_X->invnum
                          : 0
                        }++
         or $cust_event->part_event->eventtable eq 'cust_bill'
            && ! $cust_X->owed;

    my $error = $cust_event->retry;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error scheduling event for retry: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item do_cust_event [ HASHREF | OPTION => VALUE ... ]

Runs billing events; see L<FS::part_event> and the billing events web
interface.

If there is an error, returns the error, otherwise returns false.

Options are passed as name-value pairs.

Currently available options are:

=over 4

=item time

Use this time when deciding when to print invoices and late notices on those invoices.  The default is now.  It is specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.

=item check_freq

"1d" for the traditional, daily events (the default), or "1m" for the new monthly events (part_event.check_freq)

=item stage

"collect" (the default) or "pre-bill"

=item quiet
 
set true to surpress email card/ACH decline notices.

=item debug

Debugging level.  Default is 0 (no debugging), or can be set to 1 (passed-in options), 2 (traces progress), 3 (more information), or 4 (include full search queries)

=back
=cut

# =item payby
#
# allows for one time override of normal customer billing method

# =item retry
#
# Retry card/echeck/LEC transactions even when not scheduled by invoice events.

sub do_cust_event {
  my( $self, %options ) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my $time = $options{'time'} || time;

  #put below somehow?
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  if ( $DEBUG ) {
    my $balance = $self->balance;
    warn "$me do_cust_event customer ". $self->custnum. ": balance $balance\n"
  }

#  if ( exists($options{'retry_card'}) ) {
#    carp 'retry_card option passed to collect is deprecated; use retry';
#    $options{'retry'} ||= $options{'retry_card'};
#  }
#  if ( exists($options{'retry'}) && $options{'retry'} ) {
#    my $error = $self->retry_realtime;
#    if ( $error ) {
#      $dbh->rollback if $oldAutoCommit;
#      return $error;
#    }
#  }

  # false laziness w/pay_batch::import_results

  my $due_cust_event = $self->due_cust_event(
    'debug'      => ( $options{'debug'} || 0 ),
    'time'       => $time,
    'check_freq' => $options{'check_freq'},
    'stage'      => ( $options{'stage'} || 'collect' ),
  );
  unless( ref($due_cust_event) ) {
    $dbh->rollback if $oldAutoCommit;
    return $due_cust_event;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  #never want to roll back an event just because it or a different one
  # returned an error
  local $FS::UID::AutoCommit = 1; #$oldAutoCommit;

  foreach my $cust_event ( @$due_cust_event ) {

    #XXX lock event
    
    #re-eval event conditions (a previous event could have changed things)
    unless ( $cust_event->test_conditions ) {
      #don't leave stray "new/locked" records around
      my $error = $cust_event->delete;
      return $error if $error;
      next;
    }

    {
      local $FS::cust_main::Billing_Realtime::realtime_bop_decline_quiet = 1
        if $options{'quiet'};
      warn "  running cust_event ". $cust_event->eventnum. "\n"
        if $DEBUG > 1;

      #if ( my $error = $cust_event->do_event(%options) ) { #XXX %options?
      if ( my $error = $cust_event->do_event( 'time' => $time ) ) {
        #XXX wtf is this?  figure out a proper dealio with return value
        #from do_event
        return $error;
      }
    }

  }

  '';

}

=item due_cust_event [ HASHREF | OPTION => VALUE ... ]

Inserts database records for and returns an ordered listref of new events due
for this customer, as FS::cust_event objects (see L<FS::cust_event>).  If no
events are due, an empty listref is returned.  If there is an error, returns a
scalar error message.

To actually run the events, call each event's test_condition method, and if
still true, call the event's do_event method.

Options are passed as a hashref or as a list of name-value pairs.  Available
options are:

=over 4

=item check_freq

Search only for events of this check frequency (how often events of this type are checked); currently "1d" (daily, the default) and "1m" (monthly) are recognized.

=item stage

"collect" (the default) or "pre-bill"

=item time

"Current time" for the events.

=item debug

Debugging level.  Default is 0 (no debugging), or can be set to 1 (passed-in options), 2 (traces progress), 3 (more information), or 4 (include full search queries)

=item eventtable

Only return events for the specified eventtable (by default, events of all eventtables are returned)

=item objects

Explicitly pass the objects to be tested (typically used with eventtable).

=item testonly

Set to true to return the objects, but not actually insert them into the
database.

=back

=cut

sub due_cust_event {
  my $self = shift;
  my %opt = ref($_[0]) ? %{ $_[0] } : @_;

  #???
  #my $DEBUG = $opt{'debug'}
  local($DEBUG) = $opt{'debug'}
    if defined($opt{'debug'}) && $opt{'debug'} > $DEBUG;
  $DEBUG = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  warn "$me due_cust_event called with options ".
       join(', ', map { "$_: $opt{$_}" } keys %opt). "\n"
    if $DEBUG;

  $opt{'time'} ||= time;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update #mutex
    unless $opt{testonly};

  ###
  # find possible events (initial search)
  ###
  
  my @cust_event = ();

  my @eventtable = $opt{'eventtable'}
                     ? ( $opt{'eventtable'} )
                     : FS::part_event->eventtables_runorder;

  my $check_freq = $opt{'check_freq'} || '1d';

  foreach my $eventtable ( @eventtable ) {

    my @objects;
    if ( $opt{'objects'} ) {

      @objects = @{ $opt{'objects'} };

    } elsif ( $eventtable eq 'cust_main' ) {

      @objects = ( $self );

    } else {

      my $cm_join = " LEFT JOIN cust_main USING ( custnum )";
      # linkage not needed here because FS::cust_main->$eventtable will 
      # already supply it

      #some false laziness w/Cron::bill bill_where

      my $join  = FS::part_event_condition->join_conditions_sql( $eventtable);
      my $where = FS::part_event_condition->where_conditions_sql($eventtable,
        'time'=>$opt{'time'},
      );
      $where = $where ? "AND $where" : '';

      my $are_part_event = 
      "EXISTS ( SELECT 1 FROM part_event $join
        WHERE check_freq = '$check_freq'
        AND eventtable = '$eventtable'
        AND ( disabled = '' OR disabled IS NULL )
        $where
        )
      ";
      #eofalse

      @objects = $self->$eventtable(
        'addl_from' => $cm_join,
        'extra_sql' => " AND $are_part_event",
      );
    } # if ( !$opt{objects} and $eventtable ne 'cust_main' )

    my @e_cust_event = ();

    my $linkage = FS::part_event->eventtables_cust_join->{$eventtable} || '';

    my $cross = "CROSS JOIN $eventtable $linkage";
    $cross .= ' LEFT JOIN cust_main USING ( custnum )'
      unless $eventtable eq 'cust_main';

    foreach my $object ( @objects ) {

      #this first search uses the condition_sql magic for optimization.
      #the more possible events we can eliminate in this step the better

      my $cross_where = '';
      my $pkey = $object->primary_key;
      $cross_where = "$eventtable.$pkey = ". $object->$pkey();

      my $join = FS::part_event_condition->join_conditions_sql( $eventtable );
      my $extra_sql =
        FS::part_event_condition->where_conditions_sql( $eventtable,
                                                        'time'=>$opt{'time'}
                                                      );
      my $order = FS::part_event_condition->order_conditions_sql( $eventtable );

      $extra_sql = "AND $extra_sql" if $extra_sql;

      #here is the agent virtualization
      $extra_sql .= " AND (    part_event.agentnum IS NULL
                            OR part_event.agentnum = ". $self->agentnum. ' )';

      $extra_sql .= " $order";

      warn "searching for events for $eventtable ". $object->$pkey. "\n"
        if $opt{'debug'} > 2;
      my @part_event = qsearch( {
        'debug'     => ( $opt{'debug'} > 3 ? 1 : 0 ),
        'select'    => 'part_event.*',
        'table'     => 'part_event',
        'addl_from' => "$cross $join",
        'hashref'   => { 'check_freq' => $check_freq,
                         'eventtable' => $eventtable,
                         'disabled'   => '',
                       },
        'extra_sql' => "AND $cross_where $extra_sql",
      } );

      if ( $DEBUG > 2 ) {
        my $pkey = $object->primary_key;
        warn "      ". scalar(@part_event).
             " possible events found for $eventtable ". $object->$pkey(). "\n";
      }

      push @e_cust_event, map { 
        $_->new_cust_event($object, 'time' => $opt{'time'}) 
      } @part_event;

    }

    warn "    ". scalar(@e_cust_event).
         " subtotal possible cust events found for $eventtable\n"
      if $DEBUG > 1;

    push @cust_event, @e_cust_event;

  }

  warn "  ". scalar(@cust_event).
       " total possible cust events found in initial search\n"
    if $DEBUG; # > 1;


  ##
  # test stage
  ##

  $opt{stage} ||= 'collect';
  @cust_event =
    grep { my $stage = $_->part_event->event_stage;
           $opt{stage} eq $stage or ( ! $stage && $opt{stage} eq 'collect' )
         }
         @cust_event;

  ##
  # test conditions
  ##
  
  my %unsat = ();

  @cust_event = grep $_->test_conditions( 'stats_hashref' => \%unsat ),
                     @cust_event;

  warn "  ". scalar(@cust_event). " cust events left satisfying conditions\n"
    if $DEBUG; # > 1;

  warn "    invalid conditions not eliminated with condition_sql:\n".
       join('', map "      $_: ".$unsat{$_}."\n", keys %unsat )
    if keys %unsat && $DEBUG; # > 1;

  ##
  # insert
  ##

  unless( $opt{testonly} ) {
    foreach my $cust_event ( @cust_event ) {

      my $error = $cust_event->insert();
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
                                       
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ##
  # return
  ##

  warn "  returning events: ". Dumper(@cust_event). "\n"
    if $DEBUG > 2;

  \@cust_event;

}

=item apply_payments_and_credits [ OPTION => VALUE ... ]

Applies unapplied payments and credits.

In most cases, this new method should be used in place of sequential
apply_payments and apply_credits methods.

A hash of optional arguments may be passed.  Currently "manual" is supported.
If true, a payment receipt is sent instead of a statement when
'payment_receipt_email' configuration option is set.

If there is an error, returns the error, otherwise returns false.

=cut

sub apply_payments_and_credits {
  my( $self, %options ) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  foreach my $cust_bill ( $self->open_cust_bill ) {
    my $error = $cust_bill->apply_payments_and_credits(%options);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error applying: $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item apply_credits OPTION => VALUE ...

Applies (see L<FS::cust_credit_bill>) unapplied credits (see L<FS::cust_credit>)
to outstanding invoice balances in chronological order (or reverse
chronological order if the I<order> option is set to B<newest>) and returns the
value of any remaining unapplied credits available for refund (see
L<FS::cust_refund>).

Dies if there is an error.

=cut

sub apply_credits {
  my $self = shift;
  my %opt = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  unless ( $self->total_unapplied_credits ) {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return 0;
  }

  my @credits = sort { $b->_date <=> $a->_date} (grep { $_->credited > 0 }
      qsearch('cust_credit', { 'custnum' => $self->custnum } ) );

  my @invoices = $self->open_cust_bill;
  @invoices = sort { $b->_date <=> $a->_date } @invoices
    if defined($opt{'order'}) && $opt{'order'} eq 'newest';

  if ( $conf->exists('pkg-balances') ) {
    # limit @credits to those w/ a pkgnum grepped from $self
    my %pkgnums = ();
    foreach my $i (@invoices) {
      foreach my $li ( $i->cust_bill_pkg ) {
        $pkgnums{$li->pkgnum} = 1;
      }
    }
    @credits = grep { ! $_->pkgnum || $pkgnums{$_->pkgnum} } @credits;
  }

  my $credit;

  foreach my $cust_bill ( @invoices ) {

    if ( !defined($credit) || $credit->credited == 0) {
      $credit = pop @credits or last;
    }

    my $owed;
    if ( $conf->exists('pkg-balances') && $credit->pkgnum ) {
      $owed = $cust_bill->owed_pkgnum($credit->pkgnum);
    } else {
      $owed = $cust_bill->owed;
    }
    unless ( $owed > 0 ) {
      push @credits, $credit;
      next;
    }

    my $amount = min( $credit->credited, $owed );
    
    my $cust_credit_bill = new FS::cust_credit_bill ( {
      'crednum' => $credit->crednum,
      'invnum'  => $cust_bill->invnum,
      'amount'  => $amount,
    } );
    $cust_credit_bill->pkgnum( $credit->pkgnum )
      if $conf->exists('pkg-balances') && $credit->pkgnum;
    my $error = $cust_credit_bill->insert;
    if ( $error ) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }
    
    redo if ($cust_bill->owed > 0) && ! $conf->exists('pkg-balances');

  }

  my $total_unapplied_credits = $self->total_unapplied_credits;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return $total_unapplied_credits;
}

=item apply_payments  [ OPTION => VALUE ... ]

Applies (see L<FS::cust_bill_pay>) unapplied payments (see L<FS::cust_pay>)
to outstanding invoice balances in chronological order.

 #and returns the value of any remaining unapplied payments.

A hash of optional arguments may be passed.  Currently "manual" is supported.
If true, a payment receipt is sent instead of a statement when
'payment_receipt_email' configuration option is set.

Dies if there is an error.

=cut

sub apply_payments {
  my( $self, %options ) = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->select_for_update; #mutex

  #return 0 unless

  my @payments = sort { $b->_date <=> $a->_date }
                 grep { $_->unapplied > 0 }
                 $self->cust_pay;

  my @invoices = sort { $a->_date <=> $b->_date}
                 grep { $_->owed > 0 }
                 $self->cust_bill;

  if ( $conf->exists('pkg-balances') ) {
    # limit @payments to those w/ a pkgnum grepped from $self
    my %pkgnums = ();
    foreach my $i (@invoices) {
      foreach my $li ( $i->cust_bill_pkg ) {
        $pkgnums{$li->pkgnum} = 1;
      }
    }
    @payments = grep { ! $_->pkgnum || $pkgnums{$_->pkgnum} } @payments;
  }

  my $payment;

  foreach my $cust_bill ( @invoices ) {

    if ( !defined($payment) || $payment->unapplied == 0 ) {
      $payment = pop @payments or last;
    }

    my $owed;
    if ( $conf->exists('pkg-balances') && $payment->pkgnum ) {
      $owed = $cust_bill->owed_pkgnum($payment->pkgnum);
    } else {
      $owed = $cust_bill->owed;
    }
    unless ( $owed > 0 ) {
      push @payments, $payment;
      next;
    }

    my $amount = min( $payment->unapplied, $owed );

    my $cbp = {
      'paynum' => $payment->paynum,
      'invnum' => $cust_bill->invnum,
      'amount' => $amount,
    };
    $cbp->{_date} = $payment->_date 
        if $options{'manual'} && $options{'backdate_application'};
    my $cust_bill_pay = new FS::cust_bill_pay($cbp);
    $cust_bill_pay->pkgnum( $payment->pkgnum )
      if $conf->exists('pkg-balances') && $payment->pkgnum;
    my $error = $cust_bill_pay->insert(%options);
    if ( $error ) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }

    redo if ( $cust_bill->owed > 0) && ! $conf->exists('pkg-balances');

  }

  my $total_unapplied_payments = $self->total_unapplied_payments;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return $total_unapplied_payments;
}

=back

=head1 FLOW

  bill_and_collect

    cancel_expired_pkgs
    suspend_adjourned_pkgs
    unsuspend_resumed_pkgs

    bill
      (do_cust_event pre-bill)
      _make_lines
        _handle_taxes
          (vendor-only) _gather_taxes
      _omit_zero_value_bundles
      calculate_taxes

    apply_payments_and_credits
    collect
      do_cust_event
        due_cust_event

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::cust_main::Billing_Realtime>

=cut

1;
