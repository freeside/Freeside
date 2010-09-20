package FS::cust_main::_Marketgear;

use strict;
use vars qw( $DEBUG $me $conf );

$DEBUG = 0;
$me = '[FS::cust_main::_Marketgear]';

install_callback FS::UID sub { 
  $conf = new FS::Conf;
};

sub start_copy_skel {
  my $self = shift;

  return '' unless $conf->config('cust_main-skeleton_tables')
                && $conf->config('cust_main-skeleton_custnum');

  warn "  inserting skeleton records\n"
    if $DEBUG > 1 || $cust_main::DEBUG > 1;

  #'mg_user_preference' => {},
  #'mg_user_indicator_profile.user_indicator_profile_id' => { 'mg_profile_indicator.profile_indicator_id' => { 'mg_profile_details.profile_detail_id' }, },
  #'mg_watchlist_header.watchlist_header_id' => { 'mg_watchlist_details.watchlist_details_id' },
  #'mg_user_grid_header.grid_header_id' => { 'mg_user_grid_details.user_grid_details_id' },
  #'mg_portfolio_header.portfolio_header_id' => { 'mg_portfolio_trades.portfolio_trades_id' => { 'mg_portfolio_trades_positions.portfolio_trades_positions_id' } },
  my @tables = eval(join('\n',$conf->config('cust_main-skeleton_tables')));
  die $@ if $@;

  _copy_skel( 'cust_main',                                 #tablename
              $conf->config('cust_main-skeleton_custnum'), #sourceid
              $self->custnum,                              #destid
              @tables,                                     #child tables
            );
}

#recursive subroutine, not a method
sub _copy_skel {
  my( $table, $sourceid, $destid, %child_tables ) = @_;

  my $primary_key;
  if ( $table =~ /^(\w+)\.(\w+)$/ ) {
    ( $table, $primary_key ) = ( $1, $2 );
  } else {
    my $dbdef_table = dbdef->table($table);
    $primary_key = $dbdef_table->primary_key
      or return "$table has no primary key".
                " (or do you need to run dbdef-create?)";
  }

  warn "  _copy_skel: $table.$primary_key $sourceid to $destid for ".
       join (', ', keys %child_tables). "\n"
    if $DEBUG > 2;

  foreach my $child_table_def ( keys %child_tables ) {

    my $child_table;
    my $child_pkey = '';
    if ( $child_table_def =~ /^(\w+)\.(\w+)$/ ) {
      ( $child_table, $child_pkey ) = ( $1, $2 );
    } else {
      $child_table = $child_table_def;

      $child_pkey = dbdef->table($child_table)->primary_key;
      #  or return "$table has no primary key".
      #            " (or do you need to run dbdef-create?)\n";
    }

    my $sequence = '';
    if ( keys %{ $child_tables{$child_table_def} } ) {

      return "$child_table has no primary key".
             " (run dbdef-create or try specifying it?)\n"
        unless $child_pkey;

      #false laziness w/Record::insert and only works on Pg
      #refactor the proper last-inserted-id stuff out of Record::insert if this
      # ever gets use for anything besides a quick kludge for one customer
      my $default = dbdef->table($child_table)->column($child_pkey)->default;
      $default =~ /^nextval\(\(?'"?([\w\.]+)"?'/i
        or return "can't parse $child_table.$child_pkey default value ".
                  " for sequence name: $default";
      $sequence = $1;

    }
  
    my @sel_columns = grep { $_ ne $primary_key }
                           dbdef->table($child_table)->columns;
    my $sel_columns = join(', ', @sel_columns );

    my @ins_columns = grep { $_ ne $child_pkey } @sel_columns;
    my $ins_columns = ' ( '. join(', ', $primary_key, @ins_columns ). ' ) ';
    my $placeholders = ' ( ?, '. join(', ', map '?', @ins_columns ). ' ) ';

    my $sel_st = "SELECT $sel_columns FROM $child_table".
                 " WHERE $primary_key = $sourceid";
    warn "    $sel_st\n"
      if $DEBUG > 2;
    my $sel_sth = dbh->prepare( $sel_st )
      or return dbh->errstr;
  
    $sel_sth->execute or return $sel_sth->errstr;

    while ( my $row = $sel_sth->fetchrow_hashref ) {

      warn "    selected row: ".
           join(', ', map { "$_=".$row->{$_} } keys %$row ). "\n"
        if $DEBUG > 2;

      my $statement =
        "INSERT INTO $child_table $ins_columns VALUES $placeholders";
      my $ins_sth =dbh->prepare($statement)
          or return dbh->errstr;
      my @param = ( $destid, map $row->{$_}, @ins_columns );
      warn "    $statement: [ ". join(', ', @param). " ]\n"
        if $DEBUG > 2;
      $ins_sth->execute( @param )
        or return $ins_sth->errstr;

      #next unless keys %{ $child_tables{$child_table} };
      next unless $sequence;
      
      #another section of that laziness
      my $seq_sql = "SELECT currval('$sequence')";
      my $seq_sth = dbh->prepare($seq_sql) or return dbh->errstr;
      $seq_sth->execute or return $seq_sth->errstr;
      my $insertid = $seq_sth->fetchrow_arrayref->[0];
  
      # don't drink soap!  recurse!  recurse!  okay!
      my $error =
        _copy_skel( $child_table_def,
                    $row->{$child_pkey}, #sourceid
                    $insertid, #destid
                    %{ $child_tables{$child_table_def} },
                  );
      return $error if $error;

    }

  }

  return '';

}

1;
