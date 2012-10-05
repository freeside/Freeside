package FS::cust_main::NationalID;

use strict;
use vars qw( $conf );
use Date::Simple qw( days_in_month );
use FS::UID;

install_callback FS::UID sub { 
  $conf = new FS::Conf;
};

sub set_national_id_from_cgi {
  my( $self, $cgi ) = @_;

  my $error = '';

  if ( my $id_country = $conf->config('national_id-country') ) {
    if ( $id_country eq 'MY' ) {
  
      if ( $cgi->param('national_id1') =~ /\S/ ) {
        my $nric = $cgi->param('national_id1');
        $nric =~ s/\s//g;
        if ( $nric =~ /^(\d{2})(\d{2})(\d{2})\-?(\d{2})\-?(\d{4})$/ ) {
          my( $y, $m, $d, $bp, $n ) = ( $1, $2, $3, $4, $5 );
          $self->national_id( "$y$m$d-$bp-$n" );
  
          my @lt = localtime(time);
          my $year = ( $y <= substr( $lt[5]+1900, -2) ) ? 2000 + $y
                                                        : 1900 + $y;
          $error ||= "Illegal NRIC: ". $cgi->param('national_id1')
            if $m < 1 || $m > 12 || $d < 1 || $d > days_in_month($year, $m);
            #$bp validation per http://en.wikipedia.org/wiki/National_Registration_Identity_Card_Number_%28Malaysia%29#Second_section:_Birthplace ?  seems like a bad idea, some could be missing or get added
        } else {
          $error ||= "Illegal NRIC: ". $cgi->param('national_id1');
        }
      } elsif ( $cgi->param('national_id2') =~ /\S/ ) {
        my $oldic = $cgi->param('national_id2');
        $oldic =~ s/\s//g;

        # can you please remove validation for "Old IC/Passport:" field, customer
        # will have other field format like, RF/123456, I/5234234 ...
        #if ( $oldic =~ /^\w\d{9}$/ ) {
          $self->national_id($oldic);
        #} else {
        #  $error ||= "Illegal Old IC/Passport: ". $cgi->param('national_id2');
        #}

      } else {
        $error ||= 'Either NRIC or Old IC/Passport is required';
      }
      
    } else {
      warn "unknown national_id-country $id_country";
    }
  } elsif ( $cgi->param('national_id0') ) {
    $self->national_id( $cgi->param('national_id0') );
  }

  $error;

}

1;

