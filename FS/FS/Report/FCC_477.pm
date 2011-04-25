package FS::Report::FCC_477;

use strict;
use vars qw( @ISA @upload @download @technology @part2aoption @part2boption );
use FS::Report;
use FS::Record qw( dbh );

@ISA = qw( FS::Report );

=head1 NAME

FS::Report::FCC_477 - Routines for FCC Form 477 reports

=head1 SYNOPSIS

=head1 BUGS

Documentation.

=head1 SEE ALSO

=cut

@upload = qw(
 <200kpbs
 200-768kpbs
 768kbps-1.5mbps
 1.5-3mpbs
 3-6mbps
 6-10mbps
 10-25mbps
 25-100mbps
 >100bmps
);

@download = qw(
 200-768kpbs
 768kbps-1.5mbps
 1.5-3mpbs
 3-6mbps
 6-10mbps
 10-25mbps
 25-100mbps
 >100bmps
);

@technology = (
  'Asymetric xDSL',
  'Symetric xDSL',
  'Other Wireline',
  'Cable Modem',
  'Optical Carrier',
  'Satellite',
  'Terrestrial Fixed Wireless',
  'Terrestrial Mobile Wireless',
  'Electric Power Line',
  'Other Technology',
);

@part2aoption = (
 'LD carrier',
 'owned loops',
 'unswitched UNE loops',
 'UNE-P',
 'UNE-P replacement',
 'FTTP',
 'coax',
 'wireless',
);

@part2boption = (
 'nomadic',
 'copper',
 'FTTP',
 'coax',
 'wireless',
 'other broadband',
);

sub restore_fcc477map {
    my $key = shift;
    FS::Record::scalar_sql('',"select formvalue from fcc477map where formkey = ?",$key);
}

sub save_fcc477map {
    my $key = shift;
    my $value = shift;

    # lame, particularly lack of transactions

    my $sql = "delete from fcc477map where formkey = ?";
    my $sth = dbh->prepare($sql) or die dbh->errstr;
    $sth->execute($key) or die "Error removing FCC 477 form defaults: " . $sth->errstr;

    $sql = "insert into fcc477map (formkey,formvalue) values (?,?)";
    $sth = dbh->prepare($sql) or die dbh->errstr;
    $sth->execute($key,$value) or die "Error setting FCC 477 form defaults: " . $sth->errstr;

    '';
}

sub parse_technology_option {
  my $cgi = shift;
  my $save = shift;
  my @result = ();
  my $i = 0;
  for (my $i = 0; $i < scalar(@technology); $i++) {
    my $value = $cgi->param("part1_technology_option_$i"); #lame
    save_fcc477map("part1_technology_option_$i",$value) 
        if $save && $value =~ /^\d+$/;
    push @result, $value =~ /^\d+$/ ? $value : 0;
  }
  return (@result);
}

1;
