package FS::Misc::prune;

use strict;
use vars qw ( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use FS::Record qw(dbh qsearch);
use FS::cust_credit_refund;
#use FS::cust_credit_bill;
#use FS::cust_bill_pay;
#use FS::cust_pay_refund;

@ISA = qw( Exporter );
@EXPORT_OK = qw( prune_applications );

=head1 NAME

FS::Misc::prune - misc. pruning subroutines

=head1 SYNOPSIS

use FS::Misc::prune qw(prune_applications);

prune_applications();

=item prune_applications OPTION_HASH

Removes applications of credits to refunds in the event that the database
is corrupt and either the credits or refunds are missing (see
L<FS::cust_credit>, L<FS::cust_refund>, and L<FS::cust_credit_refund>).
If the OPTION_HASH contains the element 'dry_run' then a report of
affected records is returned rather than actually deleting the records.

=cut

sub prune_applications {
  my $options = shift;
  my $dbh = dbh;

  local $DEBUG = 1 if exists($options->{debug});

  my $ccr = <<EOW;
    WHERE
         0 = (select count(*) from cust_credit
               where cust_credit_refund.crednum = cust_credit.crednum)
      or 
         0 = (select count(*) from cust_refund
               where cust_credit_refund.refundnum = cust_refund.refundnum)
EOW
  my $ccb = <<EOW;
    WHERE
         0 = (select count(*) from cust_credit
               where cust_credit_bill.crednum = cust_credit.crednum)
      or 
         0 = (select count(*) from cust_bill
               where cust_credit_bill.invnum = cust_bill.invnum)
EOW
  my $cbp = <<EOW;
    WHERE
         0 = (select count(*) from cust_bill
               where cust_bill_pay.invnum = cust_bill.invnum)
      or 
         0 = (select count(*) from cust_pay
               where cust_bill_pay.paynum = cust_pay.paynum)
EOW
  my $cpr = <<EOW;
    WHERE
         0 = (select count(*) from cust_pay
               where cust_pay_refund.paynum = cust_pay.paynum)
      or 
         0 = (select count(*) from cust_refund
               where cust_pay_refund.refundnum = cust_refund.refundnum)
EOW

  my %strays = (
    'cust_credit_refund' => { clause => $ccr,
                              link1  => 'crednum',
                              link2  => 'refundnum',
                            },
#    'cust_credit_bill'   => { clause => $ccb,
#                              link1  => 'crednum',
#                              link2  => 'refundnum',
#                            },
#    'cust_bill_pay'      => { clause => $cbp,
#                              link1  => 'crednum',
#                              link2  => 'refundnum',
#                            },
#    'cust_pay_refund'    => { clause => $cpr,
#                              link1  => 'crednum',
#                              link2  => 'refundnum',
#                            },
  );

  if ( exists($options->{dry_run}) ) {
    my @response = ();
    foreach my $table (keys %strays) {
      my $clause = $strays{$table}->{clause};
      my $link1  = $strays{$table}->{link1};
      my $link2  = $strays{$table}->{link2};
      my @rec = qsearch($table, {}, '', $clause);
      my $keyname = $rec[0]->primary_key if $rec[0];
      foreach (@rec) {
        push @response, "$table " .$_->$keyname . " claims attachment to ".
               "$link1 " . $_->$link1 . " and $link2 " . $_->$link2 . "\n";
      }
    }
    return (@response);
  } else {
    foreach (keys %strays) {
      my $statement = "DELETE FROM $_ " . $strays{$_}->{clause};
      warn $statement if $DEBUG;
      my $sth = $dbh->prepare($statement)
        or die $dbh->errstr;
      $sth->execute
        or die $sth->errstr;
    }
    return ();
  }
}

=back

=head1 BUGS

=cut

1;

