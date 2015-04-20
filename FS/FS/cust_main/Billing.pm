package FS::cust_main::Billing;

use strict;
use vars qw( $conf $DEBUG $me );
use Carp;
use Data::Dumper;
use List::Util qw( min );
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs dbdef );
use FS::Misc::DateTime qw( day_end );
use Tie::RefHash;
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
use FS::FeeOrigin_Mixin;
use FS::Log;
use FS::TaxEngine;

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

  my $log = FS::Log->new('FS::cust_main::Billing::bill_and_collect');
  my %logopt = (object => $self);
  $log->debug('start', %logopt);

  my $error;

  #$options{actual_time} not $options{time} because freeside-daily -d is for
  #pre-printing invoices

  $options{'actual_time'} ||= time;
  my $job = $options{'job'};

  my $actual_time = ( $conf->exists('next-bill-ignore-time')
                        ? day_end( $options{actual_time} )
                        : $options{actual_time}
                    );

  $job->update_statustext('0,cleaning expired packages') if $job;
  $log->debug('canceling expired packages', %logopt);
  $error = $self->cancel_expired_pkgs( $actual_time );
  if ( $error ) {
    $error = "Error expiring custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $log->debug('suspending adjourned packages', %logopt);
  $error = $self->suspend_adjourned_pkgs( $actual_time );
  if ( $error ) {
    $error = "Error adjourning custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $log->debug('unsuspending resumed packages', %logopt);
  $error = $self->unsuspend_resumed_pkgs( $actual_time );
  if ( $error ) {
    $error = "Error resuming custnum ".$self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $job->update_statustext('20,billing packages') if $job;
  $log->debug('billing packages', %logopt);
  $error = $self->bill( %options );
  if ( $error ) {
    $error = "Error billing custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  $job->update_statustext('50,applying payments and credits') if $job;
  $log->debug('applying payments and credits', %logopt);
  $error = $self->apply_payments_and_credits;
  if ( $error ) {
    $error = "Error applying custnum ". $self->custnum. ": $error";
    if    ( $options{fatal} && $options{fatal} eq 'return' ) { return $error; }
    elsif ( $options{fatal}                                ) { die    $error; }
    else                                                     { warn   $error; }
  }

  # In a batch tax environment, do not run collection if any pending 
  # invoices were created.  Collection will run after the next tax batch.
  my $tax = FS::TaxEngine->new;
  if ( $tax->info->{batch} and 
       qsearch('cust_bill', { custnum => $self->custnum, pending => 'Y' })
     )
  {
    warn "skipped collection for custnum ".$self->custnum.
         " due to pending invoices\n" if $DEBUG;
  } elsif ( $conf->exists('cancelled_cust-noevents')
             && ! $self->num_ncancelled_pkgs )
  {
    warn "skipped collection for custnum ".$self->custnum.
         " because they have no active packages\n" if $DEBUG;
  } else {
    # run collection normally
    $job->update_statustext('70,running collection events') if $job;
    $log->debug('running collection events', %logopt);
    $error = $self->collect( %options );
    if ( $error ) {
      $error = "Error collecting custnum ". $self->custnum. ": $error";
      if    ($options{fatal} && $options{fatal} eq 'return') { return $error; }
      elsif ($options{fatal}                               ) { die    $error; }
      else                                                   { warn   $error; }
    }
  }

  $job->update_statustext('100,finished') if $job;
  $log->debug('finish', %logopt);

  '';

}

sub cancel_expired_pkgs {
  my ( $self, $time, %options ) = @_;
  
  my @cancel_pkgs = $self->ncancelled_pkgs( { 
    'extra_sql' => " AND expire IS NOT NULL AND expire > 0 AND expire <= $time "
  } );

  my @errors = ();

  CUST_PKG: foreach my $cust_pkg ( @cancel_pkgs ) {
    my $cpr = $cust_pkg->last_cust_pkg_reason('expire');
    my $error;

    if ( $cust_pkg->change_to_pkgnum ) {

      my $new_pkg = FS::cust_pkg->by_key($cust_pkg->change_to_pkgnum);
      if ( !$new_pkg ) {
        push @errors, 'can\'t change pkgnum '.$cust_pkg->pkgnum.' to pkgnum '.
                      $cust_pkg->change_to_pkgnum.'; not expiring';
        next CUST_PKG;
      }
      $error = $cust_pkg->change( 'cust_pkg'        => $new_pkg,
                                  'unprotect_svcs'  => 1 );
      $error = '' if ref $error eq 'FS::cust_pkg';

    } else { # just cancel it
       $error = $cust_pkg->cancel($cpr ? ( 'reason'        => $cpr->reasonnum,
                                           'reason_otaker' => $cpr->otaker,
                                           'time'          => $time,
                                         )
                                       : ()
                                 );
    }
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

=item no_prepaid

Do not bill prepaid packages.  Used by freeside-daily.

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

=item estimate

Boolean value; indicates that this is an estimate rather than a "tax invoice".
This will be passed through to the tax engine, as online tax services 
sometimes need to know it for reporting purposes. Otherwise it has no effect.

=item invoice_terms

Optional terms to be printed on this invoice.  Otherwise, customer-specific
terms or the default terms are used.

=back

=cut

sub bill {
  my( $self, %options ) = @_;

  return '' if $self->complimentary eq 'Y';

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;
  my $log = FS::Log->new('FS::cust_main::Billing::bill');
  my %logopt = (object => $self);

  $log->debug('start', %logopt);
  warn "$me bill customer ". $self->custnum. "\n"
    if $DEBUG;

  my $time = $options{'time'} || time;
  my $invoice_time = $options{'invoice_time'} || $time;

  my $cmp_time = ( $conf->exists('next-bill-ignore-time')
                     ? day_end( $time )
                     : $time
                 );

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

  $log->debug('acquiring lock', %logopt);
  warn "$me acquiring lock on customer ". $self->custnum. "\n"
    if $DEBUG;

  $self->select_for_update; #mutex

  $log->debug('running pre-bill events', %logopt);
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

  $log->debug('done running pre-bill events', %logopt);
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

  my @precommit_hooks = ();

  $options{'pkg_list'} ||= [ $self->ncancelled_pkgs ];  #param checks?
  
  my %tax_engines;
  my $tax_is_batch = '';
  foreach (@passes) {
    $tax_engines{$_} = FS::TaxEngine->new(cust_main    => $self,
                                          invoice_time => $invoice_time,
                                          cancel       => $options{cancel},
                                          estimate     => $options{estimate},
                                         );
    $tax_is_batch ||= $tax_engines{$_}->info->{batch};
  }

  foreach my $cust_pkg ( @{ $options{'pkg_list'} } ) {

    next if $options{'not_pkgpart'}->{$cust_pkg->pkgpart};

    my $part_pkg = $cust_pkg->part_pkg;

    next if $options{'no_prepaid'} && $part_pkg->is_prepaid;

    $log->debug('bill package '. $cust_pkg->pkgnum, %logopt);
    warn "  bill package ". $cust_pkg->pkgnum. "\n" if $DEBUG;

    #? to avoid use of uninitialized value errors... ?
    $cust_pkg->setfield('bill', '')
      unless defined($cust_pkg->bill);
 
    my $real_pkgpart = $cust_pkg->pkgpart;
    my %hash = $cust_pkg->hash;

    # we could implement this bit as FS::part_pkg::has_hidden, but we already
    # suffer from performance issues
    $options{has_hidden} = 0;
    my @part_pkg = $part_pkg->self_and_bill_linked;
    $options{has_hidden} = 1 if ($part_pkg[1] && $part_pkg[1]->hidden);
 
    # if this package was changed from another package,
    # and it hasn't been billed since then,
    # and package balances are enabled,
    if ( $cust_pkg->change_pkgnum
        and $cust_pkg->change_date >= ($cust_pkg->last_bill || 0)
        and $cust_pkg->change_date <  $invoice_time
      and $conf->exists('pkg-balances') )
    {
      # _transfer_balance will also create the appropriate credit
      my @transfer_items = $self->_transfer_balance($cust_pkg);
      # $part_pkg[0] is the "real" part_pkg
      my $pass = ($cust_pkg->no_auto || $part_pkg[0]->no_auto) ? 
                  'no_auto' : '';
      push @{ $cust_bill_pkg{$pass} }, @transfer_items;
      # treating this as recur, just because most charges are recur...
      ${$total_recur{$pass}} += $_->recur foreach @transfer_items;

      # currently not considering separate_bill here, as it's for 
      # one-time charges only
    }

    foreach my $part_pkg ( @part_pkg ) {

      $cust_pkg->set($_, $hash{$_}) foreach qw ( setup last_bill bill );

      my $pass = '';
      if ( $cust_pkg->separate_bill ) {
        # if no_auto is also set, that's fine. we just need to not have
        # invoices that are both auto and no_auto, and since the package
        # gets an invoice all to itself, it will only be one or the other.
        $pass = $cust_pkg->pkgnum;
        if (!exists $cust_bill_pkg{$pass}) { # it may not exist yet
          push @passes, $pass;
          $total_setup{$pass} = do { my $z = 0; \$z };
          $total_recur{$pass} = do { my $z = 0; \$z };
          # it also needs its own tax context
          $tax_engines{$pass} = FS::TaxEngine->new(
                                  cust_main    => $self,
                                  invoice_time => $invoice_time,
                                  cancel       => $options{cancel},
                                  estimate     => $options{estimate},
                                );
          $cust_bill_pkg{$pass} = [];
        }
      } elsif ( ($cust_pkg->no_auto || $part_pkg->no_auto) ) {
        $pass = 'no_auto';
      }

      my $next_bill = $cust_pkg->getfield('bill') || 0;
      my $error;
      # let this run once if this is the last bill upon cancellation
      while ( $next_bill <= $cmp_time or $options{cancel} ) {
        $error =
          $self->_make_lines( 'part_pkg'            => $part_pkg,
                              'cust_pkg'            => $cust_pkg,
                              'precommit_hooks'     => \@precommit_hooks,
                              'line_items'          => $cust_bill_pkg{$pass},
                              'setup'               => $total_setup{$pass},
                              'recur'               => $total_recur{$pass},
                              'tax_engine'          => $tax_engines{$pass},
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

  foreach my $pass (@passes) { # keys %cust_bill_pkg )

    my @cust_bill_pkg = _omit_zero_value_bundles(@{ $cust_bill_pkg{$pass} });

    warn "$me billing pass $pass\n"
           #.Dumper(\@cust_bill_pkg)."\n"
      if $DEBUG > 2;

    ###
    # process fees
    ###

    my @pending_fees = FS::FeeOrigin_Mixin->by_cust($self->custnum,
      hashref => { 'billpkgnum' => '' }
    );
    warn "$me found pending fees:\n".Dumper(\@pending_fees)."\n"
      if @pending_fees and $DEBUG > 1;

    # determine whether to generate an invoice
    my $generate_bill = scalar(@cust_bill_pkg) > 0;

    foreach my $fee (@pending_fees) {
      $generate_bill = 1 unless $fee->nextbill;
    }
    
    # don't create an invoice with no line items, or where the only line 
    # items are fees that are supposed to be held until the next invoice
    next if !$generate_bill;

    # calculate fees...
    my @fee_items;
    foreach my $fee_origin (@pending_fees) {
      my $part_fee = $fee_origin->part_fee;

      # check whether the fee is applicable before doing anything expensive:
      #
      # if the fee def belongs to a different agent, don't charge the fee.
      # event conditions should prevent this, but just in case they don't,
      # skip the fee.
      if ( $part_fee->agentnum and $part_fee->agentnum != $self->agentnum ) {
        warn "tried to charge fee#".$part_fee->feepart .
             " on customer#".$self->custnum." from a different agent.\n";
        next;
      }
      # also skip if it's disabled
      next if $part_fee->disabled eq 'Y';

      # Decide which invoice to base the fee on.
      my $cust_bill = $fee_origin->cust_bill;
      if (!$cust_bill) {
        # Then link it to the current invoice. This isn't the real cust_bill
        # object that will be inserted--in particular there are no taxes yet.
        # If you want to charge a fee on the total invoice amount including
        # taxes, you have to put the fee on the next invoice.
        $cust_bill = FS::cust_bill->new({
            'custnum'       => $self->custnum,
            'cust_bill_pkg' => \@cust_bill_pkg,
            'charged'       => ${ $total_setup{$pass} } +
                               ${ $total_recur{$pass} },
        });

        # If the origin is for a specific package, then only apply the fee to
        # line items from that package.
        if ( my $cust_pkg = $fee_origin->cust_pkg ) {
          my @charge_fee_on_item;
          my $charge_fee_on_amount = 0;
          foreach (@cust_bill_pkg) {
            if ($_->pkgnum == $cust_pkg->pkgnum) {
              push @charge_fee_on_item, $_;
              $charge_fee_on_amount += $_->setup + $_->recur;
            }
          }
          $cust_bill->set('cust_bill_pkg', \@charge_fee_on_item);
          $cust_bill->set('charged', $charge_fee_on_amount);
        }

      } # $cust_bill is now set
      # calculate the fee
      my $fee_item = $part_fee->lineitem($cust_bill) or next;
      # link this so that we can clear the marker on inserting the line item
      $fee_item->set('fee_origin', $fee_origin);
      push @fee_items, $fee_item;

    }
    
    # add fees to the invoice
    foreach my $fee_item (@fee_items) {

      push @cust_bill_pkg, $fee_item;
      ${ $total_setup{$pass} } += $fee_item->setup;
      ${ $total_recur{$pass} } += $fee_item->recur;

      my $part_fee = $fee_item->part_fee;
      my $fee_location = $self->ship_location; # I think?
      
      my $error = $tax_engines{''}->add_sale($fee_item);

      return $error if $error;

    }

    # XXX implementation of fees is supposed to make this go away...
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
                                'tax_engine'          => $tax_engines{$pass},
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

    #add tax adjustments
    #XXX does this work with batch tax engines?
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

    my $balance = $self->balance;

    my $previous_bill = qsearchs({ 'table'     => 'cust_bill',
                                   'hashref'   => { custnum=>$self->custnum },
                                   'extra_sql' => 'ORDER BY _date DESC LIMIT 1',
                                });
    my $previous_balance =
      $previous_bill
        ? ( $previous_bill->billing_balance + $previous_bill->charged )
        : 0;

    $log->debug('creating the new invoice', %logopt);
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
      'pending'             => 'Y', # clear this after doing taxes
    } );

    if (!$options{no_commit}) {
      # probably we ought to insert it as pending, and then rollback
      # without ever un-pending it
      $error = $cust_bill->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit && !$options{no_commit};
        return "can't create invoice for customer #". $self->custnum. ": $error";
      }

    }

    # calculate and append taxes
    if ( ! $tax_is_batch) {
      my $arrayref_or_error = $tax_engines{$pass}->calculate_taxes($cust_bill);

      unless ( ref( $arrayref_or_error ) ) {
        $dbh->rollback if $oldAutoCommit && !$options{no_commit};
        return $arrayref_or_error;
      }

      # or should this be in TaxEngine?
      my $total_tax = 0;
      foreach my $taxline ( @$arrayref_or_error ) {
        $total_tax += $taxline->setup;
        $taxline->set('invnum' => $cust_bill->invnum); # just to be sure
        push @cust_bill_pkg, $taxline; # for return_bill

        if (!$options{no_commit}) {
          my $error = $taxline->insert;
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return $error;
          }
        }

      }

      # add tax to the invoice amount and finalize it
      ${ $total_setup{$pass} } = sprintf('%.2f', ${ $total_setup{$pass} } + $total_tax);
      $charged = sprintf('%.2f', $charged + $total_tax);
      $cust_bill->set('charged', $charged);
      $cust_bill->set('pending', '');

      if (!$options{no_commit}) {
        my $error = $cust_bill->replace;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }

    } # if !$tax_is_batch
      # if it IS batch, then we'll do all this in process_tax_batch

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

sub _make_lines {
  my ($self, %params) = @_;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my $part_pkg = $params{part_pkg} or die "no part_pkg specified";
  my $cust_pkg = $params{cust_pkg} or die "no cust_pkg specified";
  my $cust_location = $cust_pkg->tax_location;
  my $precommit_hooks = $params{precommit_hooks} or die "no precommit_hooks specified";
  my $cust_bill_pkgs = $params{line_items} or die "no line buffer specified";
  my $total_setup = $params{setup} or die "no setup accumulator specified";
  my $total_recur = $params{recur} or die "no recur accumulator specified";
  my $time = $params{'time'} or die "no time specified";
  my (%options) = %{$params{options}};

  my $tax_engine = $params{tax_engine};

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

  my $cmp_time = ( $conf->exists('next-bill-ignore-time')
                     ? day_end( $time )
                     : $time
                 );

  ###
  # bill setup
  ###

  my $setup = 0;
  my $unitsetup = 0;
  my @setup_discounts = ();
  my %setup_param = ( 'discounts'     => \@setup_discounts,
                      'real_pkgpart'  => $params{real_pkgpart}
                    );
  my $setup_billed_currency = '';
  my $setup_billed_amount = 0;
  # Conditions for setting setup date and charging the setup fee:
  # - this is not a recurring-only billing run
  # - and the package is not currently being canceled
  # - and, unless we're specifically told otherwise via 'resetup':
  #   - it doesn't already HAVE a setup date
  #   - or a start date in the future
  #   - and it's not suspended
  #
  # The last condition used to check the "disable_setup_suspended" option but 
  # that's obsolete. We now never set the setup date on a suspended package.
  if (     ! $options{recurring_only}
       and ! $options{cancel}
       and ( $options{'resetup'}
             || ( ! $cust_pkg->setup
                  && ( ! $cust_pkg->start_date
                       || $cust_pkg->start_date <= $cmp_time
                     )
                  && ( ! $cust_pkg->getfield('susp') )
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

        $unitsetup = $cust_pkg->base_setup()
                       || $setup; #XXX uuh

        if ( $setup_param{'billed_currency'} ) {
          $setup_billed_currency = delete $setup_param{'billed_currency'};
          $setup_billed_amount   = delete $setup_param{'billed_amount'};
        }
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

  my $recur = 0;
  my $unitrecur = 0;
  my @recur_discounts = ();
  my $recur_billed_currency = '';
  my $recur_billed_amount = 0;
  my $sdate;
  if (     ! $cust_pkg->start_date
       and 
           ( ! $cust_pkg->susp
               || ( $cust_pkg->susp != $cust_pkg->order_date
                      && (    $cust_pkg->option('suspend_bill',1)
                           || ( $part_pkg->option('suspend_bill', 1)
                                 && ! $cust_pkg->option('no_suspend_bill',1)
                              )
                         )
                  )
               || $cust_pkg->is_status_delay_cancel
           )
       and
            ( $part_pkg->freq ne '0' && ( $cust_pkg->bill || 0 ) <= $cmp_time )
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
                                && ( $cust_pkg->getfield('bill') || 0 ) <= $cmp_time
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

    #base_cancel???
    $unitrecur = $cust_pkg->base_recur( \$sdate ) || $recur; #XXX uuh, better

    if ( $param{'billed_currency'} ) {
      $recur_billed_currency = delete $param{'billed_currency'};
      $recur_billed_amount   = delete $param{'billed_amount'};
    }

    if ( $increment_next_bill ) {

      my $next_bill;

      if ( my $main_pkg = $cust_pkg->main_pkg ) {
        # supplemental package
        # to keep in sync with the main package, simulate billing at 
        # its frequency
        my $main_pkg_freq = $main_pkg->part_pkg->freq;
        my $supp_pkg_freq = $part_pkg->freq;
        my $ratio = $supp_pkg_freq / $main_pkg_freq;
        if ( $ratio != int($ratio) ) {
          # the UI should prevent setting up packages like this, but just
          # in case
          return "supplemental package period is not an integer multiple of main  package period";
        }
        $next_bill = $sdate;
        for (1..$ratio) {
          $next_bill = $part_pkg->add_freq( $next_bill, $main_pkg_freq );
        }

      } else {
        # the normal case
      $next_bill = $part_pkg->add_freq($sdate, $options{freq_override} || 0);
      return "unparsable frequency: ". $part_pkg->freq
        if $next_bill == -1;
      }  
  
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
        'pkgnum'                => $cust_pkg->pkgnum,
        'setup'                 => $setup,
        'unitsetup'             => $unitsetup,
        'setup_billed_currency' => $setup_billed_currency,
        'setup_billed_amount'   => $setup_billed_amount,
        'recur'                 => $recur,
        'unitrecur'             => $unitrecur,
        'recur_billed_currency' => $recur_billed_currency,
        'recur_billed_amount'   => $recur_billed_amount,
        'quantity'              => $cust_pkg->quantity,
        'details'               => \@details,
        'discounts'             => [ @setup_discounts, @recur_discounts ],
        'hidden'                => $part_pkg->hidden,
        'freq'                  => $part_pkg->freq,
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
      } else { #if ( $part_pkg->recur_temporality eq 'upcoming' )
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
      
      my $error = $tax_engine->add_sale($cust_bill_pkg);
      return $error if $error;

      $cust_bill_pkg->set_display(
        part_pkg     => $part_pkg,
        real_pkgpart => $real_pkgpart,
      );

      push @$cust_bill_pkgs, $cust_bill_pkg;

    } #if $setup != 0 || $recur != 0
      
  } #if $line_items

  '';

}

=item _transfer_balance TO_PKG [ FROM_PKGNUM ]

Takes one argument, a cust_pkg object that is being billed.  This will 
be called only if the package was created by a package change, and has
not been billed since the package change, and package balance tracking
is enabled.  The second argument can be an alternate package number to 
transfer the balance from; this should not be used externally.

Transfers the balance from the previous package (now canceled) to
this package, by crediting one package and creating an invoice item for 
the other.  Inserts the credit and returns the invoice item (so that it 
can be added to an invoice that's being built).

If the previous package was never billed, and was also created by a package
change, then this will also transfer the balance from I<its> previous 
package, and so on, until reaching a package that either has been billed
or was not created by a package change.

=cut

my $balance_transfer_reason;

sub _transfer_balance {
  my $self = shift;
  my $cust_pkg = shift;
  my $from_pkgnum = shift || $cust_pkg->change_pkgnum;
  my $from_pkg = FS::cust_pkg->by_key($from_pkgnum);

  my @transfers;

  # if $from_pkg is not the first package in the chain, and it was never 
  # billed, walk back
  if ( $from_pkg->change_pkgnum and scalar($from_pkg->cust_bill_pkg) == 0 ) {
    @transfers = $self->_transfer_balance($cust_pkg, $from_pkg->change_pkgnum);
  }

  my $prev_balance = $self->balance_pkgnum($from_pkgnum);
  if ( $prev_balance != 0 ) {
    $balance_transfer_reason ||= FS::reason->new_or_existing(
      'reason' => 'Package balance transfer',
      'type'   => 'Internal adjustment',
      'class'  => 'R'
    );

    my $credit = FS::cust_credit->new({
        'custnum'   => $self->custnum,
        'amount'    => abs($prev_balance),
        'reasonnum' => $balance_transfer_reason->reasonnum,
        '_date'     => $cust_pkg->change_date,
    });

    my $cust_bill_pkg = FS::cust_bill_pkg->new({
        'setup'     => 0,
        'recur'     => abs($prev_balance),
        #'sdate'     => $from_pkg->last_bill, # not sure about this
        #'edate'     => $cust_pkg->change_date,
        'itemdesc'  => $self->mt('Previous Balance, [_1]',
                                 $from_pkg->part_pkg->pkg),
    });

    if ( $prev_balance > 0 ) {
      # credit the old package, charge the new one
      $credit->set('pkgnum', $from_pkgnum);
      $cust_bill_pkg->set('pkgnum', $cust_pkg->pkgnum);
    } else {
      # the reverse
      $credit->set('pkgnum', $cust_pkg->pkgnum);
      $cust_bill_pkg->set('pkgnum', $from_pkgnum);
    }
    my $error = $credit->insert;
    die "error transferring package balance from #".$from_pkgnum.
        " to #".$cust_pkg->pkgnum.": $error\n" if $error;

    push @transfers, $cust_bill_pkg;
  } # $prev_balance != 0

  return @transfers;
}

#### vestigial code ####

=item handle_taxes TAXLISTHASH CUST_BILL_PKG [ OPTIONS ]

This is _handle_taxes.  It's called once for each cust_bill_pkg generated
from _make_lines.

TAXLISTHASH is a hashref shared across the entire invoice.  It looks like 
this:
{
  'cust_main_county 1001' => [ [FS::cust_main_county], ... ],
  'cust_main_county 1002' => [ [FS::cust_main_county], ... ],
}

'cust_main_county' can also be 'tax_rate'.  The first object in the array
is always the cust_main_county or tax_rate identified by the key.

That "..." is a list of FS::cust_bill_pkg objects that will be fed to 
the 'taxline' method to calculate the amount of the tax.  This doesn't
happen until calculate_taxes, though.

OPTIONS may include:
- part_item: a part_pkg or part_fee object to be used as the package/fee 
  definition.
- location: a cust_location to be used as the billing location.
- cancel: true if this package is being billed on cancellation.  This 
  allows tax to be calculated on usage charges only.

If not supplied, part_item will be inferred from the pkgnum or feepart of the
cust_bill_pkg, and location from the pkgnum (or, for fees, the invnum and 
the customer's default service location).

This method will also calculate exemptions for any taxes that apply to the
line item (using the C<set_exemptions> method of L<FS::cust_bill_pkg>) and
attach them.  This is the only place C<set_exemptions> is called in normal
invoice processing.

=cut

sub _handle_taxes {
  my $self = shift;
  my $taxlisthash = shift;
  my $cust_bill_pkg = shift;
  my %options = @_;

  # at this point I realize that we have enough information to infer all this
  # stuff, instead of passing around giant honking argument lists
  my $location = $options{location} || $cust_bill_pkg->tax_location;
  my $part_item = $options{part_item} || $cust_bill_pkg->part_X;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  return if ( $self->payby eq 'COMP' ); #dubious

  if ( $conf->exists('enable_taxproducts')
       && ( scalar($part_item->part_pkg_taxoverride)
            || $part_item->has_taxproduct
          )
     )
    {

    # EXTERNAL TAX RATES (via tax_rate)
    my %cust_bill_pkg = ();
    my %taxes = ();

    my @classes;
    my $usage = $cust_bill_pkg->usage || 0;
    push @classes, $cust_bill_pkg->usage_classes if $usage;
    push @classes, 'setup' if $cust_bill_pkg->setup and !$options{cancel};
    push @classes, 'recur' if ($cust_bill_pkg->recur - $usage)
        and !$options{cancel};
    # that's better--probably don't even need $options{cancel} now
    # but leave it for now, just to be safe
    #
    # About $options{cancel}: This protects against charging per-line or
    # per-customer or other flat-rate surcharges on a package that's being
    # billed on cancellation (which is an out-of-cycle bill and should only
    # have usage charges).  See RT#29443.

    # customer exemption is now handled in the 'taxline' method
    #my $exempt = $conf->exists('cust_class-tax_exempt')
    #               ? ( $self->cust_class ? $self->cust_class->tax : '' )
    #               : $self->tax;
    # standardize this just to be sure
    #$exempt = ($exempt eq 'Y') ? 'Y' : '';
    #
    #if ( !$exempt ) {

    unless (exists $taxes{''}) {
      # unsure what purpose this serves, but last time I deleted something
      # from here just because I didn't see the point, it actually did
      # something important.
      my $err_or_ref = $self->_gather_taxes($part_item, '', $location);
      return $err_or_ref unless ref($err_or_ref);
      $taxes{''} = $err_or_ref;
    }

    # NO DISINTEGRATIONS.
    # my %tax_cust_bill_pkg = $cust_bill_pkg->disintegrate;
    #
    # do not call taxline() with any argument except the entire set of
    # cust_bill_pkgs on an invoice that are eligible for the tax.

    # only calculate exemptions once for each tax rate, even if it's used
    # for multiple classes
    my %tax_seen = ();
 
    foreach my $class (@classes) {
      my $err_or_ref = $self->_gather_taxes($part_item, $class, $location);
      return $err_or_ref unless ref($err_or_ref);
      my @taxes = @$err_or_ref;

      next if !@taxes;

      foreach my $tax ( @taxes ) {

        my $tax_id = ref( $tax ). ' '. $tax->taxnum;
        # $taxlisthash: keys are tax identifiers ('FS::tax_rate 123456').
        # Values are arrayrefs, first the tax object (cust_main_county
        # or tax_rate), then the cust_bill_pkg object that the 
        # tax applies to, then the tax class (setup, recur, usage classnum).
        $taxlisthash->{ $tax_id } ||= [ $tax ];
        push @{ $taxlisthash->{ $tax_id  } }, $cust_bill_pkg, $class;

        # determine any exemptions that apply
        if (!$tax_seen{$tax_id}) {
          $cust_bill_pkg->set_exemptions( $tax, custnum => $self->custnum );
          $tax_seen{$tax_id} = 1;
        }

        # tax on tax will be done later, when we actually create the tax
        # line items

      }
    }

  } else {

    # INTERNAL TAX RATES (cust_main_county)

    # We fetch taxes even if the customer is completely exempt,
    # because we need to record that fact.

    my @loc_keys = qw( district city county state country );
    my %taxhash = map { $_ => $location->$_ } @loc_keys;

    $taxhash{'taxclass'} = $part_item->taxclass;

    warn "taxhash:\n". Dumper(\%taxhash) if $DEBUG > 2;

    my @taxes = (); # entries are cust_main_county objects
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

    foreach (@taxes) {
      my $tax_id = 'cust_main_county '.$_->taxnum;
      $taxlisthash->{$tax_id} ||= [ $_ ];
      $cust_bill_pkg->set_exemptions($_, custnum => $self->custnum);
      push @{ $taxlisthash->{$tax_id} }, $cust_bill_pkg;
    }

  }
  '';
}

=item _gather_taxes PART_ITEM CLASS CUST_LOCATION

Internal method used with vendor-provided tax tables.  PART_ITEM is a part_pkg
or part_fee (which will define the tax eligibility of the product), CLASS is
'setup', 'recur', null, or a C<usage_class> number, and CUST_LOCATION is the 
location where the service was provided (or billed, depending on 
configuration).  Returns an arrayref of L<FS::tax_rate> objects that 
can apply to this line item.

=cut

sub _gather_taxes {
  my $self = shift;
  my $part_item = shift;
  my $class = shift;
  my $location = shift;

  local($DEBUG) = $FS::cust_main::DEBUG if $FS::cust_main::DEBUG > $DEBUG;

  my $geocode = $location->geocode('cch');

  [ $part_item->tax_rates('cch', $geocode, $class) ]

}

#### end vestigial code ####

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

  # I guess this is always as of now?
  my $join = FS::part_event_condition->join_conditions_sql('', 'time' => time);
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

  my $is_realtime_event =
    ' part_event.action IN ( '.
        join(',', map "'$_'", @realtime_events ).
    ' ) ';

  my $batch_or_statustext =
    "( part_event.action = 'cust_bill_batch'
       OR ( statustext IS NOT NULL AND statustext != '' )
     )";


  my @cust_event = qsearch({
    'table'     => 'cust_event',
    'select'    => 'cust_event.*',
    'addl_from' => "LEFT JOIN part_event USING ( eventpart ) $join",
    'hashref'   => { 'status' => 'done' },
    'extra_sql' => " AND $batch_or_statustext ".
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
  $opt{'debug'} ||= 0; # silence some warnings
  local($DEBUG) = $opt{'debug'}
    if $opt{'debug'} > $DEBUG;
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

      my $join  = FS::part_event_condition->join_conditions_sql( $eventtable,
        'time' => $opt{'time'});
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

      my $join = FS::part_event_condition->join_conditions_sql( $eventtable,
        'time' => $opt{'time'});
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

  my @payments = $self->unapplied_cust_pay;

  my @invoices = $self->open_cust_bill;

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
