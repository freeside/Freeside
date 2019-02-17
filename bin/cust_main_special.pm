package cust_main_special;

require 5.006;
use strict;
use vars qw( @ISA $DEBUG $me $conf );
use Safe;
use Carp;
use Data::Dumper;
use Date::Format;
use FS::UID qw( dbh );
use FS::Record qw( qsearchs qsearch );
use FS::payby;
use FS::cust_pkg;
use FS::cust_bill;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pkg_tax_location;
use FS::cust_main_county;
use FS::cust_location;
use FS::tax_rate;
use FS::cust_tax_location;
use FS::part_pkg_taxrate;
use FS::queue;
use FS::part_pkg;

@ISA = qw ( FS::cust_main );

$DEBUG = 0;
$me = '[emergency billing program]';

$conf = new FS::Conf;

=head1 METHODS

=over 4

=item bill OPTIONS

Generates invoices (see L<FS::cust_bill>) for this customer.  Usually used in
conjunction with the collect method by calling B<bill_and_collect>.

If there is an error, returns the error, otherwise returns false.

Options are passed as name-value pairs.  Currently available options are:

=over 4

=item resetup

If set true, re-charges setup fees.

=item time

Bills the customer as if it were that time.  Specified as a UNIX timestamp; see L<perlfunc/"time">).  Also see L<Time::Local> and L<Date::Parse> for conversion functions.  For example:

 use Date::Parse;
 ...
 $cust_main->bill( 'time' => str2time('April 20th, 2001') );

=item pkg_list

An array ref of specific packages (objects) to attempt billing, instead trying all of them.

 $cust_main->bill( pkg_list => [$pkg1, $pkg2] );

=item invoice_time

Used in conjunction with the I<time> option, this option specifies the date of for the generated invoices.  Other calculations, such as whether or not to generate the invoice in the first place, are not affected.

=item backbill

Used to specify the period starting date and preventing normal billing.  Instead all outstanding cdrs/usage are processed as if from the unix timestamp in backbill and without changing the dates in the customer packages.  Useful in those situations when cdrs were not imported before a billing run

=back

=cut

