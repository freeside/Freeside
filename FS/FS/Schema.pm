package FS::Schema;

use vars qw(@ISA @EXPORT_OK $DEBUG $setup_hack %dbdef_cache);
use subs qw(reload_dbdef);
use Exporter;
use DBIx::DBSchema 0.40; #0.40 for mysql upgrade fixes
use DBIx::DBSchema::Table;
use DBIx::DBSchema::Column;
use DBIx::DBSchema::Index;

@ISA = qw(Exporter);
@EXPORT_OK = qw( dbdef dbdef_dist reload_dbdef );

$DEBUG = 0;
$me = '[FS::Schema]';

=head1 NAME

FS::Schema - Freeside database schema

=head1 SYNOPSYS

    use FS::Schema qw(dbdef dbdef_dist reload_dbdef);

    $dbdef = reload_dbdef;
    $dbdef = reload_dbdef "/non/standard/filename";
    $dbdef = dbdef;
    $dbdef_dist = dbdef_dist;

=head1 DESCRIPTION

This class represents the database schema.

=head1 METHODS

=over 4

=item reload_dbdef([FILENAME])

Load a database definition (see L<DBIx::DBSchema>), optionally from a
non-default filename.  This command is executed at startup unless
I<$FS::Schema::setup_hack> is true.  Returns a DBIx::DBSchema object.

=cut

sub reload_dbdef {
  my $file = shift;

  unless ( exists $dbdef_cache{$file} ) {
    warn "[debug]$me loading dbdef for $file\n" if $DEBUG;
    $dbdef_cache{$file} = DBIx::DBSchema->load( $file )
      or die "can't load database schema from $file: $DBIx::DBSchema::errstr\n";
  } else {
    warn "[debug]$me re-using cached dbdef for $file\n" if $DEBUG;
  }
  $dbdef = $dbdef_cache{$file};
}

=item dbdef

Returns the current database definition (represents the current database,
assuming it is up-to-date).  See L<DBIx::DBSchema>.

=cut

sub dbdef { $dbdef; }

=item dbdef_dist [ DATASRC ]

Returns the current canoical database definition as defined in this file.

Optionally, pass a DBI data source to enable syntax specific to that database.
Currently, this enables "TYPE=InnoDB" for MySQL databases.

=cut

sub dbdef_dist {
  my $datasrc = @_ ? shift : '';
  
  my $local_options = '';
  if ( $datasrc =~ /^dbi:mysql/i ) {
    $local_options = 'TYPE=InnoDB';
  }

  ###
  # create a dbdef object from the old data structure
  ###

  my $tables_hashref = tables_hashref();

  #turn it into objects
  my $dbdef = new DBIx::DBSchema map {  

    my $tablename = $_;
    my $indexnum = 1;

    my @columns;
    while (@{$tables_hashref->{$tablename}{'columns'}}) {
      #my($name, $type, $null, $length, $default, $local) =
      my @coldef = 
        splice @{$tables_hashref->{$tablename}{'columns'}}, 0, 6;
      my %hash = map { $_ => shift @coldef }
                     qw( name type null length default local );

      #can be removed once we depend on DBIx::DBSchema 0.39;
      $hash{'type'} = 'LONGTEXT'
        if $hash{'type'} =~ /^TEXT$/i && $datasrc =~ /^dbi:mysql/i;

      unless ( defined $hash{'default'} ) {
        warn "$tablename:\n".
             join('', map "$_ => $hash{$_}\n", keys %hash) ;# $stop = <STDIN>;
      }

      push @columns, new DBIx::DBSchema::Column ( \%hash );
    }

    #false laziness w/sub indices in DBIx::DBSchema::DBD (well, sorta)
    #and sub sql_create_table in DBIx::DBSchema::Table (slighty more?)
    my $unique = $tables_hashref->{$tablename}{'unique'};
    warn "missing index for $tablename\n" unless defined $tables_hashref->{$tablename}{'index'};
    my @index  = @{ $tables_hashref->{$tablename}{'index'} };

    # kludge to avoid avoid "BLOB/TEXT column 'statustext' used in key
    #  specification without a key length".
    # better solution: teach DBIx::DBSchema to specify a default length for
    #  MySQL indices on text columns, or just to support an index length at all
    #  so we can pass something in.
    # best solution: eliminate need for this index in cust_main::retry_realtime
    @index = grep { @{$_}[0] ne 'statustext' } @index
      if $datasrc =~ /^dbi:mysql/i;

    my @indices = ();
    push @indices, map {
                         DBIx::DBSchema::Index->new({
                           'name'    => $tablename. $indexnum++,
                           'unique'  => 1,
                           'columns' => $_,
                         });
                       }
                       @$unique;
    push @indices, map {
                         DBIx::DBSchema::Index->new({
                           'name'    => $tablename. $indexnum++,
                           'unique'  => 0,
                           'columns' => $_,
                         });
                       }
                       @index;

    DBIx::DBSchema::Table->new({
      'name'          => $tablename,
      'primary_key'   => $tables_hashref->{$tablename}{'primary_key'},
      'columns'       => \@columns,
      'indices'       => \@indices,
      'local_options' => $local_options,
    });

  } keys %$tables_hashref;

  if ( $DEBUG ) {
    warn "[debug]$me initial dbdef_dist created ($dbdef) with tables:\n";
    warn "[debug]$me   $_\n" foreach $dbdef->tables;
  }
  
  #add radius attributes to svc_acct
  #
  #my($svc_acct)=$dbdef->table('svc_acct');
  # 
  #my($attribute);
  #foreach $attribute (@attributes) {
  #  $svc_acct->addcolumn ( new DBIx::DBSchema::Column (
  #    'radius_'. $attribute,
  #    'varchar',
  #    'NULL',
  #    $char_d,
  #  ));
  #}
  # 
  #foreach $attribute (@check_attributes) {
  #  $svc_acct->addcolumn( new DBIx::DBSchema::Column (
  #    'rc_'. $attribute,
  #    'varchar',
  #    'NULL',
  #    $char_d,
  #  ));
  #}

  my $tables_hashref_torrus = tables_hashref_torrus();

  #create history tables (false laziness w/create-history-tables)
  foreach my $table (
    grep {    ! /^clientapi_session/
           && ! /^h_/
           && ! $tables_hashref_torrus->{$_}
         }
      $dbdef->tables
  ) {
    my $tableobj = $dbdef->table($table)
      or die "unknown table $table";

    my %h_indices = ();

    unless ( $table eq 'cust_event' ) { #others?

      my %indices = $tableobj->indices;
    
      %h_indices = map { 
                         ( "h_$_" =>
                             DBIx::DBSchema::Index->new({
                               'name'    => 'h_'. $indices{$_}->name,
                               'unique'  => 0,
                               'columns' => [ @{$indices{$_}->columns} ],
                             })
                         );
                       }
                       keys %indices;

      $h_indices{"h_${table}_srckey"} =
        DBIx::DBSchema::Index->new({
          'name'    => "h_${table}_srckey",
          'unique'  => 0,
          'columns' => [ 'history_action', #right?
                         $tableobj->primary_key,
                       ],
        });

      $h_indices{"h_${table}_srckey2"} =
         DBIx::DBSchema::Index->new({
           'name'    => "h_${table}_srckey2",
           'unique'  => 0,
           'columns' => [ 'history_date',
                          $tableobj->primary_key,
                        ],
         });

    }

    my $h_tableobj = DBIx::DBSchema::Table->new( {
      'name'          => "h_$table",
      'primary_key'   => 'historynum',
      'indices'       => \%h_indices,
      'local_options' => $local_options,
      'columns'       => [
          DBIx::DBSchema::Column->new( {
            'name'    => 'historynum',
            'type'    => 'serial',
            'null'    => 'NOT NULL',
            'length'  => '',
            'default' => '',
            'local'   => '',
          } ),
          DBIx::DBSchema::Column->new( {
            'name'    => 'history_date',
            'type'    => 'int',
            'null'    => 'NULL',
            'length'  => '',
            'default' => '',
            'local'   => '',
          } ),
          DBIx::DBSchema::Column->new( {
            'name'    => 'history_user',
            'type'    => 'varchar',
            'null'    => 'NOT NULL',
            'length'  => '80',
            'default' => '',
            'local'   => '',
          } ),
          DBIx::DBSchema::Column->new( {
            'name'    => 'history_action',
            'type'    => 'varchar',
            'null'    => 'NOT NULL',
            'length'  => '80',
            'default' => '',
            'local'   => '',
          } ),
          map {
            my $column = $tableobj->column($_);
    
            #clone so as to not disturb the original
            $column = DBIx::DBSchema::Column->new( {
              map { $_ => $column->$_() }
                qw( name type null length default local )
            } );
    
            if ( $column->type =~ /^(\w*)SERIAL$/i ) {
              $column->type(uc($1).'INT');
              $column->null('NULL');
            }
            #$column->default('')
            #  if $column->default =~ /^nextval\(/i;
            #( my $local = $column->local ) =~ s/AUTO_INCREMENT//i;
            #$column->local($local);
            $column;
          } $tableobj->columns
      ],
    } );
    $dbdef->addtable($h_tableobj);
  }

  if ( $datasrc =~ /^dbi:mysql/i ) {

    my $dup_lock_table = DBIx::DBSchema::Table->new( {
      'name'          => 'duplicate_lock',
      'primary_key'   => 'duplocknum',
      'local_options' => $local_options,
      'columns'       => [
        DBIx::DBSchema::Column->new( {
          'name'    => 'duplocknum',
          'type'    => 'serial',
          'null'    => 'NOT NULL',
          'length'  => '',
          'default' => '',
          'local'   => '',
        } ),
        DBIx::DBSchema::Column->new( {
          'name'    => 'lockname',
          'type'    => 'varchar',
          'null'    => 'NOT NULL',
          'length'  => '80',
          'default' => '',
          'local'   => '',
        } ),
      ],
      'indices' => { 'duplicate_lock1' =>
                       DBIx::DBSchema::Index->new({
                         'name'    => 'duplicate_lock1',
                         'unique'  => 1,
                         'columns' => [ 'lockname' ],
                       })
                   },
    } );

    $dbdef->addtable($dup_lock_table);

  }

  $dbdef;

}

#torrus tables http://torrus.org/reporting_setup.pod.html#create_sql_tables
sub tables_hashref_torrus {

  return {

    # Collector export table. It usually grows at several megabytes
    # per month, and is updated every 5 minutes
    'srvexport' => {
      'columns' => [
        'id',         'serial', '', '', '', '',
        'srv_date',     'date', '', '', '', '',#date and time of the data sample
        'srv_time',     'time', '', '', '', '',
        'serviceid', 'varchar', '', 64, '', '',#unique service ID per counter
        'value',     'double precision', '', '', '', '',#collected rate or gauge value
        'intvl', 'int', '', '', '', '', # collection interval - for counter volume calculation
      ],
      'primary_key' => 'id',
      'unique' => [],
      'index'  => [ ['srv_date'], ['srv_date', 'srv_time'], ['serviceid'], ],
    },

    #Tables for (currently monthly only) report contents.
    #These are updated usually once per month, and read at the moment of
    #rendering the report output (HTML now, PDF or XML or Excel or whatever
    #in the future)

    #DBIx::Sequence backend, theplatform-independent inplementation
    #of sequences
    'dbix_sequence_state' => {
      'columns' => [
        'id',       'serial', '', '', '', '',
        'dataset', 'varchar', '', 50, '', '',
        'state_id',    'int', '', '', '', '',
      ],
      'primary_key' => 'id',
      #CONSTRAINT pk_dbix_sequence PRIMARY KEY (dataset, state_id)
      'unique' => [ [ 'dataset', 'state_id' ], ],
      'index'  => [],
    },

    'dbix_sequence_release' => {
      'columns' => [
        'id',       'serial', '', '', '', '',
        'dataset', 'varchar', '', 50, '', '',
        'released_id', 'int', '', '', '', '',
      ],
      'primary_key' => 'id',
      #CONSTRAINT pk_dbi_release PRIMARY KEY (dataset, released_id)
      'unique' => [ [ 'dataset', 'released_id', ] ],
      'index'  => [],
    },

    #Each report is characterized by name, date and time.
    #Monthly reports are automatically assigned 00:00 of the 1st day
    #in the month. The report contains fields for every service ID
    #defined across all datasource trees.
    'reports' => {
      'columns' => [
        'id',          'serial', '', '', '', '',
        'rep_date',      'date', '', '', '', '',#Start date of the report
        'rep_time',      'time', '', '', '', '',#Start time of the report
        'reportname', 'varchar', '', 64, '', '',#Report name, such as
                                                # MonthlyUsage
        'iscomplete',     'int', '', '', '', '',#0 when the report is in
                                                # progress, 1 when it is ready
      ],
      'primary_key' => 'id',
      'unique' => [ [ qw(rep_date rep_time reportname) ] ],
      'index'  => [ [ 'rep_date' ] ],
    },

    #Each report contains fields. For each service ID,
    #the report may contain several fields for various statistics.
    #Each field contains information about the units of the value it
    #contains
    'reportfields' => {
      'columns' => [
        'id',              'serial',     '', '',    '', '',
        'rep_id',             'int', 'NULL', '',    '', '',
        'name',           'varchar',     '', 64,    '', '',#name of the field,
                                                           # such as AVG or MAX
        'serviceid',      'varchar',     '', 64,    '', '',#service ID
        'value', 'double precision',     '', '',    '', '',#Numeric value
        'units',          'varchar',     '', 64, \"''", '',#Units, such as bytes
                                                           # or Mbps
      ],
      'primary_key', => 'id',
      'unique' => [ [ qw(rep_id name serviceid) ] ],
      'index'  => [],
    },

  };

}

