package FS::h_Common;

use strict;
use FS::Record qw(dbdef);
use Carp qw(confess);

=head1 NAME

FS::h_Common - History table "mixin" common base class

=head1 SYNOPSIS

package FS::h_tablename;
@ISA = qw( FS::h_Common FS::tablename ); 

sub table { 'h_table_name'; }

sub insert { return "can't insert history records manually"; }
sub delete { return "can't delete history records"; }
sub replace { return "can't modify history records"; }

=head1 DESCRIPTION

FS::h_Common is intended as a "mixin" base class for history table classes to
inherit from.

=head1 METHODS

=over 4

=item sql_h_search END_TIMESTAMP [ START_TIMESTAMP ] 

Returns an a list consisting of the "SELECT", "EXTRA_SQL", SQL fragments, a
placeholder for "CACHE_OBJ" and an "AS" SQL fragment, to search for the
appropriate history records created before END_TIMESTAMP and (optionally) not
deleted before START_TIMESTAMP.

=cut

sub sql_h_search {
  my( $self, $end ) = ( shift, shift );

  my $table = $self->table;
  my $real_table = ($table =~ /^h_(.*)$/) ? $1 : $table;
  my $pkey = dbdef->table($real_table)->primary_key
    or die "can't (yet) search history table $real_table without a primary key";

  unless ($end) {
    confess 'Called sql_h_search without END_TIMESTAMP';
  }

  my( $notdeleted, $notdeleted_mr ) = ( '', '' );
  if ( scalar(@_) && $_[0] ) {
    $notdeleted =
      "AND NOT EXISTS ( SELECT 1 FROM $table as notdel
                          WHERE notdel.$pkey = maintable.$pkey
                            AND notdel.history_action = 'delete'
                            AND notdel.history_date > maintable.history_date
                            AND notdel.history_date <= $_[0]
                      )";
    $notdeleted_mr =
      "AND NOT EXISTS ( SELECT 1 FROM $table as notdel_mr
                          WHERE notdel_mr.$pkey = mostrecent.$pkey
                            AND notdel_mr.history_action = 'delete'
                            AND notdel_mr.history_date > mostrecent.history_date
                            AND notdel_mr.history_date <= $_[0]
                      )";
  }

  (
    #"DISTINCT ON ( $pkey ) *",
    "*",

    "AND history_date <= $end
     AND (    history_action = 'insert'
           OR history_action = 'replace_new'
         )
     $notdeleted
     AND history_date = ( SELECT MAX(mostrecent.history_date)
                            FROM $table AS mostrecent
                            WHERE mostrecent.$pkey = maintable.$pkey
			      AND mostrecent.history_date <= $end
			      AND (    mostrecent.history_action = 'insert'
			            OR mostrecent.history_action = 'replace_new'
				  )
			      $notdeleted_mr
                        )

     ORDER BY $pkey ASC",
     #ORDER BY $pkey ASC, history_date DESC",

     '',

     'AS maintable',
  );

}

=item sql_h_searchs END_TIMESTAMP [ START_TIMESTAMP ] 

Like sql_h_search, but limited to the single most recent record (before
END_TIMESTAMP)

=cut

sub sql_h_searchs {
  my $self = shift;
  my($select, $where, $cacheobj, $as) = $self->sql_h_search(@_);
  $where .= ' LIMIT 1';
  ($select, $where, $cacheobj, $as);
}

=item sql_diff START_TIMESTAMP, END_TIMESTAMP[, WHERE]

Returns a complete SQL statement to find all records that were changed 
between START_TIMESTAMP and END_TIMESTAMP. This finds only replacements,
not new or deleted records.

For each modified record, this will return I<one> row (not two rows as in
the history table) with the primary key of the record, "old_historynum"
(the historynum of the last modification before START_TIMESTAMP), and
"new_historynum" (the last modification before END_TIMESTAMP). Join these
back to the h_* table to retrieve the actual field values.

Within the query, the last history records as of START and END are aliased
as "old" and "new"; you can append a WHERE clause to take advantage of this.

=cut

sub sql_diff {
  my $class = shift;
  my $table = $class->table;
  my ($real_table) = ($table =~ /^h_(\w+)$/);
  my $pkey = dbdef->table($real_table)->primary_key;
  my @fields = "FS::$real_table"->fields;

  my ($sdate, $edate) = @_;
  ($sdate, $edate) = ($edate, $sdate) if $edate < $sdate;

  my @select = (
    "old.$pkey",
    'old.historynum   AS old_historynum',
    'new.historynum   AS new_historynum',
  );
  my $new = 
    "SELECT DISTINCT ON ($pkey) * FROM $table
      WHERE history_action = 'replace_new'
        AND history_date >= $sdate AND history_date <  $edate
      ORDER BY $pkey ASC, history_date DESC";
  my $old =
    "SELECT DISTINCT ON ($pkey) * FROM $table
      WHERE (history_action = 'replace_new' OR history_action = 'insert')
        AND history_date <  $sdate
      ORDER BY $pkey ASC, history_date DESC";

  my $from = "($new) AS new JOIN ($old) AS old USING ($pkey)";

  return "SELECT ".join(',', @select)." FROM $from";
}


=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation

=cut

1;