sub bill {
  my( $self, %options ) = @_;

  bless $self, 'cust_main_special';
  return '' if $self->payby eq 'COMP';
  warn "$me backbill usage for customer ". $self->custnum. "\n"
    if $DEBUG;

  my $time = $options{'time'} || time;
  my $invoice_time = $options{'invoice_time'} || $time;

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

  my @cust_bill_pkg = ();

  ###
  # find the packages which are due for billing, find out how much they are
  # & generate invoice database.
  ###

  my( $total_setup, $total_recur, $postal_charge ) = ( 0, 0, 0 );
  my %taxlisthash;
  my @precommit_hooks = ();

  my @cust_pkgs = qsearch('cust_pkg', { 'custnum' => $self->custnum } );
  foreach my $cust_pkg (@cust_pkgs) {

    #NO!! next if $cust_pkg->cancel;  
    next if $cust_pkg->getfield('cancel');  

    warn "  bill package ". $cust_pkg->pkgnum. "\n" if $DEBUG > 1;

    #? to avoid use of uninitialized value errors... ?
    $cust_pkg->setfield('bill', '')
      unless defined($cust_pkg->bill);
 
    #my $part_pkg = $cust_pkg->part_pkg;

    my $real_pkgpart = $cust_pkg->pkgpart;
    my %hash = $cust_pkg->hash;

    foreach my $part_pkg ( $cust_pkg->part_pkg->self_and_bill_linked ) {

      $cust_pkg->set($_, $hash{$_}) foreach qw ( setup last_bill bill );

      my $error =
        $self->_make_lines( 'part_pkg'            => $part_pkg,
                            'cust_pkg'            => $cust_pkg,
                            'precommit_hooks'     => \@precommit_hooks,
                            'line_items'          => \@cust_bill_pkg,
                            'setup'               => \$total_setup,
                            'recur'               => \$total_recur,
                            'tax_matrix'          => \%taxlisthash,
                            'time'                => $time,
                            'options'             => \%options,
                          );
      if ($error) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    } #foreach my $part_pkg

  } #foreach my $cust_pkg

  unless ( @cust_bill_pkg ) { #don't create an invoice w/o line items
    unless ( $options{backbill} ) {
      #but do commit any package date cycling that happened
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    } else {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    }
    return '';
  }

  my $postal_pkg = $self->charge_postal_fee();
  if ( $postal_pkg && !ref( $postal_pkg ) ) {
    $dbh->rollback if $oldAutoCommit;
    return "can't charge postal invoice fee for customer ".
      $self->custnum. ": $postal_pkg";
  }
  if ( !$options{backbill} && $postal_pkg &&
       ( scalar( grep { $_->recur && $_->recur > 0 } @cust_bill_pkg) ||
         !$conf->exists('postal_invoice-recurring_only')
       )
     )
  {
    foreach my $part_pkg ( $postal_pkg->part_pkg->self_and_bill_linked ) {
      my $error =
        $self->_make_lines( 'part_pkg'            => $part_pkg,
                            'cust_pkg'            => $postal_pkg,
                            'precommit_hooks'     => \@precommit_hooks,
                            'line_items'          => \@cust_bill_pkg,
                            'setup'               => \$total_setup,
                            'recur'               => \$total_recur,
                            'tax_matrix'          => \%taxlisthash,
                            'time'                => $time,
                            'options'             => \%options,
                          );
      if ($error) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  warn "having a look at the taxes we found...\n" if $DEBUG > 2;

  # keys are tax names (as printed on invoices / itemdesc )
  # values are listrefs of taxlisthash keys (internal identifiers)
  my %taxname = ();

  # keys are taxlisthash keys (internal identifiers)
  # values are (cumulative) amounts
  my %tax = ();

  # keys are taxlisthash keys (internal identifiers)
  # values are listrefs of cust_bill_pkg_tax_location hashrefs
  my %tax_location = ();

  foreach my $tax ( keys %taxlisthash ) {
    my $tax_object = shift @{ $taxlisthash{$tax} };
    warn "found ". $tax_object->taxname. " as $tax\n" if $DEBUG > 2;
    warn " ". join('/', @{ $taxlisthash{$tax} } ). "\n" if $DEBUG > 2;
    my $hashref_or_error =
      $tax_object->taxline( $taxlisthash{$tax},
                            'custnum'      => $self->custnum,
                            'invoice_time' => $invoice_time
                          );
    unless ( ref($hashref_or_error) ) {
      $dbh->rollback if $oldAutoCommit;
      return $hashref_or_error;
    }
    unshift @{ $taxlisthash{$tax} }, $tax_object;

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

  }

  #move the cust_tax_exempt_pkg records to the cust_bill_pkgs we will commit
  my %packagemap = map { $_->pkgnum => $_ } @cust_bill_pkg;
  foreach my $tax ( keys %taxlisthash ) {
    foreach ( @{ $taxlisthash{$tax} }[1 ... scalar(@{ $taxlisthash{$tax} })] ) {
      next unless ref($_) eq 'FS::cust_bill_pkg';

      push @{ $packagemap{$_->pkgnum}->_cust_tax_exempt_pkg }, 
        splice( @{ $_->_cust_tax_exempt_pkg } );
    }
  }

  #consolidate and create tax line items
  warn "consolidating and generating...\n" if $DEBUG > 2;
  foreach my $taxname ( keys %taxname ) {
    my $tax = 0;
    my %seen = ();
    my @cust_bill_pkg_tax_location = ();
    warn "adding $taxname\n" if $DEBUG > 1;
    foreach my $taxitem ( @{ $taxname{$taxname} } ) {
      next if $seen{$taxitem}++;
      warn "adding $tax{$taxitem}\n" if $DEBUG > 1;
      $tax += $tax{$taxitem};
      push @cust_bill_pkg_tax_location,
        map { new FS::cust_bill_pkg_tax_location $_ }
            @{ $tax_location{ $taxitem } };
    }
    next unless $tax;

    $tax = sprintf('%.2f', $tax );
    $total_setup = sprintf('%.2f', $total_setup+$tax );
  
    push @cust_bill_pkg, new FS::cust_bill_pkg {
      'pkgnum'   => 0,
      'setup'    => $tax,
      'recur'    => 0,
      'sdate'    => '',
      'edate'    => '',
      'itemdesc' => $taxname,
      'cust_bill_pkg_tax_location' => \@cust_bill_pkg_tax_location,
    };

  }

  my $charged = sprintf('%.2f', $total_setup + $total_recur );

  #create the new invoice
  my $cust_bill = new FS::cust_bill ( {
    'custnum' => $self->custnum,
    '_date'   => ( $invoice_time ),
    'charged' => $charged,
  } );
  my $error = $cust_bill->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "can't create invoice for customer #". $self->custnum. ": $error";
  }

  foreach my $cust_bill_pkg ( @cust_bill_pkg ) {
    $cust_bill_pkg->invnum($cust_bill->invnum); 
    my $error = $cust_bill_pkg->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't create invoice line item: $error";
    }
  }
    

  #foreach my $hook ( @precommit_hooks ) { 
  #  eval {
  #    &{$hook}; #($self) ?
  #  };
  #  if ( $@ ) {
  #    $dbh->rollback if $oldAutoCommit;
  #    return "$@ running precommit hook $hook\n";
  #  }
  #}
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error
}


