#!/usr/bin/perl

use strict;
use FS::UID qw(adminsuidsetup);
use FS::Record qw(qsearchs qsearch);
use FS::svc_broadband;

my $user = shift or die &usage;
my $dbh = adminsuidsetup($user);

my $fcc_up_speed = "(select part_pkg_fcc_option.optionvalue from part_pkg_fcc_option where fccoptionname = 'broadband_upstream' and pkgpart = cust_pkg.pkgpart) AS fcc477_upstream";
my $fcc_down_speed = "(select part_pkg_fcc_option.optionvalue from part_pkg_fcc_option where fccoptionname = 'broadband_downstream' and pkgpart = cust_pkg.pkgpart) AS fcc477_downstream";
foreach my $rec (qsearch({
	'select'    => 'svc_broadband.*, cust_svc.svcpart, cust_pkg.pkgpart, '.$fcc_up_speed.', '.$fcc_down_speed,
	'table'     => 'svc_broadband',
	'addl_from' => 'LEFT JOIN cust_svc USING ( svcnum ) LEFT JOIN cust_pkg USING ( pkgnum )',
})) {
  $rec->{Hash}->{speed_test_up} = $rec->{Hash}->{speed_up};
  $rec->{Hash}->{speed_test_down} = $rec->{Hash}->{speed_down};
  $rec->{Hash}->{speed_up} = $rec->{Hash}->{fcc477_upstream} * 1000;
  $rec->{Hash}->{speed_down} = $rec->{Hash}->{fcc477_downstream} * 1000;
  $rec->replace();
  warn "Fixing broadband service speeds for service ".$rec->{Hash}->{svcnum}."-".$rec->{Hash}->{description}."\n";
}

warn "Completed fixing broadband service speeds!\n";

exit;

=head1 NAME

move_svc_broadband_speeds

=head1 SYNOPSIS

  move_svc_broadband_speeds.pl [ user ]

=head1 DESCRIPTION

Moves value for speed_down to speed_test_down, speed_up to speed_test_up, 
and sets speed_down, speed_up to matching fcc_477 speeds from package for
all svc_broadband services.

user: freeside username

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_broadband>

=cut