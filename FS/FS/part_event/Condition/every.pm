package FS::part_event::Condition::every;

use strict;
use FS::UID qw( dbh );
use FS::Record qw( qsearch );
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Don't retry failures more often than specified interval"; }

sub option_fields {
  (
    'retry_delay' => { label=>'Retry after', type=>'freq', value=>'1d', },
    'max_tries'   => { label=>'Maximum # of attempts', type=>'text', size=>3, },
  );
}

my %after = (
  'h' =>     3600,
  'd' =>    86400,
  'w' =>   604800,
  'm' =>  2592000, #well, 30 days... presumably people would mostly use d or w
  ''  =>  2592000,
  'y' => 31536000, #well, 365 days...
);

my $sql =
  "SELECT COUNT(*) FROM cust_event WHERE eventpart = ? AND tablenum = ?";

sub condition {
  my($self, $object, %opt) = @_;

  my $obj_pkey = $object->primary_key;
  my $tablenum = $object->$obj_pkey();

  if ( $self->option('max_tries') =~ /^\s*(\d+)\s*$/ ) {
    my $max_tries = $1;
    my $sth = dbh->prepare($sql)
      or die dbh->errstr. " preparing: $sql";
    $sth->execute($self->eventpart, $tablenum)
      or die $sth->errstr. " executing: $sql";
    my $tries = $sth->fetchrow_arrayref->[0];
    return 0 if $tries >= $max_tries;
  }

  my $time = $opt{'time'};
  my $retry_delay = $self->option('retry_delay');
  $retry_delay =~ /^(\d+)([hdwmy]?)$/
    or die "unparsable retry_delay: $retry_delay";
  my $date_after = $time - $1 * $after{$2};

  my $sth = dbh->prepare("$sql AND _date > ?") # AND status = 'failed' "
    or die  dbh->errstr. " preparing: $sql";
  $sth->execute($self->eventpart, $tablenum, $date_after)
    or die $sth->errstr. " executing: $sql";
  ! $sth->fetchrow_arrayref->[0];

}

#sub condition_sql {
#  my( $self, $table ) = @_;
#
#  'true';
#}

1;