sub _make_lines {
  my ($self, %params) = @_;

  warn "    making lines\n" if $DEBUG > 1;
  my $part_pkg = $params{part_pkg} or die "no part_pkg specified";
  my $cust_pkg = $params{cust_pkg} or die "no cust_pkg specified";
  my $precommit_hooks = $params{precommit_hooks} or die "no package specified";
  my $cust_bill_pkgs = $params{line_items} or die "no line buffer specified";
  my $total_setup = $params{setup} or die "no setup accumulator specified";
  my $total_recur = $params{recur} or die "no recur accumulator specified";
  my $taxlisthash = $params{tax_matrix} or die "no tax accumulator specified";
  my $time = $params{'time'} or die "no time specified";
  my (%options) = %{$params{options}};

  my $dbh = dbh;
  my $real_pkgpart = $cust_pkg->pkgpart;
  my %hash = $cust_pkg->hash;
  my $old_cust_pkg = new FS::cust_pkg \%hash;
  my $backbill = $options{backbill} || 0;

  my @details = ();

  my $lineitems = 0;

  $cust_pkg->pkgpart($part_pkg->pkgpart);

  ###
  # bill setup
  ###

  my $setup = 0;
  my $unitsetup = 0;
  if ( ! $cust_pkg->setup &&
       (
         ( $conf->exists('disable_setup_suspended_pkgs') &&
          ! $cust_pkg->getfield('susp')
        ) || ! $conf->exists('disable_setup_suspended_pkgs')
       )
    || $options{'resetup'}
  ) {
    
    warn "    bill setup\n" if $DEBUG > 1;
    $lineitems++;

    $setup = eval { $cust_pkg->calc_setup( $time, \@details ) };
    return "$@ running calc_setup for $cust_pkg\n"
      if $@;

    $unitsetup = $cust_pkg->part_pkg->unit_setup || $setup; #XXX uuh

    $cust_pkg->setfield('setup', $time)
      unless $cust_pkg->setup;
          #do need it, but it won't get written to the db
          #|| $cust_pkg->pkgpart != $real_pkgpart;

  }

  ###
  # bill recurring fee
  ### 

  #XXX unit stuff here too
  my $recur = 0;
  my $unitrecur = 0;
  my $sdate;
  if ( ! $cust_pkg->getfield('susp') and
           ( $part_pkg->getfield('freq') ne '0' &&
             ( $cust_pkg->getfield('bill') || 0 ) <= $time
           )
        || ( $part_pkg->plan eq 'voip_cdr'
              && $part_pkg->option('bill_every_call')
           )
        || $backbill
  ) {

    # XXX should this be a package event?  probably.  events are called
    # at collection time at the moment, though...
    $part_pkg->reset_usage($cust_pkg, 'debug'=>$DEBUG)
      if $part_pkg->can('reset_usage');
      #don't want to reset usage just cause we want a line item??
      #&& $part_pkg->pkgpart == $real_pkgpart;

    warn "    bill recur\n" if $DEBUG > 1;
    $lineitems++;

    # XXX shared with $recur_prog
    $sdate = $cust_pkg->bill || $cust_pkg->setup || $time;
    $sdate = $cust_pkg->lastbill || $backbill if $backbill;

    #over two params!  lets at least switch to a hashref for the rest...
    my $increment_next_bill = ( $part_pkg->freq ne '0'
                                && ( $cust_pkg->getfield('bill') || 0 ) <= $time
                              );
    my %param = ( 'precommit_hooks'     => $precommit_hooks,
                  'increment_next_bill' => $increment_next_bill,
                );

    $recur = eval { $cust_pkg->calc_recur( \$sdate, \@details, \%param ) };
    return "$@ running calc_recur for $cust_pkg\n"
      if ( $@ );


    warn "details is now: \n" if $DEBUG > 2;
    warn Dumper(\@details) if $DEBUG > 2;

    if ( $increment_next_bill ) {

      my $next_bill = $part_pkg->add_freq($sdate);
      return "unparsable frequency: ". $part_pkg->freq
        if $next_bill == -1;
  
      #pro-rating magic - if $recur_prog fiddled $sdate, want to use that
      # only for figuring next bill date, nothing else, so, reset $sdate again
      # here
      $sdate = $cust_pkg->bill || $cust_pkg->setup || $time;
      $sdate = $cust_pkg->lastbill || $backbill if $backbill;
      #no need, its in $hash{last_bill}# my $last_bill = $cust_pkg->last_bill;
      $cust_pkg->last_bill($sdate);

      $cust_pkg->setfield('bill', $next_bill );

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

    if ( !$backbill && $cust_pkg->modified && $cust_pkg->pkgpart == $real_pkgpart ) {
      # hmm.. and if just the options are modified in some weird price plan?
  
      warn "  package ". $cust_pkg->pkgnum. " modified; updating\n"
        if $DEBUG >1;
  
      my $error = $cust_pkg->replace( $old_cust_pkg,
                                      'options' => { $cust_pkg->options },
                                    );
      return "Error modifying pkgnum ". $cust_pkg->pkgnum. ": $error"
        if $error; #just in case
    }
  
    my @cust_pkg_detail = map { $_->detail } $cust_pkg->cust_pkg_detail('I');
    if ( $DEBUG > 1 ) {
      warn "      tentatively adding customer package invoice detail: $_\n"
        foreach @cust_pkg_detail;
    }
    push @details, @cust_pkg_detail;

    $setup = sprintf( "%.2f", $setup );
    $recur = sprintf( "%.2f", $recur );
    my $cust_bill_pkg = new FS::cust_bill_pkg {
      'pkgnum'    => $cust_pkg->pkgnum,
      'setup'     => $setup,
      'unitsetup' => $unitsetup,
      'recur'     => $recur,
      'unitrecur' => $unitrecur,
      'quantity'  => $cust_pkg->quantity,
      'details'   => \@details,
    };

    warn "created cust_bill_pkg which looks like:\n" if $DEBUG > 2;
    warn Dumper($cust_bill_pkg) if $DEBUG > 2;
    if ($backbill) {
      my %usage_cust_bill_pkg = $cust_bill_pkg->disintegrate;
      $recur = 0;
      foreach my $key (keys %usage_cust_bill_pkg) {
        next if ($key eq 'setup' || $key eq 'recur');
        $recur += $usage_cust_bill_pkg{$key}->recur;
      }
      $setup = 0;
    }

    $setup = sprintf( "%.2f", $setup );
    $recur = sprintf( "%.2f", $recur );
    if ( $setup < 0 && ! $conf->exists('allow_negative_charges') ) {
      return "negative setup $setup for pkgnum ". $cust_pkg->pkgnum;
    }
    if ( $recur < 0 && ! $conf->exists('allow_negative_charges') ) {
      return "negative recur $recur for pkgnum ". $cust_pkg->pkgnum;
    }


    if ( $setup != 0 || $recur != 0 ) {

      warn "    charges (setup=$setup, recur=$recur); adding line items\n"
        if $DEBUG > 1;

      $cust_bill_pkg->setup($setup);
      $cust_bill_pkg->recur($recur);

      warn "cust_bill_pkg now looks like:\n" if $DEBUG > 2;
      warn Dumper($cust_bill_pkg) if $DEBUG > 2;

      if ( $part_pkg->option('recur_temporality', 1) eq 'preceding' ) {
        $cust_bill_pkg->sdate( $hash{last_bill} );
        $cust_bill_pkg->edate( $sdate - 86399   ); #60s*60m*24h-1
      } else { #if ( $part_pkg->option('recur_temporality', 1) eq 'upcoming' ) {
        $cust_bill_pkg->sdate( $sdate );
        $cust_bill_pkg->edate( $cust_pkg->bill );
      }

      $cust_bill_pkg->pkgpart_override($part_pkg->pkgpart)
        unless $part_pkg->pkgpart == $real_pkgpart;

      $$total_setup += $setup;
      $$total_recur += $recur;

      ###
      # handle taxes
      ###

      my $error = 
        $self->_handle_taxes($part_pkg, $taxlisthash, $cust_bill_pkg, $cust_pkg, $options{invoice_time});
      return $error if $error;

      push @$cust_bill_pkgs, $cust_bill_pkg;

    } #if $setup != 0 || $recur != 0
      
  } #if $line_items

  '';

}


sub _gather_taxes {
  my $self = shift;
  my $part_pkg = shift;
  my $class = shift;

  my @taxes = ();
  my $geocode = $self->geocode('cch');

  my @taxclassnums = map { $_->taxclassnum }
                     $part_pkg->part_pkg_taxoverride($class);

  unless (@taxclassnums) {
    @taxclassnums = map { $_->taxclassnum }
                    $part_pkg->part_pkg_taxrate('cch', $geocode, $class);
  }
  warn "Found taxclassnum values of ". join(',', @taxclassnums)
    if $DEBUG;

  my $extra_sql =
    "AND (".
    join(' OR ', map { "taxclassnum = $_" } @taxclassnums ). ")";

  @taxes = grep { ($_->fee  || 0 ) == 0 }   #ignore unit based taxes
           qsearch({ 'table' => 'tax_rate',
                     'hashref' => { 'geocode' => $geocode, },
                     'extra_sql' => $extra_sql,
                  })
    if scalar(@taxclassnums);

  warn "Found taxes ".
       join(',', map{ ref($_). " ". $_->get($_->primary_key) } @taxes). "\n"
   if $DEBUG;

  [ @taxes ];

}


=back


=cut

1;

