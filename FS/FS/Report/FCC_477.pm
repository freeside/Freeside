package FS::Report::FCC_477;
use base qw( FS::Report );

use strict;
use vars qw( @upload @download @technology @part2aoption @part2boption
             %states
           );
use FS::Record qw( dbh );

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

#from the select at http://www.ffiec.gov/census/default.aspx
%states = (
  '01' => 'ALABAMA (AL)',
  '02' => 'ALASKA (AK)',
  '04' => 'ARIZONA (AZ)',
  '05' => 'ARKANSAS (AR)',
  '06' => 'CALIFORNIA (CA)',
  '08' => 'COLORADO (CO)',

  '09' => 'CONNECTICUT (CT)',
  '10' => 'DELAWARE (DE)',
  '11' => 'DISTRICT OF COLUMBIA (DC)',
  '12' => 'FLORIDA (FL)',
  '13' => 'GEORGIA (GA)',
  '15' => 'HAWAII (HI)',

  '16' => 'IDAHO (ID)',
  '17' => 'ILLINOIS (IL)',
  '18' => 'INDIANA (IN)',
  '19' => 'IOWA (IA)',
  '20' => 'KANSAS (KS)',
  '21' => 'KENTUCKY (KY)',

  '22' => 'LOUISIANA (LA)',
  '23' => 'MAINE (ME)',
  '24' => 'MARYLAND (MD)',
  '25' => 'MASSACHUSETTS (MA)',
  '26' => 'MICHIGAN (MI)',
  '27' => 'MINNESOTA (MN)',

  '28' => 'MISSISSIPPI (MS)',
  '29' => 'MISSOURI (MO)',
  '30' => 'MONTANA (MT)',
  '31' => 'NEBRASKA (NE)',
  '32' => 'NEVADA (NV)',
  '33' => 'NEW HAMPSHIRE (NH)',

  '34' => 'NEW JERSEY (NJ)',
  '35' => 'NEW MEXICO (NM)',
  '36' => 'NEW YORK (NY)',
  '37' => 'NORTH CAROLINA (NC)',
  '38' => 'NORTH DAKOTA (ND)',
  '39' => 'OHIO (OH)',

  '40' => 'OKLAHOMA (OK)',
  '41' => 'OREGON (OR)',
  '42' => 'PENNSYLVANIA (PA)',
  '44' => 'RHODE ISLAND (RI)',
  '45' => 'SOUTH CAROLINA (SC)',
  '46' => 'SOUTH DAKOTA (SD)',

  '47' => 'TENNESSEE (TN)',
  '48' => 'TEXAS (TX)',
  '49' => 'UTAH (UT)',
  '50' => 'VERMONT (VT)',
  '51' => 'VIRGINIA (VA)',
  '53' => 'WASHINGTON (WA)',

  '54' => 'WEST VIRGINIA (WV)',
  '55' => 'WISCONSIN (WI)',
  '56' => 'WYOMING (WY)',
  '72' => 'PUERTO RICO (PR)',
);

sub restore_fcc477map {
  my $key = shift;
  FS::Record::scalar_sql('',"select formvalue from fcc477map where formkey = ?",$key);
}

sub save_fcc477map {
  my $key = shift;
  my $value = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  # lame (should be normal FS::Record access)

  my $sql = "delete from fcc477map where formkey = ?";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute($key) or do {
    warn "WARNING: Error removing FCC 477 form defaults: " . $sth->errstr;
    $dbh->rollback if $oldAutoCommit;
  };

  $sql = "insert into fcc477map (formkey,formvalue) values (?,?)";
  $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute($key,$value) or do {
    warn "WARNING: Error setting FCC 477 form defaults: " . $sth->errstr;
    $dbh->rollback if $oldAutoCommit;
  };

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

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

sub statenum2state {
  my $num = shift;
  $states{$num};
}

#sub statenum2abbr {
#  my $num = shift;
#  $states{$num} =~ /\((\w\w)\)$/ or return '';
#  $1;
#}

1;
