#!/usr/bin/perl -w

use strict;

use DBI;
use DBD::Pg;

my $dsn = "dbname=p1";
my $dbh = DBI->connect('dbi:Pg:dbname=p1', undef, undef, { AutoCommit => 1 });

my $buf = 'abcdefghijklmnopqrstuvwxyz' x 400;

my $id = write_blob($dbh, undef, $buf);

my $dat = read_blob($dbh, $id);

print "Done\n";

sub write_blob {
    my ($dbh, $lobj_id, $data) = @_;
    
    # begin transaction
    $dbh->{AutoCommit} = 0;
    
    # Create a new lo if we are not passed an lo object ID.
    unless ($lobj_id) {
	# Create the object.
	$lobj_id = $dbh->func($dbh->{'pg_INV_WRITE'}, 'lo_creat');
    }    

    # Open it to get a file descriptor.
    my $lobj_fd = $dbh->func($lobj_id, $dbh->{'pg_INV_WRITE'}, 'lo_open');

    $dbh->func($lobj_fd, 0, 0, 'lo_lseek');
    
    # Write some data to it.
    my $len = $dbh->func($lobj_fd, $data, length($data), 'lo_write');
    
    die "Errors writing lo\n" if $len != length($data);

    # Close 'er up.
    $dbh->func($lobj_fd, 'lo_close') or die "Problems closing lo object\n";
 
    # end transaction
    $dbh->{AutoCommit} = 1;
    
    return $lobj_id;
}

sub read_blob {
    my ($dbh, $lobj_id) = @_;
    my $data = '';
    my $read_len = 256;
    my $chunk = '';

    # begin transaction
    $dbh->{AutoCommit} = 0;

    my $lobj_fd = $dbh->func($lobj_id, $dbh->{'pg_INV_READ'}, 'lo_open');
    
    $dbh->func($lobj_fd, 0, 0, 'lo_lseek');

    # Pull out all the data.
    while ($dbh->func($lobj_fd, $chunk, $read_len, 'lo_read')) {
	$data .= $chunk;
    }

    $dbh->func($lobj_fd, 'lo_close') or die "Problems closing lo object\n";

    # end transaction
    $dbh->{AutoCommit} = 1;
       
    return $data;
}