sub tables_hashref {

  my $char_d = 80; #default maxlength for text fields

  #my(@date_type)  = ( 'timestamp', '', ''     );
  my @date_type  = ( 'int', 'NULL', ''     );
  my @perl_type = ( 'text', 'NULL', ''  ); 
  my @money_type = ( 'decimal',   '', '10,2' );
  my @money_typen = ( 'decimal',   'NULL', '10,2' );
  my @taxrate_type  = ( 'decimal',   '',     '14,8' ); # requires pg 8 for 
  my @taxrate_typen = ( 'decimal',   'NULL', '14,8' ); # fs-upgrade to work

  my $username_len = 32; #usernamemax config file

    # name type nullability length default local

  return {

    'agent' => {
      'columns' => [
        'agentnum',          'serial',    '',       '', '', '', 
        'agent',            'varchar',    '',  $char_d, '', '', 
        'typenum',              'int',    '',       '', '', '', 
        'ticketing_queueid',    'int', 'NULL',      '', '', '', 
        'invoice_template', 'varchar', 'NULL', $char_d, '', '',
        'agent_custnum',        'int', 'NULL',      '', '', '',
        'disabled',            'char', 'NULL',       1, '', '', 
        'username',         'varchar', 'NULL', $char_d, '', '',
        '_password',        'varchar', 'NULL', $char_d, '', '',
        'freq',              'int', 'NULL', '', '', '', #deprecated (never used)
        'prog',                     @perl_type, '', '', #deprecated (never used)
      ],
      'primary_key' => 'agentnum',
      #'unique' => [ [ 'agent_custnum' ] ], #one agent per customer?
                                            #insert is giving it a value, tho..
      #'index' => [ ['typenum'], ['disabled'] ],
      'unique' => [],
      'index' => [ ['typenum'], ['disabled'], ['agent_custnum'] ],
    },

    'agent_type' => {
      'columns' => [
        'typenum',   'serial',  '', '', '', '', 
        'atype',     'varchar', '', $char_d, '', '', 
      ],
      'primary_key' => 'typenum',
      'unique' => [],
      'index' => [],
    },

    'type_pkgs' => {
      'columns' => [
        'typepkgnum', 'serial', '', '', '', '', 
        'typenum',   'int',  '', '', '', '', 
        'pkgpart',   'int',  '', '', '', '', 
      ],
      'primary_key' => 'typepkgnum',
      'unique' => [ ['typenum', 'pkgpart'] ],
      'index' => [ ['typenum'] ],
    },

    'cust_attachment' => {
      'columns' => [
        'attachnum', 'serial', '', '', '', '',
        'custnum',   'int', '', '', '', '',
        '_date',     @date_type, '', '',
        'otaker',    'varchar', 'NULL', 32, '', '',
        'usernum',   'int', 'NULL', '', '', '',
        'filename',  'varchar', '', 255, '', '',
        'mime_type', 'varchar', '', $char_d, '', '',
        'title',     'varchar', 'NULL', $char_d, '', '',
        'body',      'blob', 'NULL', '', '', '',
        'disabled',  @date_type, '', '',
      ],
      'primary_key' => 'attachnum',
      'unique'      => [],
      'index'       => [ ['custnum'], ['usernum'], ],
    },

    'cust_bill' => {
      'columns' => [
        #regular fields
        'invnum',    'serial',     '', '', '', '', 
        'custnum',      'int',     '', '', '', '', 
        '_date',        @date_type,        '', '', 
        'charged',      @money_type,       '', '', 
        'invoice_terms', 'varchar', 'NULL', $char_d, '', '',

        #customer balance info at invoice generation time
        'previous_balance',   @money_typen, '', '',  #eventually not nullable
        'billing_balance',    @money_typen, '', '',  #eventually not nullable

        #deprecated (unused by now, right?)
        'printed',      'int',     '', '', '', '', 

        #specific use cases
        'closed',      'char', 'NULL',  1, '', '', #not yet used much
        'statementnum', 'int', 'NULL', '', '', '', #invoice aggregate statements
        'agent_invid',  'int', 'NULL', '', '', '', #(varchar?) importing legacy
        'promised_date', @date_type,       '', '',
      ],
      'primary_key' => 'invnum',
      'unique' => [ [ 'custnum', 'agent_invid' ] ], #agentnum?  huh
      'index' => [ ['custnum'], ['_date'], ['statementnum'], ['agent_invid'] ],
    },

    #for importing invoices from a legacy system for display purposes only
    # no effect upon balance
    'legacy_cust_bill' => {
      'columns' => [
        'legacyinvnum',  'serial',     '',      '', '', '',
        'legacyid',     'varchar', 'NULL', $char_d, '', '',
        'custnum',          'int',     '',      '', '', '', 
        '_date',       @date_type,                  '', '', 
        'charged',    @money_type,                  '', '', 
        'content_pdf',     'blob', 'NULL',      '', '', '',
        'content_html',    'text', 'NULL',      '', '', '',
        'locale',       'varchar', 'NULL',      16, '', '', 
      ],
      'primary_key' => 'legacyinvnum',
      'unique' => [],
      'index'  => [ ['legacyid', 'custnum', 'locale' ], ],
    },

    'cust_statement' => {
      'columns' => [
        'statementnum', 'serial', '', '', '', '',
        'custnum',         'int', '', '', '', '',
        '_date',           @date_type,    '', '',
      ],
      'primary_key' => 'statementnum',
      'unique' => [],
      'index' => [ ['custnum'], ['_date'], ],
    },

    'cust_bill_event' => {
      'columns' => [
        'eventnum',    'serial',  '', '', '', '', 
        'invnum',   'int',  '', '', '', '', 
        'eventpart',   'int',  '', '', '', '', 
        '_date',     @date_type, '', '', 
        'status', 'varchar', '', $char_d, '', '', 
        'statustext', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'eventnum',
      #no... there are retries now #'unique' => [ [ 'eventpart', 'invnum' ] ],
      'unique' => [],
      'index' => [ ['invnum'], ['status'], ['eventpart'],
                   ['statustext'], ['_date'],
                 ],
    },

    'part_bill_event' => {
      'columns' => [
        'eventpart',    'serial',  '', '', '', '', 
        'freq',        'varchar',       'NULL',     $char_d, '', '', 
        'payby',       'char',  '', 4, '', '', 
        'event',       'varchar',           '',     $char_d, '', '', 
        'eventcode',    @perl_type, '', '', 
        'seconds',     'int', 'NULL', '', '', '', 
        'weight',      'int', '', '', '', '', 
        'plan',       'varchar', 'NULL', $char_d, '', '', 
        'plandata',   'text', 'NULL', '', '', '', 
        'reason',     'int', 'NULL', '', '', '', 
        'disabled',     'char', 'NULL', 1, '', '', 
      ],
      'primary_key' => 'eventpart',
      'unique' => [],
      'index' => [ ['payby'], ['disabled'], ],
    },

    'part_event' => {
      'columns' => [
        'eventpart',   'serial',      '',      '', '', '', 
        'agentnum',    'int',     'NULL',      '', '', '', 
        'event',       'varchar',     '', $char_d, '', '', 
        'eventtable',  'varchar',     '', $char_d, '', '',
        'check_freq',  'varchar', 'NULL', $char_d, '', '', 
        'weight',      'int',         '',      '', '', '', 
        'action',      'varchar',     '', $char_d, '', '',
        'disabled',     'char',   'NULL',       1, '', '', 
      ],
      'primary_key' => 'eventpart',
      'unique' => [],
      'index' => [ ['agentnum'], ['eventtable'], ['check_freq'], ['disabled'], ],
    },

    'part_event_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'eventpart', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'eventpart' ], [ 'optionname' ] ],
    },

    'part_event_condition' => {
      'columns' => [
        'eventconditionnum', 'serial', '', '', '', '', 
        'eventpart', 'int', '', '', '', '', 
        'conditionname', 'varchar', '', $char_d, '', '', 
      ],
      'primary_key' => 'eventconditionnum',
      'unique'      => [],
      'index'       => [ [ 'eventpart' ], [ 'conditionname' ] ],
    },

    'part_event_condition_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'eventconditionnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'eventconditionnum' ], [ 'optionname' ] ],
    },

    'part_event_condition_option_option' => {
      'columns' => [
        'optionoptionnum', 'serial', '', '', '', '', 
        'optionnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionoptionnum',
      'unique'      => [],
      'index'       => [ [ 'optionnum' ], [ 'optionname' ] ],
    },

    'cust_event' => {
      'columns' => [
        'eventnum',    'serial',  '', '', '', '', 
        'eventpart',   'int',  '', '', '', '', 
        'tablenum',   'int',  '', '', '', '', 
        '_date',     @date_type, '', '', 
        'status', 'varchar', '', $char_d, '', '', 
        'statustext', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'eventnum',
      #no... there are retries now #'unique' => [ [ 'eventpart', 'invnum' ] ],
      'unique' => [],
      'index' => [ ['eventpart'], ['tablenum'], ['status'],
                   ['statustext'], ['_date'],
                 ],
    },

    'cust_bill_pkg' => {
      'columns' => [
        'billpkgnum',        'serial',     '',      '', '', '', 
        'invnum',               'int',     '',      '', '', '', 
        'pkgnum',               'int',     '',      '', '', '', 
        'pkgpart_override',     'int', 'NULL',      '', '', '', 
        'setup',               @money_type,             '', '', 
        'recur',               @money_type,             '', '', 
        'sdate',               @date_type,              '', '', 
        'edate',               @date_type,              '', '', 
        'itemdesc',         'varchar', 'NULL', $char_d, '', '', 
        'itemcomment',      'varchar', 'NULL', $char_d, '', '', 
        'section',          'varchar', 'NULL', $char_d, '', '', 
        'freq',             'varchar', 'NULL', $char_d, '', '',
        'quantity',             'int', 'NULL',      '', '', '',
        'unitsetup',           @money_typen,            '', '', 
        'unitrecur',           @money_typen,            '', '', 
        'hidden',              'char', 'NULL',       1, '', '',
      ],
      'primary_key' => 'billpkgnum',
      'unique' => [],
      'index' => [ ['invnum'], [ 'pkgnum' ], [ 'itemdesc' ], ],
    },

    'cust_bill_pkg_detail' => {
      'columns' => [
        'detailnum', 'serial', '', '', '', '', 
        'billpkgnum', 'int', 'NULL', '', '', '',        # should not be nullable
        'pkgnum',  'int', 'NULL', '', '', '',           # deprecated
        'invnum',  'int', 'NULL', '', '', '',           # deprecated
        'amount',  'decimal', 'NULL', '10,4', '', '',
        'format',  'char', 'NULL', 1, '', '',
        'classnum', 'int', 'NULL', '', '', '',
        'duration', 'int', 'NULL', '',  0, '',
        'phonenum', 'varchar', 'NULL', 15, '', '',
        'accountcode', 'varchar',  'NULL',      20, '', '',
        'startdate',  @date_type, '', '', 
        'regionname', 'varchar', 'NULL', $char_d, '', '',
        'detail',  'varchar', '', 255, '', '', 
      ],
      'primary_key' => 'detailnum',
      'unique' => [],
      'index' => [ [ 'billpkgnum' ], [ 'classnum' ], [ 'pkgnum', 'invnum' ] ],
    },

    'cust_bill_pkg_display' => {
      'columns' => [
        'billpkgdisplaynum', 'serial', '', '', '', '', 
        'billpkgnum', 'int', '', '', '', '', 
        'section',  'varchar', 'NULL', $char_d, '', '', 
        #'unitsetup', @money_typen, '', '',     #override the linked real one?
        #'unitrecur', @money_typen, '', '',     #this too?
        'post_total', 'char', 'NULL', 1, '', '',
        'type',       'char', 'NULL', 1, '', '',
        'summary',    'char', 'NULL', 1, '', '',
      ],
      'primary_key' => 'billpkgdisplaynum',
      'unique' => [],
      'index' => [ ['billpkgnum'], ],
    },

    'cust_bill_pkg_tax_location' => {
      'columns' => [
        'billpkgtaxlocationnum', 'serial',      '', '', '', '',
        'billpkgnum',               'int',      '', '', '', '',
        'taxnum',                   'int',      '', '', '', '',
        'taxtype',              'varchar',      '', $char_d, '', '',
        'pkgnum',                   'int',      '', '', '', '',
        'locationnum',              'int',      '', '', '', '', #redundant?
        'amount',                   @money_type,        '', '',
      ],
      'primary_key' => 'billpkgtaxlocationnum',
      'unique' => [],
      'index'  => [ [ 'billpkgnum' ], [ 'taxnum' ], [ 'pkgnum' ], [ 'locationnum' ] ],
    },

    'cust_bill_pkg_tax_rate_location' => {
      'columns' => [
        'billpkgtaxratelocationnum', 'serial',      '', '', '', '',
        'billpkgnum',                   'int',      '', '', '', '',
        'taxnum',                       'int',      '', '', '', '',
        'taxtype',                  'varchar',      '', $char_d, '', '',
        'locationtaxid',            'varchar',  'NULL', $char_d, '', '',
        'taxratelocationnum',           'int',      '', '', '', '',
        'amount',                       @money_type,        '', '',
      ],
      'primary_key' => 'billpkgtaxratelocationnum',
      'unique' => [],
      'index'  => [ [ 'billpkgnum' ], [ 'taxnum' ], [ 'taxratelocationnum' ] ],
    },

    'cust_credit' => {
      'columns' => [
        'crednum',  'serial', '', '', '', '', 
        'custnum',  'int', '', '', '', '', 
        '_date',    @date_type, '', '', 
        'amount',   @money_type, '', '', 
        'otaker',   'varchar', 'NULL', 32, '', '', 
        'usernum',   'int', 'NULL', '', '', '',
        'reason',   'text', 'NULL', '', '', '', 
        'reasonnum', 'int', 'NULL', '', '', '', 
        'addlinfo', 'text', 'NULL', '', '', '',
        'closed',    'char', 'NULL', 1, '', '', 
        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances
        'eventnum', 'int', 'NULL', '', '', '', #triggering event for commission
      ],
      'primary_key' => 'crednum',
      'unique' => [],
      'index' => [ ['custnum'], ['_date'], ['usernum'], ['eventnum'] ],
    },

    'cust_credit_bill' => {
      'columns' => [
        'creditbillnum', 'serial', '', '', '', '', 
        'crednum',  'int', '', '', '', '', 
        'invnum',  'int', '', '', '', '', 
        '_date',    @date_type, '', '', 
        'amount',   @money_type, '', '', 
        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances
      ],
      'primary_key' => 'creditbillnum',
      'unique' => [],
      'index' => [ ['crednum'], ['invnum'] ],
    },

    'cust_credit_bill_pkg' => {
      'columns' => [
        'creditbillpkgnum', 'serial', '',      '', '', '',
        'creditbillnum',       'int', '',      '', '', '',
        'billpkgnum',          'int', '',      '', '', '',
        'billpkgtaxlocationnum', 'int', 'NULL', '', '', '',
        'billpkgtaxratelocationnum', 'int', 'NULL', '', '', '',
        'amount',            @money_type,          '', '',
        'setuprecur',      'varchar', '', $char_d, '', '',
        'sdate',   @date_type, '', '', 
        'edate',   @date_type, '', '', 
      ],
      'primary_key' => 'creditbillpkgnum',
      'unique'      => [],
      'index'       => [ [ 'creditbillnum' ],
                         [ 'billpkgnum' ], 
                         [ 'billpkgtaxlocationnum' ],
                         [ 'billpkgtaxratelocationnum' ],
                       ],
    },

    'cust_main' => {
      'columns' => [
        'custnum',  'serial',  '',     '', '', '', 
        'agentnum', 'int',  '',     '', '', '', 
        'agent_custid', 'varchar', 'NULL', $char_d, '', '',
        'classnum', 'int', 'NULL', '', '', '',
        'custbatch', 'varchar', 'NULL', $char_d, '', '',
#        'titlenum', 'int',  'NULL',   '', '', '', 
        'last',     'varchar', '',   2*$char_d, '', '', 
#        'middle',   'varchar', 'NULL', $char_d, '', '', 
        'first',    'varchar', '',     $char_d, '', '', 
        'ss',       'varchar', 'NULL', 11, '', '', 
        'stateid', 'varchar', 'NULL', $char_d, '', '', 
        'stateid_state', 'varchar', 'NULL', $char_d, '', '', 
        'birthdate' ,@date_type, '', '', 
        'signupdate',@date_type, '', '', 
        'dundate',   @date_type, '', '', 
        'company',  'varchar', 'NULL', $char_d, '', '', 
        'address1', 'varchar', '',     $char_d, '', '', 
        'address2', 'varchar', 'NULL', $char_d, '', '', 
        'city',     'varchar', '',     $char_d, '', '', 
        'county',   'varchar', 'NULL', $char_d, '', '', 
        'state',    'varchar', 'NULL', $char_d, '', '', 
        'zip',      'varchar', 'NULL', 10, '', '', 
        'country',  'char', '',     2, '', '', 
        'latitude', 'decimal', 'NULL', '10,7', '', '', 
        'longitude','decimal', 'NULL', '10,7', '', '', 
        'coord_auto',  'char', 'NULL',  1, '', '',
        'daytime',  'varchar', 'NULL', 20, '', '', 
        'night',    'varchar', 'NULL', 20, '', '', 
        'fax',      'varchar', 'NULL', 12, '', '', 
        'mobile',   'varchar', 'NULL', 12, '', '', 
        'ship_last',     'varchar', 'NULL', 2*$char_d, '', '', 
#        'ship_middle',   'varchar', 'NULL', $char_d, '', '', 
        'ship_first',    'varchar', 'NULL', $char_d, '', '', 
        'ship_company',  'varchar', 'NULL', $char_d, '', '', 
        'ship_address1', 'varchar', 'NULL', $char_d, '', '', 
        'ship_address2', 'varchar', 'NULL', $char_d, '', '', 
        'ship_city',     'varchar', 'NULL', $char_d, '', '', 
        'ship_county',   'varchar', 'NULL', $char_d, '', '', 
        'ship_state',    'varchar', 'NULL', $char_d, '', '', 
        'ship_zip',      'varchar', 'NULL', 10, '', '', 
        'ship_country',  'char', 'NULL', 2, '', '', 
        'ship_latitude', 'decimal', 'NULL', '10,7', '', '', 
        'ship_longitude','decimal', 'NULL', '10,7', '', '', 
        'ship_coord_auto',  'char', 'NULL',  1, '', '',
        'ship_daytime',  'varchar', 'NULL', 20, '', '', 
        'ship_night',    'varchar', 'NULL', 20, '', '', 
        'ship_fax',      'varchar', 'NULL', 12, '', '', 
        'ship_mobile',   'varchar', 'NULL', 12, '', '', 
        'payby',    'char', '',     4, '', '', 
        'payinfo',  'varchar', 'NULL', 512, '', '', 
        'paycvv',   'varchar', 'NULL', 512, '', '', 
	'paymask', 'varchar', 'NULL', $char_d, '', '', 
        #'paydate',  @date_type, '', '', 
        'paydate',  'varchar', 'NULL', 10, '', '', 
        'paystart_month', 'int', 'NULL', '', '', '', 
        'paystart_year',  'int', 'NULL', '', '', '', 
        'payissue', 'varchar', 'NULL', 2, '', '', 
        'payname',  'varchar', 'NULL', 2*$char_d, '', '', 
        'paystate', 'varchar', 'NULL', $char_d, '', '', 
        'paytype',  'varchar', 'NULL', $char_d, '', '', 
        'payip',    'varchar', 'NULL', 15, '', '', 
        'geocode',  'varchar', 'NULL', 20,  '', '',
        'censustract', 'varchar', 'NULL', 20,  '', '', # 7 to save space?
        'censusyear', 'char', 'NULL', 4, '', '',
        'tax',      'char', 'NULL', 1, '', '', 
        'otaker',   'varchar', 'NULL',    32, '', '', 
        'usernum',   'int', 'NULL', '', '', '',
        'refnum',   'int',  '',     '', '', '', 
        'referral_custnum', 'int',  'NULL', '', '', '', 
        'comments', 'text', 'NULL', '', '', '', 
        'spool_cdr','char', 'NULL', 1, '', '', 
        'squelch_cdr','char', 'NULL', 1, '', '', 
        'cdr_termination_percentage', 'decimal', 'NULL', '7,4', '', '',
        'invoice_terms', 'varchar', 'NULL', $char_d, '', '',
        'credit_limit', @money_typen, '', '',
        'archived', 'char', 'NULL', 1, '', '',
        'email_csv_cdr', 'char', 'NULL', 1, '', '',
        'accountcode_cdr', 'char', 'NULL', 1, '', '',
        'billday',   'int', 'NULL', '', '', '',
        'edit_subject', 'char', 'NULL', 1, '', '',
        'locale', 'varchar', 'NULL', 16, '', '', 
        'calling_list_exempt', 'char', 'NULL', 1, '', '',
      ],
      'primary_key' => 'custnum',
      'unique' => [ [ 'agentnum', 'agent_custid' ] ],
      #'index' => [ ['last'], ['company'] ],
      'index' => [
                   [ 'agentnum' ], [ 'refnum' ], [ 'classnum' ], [ 'usernum' ],
                   [ 'custbatch' ],
                   [ 'referral_custnum' ],
                   [ 'payby' ], [ 'paydate' ],
                   [ 'archived' ],
                   #billing
                   [ 'last' ], [ 'company' ],
                   [ 'county' ], [ 'state' ], [ 'country' ],
                   [ 'zip' ],
                   [ 'daytime' ], [ 'night' ], [ 'fax' ], [ 'mobile' ],
                   #shipping
                   [ 'ship_last' ], [ 'ship_company' ],
                   [ 'ship_county' ], [ 'ship_state' ], [ 'ship_country' ],
                   [ 'ship_zip' ],
                   [ 'ship_daytime' ], [ 'ship_night' ], [ 'ship_fax' ], [ 'ship_mobile' ]
                 ],
    },

    'cust_recon' => {  # what purpose does this serve?
      'columns' => [
        'reconid',      'serial',  '',          '', '', '', 
        'recondate',    @date_type,                 '', '', 
        'custnum',      'int'   ,  '',          '', '', '', 
        'agentnum',     'int',     '',          '', '', '', 
        'last',         'varchar', '',     $char_d, '', '', 
        'first',        'varchar', '',     $char_d, '', '', 
        'address1',     'varchar', '',     $char_d, '', '', 
        'address2',     'varchar', 'NULL', $char_d, '', '', 
        'city',         'varchar', '',     $char_d, '', '', 
        'state',        'varchar', 'NULL', $char_d, '', '', 
        'zip',          'varchar', 'NULL',      10, '', '', 
        'pkg',          'varchar', 'NULL', $char_d, '', '', 
        'adjourn',      @date_type,                 '', '',
        'status',       'varchar', 'NULL',      10, '', '', 
        'agent_custid', 'varchar',  '',    $char_d, '', '',
        'agent_pkg',    'varchar', 'NULL', $char_d, '', '', 
        'agent_adjourn', @date_type,                '', '',
        'comments',     'text',    'NULL',      '', '', '', 
      ],
      'primary_key' => 'reconid',
      'unique' => [],
      'index' => [],
    },

    #eventually for cust_main too
    'contact' => {
      'columns' => [
        'contactnum', 'serial',     '',      '', '', '',
        'prospectnum',   'int', 'NULL',      '', '', '',
        'custnum',       'int', 'NULL',      '', '', '',
        'locationnum',   'int', 'NULL',      '', '', '', #not yet
#        'titlenum',      'int', 'NULL',      '', '', '', #eg Mr. Mrs. Dr. Rev.
        'last',      'varchar',     '', $char_d, '', '', 
#        'middle',    'varchar', 'NULL', $char_d, '', '', 
        'first',     'varchar',     '', $char_d, '', '', 
        'title',     'varchar', 'NULL', $char_d, '', '', #eg Head Bottle Washer
        'comment',   'varchar', 'NULL', $char_d, '', '', 
        'disabled',     'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'contactnum',
      'unique'      => [],
      'index'       => [ [ 'prospectnum' ], [ 'custnum' ], [ 'locationnum' ],
                         [ 'last' ], [ 'first' ],
                       ],
    },

    'contact_phone' => {
      'columns' => [
        'contactphonenum', 'serial',     '', '', '', '',
        'contactnum',         'int',     '', '', '', '',
        'phonetypenum',       'int',     '', '', '', '',
        'countrycode',    'varchar',     '',  3, '', '', 
        'phonenum',       'varchar',     '', 14, '', '', 
        'extension',      'varchar', 'NULL',  7, '', '',
        #?#'comment',        'varchar',     '', $char_d, '', '', 
      ],
      'primary_key' => 'contactphonenum',
      'unique'      => [],
      'index'       => [],
    },

    'phone_type' => {
      'columns' => [
        'phonetypenum',  'serial', '',      '', '', '',
        'typename',     'varchar', '', $char_d, '', '',
        'weight',           'int', '',      '', '', '', 
      ],
      'primary_key' => 'phonetypenum',
      'unique'      => [ [ 'typename' ], ],
      'index'       => [],
    },

    'contact_email' => {
      'columns' => [
        'contactemailnum', 'serial', '',      '', '', '',
        'contactnum',         'int', '',      '', '', '',
        'emailaddress',   'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'contactemailnum',
      'unique'      => [ [ 'emailaddress' ], ],
      'index'       => [],
    },

    'prospect_main' => {
      'columns' => [
        'prospectnum',  'serial',     '',      '', '', '',
        'agentnum',        'int',     '',      '', '', '',
        'company',     'varchar', 'NULL', $char_d, '', '',
        'add_date',   @date_type,                  '', '', 
        'disabled',       'char', 'NULL',       1, '', '', 
        'custnum',         'int', 'NULL',      '', '', '',
      ],
      'primary_key' => 'prospectnum',
      'unique'      => [],
      'index'       => [ [ 'company' ], [ 'agentnum' ], [ 'disabled' ] ],
    },

    #eventually use for billing & ship from cust_main too
    #for now, just cust_pkg locations
    'cust_location' => { #'location' now that its prospects too, but...
      'columns' => [
        'locationnum',      'serial',     '',      '', '', '',
        'prospectnum',         'int', 'NULL',      '', '', '',
        'custnum',             'int', 'NULL',      '', '', '',
        'address1',        'varchar',     '', $char_d, '', '', 
        'address2',        'varchar', 'NULL', $char_d, '', '', 
        'city',            'varchar',     '', $char_d, '', '', 
        'county',          'varchar', 'NULL', $char_d, '', '', 
        'state',           'varchar', 'NULL', $char_d, '', '', 
        'zip',             'varchar', 'NULL',      10, '', '', 
        'latitude',        'decimal', 'NULL',  '10,7', '', '', 
        'longitude',       'decimal', 'NULL',  '10,7', '', '', 
        'coord_auto',         'char', 'NULL',       1, '', '',
        'country',            'char',     '',       2, '', '', 
        'geocode',         'varchar', 'NULL',      20, '', '',
        'location_type',   'varchar', 'NULL',      20, '', '',
        'location_number', 'varchar', 'NULL',      20, '', '',
        'location_kind',      'char', 'NULL',       1, '', '',
        'disabled',           'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'locationnum',
      'unique'      => [],
      'index'       => [ [ 'prospectnum' ], [ 'custnum' ],
                         [ 'county' ], [ 'state' ], [ 'country' ], [ 'zip' ],
                       ],
    },

    'cust_main_invoice' => {
      'columns' => [
        'destnum',  'serial',  '',     '', '', '', 
        'custnum',  'int',  '',     '', '', '', 
        'dest',     'varchar', '',  $char_d, '', '', 
      ],
      'primary_key' => 'destnum',
      'unique' => [],
      'index' => [ ['custnum'], ],
    },

    'cust_main_note' => {
      'columns' => [
        'notenum',  'serial',  '',     '', '', '', 
        'custnum',  'int',  '',     '', '', '', 
        'classnum',      'int',     'NULL', '', '', '', 
        '_date',    @date_type, '', '', 
        'otaker',   'varchar', 'NULL',    32, '', '', 
        'usernum',   'int', 'NULL', '', '', '',
        'comments', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'notenum',
      'unique' => [],
      'index' => [ [ 'custnum' ], [ '_date' ], [ 'usernum' ], ],
    },
    
    'cust_note_class' => {
      'columns' => [
        'classnum',    'serial',   '',      '', '', '', 
        'classname',   'varchar',  '', $char_d, '', '', 
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },

    'cust_category' => {
      'columns' => [
        'categorynum',   'serial',  '', '', '', '', 
        'categoryname',  'varchar', '', $char_d, '', '', 
        'weight',         'int', 'NULL',  '', '', '',
        'disabled',      'char', 'NULL',   1, '', '', 
      ],
      'primary_key' => 'categorynum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },

    'cust_class' => {
      'columns' => [
        'classnum',    'serial',   '',      '', '', '', 
        'classname',   'varchar',  '', $char_d, '', '', 
        'categorynum', 'int',  'NULL',      '', '', '', 
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },
 
    'cust_tag' => {
      'columns' => [
        'custtagnum', 'serial', '', '', '', '',
        'custnum',       'int', '', '', '', '',
        'tagnum',        'int', '', '', '', '',
      ],
      'primary_key' => 'custtagnum',
      'unique'      => [ [ 'custnum', 'tagnum' ] ],
      'index'       => [ [ 'custnum' ] ],
    },

    'part_tag' => {
      'columns' => [
        'tagnum',    'serial',     '',      '', '', '',
        'tagname',  'varchar',     '', $char_d, '', '',
        'tagdesc',  'varchar', 'NULL', $char_d, '', '',
        'tagcolor', 'varchar', 'NULL',       6, '', '',
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'tagnum',
      'unique'      => [], #[ [ 'tagname' ] ], #?
      'index'       => [ [ 'disabled' ] ],
    },

    'cust_main_exemption' => {
      'columns' => [
        'exemptionnum', 'serial', '',      '', '', '',
        'custnum',         'int', '',      '', '', '', 
        'taxname',     'varchar', '', $char_d, '', '',
        #start/end dates?  for reporting?
      ],
      'primary_key' => 'exemptionnum',
      'unique'      => [],
      'index'       => [ [ 'custnum' ] ],
    },

    'cust_tax_adjustment' => {
      'columns' => [
        'adjustmentnum', 'serial',     '',      '', '', '',
        'custnum',          'int',     '',      '', '', '',
        'taxname',      'varchar',     '', $char_d, '', '',
        'amount',    @money_type,                   '', '', 
        'comment',     'varchar',  'NULL', $char_d, '', '', 
        'billpkgnum',       'int', 'NULL',      '', '', '',
        #more?  no cust_bill_pkg_tax_location?
      ],
      'primary_key' => 'adjustmentnum',
      'unique'      => [],
      'index'       => [ [ 'custnum' ], [ 'billpkgnum' ] ],
    },

    'cust_main_county' => { #county+state+country are checked off the
                            #cust_main_county for validation and to provide
                            # a tax rate.
      'columns' => [
        'taxnum',   'serial',   '',    '', '', '', 
        'city',     'varchar',  'NULL',    $char_d, '', '',
        'county',   'varchar',  'NULL',    $char_d, '', '', 
        'state',    'varchar',  'NULL',    $char_d, '', '', 
        'country',  'char',  '', 2, '', '', 
        'taxclass',   'varchar', 'NULL', $char_d, '', '', 
        'exempt_amount', @money_type, '', '', 
        'tax',      'real',  '',    '', '', '', #tax %
        'taxname',  'varchar',  'NULL',    $char_d, '', '', 
        'setuptax',  'char', 'NULL', 1, '', '', # Y = setup tax exempt
        'recurtax',  'char', 'NULL', 1, '', '', # Y = recur tax exempt
      ],
      'primary_key' => 'taxnum',
      'unique' => [],
  #    'unique' => [ ['taxnum'], ['state', 'county'] ],
      'index' => [ [ 'city' ], [ 'county' ], [ 'state' ], [ 'country' ],
                   [ 'taxclass' ],
                 ],
    },

    'tax_rate'    => {
      'columns' => [
        'taxnum',       'serial',     '',      '', '', '', 
        'geocode',     'varchar', 'NULL', $char_d, '', '',#cch provides 10 char
        'data_vendor', 'varchar', 'NULL', $char_d, '', '',#auto update source
        'location',    'varchar', 'NULL', $char_d, '', '',#provided by tax authority
        'taxclassnum', 'int',      '',      '', '', '', 
        'effective_date', @date_type, '', '', 
        'tax',        @taxrate_type,      '', '',        # tax %
        'excessrate', @taxrate_typen,     '', '',        # second tax %
        'taxbase',    @money_typen, '', '',              # amount at first tax rate
        'taxmax',     @money_typen, '', '',              # maximum about at both rates
        'usetax',        @taxrate_typen,     '', '',     # tax % when non-local
        'useexcessrate', @taxrate_typen,     '', '',     # second tax % when non-local
        'unittype',    'int',  'NULL', '', '', '',      # for fee
        'fee',         @taxrate_typen,     '', '',      # amount tax per unit
        'excessfee',   @taxrate_typen,     '', '',      # second amount tax per unit
        'feebase',     @taxrate_typen,     '', '',      # units taxed at first rate
        'feemax',      @taxrate_typen,     '', '',      # maximum number of unit taxed
        'maxtype',     'int',  'NULL', '', '', '',      # indicator of how thresholds accumulate
        'taxname', 'varchar',  'NULL', $char_d, '', '', # may appear on invoice
        'taxauth',     'int',  'NULL', '', '', '',      # tax authority
        'basetype',    'int',  'NULL', '', '', '', # indicator of basis for tax
        'passtype',    'int',  'NULL', '', '', '', # indicator declaring how item should be shown
        'passflag',    'char', 'NULL', 1, '', '',  # Y = required to list as line item, N = Prohibited
        'setuptax',    'char', 'NULL', 1, '', '',  # Y = setup tax exempt
        'recurtax',    'char', 'NULL', 1, '', '',  # Y = recur tax exempt
        'inoutcity',   'char', 'NULL', 1, '', '',  # '', 'I', or 'O'
        'inoutlocal',  'char', 'NULL', 1, '', '',  # '', 'I', or 'O'
        'manual',      'char', 'NULL', 1, '', '',  # Y = manually edited
        'disabled',    'char', 'NULL', 1, '', '',  # Y = tax disabled
      ],
      'primary_key' => 'taxnum',
      'unique' => [],
      'index' => [ ['taxclassnum'], ['data_vendor', 'geocode'] ],
    },

    'tax_rate_location' => { 
      'columns' => [
        'taxratelocationnum', 'serial',  '',     '', '', '', 
        'data_vendor',        'varchar', 'NULL', $char_d, '', '',
        'geocode',            'varchar', '',     20,      '', '', 
        'city',               'varchar', 'NULL', $char_d, '', '',
        'county',             'varchar', 'NULL', $char_d, '', '',
        'state',              'char',    'NULL',       2, '', '', 
        'disabled',           'char',    'NULL', 1, '', '',
      ],
      'primary_key' => 'taxratelocationnum',
      'unique' => [],
      'index' => [ [ 'data_vendor', 'geocode', 'disabled' ] ],
    },

    'cust_tax_location' => { 
      'columns' => [
        'custlocationnum', 'serial',  '',     '', '', '', 
        'data_vendor',     'varchar', 'NULL', $char_d, '', '', # update source
        'city',            'varchar', 'NULL', $char_d, '', '',
        'postalcity',      'varchar', 'NULL', $char_d, '', '',
        'county',          'varchar', 'NULL', $char_d, '', '',
        'zip',             'char',    '',     5,  '', '', 
        'state',           'char',    '',     2,  '', '', 
        'plus4hi',         'char',    'NULL', 4,  '', '', 
        'plus4lo',         'char',    'NULL', 4,  '', '', 
        'default_location','char',    'NULL', 1,  '', '', # Y = default for zip
        'cityflag',        'char',    'NULL', 1,  '', '', # I(n)/O(out)/B(oth)/NULL
        'geocode',         'varchar', '',    20,  '', '', 
      ],
      'primary_key' => 'custlocationnum',
      'unique' => [],
      'index' => [ [ 'zip', 'plus4lo', 'plus4hi' ] ],
    },

    'tax_class' => { 
      'columns' => [
        'taxclassnum',  'serial',  '',            '', '', '',
        'data_vendor',  'varchar', 'NULL',   $char_d, '', '',
        'taxclass',     'varchar', '',       $char_d, '', '',          
        'description',  'varchar', '',     2*$char_d, '', '',          
      ],
      'primary_key' => 'taxclassnum',
      'unique' => [ [ 'data_vendor', 'taxclass' ] ],
      'index' => [],
    },

    'cust_pay_pending' => {
      'columns' => [
        'paypendingnum','serial',      '',  '', '', '',
        'custnum',      'int',         '',  '', '', '', 
        'paid',         @money_type,            '', '', 
        '_date',        @date_type,             '', '', 
        'payby',        'char',        '',   4, '', '', #CARD/BILL/COMP, should
                                                        # be index into payby
                                                        # table eventually
        'payinfo',      'varchar', 'NULL', 512, '', '', #see cust_main above
	'paymask',      'varchar', 'NULL', $char_d, '', '', 
        'paydate',      'varchar', 'NULL', 10, '', '', 
        'recurring_billing', 'varchar', 'NULL', $char_d, '', '',
        #'paybatch',     'varchar', 'NULL', $char_d, '', '', #for auditing purposes.
        'payunique',    'varchar', 'NULL', $char_d, '', '', #separate paybatch "unique" functions from current usage

        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances
        'status',       'varchar',     '', $char_d, '', '', 
        'session_id',   'varchar', 'NULL', $char_d, '', '', #only need 32
        'statustext',   'text',    'NULL',  '', '', '', 
        'gatewaynum',   'int',     'NULL',  '', '', '',
        #'cust_balance', @money_type,            '', '',
        'paynum',       'int',     'NULL',  '', '', '',
        'jobnum',       'int',     'NULL',  '', '', '', 
      ],
      'primary_key' => 'paypendingnum',
      'unique'      => [ [ 'payunique' ] ],
      'index'       => [ [ 'custnum' ], [ 'status' ], ],
    },

    'cust_pay' => {
      'columns' => [
        'paynum',   'serial',    '',   '', '', '',
        'custnum',  'int',    '',   '', '', '', 
        '_date',    @date_type, '', '', 
        'paid',     @money_type, '', '', 
        'otaker',   'varchar', 'NULL', 32, '', '',
        'usernum',   'int', 'NULL', '', '', '',
        'payby',    'char',   '',     4, '', '', # CARD/BILL/COMP, should be
                                                 # index into payby table
                                                 # eventually
        'payinfo',  'varchar',   'NULL', 512, '', '', #see cust_main above
	'paymask', 'varchar', 'NULL', $char_d, '', '', 
        'paydate',  'varchar', 'NULL', 10, '', '', 
        'paybatch', 'varchar',   'NULL', $char_d, '', '', #for auditing purposes.
        'payunique', 'varchar', 'NULL', $char_d, '', '', #separate paybatch "unique" functions from current usage
        'closed',    'char', 'NULL', 1, '', '', 
        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances
      ],
      'primary_key' => 'paynum',
      #i guess not now, with cust_pay_pending, if we actually make it here, we _do_ want to record it# 'unique' => [ [ 'payunique' ] ],
      'index' => [ [ 'custnum' ], [ 'paybatch' ], [ 'payby' ], [ '_date' ], [ 'usernum' ] ],
    },

    'cust_pay_void' => {
      'columns' => [
        'paynum',    'int',    '',   '', '', '', 
        'custnum',   'int',    '',   '', '', '', 
        'paid',      @money_type, '', '', 
        '_date',     @date_type, '', '', 
        'payby',     'char',   '',     4, '', '', # CARD/BILL/COMP, should be
                                                  # index into payby table
                                                  # eventually
        'payinfo',   'varchar',   'NULL', 512, '', '', #see cust_main above
	'paymask', 'varchar', 'NULL', $char_d, '', '', 
        'paybatch',  'varchar',   'NULL', $char_d, '', '', #for auditing purposes.
        'closed',    'char', 'NULL', 1, '', '', 
        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances
        'void_date', @date_type, '', '', 
        'reason',    'varchar',   'NULL', $char_d, '', '', 
        'otaker',   'varchar', 'NULL', 32, '', '', 
        'usernum',   'int', 'NULL', '', '', '',
        'void_usernum',   'int', 'NULL', '', '', '',
      ],
      'primary_key' => 'paynum',
      'unique' => [],
      'index' => [ [ 'custnum' ], [ 'usernum' ], [ 'void_usernum' ] ],
    },

    'cust_bill_pay' => {
      'columns' => [
        'billpaynum', 'serial',     '',   '', '', '', 
        'invnum',  'int',     '',   '', '', '', 
        'paynum',  'int',     '',   '', '', '', 
        'amount',  @money_type, '', '', 
        '_date',   @date_type, '', '', 
        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances
      ],
      'primary_key' => 'billpaynum',
      'unique' => [],
      'index' => [ [ 'paynum' ], [ 'invnum' ] ],
    },

    'cust_bill_pay_batch' => {
      'columns' => [
        'billpaynum', 'serial',     '',   '', '', '', 
        'invnum',  'int',     '',   '', '', '', 
        'paybatchnum',  'int',     '',   '', '', '', 
        'amount',  @money_type, '', '', 
        '_date',   @date_type, '', '', 
      ],
      'primary_key' => 'billpaynum',
      'unique' => [],
      'index' => [ [ 'paybatchnum' ], [ 'invnum' ] ],
    },

    'cust_bill_pay_pkg' => {
      'columns' => [
        'billpaypkgnum', 'serial', '', '', '', '',
        'billpaynum',       'int', '', '', '', '',
        'billpkgnum',       'int', '', '', '', '',
        'billpkgtaxlocationnum', 'int', 'NULL', '', '', '',
        'billpkgtaxratelocationnum', 'int', 'NULL', '', '', '',
        'amount',         @money_type,     '', '',
        'setuprecur',      'varchar', '', $char_d, '', '',
	'sdate',   @date_type, '', '', 
        'edate',   @date_type, '', '', 
      ],
      'primary_key' => 'billpaypkgnum',
      'unique'      => [],
      'index'       => [ [ 'billpaynum' ], [ 'billpkgnum' ], ],
    },

    'pay_batch' => { #batches of payments to an external processor
      'columns' => [
        'batchnum', 'serial',     '', '', '', '', 
        'agentnum',    'int', 'NULL', '', '', '', 
	'payby',      'char',     '',  4, '', '', # CARD/CHEK
        'status',     'char', 'NULL',  1, '', '', 
        'download',       @date_type,     '', '', 
        'upload',         @date_type,     '', '', 
      ],
      'primary_key' => 'batchnum',
      'unique' => [],
      'index' => [],
    },

    'cust_pay_batch' => { #list of customers in current CARD/CHEK batch
      'columns' => [
        'paybatchnum',   'serial',    '',   '', '', '', 
        'batchnum',   'int',    '',   '', '', '', 
        'invnum',   'int',    '',   '', '', '', 
        'custnum',   'int',    '',   '', '', '', 
        'last',     'varchar', '',     $char_d, '', '', 
        'first',    'varchar', '',     $char_d, '', '', 
        'address1', 'varchar', '',     $char_d, '', '', 
        'address2', 'varchar', 'NULL', $char_d, '', '', 
        'city',     'varchar', '',     $char_d, '', '', 
        'state',    'varchar', 'NULL', $char_d, '', '', 
        'zip',      'varchar', 'NULL', 10, '', '', 
        'country',  'char', '',     2, '', '', 
        #        'trancode', 'int', '', '', '', ''
        'payby',    'char',   '',     4, '', '', # CARD/BILL/COMP, should be
        'payinfo',  'varchar', '',     512, '', '', 
        #'exp',      @date_type, '', ''
        'exp',      'varchar', 'NULL',     11, '', '', 
        'payname',  'varchar', 'NULL', $char_d, '', '', 
        'amount',   @money_type, '', '', 
        'status',   'varchar', 'NULL',     $char_d, '', '', 
      ],
      'primary_key' => 'paybatchnum',
      'unique' => [],
      'index' => [ ['batchnum'], ['invnum'], ['custnum'] ],
    },

    'fcc477map' => {
      'columns' => [
        'formkey',   'varchar',     '', 255, '', '',
        'formvalue',    'text', 'NULL',  '', '', '',
      ],
      'primary_key' => 'formkey',
      'unique'      => [],
      'index'       => [],
    },

    'cust_pkg' => {
      'columns' => [
        'pkgnum',           'serial',     '', '', '', '', 
        'custnum',             'int',     '', '', '', '', 
        'pkgpart',             'int',     '', '', '', '', 
        'pkgbatch',        'varchar', 'NULL', $char_d, '', '',
        'locationnum',         'int', 'NULL', '', '', '',
        'otaker',          'varchar', 'NULL', 32, '', '', 
        'usernum',             'int', 'NULL', '', '', '',
        'order_date',     @date_type,             '', '', 
        'start_date',     @date_type,             '', '', 
        'setup',          @date_type,             '', '', 
        'bill',           @date_type,             '', '', 
        'last_bill',      @date_type,             '', '', 
        'susp',           @date_type,             '', '', 
        'adjourn',        @date_type,             '', '', 
        'cancel',         @date_type,             '', '', 
        'expire',         @date_type,             '', '', 
        'contract_end',   @date_type,             '', '',
        'dundate',        @date_type,             '', '',
        'change_date',    @date_type,             '', '',
        'change_pkgnum',       'int', 'NULL', '', '', '',
        'change_pkgpart',      'int', 'NULL', '', '', '',
        'change_locationnum',  'int', 'NULL', '', '', '',
        'manual_flag',        'char', 'NULL',  1, '', '', 
        'no_auto',            'char', 'NULL',  1, '', '', 
        'quantity',            'int', 'NULL', '', '', '',
        'agent_pkgid',         'int', 'NULL', '', '', '',
        'waive_setup',        'char', 'NULL',  1, '', '', 
        'recur_show_zero',    'char', 'NULL',  1, '', '',
        'setup_show_zero',    'char', 'NULL',  1, '', '',
      ],
      'primary_key' => 'pkgnum',
      'unique' => [],
      'index' => [ ['custnum'], ['pkgpart'], [ 'pkgbatch' ], [ 'locationnum' ],
                   [ 'usernum' ], [ 'agent_pkgid' ],
                   ['order_date'], [ 'start_date' ], ['setup'], ['bill'],
                   ['last_bill'], ['susp'], ['adjourn'], ['cancel'],
                   ['expire'], ['contract_end'], ['change_date'], ['no_auto'],
                 ],
    },

    'cust_pkg_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'pkgnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'pkgnum' ], [ 'optionname' ] ],
    },

    'cust_pkg_detail' => {
      'columns' => [
        'pkgdetailnum', 'serial', '',      '', '', '',
        'pkgnum',          'int', '',      '', '', '',
        'detail',      'varchar', '', $char_d, '', '', 
        'detailtype',     'char', '',       1, '', '', # "I"nvoice or "C"omment
        'weight',          'int', '',      '', '', '',
      ],
      'primary_key' => 'pkgdetailnum',
      'unique' => [],
      'index'  => [ [ 'pkgnum', 'detailtype' ] ],
    },

    'cust_pkg_reason' => {
      'columns' => [
        'num',      'serial',    '',   '', '', '', 
        'pkgnum',   'int',    '',   '', '', '', 
        'reasonnum','int',    '',   '', '', '', 
        'action',   'char', 'NULL', 1, '', '',     #should not be nullable
        'otaker',   'varchar', 'NULL', 32, '', '', 
        'usernum',   'int', 'NULL', '', '', '',
        'date',     @date_type, '', '', 
      ],
      'primary_key' => 'num',
      'unique' => [],
      'index' => [ [ 'pkgnum' ], [ 'reasonnum' ], ['action'], [ 'usernum' ], ],
    },

    'cust_pkg_discount' => {
      'columns' => [
        'pkgdiscountnum', 'serial', '',        '', '', '',
        'pkgnum',            'int', '',        '', '', '', 
        'discountnum',       'int', '',        '', '', '',
        'months_used',   'decimal', 'NULL', '7,4', '', '',
        'end_date',     @date_type,                '', '',
        'otaker',        'varchar', 'NULL',    32, '', '', 
        'usernum',           'int', 'NULL',    '', '', '',
        'disabled',         'char', 'NULL',     1, '', '', 
      ],
      'primary_key' => 'pkgdiscountnum',
      'unique' => [],
      'index'  => [ [ 'pkgnum' ], [ 'discountnum' ], [ 'usernum' ], ],
    },

    'cust_bill_pkg_discount' => {
      'columns' => [
        'billpkgdiscountnum', 'serial',        '', '', '', '',
        'billpkgnum',            'int',        '', '', '', '', 
        'pkgdiscountnum',        'int',        '', '', '', '', 
        'amount',          @money_type,                '', '', 
        'months',            'decimal', 'NULL', '7,4', '', '',
      ],
      'primary_key' => 'billpkgdiscountnum',
      'unique' => [],
      'index' => [ [ 'billpkgnum' ], [ 'pkgdiscountnum' ] ],
    },

    'discount' => {
      'columns' => [
        'discountnum', 'serial',     '',      '', '', '',
        #'agentnum',       'int', 'NULL',      '', '', '', 
        'name',       'varchar', 'NULL', $char_d, '', '',
        'amount',   @money_type,                  '', '', 
        'percent',    'decimal',     '',   '7,4', '', '',
        'months',     'decimal', 'NULL',   '7,4', '', '',
        'disabled',      'char', 'NULL',       1, '', '', 
        'setup',      'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'discountnum',
      'unique' => [],
      'index'  => [], # [ 'agentnum' ], ],
    },

    'cust_refund' => {
      'columns' => [
        'refundnum',    'serial',    '',   '', '', '', 
        'custnum',  'int',    '',   '', '', '', 
        '_date',        @date_type, '', '', 
        'refund',       @money_type, '', '', 
        'otaker',       'varchar',   'NULL',   32, '', '', 
        'usernum',   'int', 'NULL', '', '', '',
        'reason',       'varchar',   '',   $char_d, '', '', 
        'payby',        'char',   '',     4, '', '', # CARD/BILL/COMP, should
                                                     # be index into payby
                                                     # table eventually
        'payinfo',      'varchar',   'NULL', 512, '', '', #see cust_main above
	'paymask', 'varchar', 'NULL', $char_d, '', '', 
        'paybatch',     'varchar',   'NULL', $char_d, '', '', 
        'closed',    'char', 'NULL', 1, '', '', 
      ],
      'primary_key' => 'refundnum',
      'unique' => [],
      'index' => [ ['custnum'], ['_date'], [ 'usernum' ], ],
    },

    'cust_credit_refund' => {
      'columns' => [
        'creditrefundnum', 'serial',     '',   '', '', '', 
        'crednum',  'int',     '',   '', '', '', 
        'refundnum',  'int',     '',   '', '', '', 
        'amount',  @money_type, '', '', 
        '_date',   @date_type, '', '', 
      ],
      'primary_key' => 'creditrefundnum',
      'unique' => [],
      'index' => [ ['crednum'], ['refundnum'] ],
    },


    'cust_svc' => {
      'columns' => [
        'svcnum',    'serial',    '',   '', '', '', 
        'pkgnum',    'int',    'NULL',   '', '', '', 
        'svcpart',   'int',    '',   '', '', '', 
        'overlimit', @date_type, '', '', 
      ],
      'primary_key' => 'svcnum',
      'unique' => [],
      'index' => [ ['svcnum'], ['pkgnum'], ['svcpart'] ],
    },

    'cust_svc_option' => {
      'columns' => [
        'optionnum',   'serial', '', '', '', '', 
        'svcnum',      'int', '', '', '', '', 
        'optionname',  'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'svcnum' ], [ 'optionname' ] ],
    },

   'part_pkg' => {
      'columns' => [
        'pkgpart',       'serial',    '',   '', '', '', 
        'pkg',           'varchar',   '',   $char_d, '', '', 
        'comment',       'varchar',   '', 2*$char_d, '', '', 
        'promo_code',    'varchar', 'NULL', $char_d, '', '', 
        'setup',         @perl_type, '', '', 
        'freq',          'varchar',   '',   $char_d, '', '', #billing frequency
        'recur',         @perl_type, '', '', 
        'setuptax',      'char', 'NULL', 1, '', '', 
        'recurtax',      'char', 'NULL', 1, '', '', 
        'plan',          'varchar', 'NULL', $char_d, '', '', 
        'plandata',      'text', 'NULL', '', '', '', 
        'disabled',      'char', 'NULL', 1, '', '', 
        'custom',        'char', 'NULL', 1, '', '', 
        'taxclass',      'varchar', 'NULL', $char_d, '', '', 
        'classnum',      'int',     'NULL', '', '', '', 
        'addon_classnum','int',     'NULL', '', '', '', 
        'taxproductnum', 'int',     'NULL', '', '', '', 
        'setup_cost',    @money_typen,          '', '',
        'recur_cost',    @money_typen,          '', '',
        'pay_weight',    'real',    'NULL', '', '', '',
        'credit_weight', 'real',    'NULL', '', '', '',
        'agentnum',      'int',     'NULL', '', '', '', 
        'fcc_ds0s',      'int',     'NULL', '', '', '', 
        'no_auto',          'char', 'NULL',  1, '', '', 
        'recur_show_zero',  'char', 'NULL',  1, '', '',
        'setup_show_zero',  'char', 'NULL',  1, '', '',
      ],
      'primary_key' => 'pkgpart',
      'unique' => [],
      'index' => [ [ 'promo_code' ], [ 'disabled' ], [ 'classnum' ],
                   [ 'agentnum' ], ['no_auto'],
                 ],
    },

    'part_pkg_link' => {
      'columns' => [
        'pkglinknum',  'serial',   '',      '', '', '',
        'src_pkgpart', 'int',      '',      '', '', '',
        'dst_pkgpart', 'int',      '',      '', '', '', 
        'link_type',   'varchar',  '', $char_d, '', '',
        'hidden',      'char', 'NULL',       1, '', '',
      ],
      'primary_key' => 'pkglinknum',
      'unique' => [ [ 'src_pkgpart', 'dst_pkgpart', 'link_type', 'hidden' ] ],
      'index'  => [ [ 'src_pkgpart' ] ],
    },
    # XXX somewhat borked unique: we don't really want a hidden and unhidden
    # it turns out we'd prefer to use svc, bill, and invisibill (or something)

    'part_pkg_discount' => {
      'columns' => [
        'pkgdiscountnum', 'serial',   '',      '', '', '',
        'pkgpart',        'int',      '',      '', '', '',
        'discountnum',    'int',      '',      '', '', '', 
      ],
      'primary_key' => 'pkgdiscountnum',
      'unique' => [ [ 'pkgpart', 'discountnum' ] ],
      'index'  => [],
    },

    'part_pkg_taxclass' => {
      'columns' => [
        'taxclassnum',  'serial', '',       '', '', '',
        'taxclass',     'varchar', '', $char_d, '', '', 
        'disabled', 'char',   'NULL',         1, '', '', 
      ],
      'primary_key' => 'taxclassnum',
      'unique'      => [ [ 'taxclass' ] ],
      'index'       => [ [ 'disabled' ] ],
    },

    'part_pkg_taxproduct' => {
      'columns' => [
        'taxproductnum', 'serial',      '',        '', '', '',
        'data_vendor',   'varchar', 'NULL',   $char_d, '', '', 
        'taxproduct',    'varchar',     '',   $char_d, '', '', 
        'description',   'varchar',     '', 3*$char_d, '', '', 
      ],
      'primary_key' => 'taxproductnum',
      'unique'      => [ [ 'data_vendor', 'taxproduct' ] ],
      'index'       => [],
    },

    'part_pkg_taxrate' => { 
      'columns' => [
        'pkgtaxratenum', 'serial',  '',     '',      '', '',
        'data_vendor',   'varchar', 'NULL', $char_d, '', '', # update source
        'geocode',       'varchar', 'NULL', $char_d, '', '', # cch provides 10
        'taxproductnum', 'int',  '',     '',       '', '',          
        'city',             'varchar', 'NULL', $char_d, '', '', # tax_location?
        'county',           'varchar', 'NULL', $char_d, '', '', 
        'state',            'varchar', 'NULL', $char_d, '', '', 
        'local',            'varchar', 'NULL', $char_d, '', '', 
        'country',          'char',    'NULL', 2,       '', '',
        'taxclassnumtaxed', 'int',     'NULL', '',      '', '', 
        'taxcattaxed',      'varchar', 'NULL', $char_d, '', '', 
        'taxclassnum',      'int',     'NULL', '',      '', '', 
        'effdate',          @date_type, '', '', 
        'taxable',          'char',    'NULL', 1,       '', '', 
      ],
      'primary_key' => 'pkgtaxratenum',
      'unique' => [],
      'index' => [ [ 'data_vendor', 'geocode', 'taxproductnum' ] ],
    },

    'part_pkg_taxoverride' => { 
      'columns' => [
        'taxoverridenum', 'serial', '', '', '', '',
        'pkgpart',           'int', '', '', '', '',
        'taxclassnum',       'int', '', '', '', '',
        'usage_class',    'varchar', 'NULL', $char_d, '', '', 
      ],
      'primary_key' => 'taxoverridenum',
      'unique' => [],
      'index' => [ [ 'pkgpart' ], [ 'taxclassnum' ] ],
    },

#    'part_title' => {
#      'columns' => [
#        'titlenum',   'int',    '',   '',
#        'title',      'varchar',   '',   $char_d,
#      ],
#      'primary_key' => 'titlenum',
#      'unique' => [ [] ],
#      'index' => [ [] ],
#    },

    'pkg_svc' => {
      'columns' => [
        'pkgsvcnum',  'serial', '',  '', '', '', 
        'pkgpart',    'int',    '',   '', '', '', 
        'svcpart',    'int',    '',   '', '', '', 
        'quantity',   'int',    '',   '', '', '', 
        'primary_svc','char', 'NULL',  1, '', '', 
        'hidden',     'char', 'NULL',  1, '', '',
      ],
      'primary_key' => 'pkgsvcnum',
      'unique' => [ ['pkgpart', 'svcpart'] ],
      'index' => [ ['pkgpart'], ['quantity'] ],
    },

    'part_referral' => {
      'columns' => [
        'refnum',   'serial',     '',        '', '', '', 
        'referral', 'varchar',    '',   $char_d, '', '', 
        'disabled', 'char',   'NULL',         1, '', '', 
        'agentnum', 'int',    'NULL',        '', '', '', 
      ],
      'primary_key' => 'refnum',
      'unique' => [],
      'index' => [ ['disabled'], ['agentnum'], ],
    },

    'part_svc' => {
      'columns' => [
        'svcpart',    'serial',    '',   '', '', '', 
        'svc',        'varchar',   '',   $char_d, '', '', 
        'svcdb',      'varchar',   '',   $char_d, '', '', 
        'disabled',   'char',  'NULL',   1, '', '', 
        'preserve',   'char', 'NULL',  1, '', '',
      ],
      'primary_key' => 'svcpart',
      'unique' => [],
      'index' => [ [ 'disabled' ] ],
    },

    'part_svc_column' => {
      'columns' => [
        'columnnum',   'serial',         '', '', '', '', 
        'svcpart',     'int',         '', '', '', '', 
        'columnname',  'varchar',     '', 64, '', '', 
        'columnlabel', 'varchar', 'NULL', $char_d, '', '',
        'columnvalue', 'varchar', 'NULL', $char_d, '', '', 
        'columnflag',  'char',    'NULL', 1, '', '', 
      ],
      'primary_key' => 'columnnum',
      'unique' => [ [ 'svcpart', 'columnname' ] ],
      'index' => [ [ 'svcpart' ] ],
    },

    #(this should be renamed to part_pop)
    'svc_acct_pop' => {
      'columns' => [
        'popnum',    'serial',    '',   '', '', '', 
        'city',      'varchar',   '',   $char_d, '', '', 
        'state',     'varchar',   '',   $char_d, '', '', 
        'ac',        'char',   '',   3, '', '', 
        'exch',      'char',   '',   3, '', '', 
        'loc',       'char',   'NULL',   4, '', '', #NULL for legacy purposes
      ],
      'primary_key' => 'popnum',
      'unique' => [],
      'index' => [ [ 'state' ] ],
    },

    'part_pop_local' => {
      'columns' => [
        'localnum',  'serial',     '',     '', '', '', 
        'popnum',    'int',     '',     '', '', '', 
        'city',      'varchar', 'NULL', $char_d, '', '', 
        'state',     'char',    'NULL', 2, '', '', 
        'npa',       'char',    '',     3, '', '', 
        'nxx',       'char',    '',     3, '', '', 
      ],
      'primary_key' => 'localnum',
      'unique' => [],
      'index' => [ [ 'npa', 'nxx' ], [ 'popnum' ] ],
    },
    
    'qual' => {
      'columns' => [
        'qualnum',  'serial',     '',     '', '', '', 
        'custnum',    'int',     'NULL',     '', '', '',
        'prospectnum',    'int',     'NULL',     '', '', '',
        'locationnum',    'int',     'NULL',     '', '', '',
	'phonenum',     'varchar', 'NULL',       24, '', '',
        'exportnum',      'int', 'NULL', '', '', '', 
        'vendor_qual_id',      'varchar', 'NULL', $char_d, '', '', 
        'status',      'char', '', 1, '', '', 
      ],
      'primary_key' => 'qualnum',
      'unique' => [],
      'index' => [ [ 'locationnum' ], ['custnum'], ['prospectnum'],
		    ['phonenum'], ['vendor_qual_id'] ],
    },
    
    'qual_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'qualnum',  'int',     '',     '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique' => [],
      'index' => [],
    },

    'svc_acct' => {
      'columns' => [
        'svcnum',    'int',    '',   '', '', '', 
        'username',  'varchar',   '',   $username_len, '', '',
        '_password', 'varchar',   'NULL',  512, '', '',
        '_password_encoding', 'varchar', 'NULL', $char_d, '', '',
        'sec_phrase', 'varchar',  'NULL',   $char_d, '', '', 
        'popnum',    'int',    'NULL',   '', '', '', 
        'sectornum', 'int', 'NULL',      '', '', '',
        'uid',       'int', 'NULL',   '', '', '', 
        'gid',       'int', 'NULL',   '', '', '', 
        'finger',    'varchar',   'NULL',   2*$char_d, '', '', 
        'dir',       'varchar',   'NULL',   $char_d, '', '', 
        'shell',     'varchar',   'NULL',   $char_d, '', '', 
        'quota',     'varchar',   'NULL',   $char_d, '', '', 
        'slipip',    'varchar',   'NULL',   15, '', '', #four TINYINTs, bah.
        'seconds',   'int', 'NULL',   '', '', '', #uhhhh
        'seconds_threshold',   'int', 'NULL',   '', '', '',
        'upbytes',   'bigint', 'NULL',   '', '', '', 
        'upbytes_threshold',   'bigint', 'NULL',   '', '', '',
        'downbytes', 'bigint', 'NULL',   '', '', '',
        'downbytes_threshold',   'bigint', 'NULL',   '', '', '',
        'totalbytes','bigint', 'NULL',   '', '', '',
        'totalbytes_threshold',   'bigint', 'NULL',   '', '', '',
        'domsvc',    'int',     '', '', '', '', 
        'pbxsvc',    'int', 'NULL', '', '', '',
        'last_login',  @date_type, '', '', 
        'last_logout', @date_type, '', '', 
        #cardfortress field(s)
        'cf_privatekey',      'text', 'NULL',      '', '', '',
        #communigate pro fields (quota = MaxAccountSize)
        'cgp_aliases',     'varchar', 'NULL',     255, '', '',
        #settings
        'cgp_type',        'varchar', 'NULL', $char_d, '', '', #AccountType
        'file_quota',      'varchar', 'NULL', $char_d, '', '', #MaxWebSize
        'file_maxnum',     'varchar', 'NULL', $char_d, '', '', #MaxWebFiles
        'file_maxsize',    'varchar', 'NULL', $char_d, '', '', #MaxFileSize
        'cgp_accessmodes', 'varchar', 'NULL',     255, '', '', #AccessModes
        'password_selfchange','char', 'NULL',       1, '', '', #PWDAllowed
        'password_recover',   'char', 'NULL',       1, 'Y','', #PasswordRecovery
        'cgp_rulesallowed','varchar', 'NULL', $char_d, '', '', #RulesAllowed
        'cgp_rpopallowed',    'char', 'NULL',       1, '', '', #RPOPAllowed
        'cgp_mailtoall',      'char', 'NULL',       1, '', '', #MailToAll
        'cgp_addmailtrailer', 'char', 'NULL',       1, '', '', #AddMailTrailer
        'cgp_archiveafter',    'int', 'NULL',      '', '', '', #ArchiveMessagesAfter
        #XXX mailing lists
        #preferences
        'cgp_deletemode',     'varchar', 'NULL', $char_d, '', '',#DeleteMode
        'cgp_emptytrash',     'varchar', 'NULL', $char_d, '', '',#EmptyTrash
        'cgp_language',       'varchar', 'NULL', $char_d, '', '',#Language
        'cgp_timezone',       'varchar', 'NULL', $char_d, '', '',#TimeZone
        'cgp_skinname',       'varchar', 'NULL', $char_d, '', '',#SkinName
        'cgp_prontoskinname', 'varchar', 'NULL', $char_d, '', '',#ProntoSkinName
        'cgp_sendmdnmode',    'varchar', 'NULL', $char_d, '', '',#SendMDNMode
        #mail
        #XXX RPOP settings
      ],
      'primary_key' => 'svcnum',
      #'unique' => [ [ 'username', 'domsvc' ] ],
      'unique' => [],
      'index' => [ ['username'], ['domsvc'], ['pbxsvc'] ],
    },

    'acct_rt_transaction' => {
      'columns' => [
        'svcrtid',   'int',    '',   '', '', '', 
        'svcnum',    'int',    '',   '', '', '', 
        'transaction_id',       'int', '',   '', '', '', 
        '_date',   @date_type, '', '',
        'seconds',   'int', '',   '', '', '', #uhhhh
        'support',   'int', '',   '', '', '',
      ],
      'primary_key' => 'svcrtid',
      'unique' => [],
      'index' => [ ['svcnum', 'transaction_id'] ],
    },

    #'svc_charge' => {
    #  'columns' => [
    #    'svcnum',    'int',    '',   '',
    #    'amount',    @money_type,
    #  ],
    #  'primary_key' => 'svcnum',
    #  'unique' => [ [] ],
    #  'index' => [ [] ],
    #},

    'svc_domain' => {
      'columns' => [
        'svcnum',           'int',    '',        '', '', '',
        'domain',       'varchar',    '',   $char_d, '', '',
	'suffix',       'varchar', 'NULL',  $char_d, '', '',
        'catchall',         'int', 'NULL',       '', '', '',
	'parent_svcnum',    'int', 'NULL',       '', '', '',
	'registrarnum',     'int', 'NULL',       '', '', '',
	'registrarkey', 'varchar', 'NULL',      512, '', '',
	'setup_date',      @date_type, '', '',
	'renewal_interval', 'int', 'NULL',       '', '', '',
	'expiration_date', @date_type, '', '',
	'au_registrant_name',       'varchar', 'NULL',  $char_d, '', '',
	'au_eligibility_type',      'varchar', 'NULL',  $char_d, '', '',
        #communigate pro fields (quota = MaxAccountSize)
        'max_accounts',     'int', 'NULL',       '', '', '',
        'trailer',         'text', 'NULL',       '', '', '',
        'cgp_aliases',  'varchar', 'NULL',      255, '', '',
        'cgp_accessmodes','varchar','NULL',     255, '', '', #DomainAccessModes
        'cgp_certificatetype','varchar','NULL', $char_d, '', '',
        #settings
        'acct_def_password_selfchange',   'char', 'NULL',       1,  '', '', 
        'acct_def_password_recover',      'char', 'NULL',       1, 'Y', '', 
        'acct_def_cgp_accessmodes',    'varchar', 'NULL',     255,  '', '',
        'acct_def_quota',              'varchar', 'NULL', $char_d,  '', '',
        'acct_def_file_quota',         'varchar', 'NULL', $char_d,  '', '',
        'acct_def_file_maxnum',        'varchar', 'NULL', $char_d,  '', '',
        'acct_def_file_maxsize',       'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_rulesallowed',   'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_rpopallowed',       'char', 'NULL',       1,  '', '', 
        'acct_def_cgp_mailtoall',         'char', 'NULL',       1,  '', '', 
        'acct_def_cgp_addmailtrailer',    'char', 'NULL',       1,  '', '', 
        'acct_def_cgp_archiveafter',       'int', 'NULL',      '',  '', '',
        #preferences
        'acct_def_cgp_deletemode',     'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_emptytrash',     'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_language',       'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_timezone',       'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_skinname',       'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_prontoskinname', 'varchar', 'NULL', $char_d,  '', '',
        'acct_def_cgp_sendmdnmode',    'varchar', 'NULL', $char_d,  '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [ ],
      'index' => [ ['domain'] ],
    },
    
    'svc_dsl' => {
      'columns' => [
        'svcnum',                    'int',    '',        '', '', '',
        'pushed',                    'int', 'NULL',       '', '', '',
        'desired_due_date',          'int', 'NULL',       '', '', '',
        'due_date',                  'int', 'NULL',       '', '', '',
        'vendor_order_id',       'varchar', 'NULL', $char_d,  '', '',
        'vendor_qual_id',        'varchar', 'NULL', $char_d,  '', '',
        'vendor_order_type',     'varchar', 'NULL', $char_d,  '', '',
        'vendor_order_status',   'varchar', 'NULL', $char_d,  '', '',
        'first',                 'varchar', 'NULL', $char_d,  '', '',
        'last',                  'varchar', 'NULL', $char_d,  '', '',
        'company',               'varchar', 'NULL', $char_d,  '', '',
        'phonenum',              'varchar', 'NULL',      24, '', '',
        'gateway_access_number', 'varchar', 'NULL',      24, '', '',
        'loop_type',                'char', 'NULL',       1, '', '', 
        'local_voice_provider',  'varchar', 'NULL', $char_d, '', '',
        'circuitnum',            'varchar', 'NULL', $char_d, '', '',
        'rate_band',             'varchar', 'NULL', $char_d, '', '',
        'vpi',                       'int', 'NULL',      '', '', '',
        'vci',                       'int', 'NULL',      '', '', '',
        'isp_chg',                  'char', 'NULL',       1, '', '', 
        'isp_prev',              'varchar', 'NULL', $char_d, '', '',
        'username',              'varchar', 'NULL', $char_d, '', '',
        'password',              'varchar', 'NULL', $char_d, '', '',
        'staticips',                'text', 'NULL',      '', '', '',
        'monitored',                'char', 'NULL',       1, '', '', 
        'last_pull',                 'int', 'NULL',      '', '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [ ],
      'index' => [ ['phonenum'], ['vendor_order_id'] ],
    },

    'dsl_device' => {
      'columns' => [
        'devicenum', 'serial',     '', '', '', '',
        #part_device?  or our own part_dsl_device?
        #'devicepart',   'int',     '', '', '', '',
        'svcnum',       'int',     '', '', '', '', 
        'mac_addr', 'varchar',     '', 12, '', '', 
      ],
      'primary_key' => 'devicenum',
      'unique' => [ [ 'mac_addr' ], ],
      'index'  => [ [ 'svcnum' ], ], # [ 'devicepart' ] ],
    },
    
    'dsl_note' => {
      'columns' => [
        'notenum',           'serial',    '',        '', '', '',
	'svcnum',     'int', '',       '', '', '',
        'author',     'varchar', 'NULL', $char_d,  '', '',
        'priority',   'char', 'NULL',       1,  '', '', 
	'_date',     'int', 'NULL',       '', '', '',
	'note',     'text', '',       '', '', '',
      ],
      'primary_key' => 'notenum',
      'unique' => [ ],
      'index' => [ ['svcnum'] ],
    },

    'svc_dish' => {
      'columns' => [
        'svcnum',   'int',     '',     '', '', '',
        'acctnum',  'varchar', '',     16, '', '',
        'installdate', @date_type,         '', '', 
        'note',     'text',    'NULL', '', '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [ ],
      'index' => [ ],
    },

    'svc_hardware' => {
      'columns' => [
        'svcnum',   'int',     '',          '', '', '',
        'typenum',  'int',     '',          '', '', '',
        'serial',   'varchar', 'NULL', $char_d, '', '',
        'ip_addr',  'varchar', 'NULL',      40, '', '',
        'hw_addr',  'varchar', 'NULL',      12, '', '',
        'smartcard','varchar', 'NULL',      30, '', '',
        'statusnum','int',     'NULL',      '', '', '',
        'note',     'text',    'NULL',      '', '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [ ],
      'index' => [ ],
    },

    'hardware_class' => {
      'columns' => [
        'classnum',   'serial', '',      '', '', '',
        'classname', 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'classnum',
      'unique' => [ ],
      'index'  => [ ],
    },

    'hardware_type' => {
      'columns' => [
        'typenum',  'serial', '',      '', '', '',
        'classnum',    'int', '',      '', '', '',
        'model',   'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'typenum',
      'unique' => [ ],
      'index'  => [ ],
    },

    'hardware_status' => {
      'columns' => [
        'statusnum', 'serial', '',      '', '', '',
        'label'    ,'varchar', '', $char_d, '', '',
        'disabled',    'char', 'NULL',   1, '', '', 
      ],
      'primary_key' => 'statusnum',
      'unique' => [ ],
      'index'  => [ ],
    },

    'domain_record' => {
      'columns' => [
        'recnum',    'serial',     '',  '', '', '', 
        'svcnum',    'int',     '',  '', '', '', 
        'reczone',   'varchar', '',  255, '', '', 
        'recaf',     'char',    '',  2, '', '', 
        'rectype',   'varchar',    '',  5, '', '', 
        'recdata',   'varchar', '',  255, '', '', 
        'ttl',       'int',     'NULL', '', '', '',
      ],
      'primary_key' => 'recnum',
      'unique'      => [],
      'index'       => [ ['svcnum'] ],
    },

    'registrar' => {
      'columns' => [
        'registrarnum',   'serial', '',      '', '', '',
	'registrarname', 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'registrarnum',
      'unique'      => [],
      'index'       => [],
    },

    'cgp_rule' => {
      'columns' => [
        'rulenum',  'serial',     '',      '', '', '',
        'name',    'varchar',     '', $char_d, '', '',
        'comment', 'varchar', 'NULL', $char_d, '', '',
        'svcnum',      'int',     '',      '', '', '',
        'priority',    'int',     '',      '', '', '',
      ],
      'primary_key' => 'rulenum',
      'unique'      => [ [ 'svcnum', 'name' ] ],
      'index'       => [ [ 'svcnum' ] ],
    },

    'cgp_rule_condition' => {
      'columns' => [
        'ruleconditionnum',  'serial',     '',      '', '', '',
        'conditionname',    'varchar',     '', $char_d, '', '',
        'op',               'varchar', 'NULL', $char_d, '', '',
        'params',           'varchar', 'NULL',     255, '', '',
        'rulenum',              'int',     '',      '', '', '',
      ],
      'primary_key' => 'ruleconditionnum',
      'unique'      => [],
      'index'       => [ [ 'rulenum' ] ],
    },

    'cgp_rule_action' => {
       'columns' => [
        'ruleactionnum',  'serial',     '',      '', '', '',
        'action',        'varchar',     '', $char_d, '', '',
        'params',        'varchar', 'NULL',     255, '', '',
        'rulenum',           'int',     '',      '', '', '',
      ],
      'primary_key' => 'ruleactionnum',
      'unique'      => [],
      'index'       => [ [ 'rulenum' ] ],
   },

    'svc_forward' => {
      'columns' => [
        'svcnum',   'int',            '',   '', '', '', 
        'srcsvc',   'int',        'NULL',   '', '', '', 
        'src',      'varchar',    'NULL',  255, '', '', 
        'dstsvc',   'int',        'NULL',   '', '', '', 
        'dst',      'varchar',    'NULL',  255, '', '', 
      ],
      'primary_key' => 'svcnum',
      'unique'      => [],
      'index'       => [ ['srcsvc'], ['dstsvc'] ],
    },

    'svc_www' => {
      'columns' => [
        'svcnum',   'int',      '',  '', '', '', 
        'recnum',   'int',      '',  '', '', '', 
        'usersvc',  'int',  'NULL',  '', '', '', 
        'config',   'text', 'NULL',  '', '', '', 
      ],
      'primary_key' => 'svcnum',
      'unique'      => [],
      'index'       => [],
    },

    #'svc_wo' => {
    #  'columns' => [
    #    'svcnum',    'int',    '',   '',
    #    'svcnum',    'int',    '',   '',
    #    'svcnum',    'int',    '',   '',
    #    'worker',    'varchar',   '',   $char_d,
    #    '_date',     @date_type,
    #  ],
    #  'primary_key' => 'svcnum',
    #  'unique' => [ [] ],
    #  'index' => [ [] ],
    #},

    'prepay_credit' => {
      'columns' => [
        'prepaynum',   'serial',     '',   '', '', '', 
        'identifier',  'varchar', '', $char_d, '', '', 
        'amount',      @money_type, '', '', 
        'seconds',     'int',     'NULL', '', '', '', 
        'upbytes',     'bigint',     'NULL', '', '', '', 
        'downbytes',   'bigint',     'NULL', '', '', '', 
        'totalbytes',  'bigint',     'NULL', '', '', '', 
        'agentnum',    'int',     'NULL', '', '', '', 
      ],
      'primary_key' => 'prepaynum',
      'unique'      => [ ['identifier'] ],
      'index'       => [],
    },

    'port' => {
      'columns' => [
        'portnum',  'serial',     '',   '', '', '', 
        'ip',       'varchar', 'NULL', 15, '', '', 
        'nasport',  'int',     'NULL', '', '', '', 
        'nasnum',   'int',     '',   '', '', '', 
      ],
      'primary_key' => 'portnum',
      'unique'      => [],
      'index'       => [],
    },

    'nas' => {
      'columns' => [
        'nasnum',       'serial',     '',  '',              '', '', 
        'nasname',     'varchar',     '', 128,              '', '',
        'shortname',   'varchar', 'NULL',  32,              '', '',
        'type',        'varchar',     '',  30,         'other', '',
        'ports',           'int', 'NULL',  '',              '', '',
        'secret',      'varchar',     '',  60,        'secret', '',
        'server',      'varchar', 'NULL',  64,              '', '',
        'community',   'varchar', 'NULL',  50,              '', '',
        'description', 'varchar',     '', 200, 'RADIUS Client', '',
        'svcnum',          'int', 'NULL',  '',              '', '',
      ],
      'primary_key' => 'nasnum',
      'unique'      => [ [ 'nasname' ], ],
      'index'       => [],
    },

    'export_nas' => {
      'columns' => [
        'exportnasnum', 'serial', '', '', '', '', 
        'exportnum',       'int', '', '', '', '', 
        'nasnum',          'int', '', '', '', '', 
      ],
      'primary_key' => 'exportnasnum',
      'unique'      => [ [ 'exportnum', 'nasnum' ] ],
      'index'       => [ [ 'exportnum' ], [ 'nasnum' ] ],
    },

    'queue' => {
      'columns' => [
        'jobnum',      'serial',     '',      '', '', '', 
        'job',        'varchar',     '',     512, '', '', 
        '_date',          'int',     '',      '', '', '', 
        'status',     'varchar',     '', $char_d, '', '', 
        'statustext',    'text', 'NULL',      '', '', '', 
        'svcnum',         'int', 'NULL',      '', '', '', 
        'custnum',        'int', 'NULL',      '', '', '',
        'secure',        'char', 'NULL',       1, '', '',
        'priority',       'int', 'NULL',      '', '', '',
      ],
      'primary_key' => 'jobnum',
      'unique'      => [],
      'index'       => [ [ 'secure' ], [ 'priority' ],
                         [ 'job' ], [ 'svcnum' ], [ 'custnum' ], [ 'status' ],
                       ],
    },

    'queue_arg' => {
      'columns' => [
        'argnum', 'serial', '', '', '', '', 
        'jobnum', 'int', '', '', '', '', 
        'frozen', 'char', 'NULL',       1, '', '',
        'arg', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'argnum',
      'unique'      => [],
      'index'       => [ [ 'jobnum' ] ],
    },

    'queue_depend' => {
      'columns' => [
        'dependnum', 'serial', '', '', '', '', 
        'jobnum', 'int', '', '', '', '', 
        'depend_jobnum', 'int', '', '', '', '', 
      ],
      'primary_key' => 'dependnum',
      'unique'      => [],
      'index'       => [ [ 'jobnum' ], [ 'depend_jobnum' ] ],
    },

    'export_svc' => {
      'columns' => [
        'exportsvcnum' => 'serial', '', '', '', '', 
        'exportnum'    => 'int', '', '', '', '', 
        'svcpart'      => 'int', '', '', '', '', 
      ],
      'primary_key' => 'exportsvcnum',
      'unique'      => [ [ 'exportnum', 'svcpart' ] ],
      'index'       => [ [ 'exportnum' ], [ 'svcpart' ] ],
    },

    'export_device' => {
      'columns' => [
        'exportdevicenum' => 'serial', '', '', '', '', 
        'exportnum'    => 'int', '', '', '', '', 
        'devicepart'      => 'int', '', '', '', '', 
      ],
      'primary_key' => 'exportdevicenum',
      'unique'      => [ [ 'exportnum', 'devicepart' ] ],
      'index'       => [ [ 'exportnum' ], [ 'devicepart' ] ],
    },

    'part_export' => {
      'columns' => [
        'exportnum', 'serial', '', '', '', '', 
        'exportname', 'varchar', 'NULL', $char_d, '', '',
        'machine', 'varchar', '', $char_d, '', '', 
        'exporttype', 'varchar', '', $char_d, '', '', 
        'nodomain',     'char', 'NULL', 1, '', '', 
      ],
      'primary_key' => 'exportnum',
      'unique'      => [],
      'index'       => [ [ 'machine' ], [ 'exporttype' ] ],
    },

    'part_export_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'exportnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'exportnum' ], [ 'optionname' ] ],
    },

    'radius_usergroup' => {
      'columns' => [
        'usergroupnum', 'serial', '', '', '', '', 
        'svcnum',       'int', '', '', '', '', 
        'groupname',    'varchar', 'NULL', $char_d, '', '', 
        'groupnum',     'int', 'NULL', '', '', '', 
      ],
      'primary_key' => 'usergroupnum',
      'unique'      => [],
      'index'       => [ [ 'svcnum' ], [ 'groupname' ] ],
    },
    
    'radius_group' => {
      'columns' => [
        'groupnum', 'serial', '', '', '', '', 
        'groupname',    'varchar', '', $char_d, '', '', 
        'description',  'varchar', 'NULL', $char_d, '', '', 
        'priority', 'int', '', '', '1', '',
      ],
      'primary_key' => 'groupnum',
      'unique'      => [ ['groupname'] ],
      'index'       => [],
    },

    'radius_attr' => {
      'columns' => [
        'attrnum',   'serial', '', '', '', '',
        'groupnum',     'int', '', '', '', '',
        'attrname', 'varchar', '', $char_d, '', '',
        'value',    'varchar', '', $char_d, '', '',
        'attrtype',    'char', '', 1, '', '',
        'op',          'char', '', 2, '', '',
      ],
      'primary_key' => 'attrnum',
      'unique'      => [ ['groupnum','attrname'] ], #?
      'index'       => [],
    },

    'msgcat' => {
      'columns' => [
        'msgnum', 'serial', '', '', '', '', 
        'msgcode', 'varchar', '', 255, '', '', 
        'locale', 'varchar', '', 16, '', '', 
        'msg', 'text', '', '', '', '', 
      ],
      'primary_key' => 'msgnum',
      'unique'      => [ [ 'msgcode', 'locale' ] ],
      'index'       => [],
    },

    'cust_tax_exempt' => {
      'columns' => [
        'exemptnum', 'serial', '', '', '', '', 
        'custnum',   'int', '', '', '', '', 
        'taxnum',    'int', '', '', '', '', 
        'year',      'int', '', '', '', '', 
        'month',     'int', '', '', '', '', 
        'amount',   @money_type, '', '', 
      ],
      'primary_key' => 'exemptnum',
      'unique'      => [ [ 'custnum', 'taxnum', 'year', 'month' ] ],
      'index'       => [],
    },

    'cust_tax_exempt_pkg' => {
      'columns' => [
        'exemptpkgnum',  'serial', '', '', '', '', 
        #'custnum',      'int', '', '', '', ''
        'billpkgnum',   'int', '', '', '', '', 
        'taxnum',       'int', '', '', '', '', 
        'year',         'int', '', '', '', '', 
        'month',        'int', '', '', '', '', 
        'creditbillpkgnum', 'int', 'NULL', '', '', '',
        'amount',       @money_type, '', '', 
      ],
      'primary_key' => 'exemptpkgnum',
      'unique' => [],
      'index'  => [ [ 'taxnum', 'year', 'month' ],
                    [ 'billpkgnum' ],
                    [ 'taxnum' ],
                    [ 'creditbillpkgnum' ],
                  ],
    },

    'router' => {
      'columns' => [
        'routernum', 'serial', '', '', '', '', 
        'routername', 'varchar', '', $char_d, '', '', 
        'svcnum', 'int', 'NULL', '', '', '', 
        'agentnum',   'int', 'NULL', '', '', '', 
      ],
      'primary_key' => 'routernum',
      'unique'      => [],
      'index'       => [],
    },

    'part_svc_router' => {
      'columns' => [
        'svcrouternum', 'serial', '', '', '', '', 
        'svcpart', 'int', '', '', '', '', 
	'routernum', 'int', '', '', '', '', 
      ],
      'primary_key' => 'svcrouternum',
      'unique'      => [],
      'index'       => [],
    },

    'addr_block' => {
      'columns' => [
        'blocknum', 'serial', '', '', '', '', 
	'routernum', 'int', '', '', '', '', 
        'ip_gateway', 'varchar', '', 15, '', '', 
        'ip_netmask', 'int', '', '', '', '', 
        'agentnum',   'int', 'NULL', '', '', '', 
        'manual_flag', 'char', 'NULL', 1, '', '', 
      ],
      'primary_key' => 'blocknum',
      'unique'      => [ [ 'blocknum', 'routernum' ] ],
      'index'       => [],
    },

    'svc_broadband' => {
      'columns' => [
        'svcnum',                  'int',     '',      '', '', '', 
        'description',         'varchar', 'NULL', $char_d, '', '', 
        'blocknum',                'int', 'NULL',      '', '', '', 
        'sectornum',               'int', 'NULL',      '', '', '',
        'speed_up',                'int', 'NULL',      '', '', '', 
        'speed_down',              'int', 'NULL',      '', '', '', 
        'ip_addr',             'varchar', 'NULL',      15, '', '', 
        'mac_addr',            'varchar', 'NULL',      12, '', '', 
        'authkey',             'varchar', 'NULL',      32, '', '', 
        'latitude',            'decimal', 'NULL',  '10,7', '', '', 
        'longitude',           'decimal', 'NULL',  '10,7', '', '', 
        'altitude',            'decimal', 'NULL',      '', '', '', 
        'vlan_profile',        'varchar', 'NULL', $char_d, '', '', 
        'performance_profile', 'varchar', 'NULL', $char_d, '', '',
        'plan_id',             'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key' => 'svcnum',
      'unique'      => [ [ 'mac_addr' ] ],
      'index'       => [],
    },

    'tower' => {
      'columns' => [
        'towernum',   'serial',     '',      '', '', '',
        #'agentnum',      'int', 'NULL',      '', '', '',
        'towername', 'varchar',     '', $char_d, '', '',
        'disabled',     'char', 'NULL',       1, '', '',
        'latitude', 'decimal', 'NULL',   '10,7', '', '', 
        'longitude','decimal', 'NULL',   '10,7', '', '', 
        'altitude', 'decimal', 'NULL',       '', '', '', 
        'coord_auto',  'char', 'NULL',        1, '', '',
      ],
      'primary_key' => 'towernum',
      'unique'      => [ [ 'towername' ] ], # , 'agentnum' ] ],
      'index'       => [],
    },

    'tower_sector' => {
      'columns' => [
        'sectornum',   'serial',     '',      '', '', '',
        'towernum',       'int',     '',      '', '', '',
        'sectorname', 'varchar',     '', $char_d, '', '',
        'ip_addr',    'varchar', 'NULL',      15, '', '',
      ],
      'primary_key' => 'sectornum',
      'unique'      => [ [ 'towernum', 'sectorname' ], [ 'ip_addr' ], ],
      'index'       => [ [ 'towernum' ] ],
    },

    'part_virtual_field' => {
      'columns' => [
        'vfieldpart', 'serial', '', '', '', '', 
        'dbtable', 'varchar', '', 32, '', '', 
        'name', 'varchar', '', 32, '', '', 
        'length', 'int', 'NULL', '', '', '', 
        'label', 'varchar', 'NULL', 80, '', '', 
      ],
      'primary_key' => 'vfieldpart',
      'unique' => [],
      'index' => [],
    },

    'virtual_field' => {
      'columns' => [
        'vfieldnum', 'serial', '', '', '', '', 
        'recnum', 'int', '', '', '', '', 
        'vfieldpart', 'int', '', '', '', '', 
        'value', 'varchar', '', 128, '', '', 
      ],
      'primary_key' => 'vfieldnum',
      'unique' => [ [ 'vfieldpart', 'recnum' ] ],
      'index' => [],
    },

    'acct_snarf' => {
      'columns' => [
        'snarfnum',    'serial',     '',      '', '', '', 
        'snarfname',  'varchar', 'NULL', $char_d, '', '', 
        'svcnum',         'int',     '',      '', '', '', 
        'machine',    'varchar',     '',     255, '', '', 
        'protocol',   'varchar',     '', $char_d, '', '', 
        'username',   'varchar',     '', $char_d, '', '', 
        '_password',  'varchar',     '', $char_d, '', '', 
        'check_freq',     'int', 'NULL',      '', '', '', 
        'leavemail',     'char', 'NULL',       1, '', '', 
        'apop',          'char', 'NULL',       1, '', '', 
        'tls',           'char', 'NULL',       1, '', '', 
        'mailbox',    'varchar', 'NULL', $char_d, '', '', 
      ],
      'primary_key' => 'snarfnum',
      'unique' => [],
      'index'  => [ [ 'svcnum' ] ],
    },

    'svc_external' => {
      'columns' => [
        'svcnum',     'int',     '',      '', '', '', 
        'id',      'bigint', 'NULL',      '', '', '', 
        'title',  'varchar', 'NULL', $char_d, '', '', 
      ],
      'primary_key' => 'svcnum',
      'unique'      => [],
      'index'       => [],
    },

    'cust_pay_refund' => {
      'columns' => [
        'payrefundnum', 'serial', '', '', '', '', 
        'paynum',  'int', '', '', '', '', 
        'refundnum',  'int', '', '', '', '', 
        '_date',    @date_type, '', '', 
        'amount',   @money_type, '', '', 
      ],
      'primary_key' => 'payrefundnum',
      'unique' => [],
      'index' => [ ['paynum'], ['refundnum'] ],
    },

    'part_pkg_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'pkgpart', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'pkgpart' ], [ 'optionname' ] ],
    },

    'part_pkg_vendor' => {
      'columns' => [
        'num', 'serial', '', '', '', '', 
        'pkgpart', 'int', '', '', '', '', 
        'exportnum', 'int', '', '', '', '', 
        'vendor_pkg_id', 'varchar', '', $char_d, '', '', 
      ],
      'primary_key' => 'num',
      'unique' => [ [ 'pkgpart', 'exportnum' ] ],
      'index'       => [ [ 'pkgpart' ] ],
    },
    
    'part_pkg_report_option' => {
      'columns' => [
        'num',      'serial',   '',      '', '', '', 
        'name',     'varchar',  '', $char_d, '', '', 
        'disabled', 'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'num',
      'unique' => [ [ 'name' ] ],
      'index' => [ [ 'disabled' ] ],
    },

    'rate' => {
      'columns' => [
        'ratenum',  'serial', '', '', '', '', 
        'ratename', 'varchar', '', $char_d, '', '', 
      ],
      'primary_key' => 'ratenum',
      'unique'      => [],
      'index'       => [],
    },

    'rate_detail' => {
      'columns' => [
        'ratedetailnum',   'serial',  '',     '',      '', '', 
        'ratenum',         'int',     '',     '',      '', '', 
        'orig_regionnum',  'int', 'NULL',     '',      '', '', 
        'dest_regionnum',  'int',     '',     '',      '', '', 
        'min_included',    'int',     '',     '',      '', '', 
        'conn_charge',     'decimal', '', '10,4', '0.0000', '',
        'conn_sec',        'int',     '',     '',      '0', '',
        'min_charge',      'decimal', '', '10,5',       '', '',
        'sec_granularity', 'int',     '',     '',       '', '', 
        'ratetimenum',     'int', 'NULL',     '',       '', '',
        'classnum',        'int', 'NULL',     '',       '', '', 
        'cdrtypenum',      'int', 'NULL',     '',       '', '',
        'region_group', 'char', 'NULL',        1,       '', '', 
      ],
      'primary_key' => 'ratedetailnum',
      'unique'      => [ [ 'ratenum', 'orig_regionnum', 'dest_regionnum' ] ],
      'index'       => [ [ 'ratenum', 'dest_regionnum' ],
                         [ 'ratenum', 'ratetimenum' ]
                       ],
    },

    'rate_region' => {
      'columns' => [
        'regionnum',   'serial',      '', '', '', '', 
        'regionname',  'varchar',     '', $char_d, '', '', 
      ],
      'primary_key' => 'regionnum',
      'unique'      => [],
      'index'       => [],
    },

    'rate_prefix' => {
      'columns' => [
        'prefixnum',   'serial',      '', '', '', '', 
        'regionnum',   'int',         '', '', '', '', 
        'countrycode', 'varchar',     '',  3, '', '', 
        'npa',         'varchar', 'NULL', 10, '', '', #actually the whole prefix
        'nxx',         'varchar', 'NULL',  3, '', '', #actually not used
        'latanum',     'int',     'NULL',      '', '', '',
        'state',       'char',    'NULL',       2, '', '', 
        'ocn',         'char',    'NULL',       4, '', '', 
      ],
      'primary_key' => 'prefixnum',
      'unique'      => [],
      'index'       => [ [ 'countrycode' ], [ 'npa' ], [ 'regionnum' ] ],
    },

    'rate_time' => {
      'columns' => [
        'ratetimenum', 'serial',      '',      '', '', '',
        'ratetimename',   'varchar',      '', $char_d, '', '',
      ],
      'primary_key' => 'ratetimenum',
      'unique'      => [],
      'index'       => [],
    },

    'rate_time_interval' => {
      'columns' => [
        'intervalnum', 'serial', '', '', '', '',
        'stime',          'int', '', '', '', '',
        'etime',          'int', '', '', '', '',
        'ratetimenum',    'int', '', '', '', '',
      ],
      'primary_key' => 'intervalnum',
      'unique'      => [],
      'index'       => [],
    },

    #not really part of the above rate_ stuff (used with flat rate rather than
    # rated billing), but could be eventually, and its a rate
    'rate_tier' => {
      'columns' => [
        'tiernum',   'serial', '',      '', '', '',
        'tiername', 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'tiernum',
      'unique'      => [ [ 'tiername'], ],
      'index'       => [],
    },

    'rate_tier_detail' => {
      'columns' => [
        'tierdetailnum', 'serial', '',     '', '', '',
        'tiernum',          'int', '',     '', '', '',
        'min_quan',         'int', '',     '', '', '',
        'min_charge',   'decimal', '', '10,4', '', '',
      ],
      'primary_key' => 'tierdetailnum',
      'unique'      => [],
      'index'       => [ ['tiernum'], ],
    },

    'usage_class' => {
      'columns' => [
        'classnum',    'serial',      '',      '', '', '', 
        'weight',      'int',     'NULL',      '', '', '',
        'classname',   'varchar',     '', $char_d, '', '', 
        'format',      'varchar', 'NULL', $char_d, '', '', 
        'disabled',    'char',    'NULL',       1, '', '', 
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },

    'reg_code' => {
      'columns' => [
        'codenum',   'serial',    '', '', '', '', 
        'code',      'varchar',   '', $char_d, '', '', 
        'agentnum',  'int',       '', '', '', '', 
      ],
      'primary_key' => 'codenum',
      'unique'      => [ [ 'agentnum', 'code' ] ],
      'index'       => [ [ 'agentnum' ] ],
    },

    'reg_code_pkg' => {
      'columns' => [
        'codepkgnum', 'serial', '', '', '', '', 
        'codenum',   'int',    '', '', '', '', 
        'pkgpart',   'int',    '', '', '', '', 
      ],
      'primary_key' => 'codepkgnum',
      'unique'      => [ [ 'codenum', 'pkgpart' ] ],
      'index'       => [ [ 'codenum' ] ],
    },

    'clientapi_session' => {
      'columns' => [
        'sessionnum',  'serial',  '', '', '', '', 
        'sessionid',  'varchar',  '', $char_d, '', '', 
        'namespace',  'varchar',  '', $char_d, '', '', 
      ],
      'primary_key' => 'sessionnum',
      'unique'      => [ [ 'sessionid', 'namespace' ] ],
      'index'       => [],
    },

    'clientapi_session_field' => {
      'columns' => [
        'fieldnum',    'serial',     '', '', '', '', 
        'sessionnum',     'int',     '', '', '', '', 
        'fieldname',  'varchar',     '', $char_d, '', '', 
        'fieldvalue',    'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'fieldnum',
      'unique'      => [ [ 'sessionnum', 'fieldname' ] ],
      'index'       => [],
    },

    'payment_gateway' => {
      'columns' => [
        'gatewaynum',       'serial',   '',     '', '', '', 
        'gateway_namespace','varchar',  'NULL', $char_d, '', '', 
        'gateway_module',   'varchar',  '',     $char_d, '', '', 
        'gateway_username', 'varchar',  'NULL', $char_d, '', '', 
        'gateway_password', 'varchar',  'NULL', $char_d, '', '', 
        'gateway_action',   'varchar',  'NULL', $char_d, '', '', 
        'gateway_callback_url', 'varchar',  'NULL', $char_d, '', '', 
        'disabled',   'char',  'NULL',   1, '', '', 
      ],
      'primary_key' => 'gatewaynum',
      'unique' => [],
      'index'  => [ [ 'disabled' ] ],
    },

    'payment_gateway_option' => {
      'columns' => [
        'optionnum',   'serial',  '',     '', '', '', 
        'gatewaynum',  'int',     '',     '', '', '', 
        'optionname',  'varchar', '',     $char_d, '', '', 
        'optionvalue', 'text',    'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'gatewaynum' ], [ 'optionname' ] ],
    },

    'agent_payment_gateway' => {
      'columns' => [
        'agentgatewaynum', 'serial', '', '', '', '', 
        'agentnum',        'int', '', '', '', '', 
        'gatewaynum',      'int', '', '', '', '', 
        'cardtype',        'varchar', 'NULL', $char_d, '', '', 
        'taxclass',        'varchar', 'NULL', $char_d, '', '', 
      ],
      'primary_key' => 'agentgatewaynum',
      'unique'      => [],
      'index'       => [ [ 'agentnum', 'cardtype' ], ],
    },

    'banned_pay' => {
      'columns' => [
        'bannum',  'serial',   '',     '', '', '', 
        'payby',   'char',     '',       4, '', '', 
        'payinfo', 'varchar',  '',     128, '', '', #say, a 512-big digest _hex encoded
	#'paymask', 'varchar',  'NULL', $char_d, '', ''
        '_date',            @date_type,         '', '', 
        'end_date',         @date_type,         '', '', 
        'otaker',  'varchar',  'NULL',      32, '', '', 
        'usernum',     'int',  'NULL',      '', '', '',
        'bantype', 'varchar',  'NULL', $char_d, '', '',
        'reason',  'varchar',  'NULL', $char_d, '', '', 
      ],
      'primary_key' => 'bannum',
      'unique'      => [],
      'index'       => [ [ 'payby', 'payinfo' ], [ 'usernum' ], ],
    },

    'pkg_category' => {
      'columns' => [
        'categorynum',   'serial',  '', '', '', '', 
        'categoryname',  'varchar', '', $char_d, '', '', 
        'weight',         'int', 'NULL',  '', '', '',
        'condense',      'char', 'NULL',   1, '', '', 
        'disabled',      'char', 'NULL',   1, '', '', 
      ],
      'primary_key' => 'categorynum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },

    'pkg_class' => {
      'columns' => [
        'classnum',    'serial',   '',      '', '', '', 
        'classname',   'varchar',  '', $char_d, '', '', 
        'categorynum', 'int',  'NULL',      '', '', '', 
        'disabled',    'char', 'NULL',       1, '', '', 
        'fcc_ds0s',      'int',     'NULL', '', '', '', 
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },

    'cdr' => {
      'columns' => [
        # qw( name type null length default local );

        ###
        #asterisk fields
        ###

        'acctid',   'bigserial',  '', '', '', '', 
        #'calldate', 'TIMESTAMP with time zone', '', '', \'now()', '',
        'calldate', 'timestamp',   '',      '', \'now()', '',
        'clid',        'varchar',  '', $char_d, \"''", '', 
        'src',         'varchar',  '', $char_d, \"''", '', 
        'dst',         'varchar',  '', $char_d, \"''", '', 
        'dcontext',    'varchar',  '', $char_d, \"''", '', 
        'channel',     'varchar',  '', $char_d, \"''", '', 
        'dstchannel',  'varchar',  '', $char_d, \"''", '', 
        'lastapp',     'varchar',  '', $char_d, \"''", '', 
        'lastdata',    'varchar',  '', $char_d, \"''", '', 

        #these don't seem to be logged by most of the SQL cdr_* modules
        #except tds under sql-illegal names, so;
        # ... don't rely on them for rating?
        # and, what they hey, i went ahead and changed the names and data types
        # to freeside-style dates...
          #'start',  'timestamp', 'NULL',  '',    '', '',
          #'answer', 'timestamp', 'NULL',  '',    '', '',
          #'end',    'timestamp', 'NULL',  '',    '', '',
        'startdate',  @date_type, '', '', 
        'answerdate', @date_type, '', '', 
        'enddate',    @date_type, '', '', 
        #

        'duration',    'int',      '',      '',     0, '',
        'billsec',     'int',      '',      '',     0, '', 
        'disposition', 'varchar',  '',      45, \"''", '',
        'amaflags',    'int',      '',      '',     0, '',
        'accountcode', 'varchar',  '',      20, \"''", '',
        'uniqueid',    'varchar',  '', $char_d, \"''", '',
        'userfield',   'varchar',  '',     512, \"''", '',

        'max_callers', 'int',  'NULL',      '',    '', '',

        ###
        # old fields for unitel/RSLCOM/convergent that don't map to asterisk
        # ones we adoped moved to "own fields" section below
        # charged_party, upstream_price, rated_price, carrierid, cdrtypenum
        ###

        'upstream_currency',      'char', 'NULL',       3, '', '',
        'upstream_price',      'decimal', 'NULL',  '10,4', '', '', 
        'upstream_rateplanid',     'int', 'NULL',      '', '', '', #?

        # how it was rated internally...
        'ratedetailnum',           'int', 'NULL',      '', '', '',

        'distance',            'decimal', 'NULL',      '', '', '',
        'islocal',                 'int', 'NULL',      '', '', '', # '',  '', 0, '' instead?

        #cdr_calltype: the big list in appendix 2
        'calltypenum',             'int', 'NULL',      '', '', '',

        'description',         'varchar', 'NULL', $char_d, '', '',
        'quantity',                'int', 'NULL',      '', '', '', 

        'upstream_rateid',         'int', 'NULL',      '', '', '',
        
        ###
        #and now for our own fields
        ###

        'cdrtypenum',              'int', 'NULL',      '', '', '',

        'charged_party',       'varchar', 'NULL', $char_d, '', '',

        # how it was rated internally...
        'rated_price',         'decimal', 'NULL',  '10,4', '', '',
        'rated_seconds',           'int', 'NULL',      '', '', '',
        'rated_minutes', 'double precision', 'NULL',   '', '', '',

        'carrierid',               'int', 'NULL',      '', '', '',

        # service it was matched to
        'svcnum',             'int',   'NULL',     '',   '', '', 

        #NULL, done (or something)
        'freesidestatus', 'varchar',   'NULL',     32,   '', '', 

        #NULL, done (or something)
        'freesiderewritestatus', 'varchar',   'NULL',     32,   '', '', 

        #an indexed place to put big numbers
        'cdrid',         'bigint',     'NULL',     '',  '', '', 

        #for taqua accountcode rewriting, for starters
        'sessionnum',       'int',    'NULL',      '', '', '',
        'subscriber',   'varchar',    'NULL', $char_d, '', '',

        #old
        'cdrbatch',     'varchar',    'NULL',     255, '', '',
        #new
        'cdrbatchnum',      'int',    'NULL',      '', '', '',

      ],
      'primary_key' => 'acctid',
      'unique' => [],
      'index' => [ [ 'calldate' ],
                   [ 'src' ], [ 'dst' ], [ 'dcontext' ], [ 'charged_party' ],
                   [ 'lastapp' ],
                   ['accountcode'], ['uniqueid'], ['carrierid'], ['cdrid'],
                   [ 'sessionnum' ], [ 'subscriber' ],
                   [ 'freesidestatus' ], [ 'freesiderewritestatus' ],
                   [ 'cdrbatch' ], [ 'cdrbatchnum' ],
                 ],
    },

    'cdr_batch' => {
      'columns' => [
        'cdrbatchnum',   'serial',    '',   '', '', '', 
        'cdrbatch', 'varchar', 'NULL', 255, '', '',
        '_date',     @date_type, '', '', 
      ],
      'primary_key' => 'cdrbatchnum',
      'unique' => [ [ 'cdrbatch' ] ],
      'index' => [],
    },

    'cdr_termination' => {
      'columns' => [
        'cdrtermnum', 'bigserial',     '',      '', '', '',
        'acctid',        'bigint',     '',      '', '', '', 
        'termpart',         'int',     '',      '', '', '',#future use see below
        'rated_price',  'decimal', 'NULL',  '10,4', '', '',
        'rated_seconds',    'int', 'NULL',      '', '', '',
        'rated_minutes', 'double precision', 'NULL',   '', '', '',
        'status',       'varchar', 'NULL',      32, '', '',
        'svcnum',           'int', 'NULL',      '', '', '',
      ],
      'primary_key' => 'cdrtermnum',
      'unique'      => [ [ 'acctid', 'termpart' ] ],
      'index'       => [ [ 'acctid' ], [ 'status' ], ],
    },

    #to handle multiple termination/settlement passes...
   # 'part_termination' => {
   #   'columns' => [
   #     'termpart',       'int', '',      '', '', '',
   #     'termname',   'varchar', '', $char_d, '', '',
   #     'cdr_column', 'varchar', '', $char_d, '', '', #maybe set it here instead of in the price plan?
   #   ],
   #   'primary_key' => 'termpart',
   #   'unique' => [],
   #   'index'  => [],
   # },

    #the remaining cdr_ tables are not really used
    'cdr_calltype' => {
      'columns' => [
        'calltypenum',   'serial',  '', '', '', '', 
        'calltypename',  'varchar', '', $char_d, '', '', 
      ],
      'primary_key' => 'calltypenum',
      'unique'      => [],
      'index'       => [],
    },

    'cdr_type' => {
      'columns' => [
        'cdrtypenum'  => 'serial',  '', '', '', '',
        'cdrtypename' => 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'cdrtypenum',
      'unique'      => [],
      'index'       => [],
    },

    'cdr_carrier' => {
      'columns' => [
        'carrierid'   => 'serial',  '', '', '', '',
        'carriername' => 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'carrierid',
      'unique'      => [],
      'index'       => [],
    },

    #'cdr_file' => {
    #  'columns' => [
    #    'filenum',    'serial',     '', '', '', '',
    #    'filename',  'varchar',     '', '', '', '',
    #    'status',    'varchar', 'NULL', '', '', '',
    #  ],
    #  'primary_key' => 'filenum',
    #  'unique' => [ [ 'filename' ], ], #just change the index if we need to
    #                                   # agent-virtualize or have a customer
    #                                   # with dup-filename needs or something
    #                                   # (only used by cdr.http_and_import for
    #                                   #  chrissakes)
    #  'index'  => [],
    #},

    'inventory_item' => {
      'columns' => [
        'itemnum',  'serial',      '',      '', '', '',
        'classnum', 'int',         '',      '', '', '',
        'agentnum', 'int',     'NULL',      '', '', '',
        'item',     'varchar',     '', $char_d, '', '',
        'svcnum',   'int',     'NULL',      '', '', '',
      ],
      'primary_key' => 'itemnum',
      'unique' => [ [ 'classnum', 'item' ] ],
      'index'  => [ [ 'classnum' ], [ 'agentnum' ], [ 'svcnum' ] ],
    },

    'inventory_class' => {
      'columns' => [
        'classnum',  'serial',       '',      '', '', '',
        'classname', 'varchar',      '', $char_d, '', '',
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index'  => [],
    },

    'access_user' => {
      'columns' => [
        'usernum',   'serial',  '',      '', '', '',
        'username',  'varchar', '', $char_d, '', '',
        '_password', 'varchar', '', $char_d, '', '',
        'last',      'varchar', '', $char_d, '', '', 
        'first',     'varchar', '', $char_d, '', '', 
        'user_custnum',  'int', 'NULL',  '', '', '',
        'disabled',     'char', 'NULL',   1, '', '', 
      ],
      'primary_key' => 'usernum',
      'unique' => [ [ 'username' ] ],
      'index'  => [ [ 'user_custnum' ] ],
    },

    'access_user_pref' => {
      'columns' => [
        'prefnum',    'serial',       '', '', '', '',
        'usernum',     'int',       '', '', '', '',
        'prefname', 'varchar', '', $char_d, '', '', 
        'prefvalue', 'text', 'NULL', '', '', '', 
        'expiration', @date_type, '', '',
      ],
      'primary_key' => 'prefnum',
      'unique' => [],
      'index'  => [ [ 'usernum' ] ],
    },

    'access_group' => {
      'columns' => [
        'groupnum',   'serial', '',      '', '', '',
        'groupname', 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'groupnum',
      'unique' => [ [ 'groupname' ] ],
      'index'  => [],
    },

    'access_usergroup' => {
      'columns' => [
        'usergroupnum', 'serial', '', '', '', '',
        'usernum',         'int', '', '', '', '',
        'groupnum',        'int', '', '', '', '',
      ],
      'primary_key' => 'usergroupnum',
      'unique' => [ [ 'usernum', 'groupnum' ] ],
      'index'  => [ [ 'usernum' ] ],
    },

    'access_groupagent' => {
      'columns' => [
        'groupagentnum', 'serial', '', '', '', '',
        'groupnum',         'int', '', '', '', '',
        'agentnum',         'int', '', '', '', '',
      ],
      'primary_key' => 'groupagentnum',
      'unique' => [ [ 'groupnum', 'agentnum' ] ],
      'index'  => [ [ 'groupnum' ] ],
    },

    'access_right' => {
      'columns' => [
        'rightnum',   'serial', '',      '', '', '',
        'righttype', 'varchar', '', $char_d, '', '',
        'rightobjnum',   'int', '',      '', '', '',
        'rightname', 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'rightnum',
      'unique' => [ [ 'righttype', 'rightobjnum', 'rightname' ] ],
      'index'  => [],
    },

    'svc_phone' => {
      'columns' => [
        'svcnum',       'int',         '',      '', '', '', 
        'countrycode',  'varchar',     '',       3, '', '', 
        'phonenum',     'varchar',     '',      15, '', '',  #12 ?
        'pin',          'varchar', 'NULL', $char_d, '', '',
        'sip_password', 'varchar', 'NULL', $char_d, '', '',
        'phone_name',   'varchar', 'NULL', $char_d, '', '',
        'pbxsvc',           'int', 'NULL',      '', '', '',
        'domsvc',           'int', 'NULL',      '', '', '', 
        'locationnum',      'int', 'NULL', '', '', '',
        'forwarddst',     'varchar',     'NULL',      15, '', '', 
        'email',           'varchar', 'NULL',  255, '', '', 
        'lnp_status',   'varchar', 'NULL', $char_d, '', '',
        'portable',   	'char', 'NULL',       1,  '', '', 
        'lrn',     'char',     'NULL',      10, '', '', 
	'lnp_desired_due_date',     'int', 'NULL',       '', '', '',
	'lnp_due_date',     'int', 'NULL',       '', '', '',
        'lnp_other_provider', 'varchar', 'NULL', $char_d,  '', '',
        'lnp_other_provider_account', 'varchar', 'NULL', $char_d,  '', '',
        'lnp_reject_reason', 'varchar', 'NULL', $char_d,  '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [],
      'index'  => [ ['countrycode', 'phonenum'], ['pbxsvc'], ['domsvc'],
                    ['locationnum'],
                  ],
    },

    'phone_device' => {
      'columns' => [
        'devicenum', 'serial',     '', '', '', '',
        'devicepart',   'int',     '', '', '', '',
        'svcnum',       'int',     '', '', '', '', 
        'mac_addr', 'varchar', 'NULL', 12, '', '', 
      ],
      'primary_key' => 'devicenum',
      'unique' => [ [ 'mac_addr' ], ],
      'index'  => [ [ 'devicepart' ], [ 'svcnum' ], ],
    },

    'part_device' => {
      'columns' => [
        'devicepart', 'serial',  '',      '', '', '',
        'devicename', 'varchar', '', $char_d, '', '',
        'inventory_classnum', 'int', 'NULL', '', '', '',
      ],
      'primary_key' => 'devicepart',
      'unique' => [ [ 'devicename' ] ], #?
      'index'  => [],
    },

    'phone_avail' => {
      'columns' => [
        'availnum',    'serial',      '',      '', '', '', 
        'exportnum',   'int',         '',      '', '', '', 
        'countrycode', 'varchar',     '',       3, '', '', 
        'state',       'char',    'NULL',       2, '', '', 
        'npa',         'char',        '',       3, '', '', 
        'nxx',         'char',    'NULL',       3, '', '', 
        'station',     'char',    'NULL',       4, '', '',
        'name',        'varchar', 'NULL', $char_d, '', '',
        'rate_center_abbrev', 'varchar', 'NULL', $char_d, '', '',
        'latanum',      'int',     'NULL',      '', '', '',
        'msanum',       'int', 'NULL', '', '', '',
        'ordernum',      'int',     'NULL',      '', '', '',
        'svcnum',      'int',     'NULL',      '', '', '',
        'availbatch', 'varchar',  'NULL', $char_d, '', '',
      ],
      'primary_key' => 'availnum',
      'unique' => [],
      'index'  => [ [ 'exportnum', 'countrycode', 'state' ],     #npa search
                    [ 'exportnum', 'countrycode', 'npa' ],       #nxx search
                    [ 'exportnum', 'countrycode', 'npa', 'nxx' ],#station search
                    [ 'exportnum', 'countrycode', 'npa', 'nxx', 'station' ], # #
                    [ 'svcnum' ],
                    [ 'availbatch' ],
                    [ 'latanum' ],
                  ],
    },
    
    'lata' => {
      'columns' => [
        'latanum',    'int',      '',      '', '', '', 
        'description',   'varchar',    '',      $char_d, '', '', 
        'have_usage',   'int',    'NULL',      '', '', '', 
      ],
      'primary_key' => 'latanum',
      'unique' => [],
      'index'  => [],
    },
    
    'msa' => {
      'columns' => [
        'msanum',    'int',      '',      '', '', '', 
        'description',   'varchar',    '',      $char_d, '', '', 
      ],
      'primary_key' => 'msanum',
      'unique' => [],
      'index'  => [],
    },
    
    'rate_center' => {
      'columns' => [
        'ratecenternum',    'serial',      '',      '', '', '', 
        'description',   'varchar',    '',      $char_d, '', '', 
      ],
      'primary_key' => 'ratecenternum',
      'unique' => [],
      'index'  => [],
    },

    'did_vendor' => {
      'columns' => [
        'vendornum',    'serial',      '',      '', '', '', 
        'vendorname',   'varchar',        '',     $char_d, '', '', 
      ],
      'primary_key' => 'vendornum',
      'unique' => [],
      'index'  => [],
    },
    
    'did_order_item' => {
      'columns' => [
        'orderitemnum',    'serial',      '',      '', '', '', 
        'ordernum',    'int',      '',      '', '', '', 
        'msanum',      'int',     'NULL',      '', '', '',
        'npa',      'int',     'NULL',      '', '', '',
        'latanum',      'int',     'NULL',      '', '', '',
        'ratecenternum',      'int',     'NULL',      '', '', '',
        'state',       'char',    'NULL',       2, '', '', 
        'quantity',      'int',     '',      '', '', '',
        'custnum',   'int', 'NULL', '', '', '',
      ],
      'primary_key' => 'orderitemnum',
      'unique' => [],
      'index'  => [],
    },

    'did_order' => {
      'columns' => [
        'ordernum',    'serial',      '',      '', '', '', 
        'vendornum',   'int',       '',      '', '', '', 
        'vendor_order_id',   'varchar',  'NULL',   $char_d, '', '', 
        'custnum',   'int', 'NULL', '', '', '',
        'submitted',      'int',     '',      '', '', '',
        'confirmed',      'int',     'NULL',      '', '', '',
        'received',      'int',     'NULL',      '', '', '',
      ],
      'primary_key' => 'ordernum',
      'unique' => [ [ 'vendornum', 'vendor_order_id' ] ],
      'index'  => [],
    },

    'reason_type' => {
      'columns' => [
        'typenum',   'serial',  '', '', '', '', 
        'class',     'char', '', 1, '', '', 
        'type',     'varchar', '', $char_d, '', '', 
      ],
      'primary_key' => 'typenum',
      'unique' => [],
      'index' => [],
    },

    'reason' => {
      'columns' => [
        'reasonnum',     'serial',  '', '', '', '', 
        'reason_type',   'int',  '', '', '', '', 
        'reason',        'text', '', '', '', '', 
        'disabled',      'char',    'NULL', 1, '', '', 
      ],
      'primary_key' => 'reasonnum',
      'unique' => [],
      'index' => [],
    },

    'conf' => {
      'columns' => [
        'confnum',  'serial',     '',      '', '', '', 
        'agentnum', 'int',    'NULL',      '', '', '', 
        'locale',   'varchar','NULL',      16, '', '',
        'name',     'varchar',    '', $char_d, '', '', 
        'value',    'text',   'NULL',      '', '', '',
      ],
      'primary_key' => 'confnum',
      'unique' => [ [ 'agentnum', 'locale', 'name' ] ],
      'index' => [],
    },

    'pkg_referral' => {
      'columns' => [
        'pkgrefnum',     'serial', '', '', '', '',
        'pkgnum',        'int',    '', '', '', '',
        'refnum',        'int',    '', '', '', '',
      ],
      'primary_key' => 'pkgrefnum',
      'unique'      => [ [ 'pkgnum', 'refnum' ] ],
      'index'       => [ [ 'pkgnum' ], [ 'refnum' ] ],
    },

    'svc_pbx' => {
      'columns' => [
        'svcnum',           'int',     '',      '', '', '', 
        'id',               'int', 'NULL',      '', '', '', 
        'title',        'varchar', 'NULL', $char_d, '', '', 
        'max_extensions',   'int', 'NULL',      '', '', '',
        'max_simultaneous', 'int', 'NULL',      '', '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [],
      'index'  => [ [ 'id' ] ],
    },

    'svc_mailinglist' => { #svc_group?
      'columns' => [
        'svcnum',            'int',     '',            '', '', '', 
        'username',      'varchar',     '', $username_len, '', '',
        'domsvc',            'int',     '',            '', '', '', 
        'listnum',           'int',     '',            '', '', '',
        'reply_to',         'char', 'NULL',             1, '', '',#SetReplyTo
        'remove_from',      'char', 'NULL',             1, '', '',#RemoveAuthor
        'reject_auto',      'char', 'NULL',             1, '', '',#RejectAuto
        'remove_to_and_cc', 'char', 'NULL',             1, '', '',#RemoveToAndCc
      ],
      'primary_key' => 'svcnum',
      'unique' => [],
      'index'  => [ ['username'], ['domsvc'], ['listnum'] ],
    },

    'mailinglist' => {
      'columns' => [
        'listnum',   'serial', '',      '', '', '',
        'listname', 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'listnum',
      'unique' => [],
      'index'  => [],
    },

    'mailinglistmember' => {
      'columns' => [
        'membernum',        'serial',     '',   '', '', '',
        'listnum',             'int',     '',   '', '', '',
        'svcnum',              'int', 'NULL',   '', '', '', 
        'contactemailnum',     'int', 'NULL',   '', '', '', 
        'email',           'varchar', 'NULL',  255, '', '', 
      ],
      'primary_key' => 'membernum',
      'unique'      => [],
      'index'       => [['listnum'],['svcnum'],['contactemailnum'],['email']],
    },

    'bill_batch' => {
      'columns' => [
        'batchnum',         'serial',     '',  '', '', '',
        'agentnum',            'int', 'NULL',  '', '', '',
        'status',             'char', 'NULL', '1', '', '',
        'pdf',                'blob', 'NULL',  '', '', '',
      ],
      'primary_key' => 'batchnum',
      'unique'      => [],
      'index'       => [ ['agentnum'] ],
    },

    'cust_bill_batch' => {
      'columns' => [
        'billbatchnum',     'serial',     '', '', '', '',
        'batchnum',            'int',     '', '', '', '',
        'invnum',              'int',     '', '', '', '',
      ],
      'primary_key' => 'billbatchnum',
      'unique'      => [],
      'index'       => [ [ 'batchnum' ], [ 'invnum' ] ],
    },

    'cust_bill_batch_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'billbatchnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key' => 'optionnum',
      'unique'      => [],
      'index'       => [ [ 'billbatchnum' ], [ 'optionname' ] ],
    },

    'msg_template' => {
      'columns' => [
        'msgnum',     'serial',     '',      '', '', '',
        'msgname',   'varchar',     '', $char_d, '', '',
        'agentnum',      'int', 'NULL',      '', '', '',
        'subject',   'varchar', 'NULL',     512, '', '',
        'mime_type', 'varchar',     '', $char_d, '', '',
        'body',         'blob', 'NULL',      '', '', '',
        'disabled',     'char', 'NULL',       1, '', '', 
        'from_addr', 'varchar', 'NULL',     255, '', '',
        'bcc_addr',  'varchar', 'NULL',     255, '', '',
      ],
      'primary_key' => 'msgnum',
      'unique'      => [ ],
      'index'       => [ ['agentnum'], ],
    },

    'template_content' => {
      'columns' => [
        'contentnum', 'serial',     '',      '', '', '',
        'msgnum',        'int',     '',      '', '', '',
        'locale',    'varchar', 'NULL',      16, '', '',
        'subject',   'varchar', 'NULL',     512, '', '',
        'body',         'text', 'NULL',      '', '', '',
      ],
      'primary_key' => 'contentnum',
      'unique'      => [ ['msgnum', 'locale'] ],
      'index'       => [ ],
    },

    'cust_msg' => {
      'columns' => [
        'custmsgnum', 'serial',     '',     '', '', '',
        'custnum',       'int',     '',     '', '', '',
        'msgnum',        'int', 'NULL',     '', '', '',
        '_date',    @date_type,                 '', '',
        'env_from',  'varchar', 'NULL',    255, '', '',
        'env_to',    'varchar', 'NULL',    255, '', '',
        'header',       'blob', 'NULL',     '', '', '',
        'body',         'blob', 'NULL',     '', '', '',
        'error',     'varchar', 'NULL',    255, '', '',
        'status',    'varchar',     '',$char_d, '', '',
      ],
      'primary_key' => 'custmsgnum',
      'unique'      => [ ],
      'index'       => [ ['custnum'], ],
    },

    'svc_cert' => {
      'columns' => [
        'svcnum',                'int',     '',      '', '', '', 
        'recnum',                'int', 'NULL',      '', '', '',
        'privatekey',           'text', 'NULL',      '', '', '',
        'csr',                  'text', 'NULL',      '', '', '',
        'certificate',          'text', 'NULL',      '', '', '',
        'cacert',               'text', 'NULL',      '', '', '',
        'common_name',       'varchar', 'NULL', $char_d, '', '',
        'organization',      'varchar', 'NULL', $char_d, '', '',
        'organization_unit', 'varchar', 'NULL', $char_d, '', '',
        'city',              'varchar', 'NULL', $char_d, '', '',
        'state',             'varchar', 'NULL', $char_d, '', '',
        'country',              'char', 'NULL',       2, '', '',
        'cert_contact',      'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [],
      'index'  => [], #recnum
    },

    'svc_port' => {
      'columns' => [
        'svcnum',                'int',     '',      '', '', '', 
        'serviceid', 'varchar', '', 64, '', '', #srvexport / reportfields
      ],
      'primary_key' => 'svcnum',
      'unique' => [],
      'index'  => [], #recnum
    },

    'areacode'  => {
      'columns' => [
        'areanum',   'serial',        '',      '', '', '',
        'code',        'char',        '',       3, '', '', 
        'country',     'char',    'NULL',       2, '', '',
        'state',       'char',    'NULL',       2, '', '', 
        'description','varchar',  'NULL',     255, '', '',
      ], 
      'primary_key' => 'areanum',
      'unique' => [ [ 'areanum' ] ],
      'index'  => [],
    },

    %{ tables_hashref_torrus() },

    # tables of ours for doing torrus virtual port combining
    'torrus_srvderive' => {
      'columns' => [
        'derivenum',     'serial',     '', '', '', '',
        'serviceid',    'varchar',     '', 64, '', '', #srvexport / reportfields
        'last_srv_date',   'date', 'NULL', '', '', '',
      ],
      'primary_key' => 'derivenum',
      'unique' => [ ['serviceid'] ],
      'index'  => [],
    },

    'torrus_srvderive_component' => {
      'columns' => [
        'componentnum', 'serial', '', '', '', '',
        'derivenum',       'int', '', '', '', '',
        'serviceid',   'varchar', '', 64, '', '', #srvexport / reportfields
      ],
      'primary_key' => 'componentnum',
      'unique'      => [ [ 'derivenum', 'serviceid' ], ],
      'index'       => [ [ 'derivenum', ], ],
    },


    # name type nullability length default local

    #'new_table' => {
    #  'columns' => [
    #    'num', 'serial',       '', '', '', '',
    #  ],
    #  'primary_key' => 'num',
    #  'unique' => [],
    #  'index'  => [],
    #},

  };

}

=back

=head1 BUGS

=head1 SEE ALSO

L<DBIx::DBSchema>

=cut

1;

