package FS::Schema;

use vars qw(@ISA @EXPORT_OK $DEBUG $setup_hack %dbdef_cache);
use subs qw(reload_dbdef);
use Exporter;
use DBIx::DBSchema 0.44; #for foreign keys with MATCH / ON DELETE/UPDATE
use DBIx::DBSchema::Table;
use DBIx::DBSchema::Column;
use DBIx::DBSchema::Index;
use DBIx::DBSchema::ForeignKey;
#can't use this yet, dependency bs #use FS::Conf;

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
Currently, this enables "ENGINE=InnoDB" for MySQL databases.

=cut

sub dbdef_dist {
  my $datasrc = @_ && !ref($_[0]) ? shift : '';
  my $opt = @_ ? shift : {};
  
  my $local_options = '';
  if ( $datasrc =~ /^dbi:mysql/i ) {
    $local_options = 'ENGINE=InnoDB';
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

    my @foreign_keys =
      map DBIx::DBSchema::ForeignKey->new($_),
        @{ $tables_hashref->{$tablename}{'foreign_keys'} || [] };

    DBIx::DBSchema::Table->new({
      name          => $tablename,
      primary_key   => $tables_hashref->{$tablename}{'primary_key'},
      columns       => \@columns,
      indices       => \@indices,
      foreign_keys  => \@foreign_keys,
      local_options => $local_options,
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

  #create history tables
  foreach my $table (
    grep {    ! /^(clientapi|access_user)_session/
           && ! /^h_/
           && ! /^log(_context)?$/
           && ( ! /^queue(_arg)?$/ || ! $opt->{'queue-no_history'} )
           && ! $tables_hashref_torrus->{$_}
         }
      $dbdef->tables
  ) {
    my $tableobj = $dbdef->table($table)
      or die "unknown table $table";

    my %h_indices = ();

    unless ( $table eq 'cust_event' || $table eq 'cdr' ) { #others?

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

    my $primary_key_col = $tableobj->column($tableobj->primary_key)
      or die "$table: primary key declared as ". $tableobj->primary_key.
             ", but no column of that name\n";

    my $historynum_type = ( $tableobj->column($tableobj->primary_key)->type
                              =~ /^(bigserial|bigint|int8)$/i
                                ? 'bigserial'
                                : 'serial'
                          );

    my $h_tableobj = DBIx::DBSchema::Table->new( {
      'name'          => "h_$table",
      'primary_key'   => 'historynum',
      'indices'       => \%h_indices,
      'local_options' => $local_options,
      'columns'       => [
          DBIx::DBSchema::Column->new( {
            'name'    => 'historynum',
            'type'    => $historynum_type,
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
            'null'    => 'NULL',
            'length'  => '80',
            'default' => '',
            'local'   => '',
          } ),
          DBIx::DBSchema::Column->new( {
            'name'    => 'history_usernum',
            'type'    => 'int',
            'null'    => 'NULL',
            'length'  => '',
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
  my @date_type = ( 'int', 'NULL', ''     );
  my @perl_type = ( 'text', 'NULL', ''  ); 
  my @money_type = ( 'decimal',   '', '10,2' );
  my @money_typen = ( 'decimal',   'NULL', '10,2' );
  my @taxrate_type  = ( 'decimal',   '',     '14,8' ); # requires pg 8 for 
  my @taxrate_typen = ( 'decimal',   'NULL', '14,8' ); # fs-upgrade to work

  my $username_len = 64; #usernamemax config file

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
      'primary_key'  => 'agentnum',
      #'unique' => [ [ 'agent_custnum' ] ], #one agent per customer?
                                            #insert is giving it a value, tho..
      #'index' => [ ['typenum'], ['disabled'] ],
      'unique'       => [],
      'index'        => [ ['typenum'], ['disabled'], ['agent_custnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'typenum' ],
                            table      => 'agent_type',
                          },
                          # 1. RT tables aren't part of our data structure, so
                          #     we can't make sure Queue is created already
                          # 2. Future ability to plug in other ticketing systems
                          #{ columns    => [ 'ticketing_queueid' ],
                          #  table      => 'Queue',
                          #  references => [ 'id' ],
                          #},
                          { columns    => [ 'agent_custnum' ],
                            table      => 'cust_main',
                            references => [ 'custnum' ],
                          },
                        ],
    },

    'agent_pkg_class' => {
      'columns' => [
        'agentpkgclassnum',    'serial',     '',    '', '', '',
        'agentnum',               'int',     '',    '', '', '',
        'classnum',               'int', 'NULL',    '', '', '',
        'commission_percent', 'decimal',     '', '7,4', '', '',
      ],
      'primary_key'  => 'agentpkgclassnum',
      'unique'       => [ [ 'agentnum', 'classnum' ], ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'pkg_class',
                          },
                        ],
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
      'primary_key'  => 'typepkgnum',
      'unique'       => [ ['typenum', 'pkgpart'] ],
      'index'        => [ ['typenum'] ],
      'foreign_keys' => [
                          { columns    => [ 'typenum' ],
                            table      => 'agent_type',
                          },
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                        ],
    },

    'agent_currency' => {
      'columns' => [
        'agentcurrencynum', 'serial', '', '', '', '',
        'agentnum',            'int', '', '', '', '',
        'currency',           'char', '',  3, '', '',
      ],
      'primary_key'  => 'agentcurrencynum',
      'unique'       => [],
      'index'        => [ ['agentnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'sales' => {
      'columns' => [
        'salesnum',          'serial',    '',       '', '', '', 
        'salesperson',      'varchar',    '',  $char_d, '', '', 
        'agentnum',             'int', 'NULL',      '', '', '', 
        'sales_custnum',        'int', 'NULL',      '', '', '',
        'disabled',            'char', 'NULL',       1, '', '', 
      ],
      'primary_key'  => 'salesnum',
      'unique'       => [],
      'index'        => [ ['salesnum'], ['disabled'] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                          { columns    => [ 'sales_custnum' ],
                            table      => 'cust_main',
                            references => [ 'custnum' ],
                          },
                        ],
    },

    'sales_pkg_class' => {
      'columns' => [
        'salespkgclassnum',    'serial',     '',    '', '', '',
        'salesnum',               'int',     '',    '', '', '',
        'classnum',               'int', 'NULL',    '', '', '',
        'commission_percent', 'decimal',     '', '7,4', '', '',
        'commission_duration',    'int', 'NULL',    '', '', '',
      ],
      'primary_key'  => 'salespkgclassnum',
      'unique'       => [ [ 'salesnum', 'classnum' ], ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'salesnum' ],
                            table      => 'sales',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'pkg_class',
                          },
                        ],
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
      'primary_key'  => 'attachnum',
      'unique'       => [],
      'index'        => [ ['custnum'], ['usernum'], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
   },

    'cust_bill' => {
      'columns' => [
        #regular fields
        'invnum',         'serial',     '',      '', '', '', 
        'custnum',           'int',     '',      '', '', '', 
        '_date',        @date_type,                  '', '', 
        'charged',     @money_type,                  '', '', 
        'currency',         'char', 'NULL',       3, '', '',
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
      'primary_key'  => 'invnum',
      'unique'       => [ [ 'custnum', 'agent_invid' ] ], #agentnum?  huh
      'index'        => [ ['custnum'], ['_date'], ['statementnum'],
                          ['agent_invid'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'statementnum' ],
                            table      => 'cust_statement',
                          },
                        ],
    },

    'cust_bill_void' => {
      'columns' => [
        #regular fields
        'invnum',            'int',     '',      '', '', '', 
        'custnum',           'int',     '',      '', '', '', 
        '_date',        @date_type,                  '', '', 
        'charged',     @money_type,                  '', '', 
        'currency',         'char', 'NULL',       3, '', '',
        'invoice_terms', 'varchar', 'NULL', $char_d, '', '',

        #customer balance info at invoice generation time
        'previous_balance',   @money_typen, '', '',  #eventually not nullable
        'billing_balance',    @money_typen, '', '',  #eventually not nullable

        #specific use cases
        'closed',      'char', 'NULL',  1, '', '', #not yet used much
        'statementnum', 'int', 'NULL', '', '', '', #invoice aggregate statements
        'agent_invid',  'int', 'NULL', '', '', '', #(varchar?) importing legacy
        'promised_date', @date_type,       '', '',

        #void fields
        'void_date', @date_type, '', '', 
        'reason',    'varchar',   'NULL', $char_d, '', '', 
        'void_usernum',   'int', 'NULL', '', '', '',
      ],
      'primary_key'  => 'invnum',
      'unique'       => [ [ 'custnum', 'agent_invid' ] ], #agentnum?  huh
      'index'        => [ ['custnum'], ['_date'], ['statementnum'],
                          ['agent_invid'], [ 'void_usernum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'statementnum' ],
                            table      => 'cust_statement', #_void? both?
                          },
                          { columns    => [ 'void_usernum' ],
                            table      => 'access_user',
                            references => [ 'usernum' ],
                          },
                        ],
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
        'currency',        'char', 'NULL',       3, '', '',
        'content_pdf',     'blob', 'NULL',      '', '', '',
        'content_html',    'text', 'NULL',      '', '', '',
        'locale',       'varchar', 'NULL',      16, '', '', 
      ],
      'primary_key'  => 'legacyinvnum',
      'unique'       => [],
      'index'        => [ ['legacyid', 'custnum', 'locale' ], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
    },

    'cust_statement' => {
      'columns' => [
        'statementnum', 'serial', '', '', '', '',
        'custnum',         'int', '', '', '', '',
        '_date',           @date_type,    '', '',
      ],
      'primary_key'  => 'statementnum',
      'unique'       => [],
      'index'        => [ ['custnum'], ['_date'], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
    },

    #old "invoice" events, deprecated
    'cust_bill_event' => {
      'columns' => [
        'eventnum',    'serial',  '', '', '', '', 
        'invnum',   'int',  '', '', '', '', 
        'eventpart',   'int',  '', '', '', '', 
        '_date',     @date_type, '', '', 
        'status', 'varchar', '', $char_d, '', '', 
        'statustext', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'eventnum',
      #no... there are retries now #'unique' => [ [ 'eventpart', 'invnum' ] ],
      'unique'       => [],
      'index'        => [ ['invnum'], ['status'], ['eventpart'],
                          ['statustext'], ['_date'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                          { columns    => [ 'eventpart' ],
                            table      => 'part_bill_event',
                          },
                        ],
    },

    #old "invoice" events, deprecated
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
      'primary_key'  => 'eventpart',
      'unique'       => [],
      'index'        => [ ['payby'], ['disabled'], ],
      'foreign_keys' => [
                          { columns    => [ 'reason' ],
                            table      => 'reason',
                            references => [ 'reasonnum' ],
                          },
                        ],
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
      'primary_key'  => 'eventpart',
      'unique'       => [],
      'index'        => [ ['agentnum'], ['eventtable'], ['check_freq'],
                          ['disabled'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'part_event_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'eventpart', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'eventpart' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'eventpart' ],
                            table      => 'part_event',
                          },
                        ],
    },

    'part_event_condition' => {
      'columns' => [
        'eventconditionnum', 'serial', '', '', '', '', 
        'eventpart', 'int', '', '', '', '', 
        'conditionname', 'varchar', '', $char_d, '', '', 
      ],
      'primary_key'  => 'eventconditionnum',
      'unique'       => [],
      'index'        => [ [ 'eventpart' ], [ 'conditionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'eventpart' ],
                            table      => 'part_event',
                          },
                        ],
    },

    'part_event_condition_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'eventconditionnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'eventconditionnum' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'eventconditionnum' ],
                            table      => 'part_event_condition',
                          },
                        ],
    },

    'part_event_condition_option_option' => {
      'columns' => [
        'optionoptionnum', 'serial', '', '', '', '', 
        'optionnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionoptionnum',
      'unique'       => [],
      'index'        => [ [ 'optionnum' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'optionnum' ],
                            table      => 'part_event_condition_option',
                          },
                        ],
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
      'primary_key'  => 'eventnum',
      #no... there are retries now #'unique' => [ [ 'eventpart', 'invnum' ] ],
      'unique'       => [],
      'index'        => [ ['eventpart'], ['tablenum'], ['status'],
                          ['statustext'], ['_date'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'eventpart' ],
                            table      => 'part_event',
                          },
                        ],
    },

    'cust_event_fee' => {
      'columns' => [
        'eventfeenum', 'serial', '', '', '', '',
        'eventnum',       'int', '', '', '', '',
        'billpkgnum',     'int', 'NULL', '', '', '',
        'feepart',        'int', '', '', '', '',
        'nextbill',      'char', 'NULL',  1, '', '',
      ],
      'primary_key'  => 'eventfeenum', # I'd rather just use eventnum
      'unique' => [ [ 'billpkgnum' ], [ 'eventnum' ] ], # one-to-one link
      'index'  => [ [ 'feepart' ] ],
      'foreign_keys' => [
                          { columns => [ 'eventnum' ],
                            table   => 'cust_event',
                          },
                          { columns => [ 'billpkgnum' ],
                            table   => 'cust_bill_pkg',
                          },
                          { columns => [ 'feepart' ],
                            table   => 'part_fee',
                          },
                        ],
    },

    'cust_bill_pkg' => {
      'columns' => [
        'billpkgnum',          'serial',     '',      '', '', '', 
        'invnum',                 'int',     '',      '', '', '', 
        'pkgnum',                 'int',     '',      '', '', '', 
        'pkgpart_override',       'int', 'NULL',      '', '', '', 
        'setup',                 @money_type,             '', '', 
        'unitsetup',             @money_typen,            '', '', 
        'setup_billed_currency', 'char', 'NULL',       3, '', '',
        'setup_billed_amount',   @money_typen,            '', '',
        'recur',                 @money_type,             '', '', 
        'unitrecur',             @money_typen,            '', '', 
        'recur_billed_currency', 'char', 'NULL',       3, '', '',
        'recur_billed_amount',   @money_typen,            '', '',
        'sdate',                 @date_type,              '', '', 
        'edate',                 @date_type,              '', '', 
        'itemdesc',           'varchar', 'NULL', $char_d, '', '', 
        'itemcomment',        'varchar', 'NULL', $char_d, '', '', 
        'section',            'varchar', 'NULL', $char_d, '', '', 
        'freq',               'varchar', 'NULL', $char_d, '', '',
        'quantity',               'int', 'NULL',      '', '', '',
        'hidden',                'char', 'NULL',       1, '', '',
        'feepart',                'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'billpkgnum',
      'unique'       => [],
      'index'        => [ ['invnum'], [ 'pkgnum' ], [ 'itemdesc' ], ],
      'foreign_keys' => [
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                          #pkgnum 0 and -1 are used for special things
                          #{ columns    => [ 'pkgnum' ],
                          #  table      => 'cust_pkg',
                          #},
                          { columns    => [ 'pkgpart_override' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ],
                          },
                          { columns    => [ 'feepart' ],
                            table      => 'part_fee',
                          },
                        ],
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
        'phonenum', 'varchar', 'NULL', 255, '', '', # has to hold a service label
        'accountcode', 'varchar',  'NULL',      20, '', '',
        'startdate',  @date_type, '', '', 
        'regionname', 'varchar', 'NULL', $char_d, '', '',
        'detail',  'varchar', '', 255, '', '', 
      ],
      'primary_key'  => 'detailnum',
      'unique'       => [],
      'index'        => [ [ 'billpkgnum' ], [ 'classnum' ],
                          [ 'pkgnum', 'invnum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                          #{ columns    => [ 'pkgnum' ],
                          #  table      => 'cust_pkg',
                          #},
                          #{ columns    => [ 'invnum' ],
                          #  table      => 'cust_bill',
                          #},
                          { columns    => [ 'classnum' ],
                            table      => 'usage_class',
                          },
                        ],
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
      'primary_key'  => 'billpkgdisplaynum',
      'unique'       => [],
      'index'        => [ ['billpkgnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                        ],
    },

    'cust_bill_pkg_fee' => {
      'columns' => [
        'billpkgfeenum',    'serial', '', '', '', '',
        'billpkgnum',          'int', '', '', '', '',
        'base_invnum',       'int', '', '', '', '',
        'base_billpkgnum',   'int', 'NULL', '', '', '',
        'amount',        @money_type,         '', '',
      ],
      'primary_key' => 'billpkgfeenum',
      'unique'      => [],
      'index'       => [ ['billpkgnum'],
                         ['base_invnum'],
                         ['base_billpkgnum'],
                       ],
      'foreign_keys' => [
                          { columns     => [ 'billpkgnum' ],
                            table       => 'cust_bill_pkg',
                          },
                          { columns     => [ 'base_billpkgnum' ],
                            table       => 'cust_bill_pkg',
                            references  => [ 'billpkgnum' ],
                          },
                          { columns     => [ 'base_invnum' ],
                            table       => 'cust_bill',
                            references  => [ 'invnum' ],
                          },
                        ],
    },

    'cust_bill_pkg_tax_location' => {
      'columns' => [
        'billpkgtaxlocationnum', 'serial',     '',      '', '', '',
        'billpkgnum',               'int',     '',      '', '', '',
        'taxnum',                   'int',     '',      '', '', '',
        'taxtype',              'varchar',     '', $char_d, '', '',
        'pkgnum',                   'int',     '',      '', '', '', #redundant
        'locationnum',              'int',     '',      '', '', '', #redundant
        'amount',             @money_type,                  '', '',
        'currency',                'char', 'NULL',       3, '', '',
        'taxable_billpkgnum',       'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'billpkgtaxlocationnum',
      'unique'       => [],
      'index'        => [ [ 'billpkgnum' ], 
                          [ 'taxnum' ],
                          [ 'pkgnum' ],
                          [ 'locationnum' ],
                          [ 'taxable_billpkgnum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                          #{ columns    => [ 'pkgnum' ],
                          #  table      => 'cust_pkg',
                          #}, # taxes can apply to fees
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                          { columns    => [ 'taxable_billpkgnum' ],
                            table      => 'cust_bill_pkg',
                            references => [ 'billpkgnum' ],
                          },
                        ],
    },

    'cust_bill_pkg_tax_rate_location' => {
      'columns' => [
        'billpkgtaxratelocationnum', 'serial',      '',      '', '', '',
        'billpkgnum',                   'int',      '',      '', '', '',
        'taxnum',                       'int',      '',      '', '', '',
        'taxtype',                  'varchar',      '', $char_d, '', '',
        'locationtaxid',            'varchar',  'NULL', $char_d, '', '',
        'taxratelocationnum',           'int',      '',      '', '', '',
        'amount',                 @money_type,                   '', '',
        'currency',                    'char', 'NULL',        3, '', '',
        'taxable_billpkgnum',           'int', 'NULL',       '', '', '',
      ],
      'primary_key'  => 'billpkgtaxratelocationnum',
      'unique'       => [],
      'index'        => [ ['billpkgnum'], ['taxnum'], ['taxratelocationnum'],
                          ['taxable_billpkgnum'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                          { columns    => [ 'taxratelocationnum' ],
                            table      => 'tax_rate_location',
                          },
                          { columns    => [ 'taxable_billpkgnum' ],
                            table      => 'cust_bill_pkg',
                            references => [ 'billpkgnum' ],
                          },
                        ],
    },

    'cust_bill_pkg_void' => {
      'columns' => [
        'billpkgnum',           'int',     '',      '', '', '', 
        'invnum',               'int',     '',      '', '', '', 
        'pkgnum',               'int',     '',      '', '', '', 
        'pkgpart_override',     'int', 'NULL',      '', '', '', 
        'setup',               @money_type,             '', '', 
        'recur',               @money_type,             '', '', 
        #XXX a currency for a line item?  or just one for the entire invoice
        #'currency',            'char', 'NULL',       3, '', '',
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
        #void fields
        'void_date', @date_type, '', '', 
        'reason',    'varchar',   'NULL', $char_d, '', '', 
        'void_usernum',   'int', 'NULL', '', '', '',
      ],
      'primary_key'  => 'billpkgnum',
      'unique'       => [],
      'index'        => [ ['invnum'], ['pkgnum'], ['itemdesc'],
                          ['void_usernum'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill_void',
                          },
                          #pkgnum 0 and -1 are used for special things
                          #{ columns    => [ 'pkgnum' ],
                          #  table      => 'cust_pkg',
                          #},
                          { columns    => [ 'pkgpart_override' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ],
                          },
                          { columns    => [ 'void_usernum' ],
                            table      => 'access_user',
                            references => [ 'usernum' ],
                          },
                        ],
    },

    'cust_bill_pkg_detail_void' => {
      'columns' => [
        'detailnum',  'int', '', '', '', '', 
        'billpkgnum', 'int', 'NULL', '', '', '',        # should not be nullable
        'pkgnum',  'int', 'NULL', '', '', '',           # deprecated
        'invnum',  'int', 'NULL', '', '', '',           # deprecated
        'amount',  'decimal', 'NULL', '10,4', '', '',
        'format',  'char', 'NULL', 1, '', '',
        'classnum', 'int', 'NULL', '', '', '',
        'duration', 'int', 'NULL', '',  0, '',
        'phonenum', 'varchar', 'NULL', 255, '', '',
        'accountcode', 'varchar',  'NULL',      20, '', '',
        'startdate',  @date_type, '', '', 
        'regionname', 'varchar', 'NULL', $char_d, '', '',
        'detail',  'varchar', '', 255, '', '', 
      ],
      'primary_key'  => 'detailnum',
      'unique'       => [],
      'index'        => [ ['billpkgnum'], ['classnum'], ['pkgnum', 'invnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg_void',
                          },
                          #{ columns    => [ 'pkgnum' ],
                          #  table      => 'cust_pkg',
                          #},
                          #{ columns    => [ 'invnum' ],
                          #  table      => 'cust_bill',
                          #},
                          { columns    => [ 'classnum' ],
                            table      => 'usage_class',
                          },
                        ],
    },

    'cust_bill_pkg_display_void' => {
      'columns' => [
        'billpkgdisplaynum',    'int', '', '', '', '', 
        'billpkgnum', 'int', '', '', '', '', 
        'section',  'varchar', 'NULL', $char_d, '', '', 
        #'unitsetup', @money_typen, '', '',     #override the linked real one?
        #'unitrecur', @money_typen, '', '',     #this too?
        'post_total', 'char', 'NULL', 1, '', '',
        'type',       'char', 'NULL', 1, '', '',
        'summary',    'char', 'NULL', 1, '', '',
      ],
      'primary_key'  => 'billpkgdisplaynum',
      'unique'       => [],
      'index'        => [ ['billpkgnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg_void',
                          },
                        ],
    },

    'cust_bill_pkg_tax_location_void' => {
      'columns' => [
        'billpkgtaxlocationnum',    'int',     '',      '', '', '',
        'billpkgnum',               'int',     '',      '', '', '',
        'taxnum',                   'int',     '',      '', '', '',
        'taxtype',              'varchar',     '', $char_d, '', '',
        'pkgnum',                   'int',     '',      '', '', '',
        'locationnum',              'int',     '',      '', '', '', #redundant?
        'amount',             @money_type,                  '', '',
        'currency',                'char', 'NULL',       3, '', '',
        'taxable_billpkgnum',       'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'billpkgtaxlocationnum',
      'unique'       => [],
      'index'        => [ ['billpkgnum'], ['taxnum'], ['pkgnum'],
                          ['locationnum'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg_void',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                          { columns    => [ 'taxable_billpkgnum' ],
                            table      => 'cust_bill_pkg_void',
                            references => [ 'billpkgnum' ],
                          },
                        ],
    },

    'cust_bill_pkg_tax_rate_location_void' => {
      'columns' => [
        'billpkgtaxratelocationnum',    'int',     '',      '', '', '',
        'billpkgnum',                   'int',     '',      '', '', '',
        'taxnum',                       'int',     '',      '', '', '',
        'taxtype',                  'varchar',     '', $char_d, '', '',
        'locationtaxid',            'varchar', 'NULL', $char_d, '', '',
        'taxratelocationnum',           'int',     '',      '', '', '',
        'amount',                 @money_type,                  '', '',
        'currency',                    'char', 'NULL',       3, '', '',
      ],
      'primary_key'  => 'billpkgtaxratelocationnum',
      'unique'       => [],
      'index'        => [ ['billpkgnum'], ['taxnum'], ['taxratelocationnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg_void',
                          },
                          { columns    => [ 'taxratelocationnum' ],
                            table      => 'tax_rate_location',
                          },
                        ],
    },

    'cust_credit' => {
      'columns' => [
        'crednum',  'serial',     '', '', '', '', 
        'custnum',     'int',     '', '', '', '', 
        '_date',  @date_type,             '', '', 
        'amount',@money_type,             '', '', 
        'currency',   'char', 'NULL',  3, '', '',
        'otaker',  'varchar', 'NULL', 32, '', '', 
        'usernum',     'int', 'NULL', '', '', '',
        'reason',     'text', 'NULL', '', '', '', 
        'reasonnum',   'int', 'NULL', '', '', '', 
        'addlinfo',   'text', 'NULL', '', '', '',
        'closed',     'char', 'NULL',  1, '', '', 
        'pkgnum',      'int', 'NULL', '', '','',#desired pkgnum for pkg-balances
        'eventnum',    'int', 'NULL', '', '','',#triggering event for commission
        'commission_agentnum', 'int', 'NULL', '', '', '', #
        'commission_salesnum', 'int', 'NULL', '', '', '', #
        'commission_pkgnum',   'int', 'NULL', '', '', '', #
        'credbatch',    'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'crednum',
      'unique'       => [],
      'index'        => [ ['custnum'], ['_date'], ['usernum'], ['eventnum'],
                          ['commission_salesnum'], ['credbatch'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'reasonnum' ],
                            table      => 'reason',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'eventnum' ],
                            table      => 'cust_event',
                          },
                          { columns    => [ 'commission_agentnum' ],
                            table      => 'agent',
                            references => [ 'agentnum' ],
                          },
                          { columns    => [ 'commission_salesnum' ],
                            table      => 'sales',
                            references => [ 'salesnum' ],
                          },
                          { columns    => [ 'commission_pkgnum' ],
                            table      => 'cust_pkg',
                            references => [ 'pkgnum' ],
                          },
                        ],
    },

    'cust_credit_void' => {
      'columns' => [
        'crednum',  'serial',     '', '', '', '', 
        'custnum',     'int',     '', '', '', '', 
        '_date',  @date_type,             '', '', 
        'amount',@money_type,             '', '', 
        'currency',   'char', 'NULL',  3, '', '',
        'otaker',  'varchar', 'NULL', 32, '', '', 
        'usernum',     'int', 'NULL', '', '', '',
        'reason',     'text', 'NULL', '', '', '', 
        'reasonnum',   'int', 'NULL', '', '', '', 
        'addlinfo',   'text', 'NULL', '', '', '',
        'closed',     'char', 'NULL',  1, '', '', 
        'pkgnum',      'int', 'NULL', '', '','',
        'eventnum',    'int', 'NULL', '', '','',
        'commission_agentnum', 'int', 'NULL', '', '', '',
        'commission_salesnum', 'int', 'NULL', '', '', '',
        'commission_pkgnum',   'int', 'NULL', '', '', '',
        #void fields
        'void_date',  @date_type,                  '', '', 
        'void_reason', 'varchar', 'NULL', $char_d, '', '', 
        'void_usernum',    'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'crednum',
      'unique'       => [],
      'index'        => [ ['custnum'], ['_date'], ['usernum'], ['eventnum'],
                          ['commission_salesnum'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'reasonnum' ],
                            table      => 'reason',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'eventnum' ],
                            table      => 'cust_event',
                          },
                          { columns    => [ 'commission_agentnum' ],
                            table      => 'agent',
                            references => [ 'agentnum' ],
                          },
                          { columns    => [ 'commission_salesnum' ],
                            table      => 'sales',
                            references => [ 'salesnum' ],
                          },
                          { columns    => [ 'commission_pkgnum' ],
                            table      => 'cust_pkg',
                            references => [ 'pkgnum' ],
                          },
                          { columns    => [ 'void_usernum' ],
                            table      => 'access_user',
                            references => [ 'usernum' ],
                          },
                        ],
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
      'primary_key'  => 'creditbillnum',
      'unique'       => [],
      'index'        => [ ['crednum'], ['invnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'crednum' ],
                            table      => 'cust_credit',
                          },
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                        ],
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
      'primary_key'  => 'creditbillpkgnum',
      'unique'       => [],
      'index'        => [ [ 'creditbillnum' ],
                          [ 'billpkgnum' ], 
                          [ 'billpkgtaxlocationnum' ],
                          [ 'billpkgtaxratelocationnum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'creditbillnum' ],
                            table      => 'cust_credit_bill',
                          },
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                          { columns    => [ 'billpkgtaxlocationnum' ],
                            table      => 'cust_bill_pkg_tax_location',
                          },
                          { columns    => [ 'billpkgtaxratelocationnum' ],
                            table      => 'cust_bill_pkg_tax_rate_location',
                          },
                        ],
    },

    'cust_main' => {
      'columns' => [
        'custnum',  'serial',  '',     '', '', '', 
        'agentnum', 'int',  '',     '', '', '', 
        'salesnum', 'int',  'NULL', '', '', '', 
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
        'national_id', 'varchar', 'NULL', $char_d, '', '',
        'birthdate' ,@date_type, '', '', 
        'spouse_last',  'varchar', 'NULL', 2*$char_d, '', '',
        'spouse_first', 'varchar', 'NULL', $char_d, '', '',
        'spouse_birthdate', @date_type, '', '', 
        'anniversary_date', @date_type, '', '', 
        'signupdate',@date_type, '', '', 
        'dundate',   @date_type, '', '', 
        'company',  'varchar', 'NULL', $char_d, '', '', 
        'address1', 'varchar', 'NULL', $char_d, '', '', 
        'address2', 'varchar', 'NULL', $char_d, '', '', 
        'city',     'varchar', 'NULL', $char_d, '', '', 
        'county',   'varchar', 'NULL', $char_d, '', '', 
        'state',    'varchar', 'NULL', $char_d, '', '', 
        'zip',      'varchar', 'NULL', 10, '', '', 
        'country',  'char',    'NULL',  2, '', '', 
        'latitude', 'decimal', 'NULL', '10,7', '', '', 
        'longitude','decimal', 'NULL', '10,7', '', '', 
        'coord_auto',  'char', 'NULL',  1, '', '',
        'addr_clean',  'char', 'NULL',  1, '', '',
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
        'ship_addr_clean',  'char', 'NULL',  1, '', '',
        'ship_daytime',  'varchar', 'NULL', 20, '', '', 
        'ship_night',    'varchar', 'NULL', 20, '', '', 
        'ship_fax',      'varchar', 'NULL', 12, '', '', 
        'ship_mobile',   'varchar', 'NULL', 12, '', '', 
        'currency',         'char', 'NULL',  3, '', '',

        #deprecated, info moved to cust_payby
        'payby',    'char', 'NULL',     4, '', '', 
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
        'district', 'varchar', 'NULL', 20, '', '',
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
        'credit_limit_currency', 'char', 'NULL',  3, '', '',
        'archived', 'char', 'NULL', 1, '', '',
        'email_csv_cdr', 'char', 'NULL', 1, '', '',
        'accountcode_cdr', 'char', 'NULL', 1, '', '',
        'billday',   'int', 'NULL', '', '', '',
        'prorate_day',   'int', 'NULL', '', '', '',
        'edit_subject', 'char', 'NULL', 1, '', '',
        'locale', 'varchar', 'NULL', 16, '', '', 
        'calling_list_exempt', 'char', 'NULL', 1, '', '',
        'invoice_noemail', 'char', 'NULL', 1, '', '',
        'message_noemail', 'char', 'NULL', 1, '', '',
        'bill_locationnum', 'int', 'NULL', '', '', '',
        'ship_locationnum', 'int', 'NULL', '', '', '',
      ],
      'primary_key'  => 'custnum',
      'unique'       => [ [ 'agentnum', 'agent_custid' ] ],
      #'index'        => [ ['last'], ['company'] ],
      'index'        => [
                          ['agentnum'], ['refnum'], ['classnum'], ['usernum'],
                          [ 'custbatch' ],
                          [ 'referral_custnum' ],
                          [ 'payby' ], [ 'paydate' ],
                          [ 'archived' ],
                          [ 'ship_locationnum' ],
                          [ 'bill_locationnum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                          { columns    => [ 'salesnum' ],
                            table      => 'sales',
                          },
                          { columns    => [ 'refnum' ],
                            table      => 'part_referral',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'cust_class',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'referral_custnum' ],
                            table      => 'cust_main',
                            references => [ 'custnum' ],
                          },
                          { columns    => [ 'bill_locationnum' ],
                            table      => 'cust_location',
                            references => [ 'locationnum' ],
                          },
                          { columns    => [ 'ship_locationnum' ],
                            table      => 'cust_location',
                            references => [ 'locationnum' ],
                          },
                        ],
    },

    'cust_payby' => {
      'columns' => [
        'custpaybynum', 'serial',     '',        '', '', '', 
        'custnum',         'int',     '',        '', '', '',
        'weight',          'int',     '',        '', '', '', 
        'payby',          'char',     '',         4, '', '', 
        'payinfo',     'varchar', 'NULL',       512, '', '', 
        'paycvv',      'varchar', 'NULL',       512, '', '', 
        'paymask',     'varchar', 'NULL',   $char_d, '', '', 
        #'paydate',   @date_type, '', '', 
        'paydate',     'varchar', 'NULL',        10, '', '', 
        'paystart_month',  'int', 'NULL',        '', '', '', 
        'paystart_year',   'int', 'NULL',        '', '', '', 
        'payissue',    'varchar', 'NULL',         2, '', '', 
        'payname',     'varchar', 'NULL', 2*$char_d, '', '', 
        'paystate',    'varchar', 'NULL',   $char_d, '', '', 
        'paytype',     'varchar', 'NULL',   $char_d, '', '', 
        'payip',       'varchar', 'NULL',        15, '', '', 
        'locationnum',     'int', 'NULL',        '', '', '',
      ],
      'primary_key'  => 'custpaybynum',
      'unique'       => [],
      'index'        => [ [ 'custnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                        ],
    },

    'contact_class' => {
      'columns' => [
        'classnum',    'serial',   '',      '', '', '', 
        'classname',   'varchar',  '', $char_d, '', '', 
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },

    'contact' => {
      'columns' => [
        'contactnum', 'serial',     '',      '', '', '',
        'prospectnum',   'int', 'NULL',      '', '', '',
        'custnum',       'int', 'NULL',      '', '', '',
        'locationnum',   'int', 'NULL',      '', '', '', #not yet
        'classnum',      'int', 'NULL',      '', '', '',
#        'titlenum',      'int', 'NULL',      '', '', '', #eg Mr. Mrs. Dr. Rev.
        'last',      'varchar',     '', $char_d, '', '', 
#        'middle',    'varchar', 'NULL', $char_d, '', '', 
        'first',     'varchar',     '', $char_d, '', '', 
        'title',     'varchar', 'NULL', $char_d, '', '', #eg Head Bottle Washer
        'comment',   'varchar', 'NULL',     255, '', '', 
        'selfservice_access',    'char', 'NULL',       1, '', '',
        '_password',          'varchar', 'NULL', $char_d, '', '',
        '_password_encoding', 'varchar', 'NULL', $char_d, '', '',
        'disabled',              'char', 'NULL',       1, '', '', 
      ],
      'primary_key'  => 'contactnum',
      'unique'       => [],
      'index'        => [ [ 'prospectnum' ], [ 'custnum' ], [ 'locationnum' ],
                          [ 'last' ], [ 'first' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'prospectnum' ],
                            table      => 'prospect_main',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'contact_class',
                          },
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
      'primary_key'  => 'contactphonenum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'contactnum' ],
                            table      => 'contact',
                          },
                          { columns    => [ 'phonetypenum' ],
                            table      => 'phone_type',
                          },
                        ],
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
      'primary_key'  => 'contactemailnum',
      #'unique'       => [ [ 'contactnum', 'emailaddress' ], ],
      'unique'       => [ [ 'emailaddress' ], ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'contactnum' ],
                            table      => 'contact',
                          },
                        ],
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
      'primary_key'  => 'prospectnum',
      'unique'       => [],
      'index'        => [ [ 'company' ], [ 'agentnum' ], [ 'disabled' ] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
    },

    'quotation' => {
      'columns' => [
        #regular fields
        'quotationnum',   'serial',     '', '', '', '', 
        'prospectnum',       'int', 'NULL', '', '', '',
        'custnum',           'int', 'NULL', '', '', '',
        '_date',        @date_type,             '', '', 
        'disabled',         'char', 'NULL',  1, '', '', 
        'usernum',           'int', 'NULL', '', '', '',
        #'total',      @money_type,       '', '', 
        #'quotation_term', 'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'quotationnum',
      'unique'       => [],
      'index'        => [ [ 'prospectnum' ], ['custnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'prospectnum' ],
                            table      => 'prospect_main',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
    },

    'quotation_pkg' => {
      'columns' => [
        'quotationpkgnum',   'serial',     '', '', '', '', 
        'quotationnum',         'int', 'NULL', '', '', '', #shouldn't be null,
                                                           # but history...
        'pkgpart',              'int',     '', '', '', '', 
        'locationnum',          'int', 'NULL', '', '', '',
        'start_date',      @date_type,             '', '', 
        'contract_end',    @date_type,             '', '',
        'quantity',             'int', 'NULL', '', '', '',
        'waive_setup',         'char', 'NULL',  1, '', '', 
      ],
      'primary_key'  => 'quotationpkgnum',
      'unique'       => [],
      'index'        => [ ['pkgpart'], ],
      'foreign_keys' => [
                          { columns    => [ 'quotationnum' ],
                            table      => 'quotation',
                          },
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                        ],
    },

    'quotation_pkg_discount' => {
      'columns' => [
        'quotationpkgdiscountnum', 'serial', '', '', '', '',
        'quotationpkgnum',            'int', '', '', '', '', 
        'discountnum',                'int', '', '', '', '',
        #'end_date',              @date_type,         '', '',
      ],
      'primary_key'  => 'quotationpkgdiscountnum',
      'unique'       => [],
      'index'        => [ [ 'quotationpkgnum' ], ], #[ 'discountnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'quotationpkgnum' ],
                            table      => 'quotation_pkg',
                          },
                          { columns    => [ 'discountnum' ],
                            table      => 'discount',
                          },
                        ],
    },

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
        'addr_clean',         'char', 'NULL',       1, '', '',
        'country',            'char',     '',       2, '', '', 
        'geocode',         'varchar', 'NULL',      20, '', '',
        'district',        'varchar', 'NULL',      20, '', '',
        'censustract',     'varchar', 'NULL',      20, '', '',
        'censusyear',         'char', 'NULL',       4, '', '',
        'location_type',   'varchar', 'NULL',      20, '', '',
        'location_number', 'varchar', 'NULL',      20, '', '',
        'location_kind',      'char', 'NULL',       1, '', '',
        'disabled',           'char', 'NULL',       1, '', '', 
      ],
      'primary_key'  => 'locationnum',
      'unique'       => [],
      'index'        => [ [ 'prospectnum' ], [ 'custnum' ],
                          [ 'county' ], [ 'state' ], [ 'country' ], [ 'zip' ],
                          [ 'city' ], [ 'district' ]
                        ],
      'foreign_keys' => [
                          { columns    => [ 'prospectnum' ],
                            table      => 'prospect_main',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
    },

    'cust_main_invoice' => {
      'columns' => [
        'destnum',  'serial',  '',     '', '', '', 
        'custnum',  'int',  '',     '', '', '', 
        'dest',     'varchar', '',  $char_d, '', '', 
      ],
      'primary_key'  => 'destnum',
      'unique'       => [],
      'index'        => [ ['custnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
    },

    'cust_main_credit_limit' => {
      'columns' => [
        'creditlimitnum',   'serial', '', '', '', '',
        'custnum',             'int', '', '', '', '', 
        '_date',          @date_type,         '', '', 
        'amount',       @money_typen,         '', '',
        #'amount_currency', 'char', 'NULL',  3, '', '',
        'credit_limit', @money_typen,         '', '',
        #'credit_limit_currency', 'char', 'NULL',  3, '', '',
      ],
      'primary_key'  => 'creditlimitnum',
      'unique'       => [],
      'index'        => [ ['custnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
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
      'primary_key'  => 'notenum',
      'unique'       => [],
      'index'        => [ [ 'custnum' ], [ '_date' ], [ 'usernum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'cust_note_class',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
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
        'classnum',     'serial',     '',      '', '', '', 
        'classname',   'varchar',     '', $char_d, '', '', 
        'categorynum',     'int', 'NULL',      '', '', '', 
        'tax',            'char', 'NULL',       1, '', '', 
        'disabled',       'char', 'NULL',       1, '', '', 
      ],
      'primary_key'  => 'classnum',
      'unique'       => [],
      'index'        => [ ['disabled'] ],
      'foreign_keys' => [
                          { columns    => [ 'categorynum' ],
                            table      => 'cust_category',
                          },
                        ],
    },
 
    'cust_tag' => {
      'columns' => [
        'custtagnum', 'serial', '', '', '', '',
        'custnum',       'int', '', '', '', '',
        'tagnum',        'int', '', '', '', '',
      ],
      'primary_key'  => 'custtagnum',
      'unique'       => [ [ 'custnum', 'tagnum' ] ],
      'index'        => [ [ 'custnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'tagnum' ],
                            table      => 'part_tag',
                          },
                        ],
    },

    'part_tag' => {
      'columns' => [
        'tagnum',    'serial',     '',      '', '', '',
        'tagname',  'varchar',     '', $char_d, '', '',
        'tagdesc',  'varchar', 'NULL', $char_d, '', '',
        'tagcolor', 'varchar', 'NULL',       6, '', '',
        'by_default',  'char', 'NULL',       1, '', '',
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'tagnum',
      'unique'      => [], #[ [ 'tagname' ] ], #?
      'index'       => [ [ 'disabled' ] ],
    },

    'cust_main_exemption' => {
      'columns' => [
        'exemptionnum',   'serial',     '',      '', '', '',
        'custnum',           'int',     '',      '', '', '', 
        'taxname',       'varchar',     '', $char_d, '', '',
        'exempt_number', 'varchar', 'NULL', $char_d, '', '',
        #start/end dates?  for reporting?
      ],
      'primary_key'  => 'exemptionnum',
      'unique'       => [],
      'index'        => [ [ 'custnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
    },

    'cust_tax_adjustment' => {
      'columns' => [
        'adjustmentnum', 'serial',     '',      '', '', '',
        'custnum',          'int',     '',      '', '', '',
        'taxname',      'varchar',     '', $char_d, '', '',
        'amount',     @money_type,                  '', '', 
        'currency',        'char', 'NULL',       3, '', '',
        'comment',      'varchar', 'NULL', $char_d, '', '', 
        'billpkgnum',       'int', 'NULL',      '', '', '',
        #more?  no cust_bill_pkg_tax_location?
      ],
      'primary_key'  => 'adjustmentnum',
      'unique'       => [],
      'index'        => [ [ 'custnum' ], [ 'billpkgnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                        ],
    },

    'cust_main_county' => { #district+city+county+state+country are checked 
                            #off the cust_main_county for validation and to 
                            #provide a tax rate.
      'columns' => [
        'taxnum',    'serial',     '',      '', '', '', 
        'district', 'varchar', 'NULL',      20, '', '',
        'city',     'varchar', 'NULL', $char_d, '', '',
        'county',   'varchar', 'NULL', $char_d, '', '', 
        'state',    'varchar', 'NULL', $char_d, '', '', 
        'country',     'char',     '',       2, '', '', 
        'taxclass', 'varchar', 'NULL', $char_d, '', '', 
        'exempt_amount', @money_type,            '', '', 
        'exempt_amount_currency', 'char', 'NULL', 3, '', '',
        'tax',         'real',     '',      '', '', '', #tax %
        'taxname',  'varchar', 'NULL', $char_d, '', '', 
        'setuptax',    'char', 'NULL',       1, '', '', # Y = setup tax exempt
        'recurtax',    'char', 'NULL',       1, '', '', # Y = recur tax exempt
      ],
      'primary_key' => 'taxnum',
      'unique' => [],
  #    'unique' => [ ['taxnum'], ['state', 'county'] ],
      'index' => [ [ 'district' ], [ 'city' ], [ 'county' ], [ 'state' ], 
                   [ 'country' ],
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
      'primary_key'  => 'taxnum',
      'unique'       => [],
      'index'        => [ ['taxclassnum'], ['data_vendor', 'geocode'] ],
      'foreign_keys' => [
                          { columns    => [ 'taxclassnum' ],
                            table      => 'tax_class',
                          },
                        ],
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
        'paypendingnum',      'serial',     '',      '', '', '',
        'custnum',               'int',     '',      '', '', '', 
        'paid',            @money_type,                  '', '', 
        'currency',             'char', 'NULL',       3, '', '',
        '_date',            @date_type,                  '', '', 
        'payby',                'char',     '',       4, '', '',
        'payinfo',           'varchar', 'NULL',     512, '', '',
	'paymask',           'varchar', 'NULL', $char_d, '', '', 
        'paydate',           'varchar', 'NULL',     10, '', '', 
        'recurring_billing', 'varchar', 'NULL', $char_d, '', '',
        'payunique',         'varchar', 'NULL', $char_d, '', '', #separate paybatch "unique" functions from current usage

        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances
        'status',       'varchar',     '', $char_d, '', '', 
        'session_id',   'varchar', 'NULL', 1024, '', '', # SHA-512-hex
        'statustext',   'text',    'NULL',  '', '', '', 
        'gatewaynum',   'int',     'NULL',  '', '', '',
        #'cust_balance', @money_type,            '', '',
        'paynum',       'int',     'NULL',  '', '', '',
        'void_paynum',  'int',     'NULL',  '', '', '',
        'jobnum',    'bigint',     'NULL',  '', '', '', 
        'invnum',       'int',     'NULL',  '', '', '',
        'manual',       'char',    'NULL',   1, '', '',
        'discount_term','int',     'NULL',  '', '', '',
        'failure_status','varchar','NULL',  16, '', '',
      ],
      'primary_key'  => 'paypendingnum',
      'unique'       => [ [ 'payunique' ] ],
      'index'        => [ [ 'custnum' ], [ 'status' ], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'gatewaynum' ],
                            table      => 'payment_gateway',
                          },
                          { columns    => [ 'paynum' ],
                            table      => 'cust_pay',
                          },
                          { columns    => [ 'void_paynum' ],
                            table      => 'cust_pay_void',
                            references => [ 'paynum' ],
                          },
                          { columns    => [ 'jobnum' ],
                            table      => 'queue',
                          },
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                        ],
    },

    'cust_pay' => {
      'columns' => [
        'paynum',       'serial',    '',       '', '', '',
        'custnum',         'int',    '',       '', '', '', 
        '_date',     @date_type,                   '', '', 
        'paid',      @money_type,                  '', '', 
        'currency',       'char', 'NULL',       3, '', '',
        'otaker',      'varchar', 'NULL',      32, '', '',
        'usernum',         'int', 'NULL',      '', '', '',
        'payby',          'char',     '',       4, '', '',
        'payinfo',     'varchar', 'NULL',     512, '', '',
        'paymask',     'varchar', 'NULL', $char_d, '', '', 
        'paydate',     'varchar', 'NULL',      10, '', '', 
        'paybatch',    'varchar', 'NULL', $char_d, '', '',#for auditing purposes
        'payunique',   'varchar', 'NULL', $char_d, '', '',#separate paybatch "unique" functions from current usage
        'closed',         'char', 'NULL',       1, '', '', 
        'pkgnum', 'int', 'NULL', '', '', '', #desired pkgnum for pkg-balances

        # cash/check deposit info fields
        'bank',        'varchar', 'NULL', $char_d, '', '',
        'depositor',   'varchar', 'NULL', $char_d, '', '',
        'account',     'varchar', 'NULL',      20, '', '',
        'teller',      'varchar', 'NULL',      20, '', '',

        'batchnum',        'int', 'NULL',      '', '', '',#pay_batch foreign key

        # credit card/EFT fields (formerly in paybatch)
        'gatewaynum',      'int', 'NULL',      '', '', '', # payment_gateway FK
        'processor',   'varchar', 'NULL', $char_d, '', '', # module name
        'auth',        'varchar', 'NULL',      16, '', '', # CC auth number
        'order_number','varchar', 'NULL', $char_d, '', '', # transaction number
      ],
      'primary_key'  => 'paynum',
      #i guess not now, with cust_pay_pending, if we actually make it here, we _do_ want to record it# 'unique' => [ [ 'payunique' ] ],
      'index'        => [ ['custnum'], ['paybatch'], ['payby'], ['_date'],
                          ['usernum'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'batchnum' ],
                            table      => 'pay_batch',
                          },
                          { columns    => [ 'gatewaynum' ],
                            table      => 'payment_gateway',
                          },
                        ],
    },

    'cust_pay_void' => {
      'columns' => [
        'paynum',          'int',    '',       '', '', '', 
        'custnum',         'int',    '',       '', '', '', 
        '_date',      @date_type,                  '', '', 
        'paid',      @money_type,                  '', '', 
        'currency',       'char', 'NULL',       3, '', '',
        'otaker',      'varchar', 'NULL',      32, '', '', 
        'usernum',         'int', 'NULL',      '', '', '',
        'payby',          'char',     '',       4, '', '',
        'payinfo',     'varchar', 'NULL',     512, '', '',
	'paymask',     'varchar', 'NULL', $char_d, '', '', 
        #'paydate' ?
        'paybatch',    'varchar', 'NULL', $char_d, '', '', #for auditing purposes.
        'closed',        'char',  'NULL',       1, '', '', 
        'pkgnum', 'int',   'NULL', '', '', '', #desired pkgnum for pkg-balances

        # cash/check deposit info fields
        'bank',       'varchar', 'NULL', $char_d, '', '',
        'depositor',  'varchar', 'NULL', $char_d, '', '',
        'account',    'varchar', 'NULL',      20, '', '',
        'teller',     'varchar', 'NULL',      20, '', '',
        'batchnum',       'int', 'NULL',      '', '', '', #pay_batch foreign key

        # credit card/EFT fields (formerly in paybatch)
        'gatewaynum',      'int', 'NULL',      '', '', '', # payment_gateway FK
        'processor',   'varchar', 'NULL', $char_d, '', '', # module name
        'auth',        'varchar', 'NULL',      16, '', '', # CC auth number
        'order_number','varchar', 'NULL', $char_d, '', '', # transaction number

        #void fields
        'void_date',  @date_type,                  '', '', 
        'reason',      'varchar', 'NULL', $char_d, '', '', 
        'void_usernum',    'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'paynum',
      'unique'       => [],
      'index'        => [ ['custnum'], ['usernum'], ['void_usernum'] ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'batchnum' ],
                            table      => 'pay_batch',
                          },
                          { columns    => [ 'gatewaynum' ],
                            table      => 'payment_gateway',
                          },
                          { columns    => [ 'void_usernum' ],
                            table      => 'access_user',
                            references => [ 'usernum' ],
                          },
                        ],
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
      'primary_key'  => 'billpaynum',
      'unique'       => [],
      'index'        => [ [ 'paynum' ], [ 'invnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                          { columns    => [ 'paynum' ],
                            table      => 'cust_pay',
                          },
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                        ],
    },

    'cust_bill_pay_batch' => {
      'columns' => [
        'billpaynum', 'serial',     '',   '', '', '', 
        'invnum',  'int',     '',   '', '', '', 
        'paybatchnum',  'int',     '',   '', '', '', 
        'amount',  @money_type, '', '', 
        '_date',   @date_type, '', '', 
      ],
      'primary_key'  => 'billpaynum',
      'unique'       => [],
      'index'        => [ [ 'paybatchnum' ], [ 'invnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                          { columns    => [ 'paybatchnum' ],
                            table      => 'cust_pay_batch',
                          },
                        ],
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
      'primary_key'  => 'billpaypkgnum',
      'unique'       => [],
      'index'        => [ [ 'billpaynum' ], [ 'billpkgnum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'billpaynum' ],
                            table      => 'cust_bill_pay',
                          },
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                          { columns    => [ 'billpkgtaxlocationnum' ],
                            table      => 'cust_bill_pkg_tax_location',
                          },
                          { columns    => [ 'billpkgtaxratelocationnum' ],
                            table      => 'cust_bill_pkg_tax_rate_location',
                          },
                        ],
    },

    'pay_batch' => { #batches of payments to an external processor
      'columns' => [
        'batchnum', 'serial',     '', '', '', '', 
        'agentnum',    'int', 'NULL', '', '', '', 
        'payby',      'char',     '',  4, '', '', # CARD/CHEK
        'status',     'char', 'NULL',  1, '', '', 
        'download',       @date_type,     '', '', 
        'upload',         @date_type,     '', '', 
        'title',   'varchar', 'NULL',255, '', '',
      ],
      'primary_key'  => 'batchnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'cust_pay_batch' => { #list of customers in current CARD/CHEK batch
      'columns' => [
        'paybatchnum',    'serial',     '',      '', '', '', 
        'batchnum',          'int',     '',      '', '', '', 
        'invnum',            'int',     '',      '', '', '', 
        'custnum',           'int',     '',      '', '', '', 
        'last',          'varchar',     '', $char_d, '', '', 
        'first',         'varchar',     '', $char_d, '', '', 
        'address1',      'varchar',     '', $char_d, '', '', 
        'address2',      'varchar', 'NULL', $char_d, '', '', 
        'city',          'varchar',     '', $char_d, '', '', 
        'state',         'varchar', 'NULL', $char_d, '', '', 
        'zip',           'varchar', 'NULL',      10, '', '', 
        'country',          'char',     '',       2, '', '', 
        'payby',            'char',     '',       4, '', '',
        'payinfo',       'varchar', 'NULL',     512, '', '', 
        #'exp',          @date_type,                  '', '',
        'exp',           'varchar', 'NULL',      11, '', '', 
        'payname',       'varchar', 'NULL', $char_d, '', '', 
        'amount',      @money_type,                  '', '', 
        'currency',         'char', 'NULL',       3, '', '',
        'status',        'varchar', 'NULL', $char_d, '', '', 
        'failure_status','varchar', 'NULL',      16, '', '',
        'error_message', 'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'paybatchnum',
      'unique'       => [],
      'index'        => [ ['batchnum'], ['invnum'], ['custnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'batchnum' ],
                            table      => 'pay_batch',
                          },
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
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
        'contactnum',          'int', 'NULL', '', '', '', 
        'locationnum',         'int', 'NULL', '', '', '',
        'otaker',          'varchar', 'NULL', 32, '', '', 
        'usernum',             'int', 'NULL', '', '', '',
        'salesnum',            'int', 'NULL', '', '', '', 
        'order_date',     @date_type,             '', '', 
        'start_date',     @date_type,             '', '', 
        'setup',          @date_type,             '', '', 
        'bill',           @date_type,             '', '', 
        'last_bill',      @date_type,             '', '', 
        'susp',           @date_type,             '', '', 
        'adjourn',        @date_type,             '', '', 
        'resume',         @date_type,             '', '', 
        'cancel',         @date_type,             '', '', 
        'uncancel',       @date_type,             '', '', 
        'uncancel_pkgnum',     'int', 'NULL', '', '', '',
        'expire',         @date_type,             '', '', 
        'contract_end',   @date_type,             '', '',
        'dundate',        @date_type,             '', '',
        'change_date',    @date_type,             '', '',
        'change_pkgnum',       'int', 'NULL', '', '', '',
        'change_pkgpart',      'int', 'NULL', '', '', '',
        'change_locationnum',  'int', 'NULL', '', '', '',
        'change_custnum',      'int', 'NULL', '', '', '',
        'main_pkgnum',         'int', 'NULL', '', '', '',
        'pkglinknum',          'int', 'NULL', '', '', '',
        'manual_flag',        'char', 'NULL',  1, '', '', 
        'no_auto',            'char', 'NULL',  1, '', '', 
        'quantity',            'int', 'NULL', '', '', '',
        'agent_pkgid',     'varchar', 'NULL', $char_d, '', '',
        'waive_setup',        'char', 'NULL',  1, '', '', 
        'recur_show_zero',    'char', 'NULL',  1, '', '',
        'setup_show_zero',    'char', 'NULL',  1, '', '',
        'change_to_pkgnum',    'int', 'NULL', '', '', '',
      ],
      'primary_key'  => 'pkgnum',
      'unique'       => [],
      'index'        => [ ['custnum'], ['pkgpart'], ['pkgbatch'],
                          ['locationnum'], ['usernum'], ['agent_pkgid'],
                          ['order_date'], [ 'start_date' ], ['setup'], ['bill'],
                          ['last_bill'], ['susp'], ['adjourn'], ['cancel'],
                          ['expire'], ['contract_end'], ['change_date'],
                          ['no_auto'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                          { columns    => [ 'contactnum' ],
                            table      => 'contact',
                          },
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'salesnum' ],
                            table      => 'sales',
                          },
                          { columns    => [ 'uncancel_pkgnum' ],
                            table      => 'cust_pkg',
                            references => [ 'pkgnum' ],
                          },
                          { columns    => [ 'change_pkgnum' ],
                            table      => 'cust_pkg',
                            references => [ 'pkgnum' ],
                          },
                          { columns    => [ 'change_pkgpart' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ],
                          },
                          { columns    => [ 'change_locationnum' ],
                            table      => 'cust_location',
                            references => [ 'locationnum' ],
                          },
                          { columns    => [ 'change_custnum' ],
                            table      => 'cust_main',
                            references => [ 'custnum' ],
                          },
                          { columns    => [ 'main_pkgnum' ],
                            table      => 'cust_pkg',
                            references => [ 'pkgnum' ],
                          },
                          { columns    => [ 'pkglinknum' ],
                            table      => 'part_pkg_link',
                          },
                          { columns    => [ 'change_to_pkgnum' ],
                            table      => 'cust_pkg',
                            references => [ 'pkgnum' ],
                          },
                        ],
   },

    'cust_pkg_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'pkgnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'pkgnum' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                        ],
    },

    'cust_pkg_detail' => {
      'columns' => [
        'pkgdetailnum', 'serial', '',      '', '', '',
        'pkgnum',          'int', '',      '', '', '',
        'detail',      'varchar', '', $char_d, '', '', 
        'detailtype',     'char', '',       1, '', '', # "I"nvoice or "C"omment
        'weight',          'int', '',      '', '', '',
      ],
      'primary_key'  => 'pkgdetailnum',
      'unique'       => [],
      'index'        => [ [ 'pkgnum', 'detailtype' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                        ],
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
      'primary_key'  => 'num',
      'unique'       => [],
      'index'        => [ ['pkgnum'], ['reasonnum'], ['action'], ['usernum'], ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'reasonnum' ],
                            table      => 'reason',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
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
      'primary_key'  => 'pkgdiscountnum',
      'unique'       => [],
      'index'        => [ [ 'pkgnum' ], [ 'discountnum' ], [ 'usernum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'discountnum' ],
                            table      => 'discount',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
    },

    'cust_pkg_usage' => {
      'columns' => [
        'pkgusagenum', 'serial', '', '', '', '',
        'pkgnum',         'int', '', '', '', '',
        'minutes',        'double precision', '', '', '', '',
        'pkgusagepart',   'int', '', '', '', '',
      ],
      'primary_key'  => 'pkgusagenum',
      'unique'       => [],
      'index'        => [ [ 'pkgnum' ], [ 'pkgusagepart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'pkgusagepart' ],
                            table      => 'part_pkg_usage',
                          },
                        ],
    },

    'cdr_cust_pkg_usage' => {
      'columns' => [
        'cdrusagenum', 'bigserial', '', '', '', '',
        'acctid',      'bigint',    '', '', '', '',
        'pkgusagenum', 'int',       '', '', '', '',
        'minutes',     'double precision',       '', '', '', '',
      ],
      'primary_key'  => 'cdrusagenum',
      'unique'       => [],
      'index'        => [ [ 'pkgusagenum' ], [ 'acctid' ] ],
      'foreign_keys' => [
                          { columns    => [ 'acctid' ],
                            table      => 'cdr',
                          },
                          { columns    => [ 'pkgusagenum' ],
                            table      => 'cust_pkg_usage',
                          },
                        ],
    },

    'cust_bill_pkg_discount' => {
      'columns' => [
        'billpkgdiscountnum', 'serial',        '', '', '', '',
        'billpkgnum',            'int',        '', '', '', '', 
        'pkgdiscountnum',        'int',        '', '', '', '', 
        'amount',          @money_type,                '', '', 
        'months',            'decimal', 'NULL', '7,4', '', '',
      ],
      'primary_key'  => 'billpkgdiscountnum',
      'unique'       => [],
      'index'        => [ [ 'billpkgnum' ], [ 'pkgdiscountnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                          { columns    => [ 'pkgdiscountnum' ],
                            table      => 'cust_pkg_discount',
                          },
                        ],
    },

    'cust_bill_pkg_discount_void' => {
      'columns' => [
        'billpkgdiscountnum',    'int',        '', '', '', '',
        'billpkgnum',            'int',        '', '', '', '', 
        'pkgdiscountnum',        'int',        '', '', '', '', 
        'amount',          @money_type,                '', '', 
        'months',            'decimal', 'NULL', '7,4', '', '',
      ],
      'primary_key'  => 'billpkgdiscountnum',
      'unique'       => [],
      'index'        => [ [ 'billpkgnum' ], [ 'pkgdiscountnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg_void',
                          },
                          { columns    => [ 'pkgdiscountnum' ],
                            table      => 'cust_pkg_discount',
                          },
                        ],
    },

    'discount' => {
      'columns' => [
        'discountnum', 'serial',     '',      '', '', '',
        #'agentnum',       'int', 'NULL',      '', '', '', 
        'classnum',       'int', 'NULL',      '', '', '',
        'name',       'varchar', 'NULL', $char_d, '', '',
        'amount',   @money_type,                  '', '', 
        'percent',    'decimal',     '',   '7,4', '', '',
        'months',     'decimal', 'NULL',   '7,4', '', '',
        'disabled',      'char', 'NULL',       1, '', '', 
        'setup',         'char', 'NULL',       1, '', '', 
        #'linked',        'char', 'NULL',       1, '', '',
      ],
      'primary_key'  => 'discountnum',
      'unique'       => [],
      'index'        => [], # [ 'agentnum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'classnum' ],
                            table      => 'discount_class',
                          },
                        ],
    },

    'discount_class' => {
      'columns' => [
        'classnum',    'serial',   '',      '', '', '', 
        'classname',   'varchar',  '', $char_d, '', '', 
        #'categorynum', 'int',  'NULL',      '', '', '', 
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index' => [ ['disabled'] ],
    },

    'cust_refund' => {
      'columns' => [
        'refundnum',    'serial',    '',   '', '', '', 
        'custnum',  'int',    '',   '', '', '', 
        '_date',        @date_type, '', '', 
        'refund',       @money_type, '', '', 
        'currency',       'char', 'NULL',       3, '', '',
        'otaker',       'varchar',   'NULL',   32, '', '', 
        'usernum',   'int', 'NULL', '', '', '',
        'reason',       'varchar',   'NULL',   $char_d, '', '', 
        'reasonnum',   'int', 'NULL', '', '', '',
        'payby',        'char',   '',     4, '', '', # CARD/BILL/COMP, should
                                                     # be index into payby
                                                     # table eventually
        'payinfo',      'varchar',   'NULL', 512, '', '', #see cust_main above
	'paymask', 'varchar', 'NULL', $char_d, '', '', 
        'paybatch',     'varchar',   'NULL', $char_d, '', '', 
        'closed',    'char', 'NULL', 1, '', '', 
        # credit card/EFT fields (formerly in paybatch)
        'gatewaynum',     'int', 'NULL', '', '', '', # payment_gateway FK
        'processor',  'varchar', 'NULL', $char_d, '', '', # module name
        'auth',       'varchar','NULL',16, '', '', # CC auth number
        'order_number', 'varchar','NULL',$char_d, '', '', # transaction number
      ],
      'primary_key'  => 'refundnum',
      'unique'       => [],
      'index'        => [ ['custnum'], ['_date'], [ 'usernum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'reasonnum' ],
                            table      => 'reason',
                          },
                          { columns    => [ 'gatewaynum' ],
                            table      => 'payment_gateway',
                          },
                        ],
    },

    'cust_credit_refund' => {
      'columns' => [
        'creditrefundnum', 'serial',     '',   '', '', '', 
        'crednum',  'int',     '',   '', '', '', 
        'refundnum',  'int',     '',   '', '', '', 
        'amount',  @money_type, '', '', 
        '_date',   @date_type, '', '', 
      ],
      'primary_key'  => 'creditrefundnum',
      'unique'       => [],
      'index'        => [ ['crednum'], ['refundnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'crednum' ],
                            table      => 'cust_credit',
                          },
                          { columns    => [ 'refundnum' ],
                            table      => 'cust_refund',
                          },
                        ],
    },


    'cust_svc' => {
      'columns' => [
        'svcnum',      'serial',     '', '', '', '', 
        'pkgnum',         'int', 'NULL', '', '', '', 
        'svcpart',        'int',     '', '', '', '', 
        'agent_svcid',    'int', 'NULL', '', '', '',
        'overlimit',           @date_type,   '', '', 
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [ ['svcnum'], ['pkgnum'], ['svcpart'],
                          ['agent_svcid'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'svcpart' ],
                            table      => 'part_svc',
                          },
                        ],
    },

    'cust_svc_option' => {
      'columns' => [
        'optionnum',   'serial', '', '', '', '', 
        'svcnum',      'int', '', '', '', '', 
        'optionname',  'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'svcnum' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
    },

    'svc_export_machine' => {
      'columns' => [
        'svcexportmachinenum', 'serial', '', '', '', '',
        'svcnum',                 'int', '', '', '', '', 
        'exportnum',              'int', '', '', '', '', 
        'machinenum',             'int', '', '', '', '',
      ],
      'primary_key'  => 'svcexportmachinenum',
      'unique'       => [ ['svcnum', 'exportnum'] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                          { columns    => [ 'machinenum' ],
                            table      => 'part_export_machine',
                          },
                        ],
    },

    'part_export_machine' => {
      'columns' => [
        'machinenum', 'serial', '', '', '', '',
        'exportnum',     'int', '', '', '', '',
        'machine',    'varchar', 'NULL', $char_d, '', '', 
        'disabled',      'char', 'NULL',       1, '', '',
      ],
      'primary_key'  => 'machinenum',
      'unique'       => [ [ 'exportnum', 'machine' ] ],
      'index'        => [ [ 'exportnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                        ],
    },

    'part_pkg' => {
      'columns' => [
        'pkgpart',       'serial',    '',   '', '', '', 
        'pkg',           'varchar',   '',   $char_d, '', '', 
        'comment',       'varchar', 'NULL', 2*$char_d, '', '', 
        'promo_code',    'varchar', 'NULL', $char_d, '', '', 
        'freq',          'varchar',   '',   $char_d, '', '', #billing frequency
        'setuptax',      'char', 'NULL', 1, '', '', 
        'recurtax',      'char', 'NULL', 1, '', '', 
        'plan',          'varchar', 'NULL', $char_d, '', '', 
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
        'fcc_voip_class','char',    'NULL',  1, '', '',
        'no_auto',          'char', 'NULL',  1, '', '', 
        'recur_show_zero',  'char', 'NULL',  1, '', '',
        'setup_show_zero',  'char', 'NULL',  1, '', '',
        'successor',     'int',     'NULL', '', '', '',
        'family_pkgpart','int',     'NULL', '', '', '',
        'delay_start',   'int',     'NULL', '', '', '',
        'agent_pkgpartid', 'varchar', 'NULL', 20, '', '',
      ],
      'primary_key'  => 'pkgpart',
      'unique'       => [],
      'index'        => [ [ 'promo_code' ], [ 'disabled' ], [ 'classnum' ],
                          [ 'agentnum' ], ['no_auto'], ['agent_pkgpartid'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'classnum' ],
                            table      => 'pkg_class',
                          },
                          { columns    => [ 'addon_classnum' ],
                            table      => 'pkg_class',
                            references => [ 'classnum' ],
                          },
                          { columns    => [ 'taxproductnum' ],
                            table      => 'part_pkg_taxproduct',
                          },
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                          { columns    => [ 'successor' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ],
                          },
                          { columns    => [ 'family_pkgpart' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ],
                          },
                        ],
    },

    'part_pkg_msgcat' => {
      'columns' => [
        'pkgpartmsgnum',  'serial',     '',        '', '', '',
        'pkgpart',           'int',     '',        '', '', '',
        'locale',        'varchar',     '',        16, '', '',
        'pkg',           'varchar',     '',   $char_d, '', '', #longer/no limit?
        'comment',       'varchar', 'NULL', 2*$char_d, '', '', #longer/no limit?
      ],
      'primary_key'  => 'pkgpartmsgnum',
      'unique'       => [ [ 'pkgpart', 'locale' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                        ],
    },

    'part_pkg_currency' => {
      'columns' => [
        'pkgcurrencynum', 'serial', '',      '', '', '',
        'pkgpart',           'int', '',      '', '', '',
        'currency',         'char', '',       3, '', '',
        'optionname',    'varchar', '', $char_d, '', '', 
        'optionvalue',      'text', '',      '', '', '', 
      ],
      'primary_key'  => 'pkgcurrencynum',
      'unique'       => [ [ 'pkgpart', 'currency', 'optionname' ] ],
      'index'        => [ ['pkgpart'] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                        ],
    },

    'currency_exchange' => {
      'columns' => [
        'currencyratenum', 'serial', '',    '', '', '',
        'from_currency',     'char', '',     3, '', '',
        'to_currency',       'char', '',     3, '', '',
        'rate',           'decimal', '', '7,6', '', '',
      ],
      'primary_key' => 'currencyratenum',
      'unique'      => [ [ 'from_currency', 'to_currency' ] ],
      'index'       => [],
    },

    'part_pkg_usageprice' => {
      'columns' => [
        'usagepricepart', 'serial',      '',      '', '', '',
        'pkgpart',           'int',      '',      '', '', '',
        'price',          @money_type,                '', '', 
        'currency',         'char',  'NULL',       3, '', '',
        'action',        'varchar',      '', $char_d, '', '',
        'target',        'varchar',      '', $char_d, '', '',
        'amount',        'varchar',      '', $char_d, '', '',
      ],
      'primary_key'  => 'usagepricepart',
      'unique'       => [ [ 'pkgpart', 'currency', 'target' ] ],
      'index'        => [ [ 'pkgpart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                        ],
    },

    'cust_pkg_usageprice' => {
      'columns' => [
        'usagepricenum', 'serial',      '',      '', '', '',
        'pkgnum',           'int',      '',      '', '', '',
        'usagepricepart',   'int',      '',      '', '', '',
        'quantity',         'int',      '',      '', '', '',
      ],
      'primary_key'  => 'usagepricenum',
      'unique'       => [ [ 'pkgnum', 'usagepricepart' ] ],
      'index'        => [ [ 'pkgnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'usagepricepart' ],
                            table      => 'part_pkg_usageprice',
                          },
                        ],
    },

    'part_fee' => {
      'columns' => [
        'feepart',       'serial',    '',   '', '', '',
        'itemdesc',      'varchar',   '',   $char_d,   '', '',
        'comment',       'varchar', 'NULL', 2*$char_d, '', '',
        'disabled',      'char',    'NULL',  1, '', '',
        'classnum',      'int',     'NULL', '', '', '',
        'taxclass',      'varchar', 'NULL', $char_d, '', '',
        'taxproductnum', 'int',     'NULL', '', '', '',
        'pay_weight',    'real',    'NULL', '', '', '',
        'credit_weight', 'real',    'NULL', '', '', '',
        'agentnum',      'int',     'NULL', '', '', '',
        'amount',   @money_type,                '', '', 
        'percent',     'decimal',    '', '7,4', '', '',
        'basis',         'varchar',  '',    16, '', '',
        'minimum',    @money_typen,             '', '',
        'maximum',    @money_typen,             '', '',
        'limit_credit',  'char',    'NULL',  1, '', '',
        'setuprecur',    'char',     '',     5, '', '',
        'taxable',       'char',    'NULL',  1, '', '',
      ],
      'primary_key'  => 'feepart',
      'unique'       => [],
      'index'        => [ [ 'disabled' ], [ 'classnum' ], [ 'agentnum' ]
                        ],
      'foreign_keys' => [
                          { columns    => [ 'classnum' ],
                            table      => 'pkg_class',
                          },
                          { columns    => [ 'taxproductnum' ],
                            table      => 'part_pkg_taxproduct',
                          },
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'part_fee_msgcat' => {
      'columns' => [
        'feepartmsgnum',  'serial',     '',        '', '', '',
        'feepart',           'int',     '',        '', '', '',
        'locale',        'varchar',     '',        16, '', '',
        'itemdesc',      'varchar',     '',   $char_d, '', '', #longer/no limit?
        'comment',       'varchar', 'NULL', 2*$char_d, '', '', #longer/no limit?
      ],
      'primary_key'  => 'feepartmsgnum',
      'unique'       => [ [ 'feepart', 'locale' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'feepart' ],
                            table      => 'part_fee',
                          },
                        ],
    },

    'part_fee_usage' => {
      'columns' => [
        'feepartusagenum','serial',     '',        '', '', '',
        'feepart',           'int',     '',        '', '', '',
        'classnum',          'int',     '',        '', '', '',
        'amount',   @money_type,                '', '',
        'percent',     'decimal',    '', '7,4', '', '',
      ],
      'primary_key'  => 'feepartusagenum',
      'unique'       => [ [ 'feepart', 'classnum' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'feepart' ],
                            table      => 'part_fee',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'usage_class',
                          },
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
      'primary_key'  => 'pkglinknum',
      'unique'       => [ ['src_pkgpart','dst_pkgpart','link_type','hidden'] ],
      'index'        => [ [ 'src_pkgpart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'src_pkgpart' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ]
                          },
                          { columns    => [ 'dst_pkgpart' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ]
                          },
                        ],
    },
    # XXX somewhat borked unique: we don't really want a hidden and unhidden
    # it turns out we'd prefer to use svc, bill, and invisibill (or something)

    'part_pkg_discount' => {
      'columns' => [
        'pkgdiscountnum', 'serial',   '',      '', '', '',
        'pkgpart',        'int',      '',      '', '', '',
        'discountnum',    'int',      '',      '', '', '', 
      ],
      'primary_key'  => 'pkgdiscountnum',
      'unique'       => [ [ 'pkgpart', 'discountnum' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                          { columns    => [ 'discountnum' ],
                            table      => 'discount',
                          },
                        ],
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
      'primary_key'  => 'pkgtaxratenum',
      'unique'       => [],
      'index'        => [ [ 'data_vendor', 'geocode', 'taxproductnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'taxproductnum' ],
                            table      => 'part_pkg_taxproduct',
                          },
                          { columns    => [ 'taxclassnumtaxed' ],
                            table      => 'tax_class',
                            references => [ 'taxclassnum' ],
                          },
                          { columns    => [ 'taxclassnum' ],
                            table      => 'tax_class',
                          },
                        ],
    },

    'part_pkg_taxoverride' => { 
      'columns' => [
        'taxoverridenum', 'serial', '', '', '', '',
        'pkgpart',           'int', '', '', '', '',
        'taxclassnum',       'int', '', '', '', '',
        'usage_class',    'varchar', 'NULL', $char_d, '', '', 
      ],
      'primary_key'  => 'taxoverridenum',
      'unique'       => [],
      'index'        => [ [ 'pkgpart' ], [ 'taxclassnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                          { columns    => [ 'taxclassnum' ],
                            table      => 'tax_class',
                          },
                        ],
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
        'pkgsvcnum',   'serial',    '', '', '', '', 
        'pkgpart',        'int',    '', '', '', '', 
        'svcpart',        'int',    '', '', '', '', 
        'quantity',       'int',    '', '', '', '', 
        'primary_svc',   'char', 'NULL', 1, '', '', 
        'hidden',        'char', 'NULL', 1, '', '',
        'bulk_skip',     'char', 'NULL', 1, '', '',
      ],
      'primary_key'  => 'pkgsvcnum',
      'unique'       => [ ['pkgpart', 'svcpart'] ],
      'index'        => [ ['pkgpart'], ['quantity'] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                          { columns    => [ 'svcpart' ],
                            table      => 'part_svc',
                          },
                        ],
    },

    'part_referral' => {
      'columns' => [
        'refnum',   'serial',     '',        '', '', '', 
        'referral', 'varchar',    '',   $char_d, '', '', 
        'disabled', 'char',   'NULL',         1, '', '', 
        'agentnum', 'int',    'NULL',        '', '', '', 
      ],
      'primary_key'  => 'refnum',
      'unique'       => [],
      'index'        => [ ['disabled'], ['agentnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'part_svc' => {
      'columns' => [
        'svcpart',             'serial',     '',        '', '', '', 
        'svc',                'varchar',     '',   $char_d, '', '', 
        'svcdb',              'varchar',     '',   $char_d, '', '', 
        'disabled',              'char', 'NULL',         1, '', '', 
        'preserve',              'char', 'NULL',         1, '', '',
        'selfservice_access', 'varchar', 'NULL',   $char_d, '', '',
        'classnum',               'int', 'NULL',        '', '', '',
        'restrict_edit_password','char', 'NULL',         1, '', '',
        'has_router',            'char', 'NULL',         1, '', '',
],
      'primary_key'  => 'svcpart',
      'unique'       => [],
      'index'        => [ [ 'disabled' ] ],
      'foreign_keys' => [
                          { columns    => [ 'classnum' ],
                            table      => 'part_svc_class',
                          },
                        ],
    },

    'part_svc_column' => {
      'columns' => [
        'columnnum',   'serial',      '',      '', '', '', 
        'svcpart',     'int',         '',      '', '', '', 
        'columnname',  'varchar',     '',      64, '', '', 
        'columnlabel', 'varchar', 'NULL', $char_d, '', '',
        'columnvalue', 'varchar', 'NULL',     512, '', '', 
        'columnflag',  'char',    'NULL',       1, '', '', 
      ],
      'primary_key'  => 'columnnum',
      'unique'       => [ [ 'svcpart', 'columnname' ] ],
      'index'        => [ [ 'svcpart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'svcpart' ],
                            table      => 'part_svc',
                          },
                        ],
    },

    'part_svc_class' => {
      'columns' => [
        'classnum',    'serial',   '',      '', '', '', 
        'classname',   'varchar',  '', $char_d, '', '', 
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index' => [ ['disabled'] ],
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
      'primary_key'  => 'localnum',
      'unique'       => [],
      'index'        => [ [ 'npa', 'nxx' ], [ 'popnum' ] ],
      'foreign_keys' => [
                         { columns    => [ 'popnum' ],
                           table      => 'svc_acct_pop',
                         },
                       ],
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
      'primary_key'  => 'qualnum',
      'unique'       => [],
      'index'        => [ ['locationnum'], ['custnum'], ['prospectnum'],
		          ['phonenum'], ['vendor_qual_id'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'prospectnum' ],
                            table      => 'prospect_main',
                          },
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                        ],
    },

    'qual_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'qualnum',  'int',     '',     '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'qualnum' ],
                            table      => 'qual',
                          },
                        ],
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
        # IP address mgmt
        'routernum', 'int', 'NULL',      '', '', '',
        'blocknum',  'int', 'NULL',      '', '', '', 
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
        #
      ],
      'primary_key'  => 'svcnum',
      #'unique'       => [ [ 'username', 'domsvc' ] ],
      'unique'       => [],
      'index'        => [ ['username'], ['domsvc'], ['pbxsvc'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'popnum' ],
                            table      => 'svc_acct_pop',
                          },
                          { columns    => [ 'sectornum' ],
                            table      => 'tower_sector',
                          },
                          { columns    => [ 'routernum' ],
                            table      => 'router',
                          },
                          { columns    => [ 'blocknum' ],
                            table      => 'addr_block',
                          },
                          { columns    => [ 'domsvc' ],
                            table      => 'svc_domain', #'cust_svc',
                            references => [ 'svcnum' ],
                          },
                          { columns    => [ 'pbxsvc' ],
                            table      => 'svc_pbx', #'cust_svc',
                            references => [ 'svcnum' ],
                          },
                        ],
    },

    'acct_rt_transaction' => {
      'columns' => [
        'svcrtid',   'int',    '',   '', '', '', #why am i not a serial
        'svcnum',    'int',    '',   '', '', '', 
        'transaction_id',       'int', '',   '', '', '', 
        '_date',   @date_type, '', '',
        'seconds',   'int', '',   '', '', '', #uhhhh
        'support',   'int', '',   '', '', '',
      ],
      'primary_key'  => 'svcrtid',
      'unique'       => [],
      'index'        => [ ['svcnum', 'transaction_id'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_acct', #'cust_svc',
                          },
                          # 1. RT tables aren't part of our data structure, so
                          #     we can't make sure Queue is created already
                          # 2. This is our internal hack for time tracking, not
                          #     a user-facing feature
                          #{ columns    => [ 'transaction_id' ],
                          #  table      => 'Transaction',
                          #  references => [ 'id' ],
                          #},
                        ],
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
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [ ['domain'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'catchall' ],
                            table      => 'svc_acct',
                            references => [ 'svcnum' ],
                          },
                          { columns    => [ 'parent_svcnum' ],
                            table      => 'cust_svc',
                            references => [ 'svcnum' ],
                          },
                          { columns    => [ 'registrarnum' ],
                            table      => 'registrar',
                          },
                        ],
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
      'primary_key'  => 'svcnum',
      'unique'       => [ ],
      'index'        => [ ['phonenum'], ['vendor_order_id'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
    },

    'dsl_device' => {
      'columns' => [
        'devicenum', 'serial',     '', '', '', '',
        #part_device?  or our own part_dsl_device?
        #'devicepart',   'int',     '', '', '', '',
        'svcnum',       'int',     '', '', '', '', 
        'mac_addr', 'varchar',     '', 12, '', '', 
      ],
      'primary_key'  => 'devicenum',
      'unique'       => [ [ 'mac_addr' ], ],
      'index'        => [ [ 'svcnum' ], ], # [ 'devicepart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_dsl',
                          },
                        ],
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
      'primary_key'  => 'notenum',
      'unique'       => [],
      'index'        => [ ['svcnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_dsl',
                          },
                        ],
    },

    'svc_dish' => {
      'columns' => [
        'svcnum',   'int',     '',     '', '', '',
        'acctnum',  'varchar', '',     16, '', '',
        'installdate', @date_type,         '', '', 
        'note',     'text',    'NULL', '', '', '',
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
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
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'typenum' ],
                            table      => 'hardware_type',
                          },
                          { columns    => [ 'statusnum' ],
                            table      => 'hardware_status',
                          },
                        ],
    },

    'hardware_class' => {
      'columns' => [
        'classnum',   'serial', '',      '', '', '',
        'classname', 'varchar', '', $char_d, '', '',
      ],
      'primary_key' => 'classnum',
      'unique' => [],
      'index'  => [],
    },

    'hardware_type' => {
      'columns' => [
        'typenum',  'serial',     '',      '', '', '',
        'classnum',    'int',     '',      '', '', '',
        'model',   'varchar',     '', $char_d, '', '',
        'revision','varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'typenum',
      'unique'       => [ [ 'classnum', 'model', 'revision' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'classnum' ],
                            table      => 'hardware_class',
                          },
                        ],
    },

    'hardware_status' => {
      'columns' => [
        'statusnum', 'serial', '',      '', '', '',
        'label'    ,'varchar', '', $char_d, '', '',
        'disabled',    'char', 'NULL',   1, '', '', 
      ],
      'primary_key' => 'statusnum',
      'unique' => [],
      'index'  => [],
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
      'primary_key'  => 'recnum',
      'unique'       => [],
      'index'        => [ ['svcnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_domain',
                          },
                        ],
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
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc', #svc_acct / svc_domain
                          },
                        ],
    },

    'cgp_rule_condition' => {
      'columns' => [
        'ruleconditionnum',  'serial',     '',      '', '', '',
        'conditionname',    'varchar',     '', $char_d, '', '',
        'op',               'varchar', 'NULL', $char_d, '', '',
        'params',           'varchar', 'NULL',     255, '', '',
        'rulenum',              'int',     '',      '', '', '',
      ],
      'primary_key'  => 'ruleconditionnum',
      'unique'       => [],
      'index'        => [ [ 'rulenum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'rulenum' ],
                            table      => 'cgp_rule',
                          },
                        ],
    },

    'cgp_rule_action' => {
       'columns' => [
        'ruleactionnum',  'serial',     '',      '', '', '',
        'action',        'varchar',     '', $char_d, '', '',
        'params',        'varchar', 'NULL',     255, '', '',
        'rulenum',           'int',     '',      '', '', '',
      ],
      'primary_key'  => 'ruleactionnum',
      'unique'       => [],
      'index'        => [ [ 'rulenum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'rulenum' ],
                            table      => 'cgp_rule',
                          },
                        ],
   },

    'svc_forward' => {
      'columns' => [
        'svcnum',   'int',            '',   '', '', '', 
        'srcsvc',   'int',        'NULL',   '', '', '', 
        'src',      'varchar',    'NULL',  255, '', '', 
        'dstsvc',   'int',        'NULL',   '', '', '', 
        'dst',      'varchar',    'NULL',  255, '', '', 
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [ ['srcsvc'], ['dstsvc'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'srcsvc' ],
                            table      => 'svc_acct',
                            references => [ 'svcnum' ]
                          },
                          { columns    => [ 'dstsvc' ],
                            table      => 'svc_acct',
                            references => [ 'svcnum' ]
                          },
                        ],
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
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'recnum' ],
                            table      => 'domain_record',
                          },
                          { columns    => [ 'usersvc' ],
                            table      => 'svc_acct',
                            references => [ 'svcnum' ]
                          },
                        ],
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
      'primary_key'  => 'prepaynum',
      'unique'       => [ ['identifier'] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'port' => {
      'columns' => [
        'portnum',  'serial',     '',   '', '', '', 
        'ip',       'varchar', 'NULL', 15, '', '', 
        'nasport',  'int',     'NULL', '', '', '', 
        'nasnum',   'int',     '',   '', '', '', 
      ],
      'primary_key'  => 'portnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'nasnum' ],
                            table      => 'nas',
                          },
                        ],
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
      'primary_key'  => 'nasnum',
      'unique'       => [ [ 'nasname' ], ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_broadband',#no? could be _acct?
                                                          #remove or cust_svc?
                          },
                        ],
    },

    'export_nas' => {
      'columns' => [
        'exportnasnum', 'serial', '', '', '', '', 
        'exportnum',       'int', '', '', '', '', 
        'nasnum',          'int', '', '', '', '', 
      ],
      'primary_key'  => 'exportnasnum',
      'unique'       => [ [ 'exportnum', 'nasnum' ] ],
      'index'        => [ [ 'exportnum' ], [ 'nasnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                          { columns    => [ 'nasnum' ],
                            table      => 'nas',
                          },
                        ],
    },

    'queue' => {
      'columns' => [
        'jobnum',   'bigserial',     '',      '', '', '', 
        'job',        'varchar',     '',     512, '', '', 
        '_date',          'int',     '',      '', '', '', 
        'status',     'varchar',     '', $char_d, '', '', 
        'statustext',    'text', 'NULL',      '', '', '', 
        'svcnum',         'int', 'NULL',      '', '', '', 
        'custnum',        'int', 'NULL',      '', '', '',
        'secure',        'char', 'NULL',       1, '', '',
        'priority',       'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'jobnum',
      'unique'       => [],
      'index'        => [ [ 'secure' ], [ 'priority' ],
                          [ 'job' ], [ 'svcnum' ], [ 'custnum' ], [ 'status' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
    },

    'queue_arg' => {
      'columns' => [
        'argnum', 'bigserial',     '', '', '', '', 
        'jobnum',    'bigint',     '', '', '', '', 
        'frozen',      'char', 'NULL',  1, '', '',
        'arg',         'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'argnum',
      'unique'       => [],
      'index'        => [ [ 'jobnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'jobnum' ],
                            table      => 'queue',
                            on_delete  => 'CASCADE',
                          },
                        ],
    },

    'queue_depend' => {
      'columns' => [
        'dependnum',  'bigserial', '', '', '', '', 
        'jobnum',        'bigint', '', '', '', '', 
        'depend_jobnum', 'bigint', '', '', '', '', 
      ],
      'primary_key'  => 'dependnum',
      'unique'       => [],
      'index'        => [ [ 'jobnum' ], [ 'depend_jobnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'jobnum' ],
                            table      => 'queue',
                          },
                          { columns    => [ 'depend_jobnum' ],
                            table      => 'queue',
                            references => [ 'jobnum' ],
                            on_delete  => 'CASCADE',
                          },
                        ],
    },

    'export_svc' => {
      'columns' => [
        'exportsvcnum' => 'serial', '', '', '', '', 
        'exportnum'    => 'int', '', '', '', '', 
        'svcpart'      => 'int', '', '', '', '', 
      ],
      'primary_key'  => 'exportsvcnum',
      'unique'       => [ [ 'exportnum', 'svcpart' ] ],
      'index'        => [ [ 'exportnum' ], [ 'svcpart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                          { columns    => [ 'svcpart' ],
                            table      => 'part_svc',
                          },
                        ],
    },

    'export_device' => {
      'columns' => [
        'exportdevicenum' => 'serial', '', '', '', '', 
        'exportnum'       => 'int', '', '', '', '', 
        'devicepart'      => 'int', '', '', '', '', 
      ],
      'primary_key'  => 'exportdevicenum',
      'unique'       => [ [ 'exportnum', 'devicepart' ] ],
      'index'        => [ [ 'exportnum' ], [ 'devicepart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                          { columns    => [ 'devicepart' ],
                            table      => 'part_device',
                          },
                        ],
    },

    'part_export' => {
      'columns' => [
        'exportnum',   'serial',     '',      '', '', '', 
        'exportname', 'varchar', 'NULL', $char_d, '', '',
        'machine',    'varchar', 'NULL', $char_d, '', '',
        'exporttype', 'varchar',     '', $char_d, '', '', 
        'nodomain',      'char', 'NULL',       1, '', '', 
        'default_machine','int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'exportnum',
      'unique'       => [],
      'index'        => [ [ 'machine' ], [ 'exporttype' ] ],
      'foreign_keys' => [
                          { columns    => [ 'default_machine' ],
                            table      => 'part_export_machine',
                            references => [ 'machinenum' ]
                          },
                        ],
    },

    'part_export_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'exportnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'exportnum' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                        ],
    },

    'radius_usergroup' => {
      'columns' => [
        'usergroupnum', 'serial', '', '', '', '', 
        'svcnum',       'int', '', '', '', '', 
        'groupname',    'varchar', 'NULL', $char_d, '', '', #deprecated
        'groupnum',     'int', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'usergroupnum',
      'unique'       => [],
      'index'        => [ [ 'svcnum' ], [ 'groupname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc', #svc_acct / svc_broadband
                          },
                          { columns    => [ 'groupnum' ],
                            table      => 'radius_group',
                          },
                        ],
    },

    'radius_group' => {
      'columns' => [
        'groupnum', 'serial', '', '', '', '', 
        'groupname',    'varchar', '', $char_d, '', '', 
        'description',  'varchar', 'NULL', $char_d, '', '', 
        'priority', 'int', '', '', '1', '',
        'speed_up', 'int', 'NULL', '', '', '',
        'speed_down', 'int', 'NULL', '', '', '',
      ],
      'primary_key' => 'groupnum',
      'unique'      => [ ['groupname'] ],
      'index'       => [],
    },

    'radius_attr' => {
      'columns' => [
        'attrnum',   'serial', '',      '', '', '',
        'groupnum',     'int', '',      '', '', '',
        'attrname', 'varchar', '', $char_d, '', '',
        'value',    'varchar', '',     255, '', '',
        'attrtype',    'char', '',       1, '', '',
        'op',          'char', '',       2, '', '',
      ],
      'primary_key'  => 'attrnum',
      'unique'       => [],
      'index'        => [ ['groupnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'groupnum' ],
                            table      => 'radius_group',
                          },
                        ],
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
      'primary_key'  => 'exemptnum',
      'unique'       => [ [ 'custnum', 'taxnum', 'year', 'month' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'taxnum' ],
                            table      => 'cust_main_county',
                          },
                        ],
    },

    'cust_tax_exempt_pkg' => {
      'columns' => [
        'exemptpkgnum',  'serial', '', '', '', '', 
        #'custnum',      'int', '', '', '', ''
        'billpkgnum',   'int', '', '', '', '', 
        'taxnum',       'int', '', '', '', '', 
        'year',         'int', 'NULL', '', '', '', 
        'month',        'int', 'NULL', '', '', '', 
        'creditbillpkgnum', 'int', 'NULL', '', '', '',
        'amount',       @money_type, '', '', 
        # exemption type flags
        'exempt_cust',          'char', 'NULL', 1, '', '',
        'exempt_setup',         'char', 'NULL', 1, '', '',
        'exempt_recur',         'char', 'NULL', 1, '', '',
        'exempt_cust_taxname',  'char', 'NULL', 1, '', '',
        'exempt_monthly',       'char', 'NULL', 1, '', '',
      ],
      'primary_key'  => 'exemptpkgnum',
      'unique'       => [],
      'index'        => [ [ 'taxnum', 'year', 'month' ],
                          [ 'billpkgnum' ],
                          [ 'taxnum' ],
                          [ 'creditbillpkgnum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg',
                          },
                          { columns    => [ 'taxnum' ],
                            table      => 'cust_main_county',
                          },
                          { columns    => [ 'creditbillpkgnum' ],
                            table      => 'cust_credit_bill_pkg',
                          },
                        ],
    },

    'cust_tax_exempt_pkg_void' => {
      'columns' => [
        'exemptpkgnum',  'int', '', '', '', '', 
        #'custnum',      'int', '', '', '', ''
        'billpkgnum',   'int', '', '', '', '', 
        'taxnum',       'int', '', '', '', '', 
        'year',         'int', 'NULL', '', '', '', 
        'month',        'int', 'NULL', '', '', '', 
        'creditbillpkgnum', 'int', 'NULL', '', '', '',
        'amount',       @money_type, '', '', 
        # exemption type flags
        'exempt_cust',          'char', 'NULL', 1, '', '',
        'exempt_setup',         'char', 'NULL', 1, '', '',
        'exempt_recur',         'char', 'NULL', 1, '', '',
        'exempt_cust_taxname',  'char', 'NULL', 1, '', '',
        'exempt_monthly',       'char', 'NULL', 1, '', '',
      ],
      'primary_key'  => 'exemptpkgnum',
      'unique'       => [],
      'index'        => [ [ 'taxnum', 'year', 'month' ],
                          [ 'billpkgnum' ],
                          [ 'taxnum' ],
                          [ 'creditbillpkgnum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'billpkgnum' ],
                            table      => 'cust_bill_pkg_void',
                          },
                          { columns    => [ 'taxnum' ],
                            table      => 'cust_main_county',
                          },
                          { columns    => [ 'creditbillpkgnum' ],
                            table      => 'cust_credit_bill_pkg',
                          },
                        ],
    },

    'router' => {
      'columns' => [
        'routernum', 'serial', '', '', '', '', 
        'routername', 'varchar', '', $char_d, '', '', 
        'svcnum', 'int', 'NULL', '', '', '', 
        'agentnum',   'int', 'NULL', '', '', '', 
        'manual_addr', 'char', 'NULL', 1, '', '',
      ],
      'primary_key'  => 'routernum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc', #svc_acct / svc_broadband
                          },
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'part_svc_router' => {
      'columns' => [
        'svcrouternum', 'serial', '', '', '', '', 
        'svcpart', 'int', '', '', '', '', 
	'routernum', 'int', '', '', '', '', 
      ],
      'primary_key'  => 'svcrouternum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcpart' ],
                            table      => 'part_svc',
                          },
                          { columns    => [ 'routernum' ],
                            table      => 'router',
                          },
                        ],
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
      'primary_key'  => 'blocknum',
      'unique'       => [ [ 'blocknum', 'routernum' ] ],
      'index'        => [],
      'foreign_keys' => [
                          #{ columns    => [ 'routernum' ],
                          #   table      => 'router',
                          #},
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'addr_range' => {
      'columns' => [
        'rangenum', 'serial', '', '', '', '',
        'start',    'varchar', '', 15, '', '',
        'length',   'int', '', '', '', '',
        'status',   'varchar', 'NULL', 32, '', '',
      ],
      'primary_key' => 'rangenum',
      'unique'      => [],
      'index'       => [],
    },

    'svc_broadband' => {
      'columns' => [
        'svcnum',                  'int',     '',        '', '', '', 
        'description',         'varchar', 'NULL',   $char_d, '', '', 
        'routernum',               'int', 'NULL',        '', '', '',
        'blocknum',                'int', 'NULL',        '', '', '', 
        'sectornum',               'int', 'NULL',        '', '', '',
        'speed_up',                'int', 'NULL',        '', '', '', 
        'speed_down',              'int', 'NULL',        '', '', '', 
        'ip_addr',             'varchar', 'NULL',        15, '', '', 
        'mac_addr',            'varchar', 'NULL',        12, '', '', 
        'authkey',             'varchar', 'NULL',        32, '', '', 
        'latitude',            'decimal', 'NULL',    '10,7', '', '', 
        'longitude',           'decimal', 'NULL',    '10,7', '', '', 
        'altitude',            'decimal', 'NULL',        '', '', '', 
        'vlan_profile',        'varchar', 'NULL',   $char_d, '', '', 
        'performance_profile', 'varchar', 'NULL',   $char_d, '', '',
        'plan_id',             'varchar', 'NULL',   $char_d, '', '',
        'radio_serialnum',     'varchar', 'NULL',   $char_d, '', '',
        'radio_location',      'varchar', 'NULL', 2*$char_d, '', '',
        'poe_location',        'varchar', 'NULL', 2*$char_d, '', '',
        'rssi',                    'int', 'NULL',        '', '', '',
        'suid',                    'int', 'NULL',        '', '', '',
        'shared_svcnum',           'int', 'NULL',        '', '', '',
        'serviceid',           'varchar', 'NULL',        64, '', '',#srvexport/reportfields
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [ [ 'ip_addr' ], [ 'mac_addr' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'routernum' ],
                            table      => 'router',
                          },
                          { columns    => [ 'blocknum' ],
                            table      => 'addr_block',
                          },
                          { columns    => [ 'sectornum' ],
                            table      => 'tower_sector',
                          },
                          { columns    => [ 'shared_svcnum' ],
                            table      => 'svc_broadband',
                            references => [ 'svcnum' ],
                          },
                        ],
    },

    'tower' => {
      'columns' => [
        'towernum',    'serial',     '',      '', '', '',
        #'agentnum',       'int', 'NULL',      '', '', '',
        'towername',  'varchar',     '', $char_d, '', '',
        'disabled',      'char', 'NULL',       1, '', '',
        'latitude',   'decimal', 'NULL',  '10,7', '', '', 
        'longitude',  'decimal', 'NULL',  '10,7', '', '', 
        'coord_auto',    'char', 'NULL',       1, '', '',
        'altitude',   'decimal', 'NULL',      '', '', '', 
        'height',     'decimal', 'NULL',      '', '', '', 
        'veg_height', 'decimal', 'NULL',      '', '', '', 
        'color',      'varchar', 'NULL',       6, '', '',
      ],
      'primary_key' => 'towernum',
      'unique'      => [ [ 'towername' ] ], # , 'agentnum' ] ],
      'index'       => [],
    },

    'tower_sector' => {
      'columns' => [
        'sectornum',     'serial',     '',      '', '', '',
        'towernum',         'int',     '',      '', '', '',
        'sectorname',   'varchar',     '', $char_d, '', '',
        'ip_addr',      'varchar', 'NULL',      15, '', '',
        'height',       'decimal', 'NULL',      '', '', '', 
        'freq_mhz',         'int', 'NULL',      '', '', '',
        'direction',        'int', 'NULL',      '', '', '',
        'width',            'int', 'NULL',      '', '', '',
        #downtilt etc? rfpath has profile files for devices/antennas you upload?
        'sector_range', 'decimal', 'NULL',      '', '', '',  #?
      ],
      'primary_key'  => 'sectornum',
      'unique'       => [ [ 'towernum', 'sectorname' ], [ 'ip_addr' ], ],
      'index'        => [ [ 'towernum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'towernum' ],
                            table      => 'tower',
                          },
                        ],
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
      'primary_key'  => 'vfieldnum',
      'unique'       => [ [ 'vfieldpart', 'recnum' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'vfieldpart' ],
                            table      => 'part_virtual_field',
                          },
                        ],
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
      'primary_key'  => 'snarfnum',
      'unique'       => [],
      'index'        => [ [ 'svcnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_acct',
                          },
                        ],
    },

    'svc_external' => {
      'columns' => [
        'svcnum',     'int',     '',      '', '', '', 
        'id',      'bigint', 'NULL',      '', '', '', 
        'title',  'varchar', 'NULL', $char_d, '', '', 
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
    },

    'cust_pay_refund' => {
      'columns' => [
        'payrefundnum', 'serial', '', '', '', '', 
        'paynum',  'int', '', '', '', '', 
        'refundnum',  'int', '', '', '', '', 
        '_date',    @date_type, '', '', 
        'amount',   @money_type, '', '', 
      ],
      'primary_key'  => 'payrefundnum',
      'unique'       => [],
      'index'        => [ ['paynum'], ['refundnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'paynum' ],
                            table      => 'cust_pay',
                          },
                          { columns    => [ 'refundnum' ],
                            table      => 'cust_refund',
                          },
                        ],
    },

    'part_pkg_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'pkgpart', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'pkgpart' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                        ],
    },

    'part_pkg_vendor' => {
      'columns' => [
        'num', 'serial', '', '', '', '', 
        'pkgpart', 'int', '', '', '', '', 
        'exportnum', 'int', '', '', '', '', 
        'vendor_pkg_id', 'varchar', '', $char_d, '', '', 
      ],
      'primary_key'  => 'num',
      'unique'       => [ [ 'pkgpart', 'exportnum' ] ],
      'index'        => [ [ 'pkgpart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                        ],
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

    'part_pkg_usage' => {
      'columns' => [
        'pkgusagepart', 'serial',   '', '', '', '',
        'pkgpart',  'int',      '', '', '', '',
        'minutes',  'double precision',      '', '', '', '',
        'priority', 'int',  'NULL', '', '', '',
        'shared',   'char', 'NULL',  1, '', '',
        'rollover', 'char', 'NULL',  1, '', '',
        'description',  'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'pkgusagepart',
      'unique'       => [],
      'index'        => [ [ 'pkgpart' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                        ],
    },

    'part_pkg_usage_class' => {
      'columns' => [
        'num',       'serial',  '', '', '', '',
        'pkgusagepart', 'int',  '', '', '', '',
        'classnum',     'int','NULL', '', '', '',
      ],
      'primary_key'  => 'num',
      'unique'       => [ [ 'pkgusagepart', 'classnum' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'pkgusagepart' ],
                            table      => 'part_pkg_usage',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'usage_class',
                          },
                        ],
    },

    'rate' => {
      'columns' => [
        'ratenum',   'serial',     '',      '', '', '', 
        'ratename', 'varchar',     '', $char_d, '', '', 
        'agentnum',     'int', 'NULL',      '', '', '',
      ],
      'primary_key' => 'ratenum',
      'unique'      => [],
      'index'       => [],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'rate_detail' => {
      'columns' => [
        'ratedetailnum',   'serial',  '',     '',      '', '', 
        'ratenum',         'int',     '',     '',      '', '', 
        'orig_regionnum',  'int', 'NULL',     '',      '', '', 
        'dest_regionnum',  'int',     '',     '',      '', '', 
        'min_included',    'int',     '',     '',      '', '', 
        'conn_charge',     'decimal', '', '10,4', '0.0000', '',
        'conn_cost',       'decimal', '', '10,4', '0.0000', '',
        'conn_sec',        'int',     '',     '',      '0', '',
        'min_charge',      'decimal', '', '10,5',       '', '',
        'min_cost',        'decimal', '', '10,5','0.00000', '',
        'sec_granularity', 'int',     '',     '',       '', '', 
        'ratetimenum',     'int', 'NULL',     '',       '', '',
        'classnum',        'int', 'NULL',     '',       '', '', 
        'cdrtypenum',      'int', 'NULL',     '',       '', '',
        'region_group',   'char', 'NULL',      1,       '', '', 
      ],
      'primary_key'  => 'ratedetailnum',
      'unique'       => [ [ 'ratenum', 'orig_regionnum', 'dest_regionnum' ] ],
      'index'        => [ [ 'ratenum', 'dest_regionnum' ],
                          [ 'ratenum', 'ratetimenum' ]
                        ],
      'foreign_keys' => [
                          { columns    => [ 'ratenum' ],
                            table      => 'rate',
                          },
                          { columns    => [ 'orig_regionnum' ],
                            table      => 'rate_region',
                            references => [ 'regionnum' ],
                          },
                          { columns    => [ 'dest_regionnum' ],
                            table      => 'rate_region',
                            references => [ 'regionnum' ],
                          },
                          { columns    => [ 'ratetimenum' ],
                            table      => 'rate_time',
                          },
                          { columns    => [ 'classnum' ],
                            table      => 'usage_class',
                          },
                          { columns    => [ 'cdrtypenum' ],
                            table      => 'cdr_type',
                          },
                        ],
    },

    'rate_region' => {
      'columns' => [
        'regionnum',   'serial',      '', '', '', '', 
        'regionname',  'varchar',     '', $char_d, '', '', 
        'exact_match', 'char',    'NULL',  1, '', '',
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
      'primary_key'  => 'prefixnum',
      'unique'       => [],
      'index'        => [ [ 'countrycode' ], [ 'npa' ], [ 'regionnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'regionnum' ],
                            table      => 'rate_region',
                          },
                          { columns    => [ 'latanum' ],
                            table      => 'lata',
                          },
                        ],
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
      'primary_key'  => 'intervalnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'ratetimenum' ],
                            table      => 'rate_time',
                          },
                        ],
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
      'primary_key'  => 'tierdetailnum',
      'unique'       => [],
      'index'        => [ ['tiernum'], ],
      'foreign_keys' => [
                          { columns    => [ 'tiernum' ],
                            table      => 'rate_tier',
                          },
                        ],
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
      'primary_key'  => 'codenum',
      'unique'       => [ [ 'agentnum', 'code' ] ],
      'index'        => [ [ 'agentnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
     },

    'reg_code_pkg' => {
      'columns' => [
        'codepkgnum', 'serial', '', '', '', '', 
        'codenum',   'int',    '', '', '', '', 
        'pkgpart',   'int',    '', '', '', '', 
      ],
      'primary_key'  => 'codepkgnum',
      'unique'       => [ [ 'codenum', 'pkgpart' ] ],
      'index'        => [ [ 'codenum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'codenum' ],
                            table      => 'reg_code',
                          },
                          { columns    => [ 'pkgpart' ],
                            table      => 'part_pkg',
                          },
                        ],
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
      'primary_key'  => 'fieldnum',
      'unique'       => [ [ 'sessionnum', 'fieldname' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'sessionnum' ],
                            table      => 'clientapi_session',
                          },
                        ],
    },

    'payment_gateway' => {
      'columns' => [
        'gatewaynum',       'serial',   '',     '', '', '', 
        'gateway_namespace','varchar',  'NULL', $char_d, '', '', 
        'gateway_module',   'varchar',  '',     $char_d, '', '', 
        'gateway_username', 'varchar',  'NULL', $char_d, '', '', 
        'gateway_password', 'varchar',  'NULL', $char_d, '', '', 
        'gateway_action',   'varchar',  'NULL', $char_d, '', '', 
        'gateway_callback_url', 'varchar',  'NULL', 255, '', '', 
        'gateway_cancel_url',   'varchar',  'NULL', 255, '', '',
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
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'gatewaynum' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'gatewaynum' ],
                            table      => 'payment_gateway',
                          },
                        ],
    },

    'agent_payment_gateway' => {
      'columns' => [
        'agentgatewaynum', 'serial', '', '', '', '', 
        'agentnum',        'int', '', '', '', '', 
        'gatewaynum',      'int', '', '', '', '', 
        'cardtype',        'varchar', 'NULL', $char_d, '', '', 
        'taxclass',        'varchar', 'NULL', $char_d, '', '', 
      ],
      'primary_key'  => 'agentgatewaynum',
      'unique'       => [],
      'index'        => [ [ 'agentnum', 'cardtype' ], ],

      'foreign_keys' => [

                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                          { columns    => [ 'gatewaynum' ],
                            table      => 'payment_gateway',
                          },
                        ],
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
      'primary_key'  => 'bannum',
      'unique'       => [],
      'index'        => [ [ 'payby', 'payinfo' ], [ 'usernum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
    },

    'pkg_category' => {
      'columns' => [
        'categorynum',        'serial',     '',      '', '', '', 
        'categoryname',      'varchar',     '', $char_d, '', '', 
        'weight',                'int', 'NULL',      '', '', '',
        'ticketing_queueid',     'int', 'NULL',      '', '', '', 
        'condense',             'char', 'NULL',       1, '', '', 
        'disabled',             'char', 'NULL',       1, '', '', 
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
      'primary_key'  => 'classnum',
      'unique'       => [],
      'index'        => [ ['disabled'] ],
      'foreign_keys' => [
                          { columns    => [ 'categorynum' ],
                            table      => 'pkg_category',
                          },
                        ],
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
        'lastdata',    'varchar',  '',     255, \"''", '', 

        #currently only opensips & voipswitch
        'src_ip_addr', 'varchar',  'NULL',  15,    '', '',

        #currently only opensips
        'dst_ip_addr', 'varchar',  'NULL',  15,    '', '',

        #currently only u4:
        # terminating number (as opposed to dialed destination)
        'dst_term',    'varchar',  'NULL', $char_d, '', '',

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
        # more fields, for GSM imports
        ###
        'servicecode',             'int', 'NULL',      '', '', '',
        'quantity_able',           'int', 'NULL',      '', '', '', 

        ###
        #and now for our own fields
        ###

        'cdrtypenum',              'int', 'NULL',      '', '', '',

        'charged_party',       'varchar', 'NULL', $char_d, '', '',
        'charged_party_imsi',  'varchar', 'NULL', $char_d, '', '',

        'upstream_price',      'decimal', 'NULL',  '10,5', '', '', 

        #currently only voipswitch
        #'upstream_rate',      'decimal', 'NULL',  '10,5', '', '', 

        'upstream_src_regionname', 'varchar', 'NULL', $char_d, '', '',
        'upstream_dst_regionname', 'varchar', 'NULL', $char_d, '', '',

        # how it was rated internally...
        'rated_pretty_dst',       'varchar', 'NULL', $char_d, '', '',
        'rated_regionname',       'varchar', 'NULL', $char_d, '', '',
        'rated_price',            'decimal', 'NULL',  '10,4', '', '',
        'rated_seconds',              'int', 'NULL',      '', '', '',
        'rated_minutes', 'double precision', 'NULL',      '', '', '',
        'rated_granularity',          'int', 'NULL',      '', '', '',
        'rated_ratedetailnum',        'int', 'NULL',      '', '', '',
        'rated_classnum',             'int', 'NULL',      '', '', '', 
        'rated_ratename',         'varchar', 'NULL', $char_d, '', '', 

        'carrierid',               'bigint', 'NULL',      '', '', '',

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
                   [ 'src_ip_addr' ], [ 'dst_ip_addr' ], [ 'dst_term' ],
                 ],
      #no FKs on cdr table... choosing not to throw errors no matter what's
      # thrown in here.  better to have the data.
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
      'primary_key'  => 'cdrtermnum',
      'unique'       => [ [ 'acctid', 'termpart' ] ],
      'index'        => [ [ 'acctid' ], [ 'status' ], ],
      'foreign_keys' => [
                          { columns    => [ 'acctid' ],
                            table      => 'cdr',
                          },
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
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
        'carrierid'   =>  'serial',     '',      '', '', '',
        'carriername' => 'varchar',     '', $char_d, '', '',
        'disabled'    =>    'char', 'NULL',       1, '', '', 
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
        'itemnum',   'serial',      '',      '', '', '',
        'classnum',  'int',         '',      '', '', '',
        'agentnum',  'int',     'NULL',      '', '', '',
        'item',      'varchar',     '', $char_d, '', '',
        'svcnum',    'int',     'NULL',      '', '', '',
        'svc_field', 'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'itemnum',
      'unique'       => [ [ 'classnum', 'item' ] ],
      'index'        => [ [ 'classnum' ], [ 'agentnum' ], [ 'svcnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'classnum' ],
                            table      => 'inventory_class',
                          },
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
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

    'access_user_session' => {
      'columns' => [
        'sessionnum',   'serial',  '',      '', '', '', 
        'sessionkey',  'varchar',  '', $char_d, '', '',
        'usernum',         'int',  '',      '', '', '',
        'start_date', @date_type,               '', '',
        'last_date',  @date_type,               '', '',
      ],
      'primary_key'  => 'sessionnum',
      'unique'       => [ [ 'sessionkey' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
    },

    'access_user' => {
      'columns' => [
        'usernum',             'serial',     '',      '', '', '',
        'username',           'varchar',     '', $char_d, '', '',
        '_password',          'varchar', 'NULL', $char_d, '', '',
        '_password_encoding', 'varchar', 'NULL', $char_d, '', '',
        'last',               'varchar', 'NULL', $char_d, '', '', 
        'first',              'varchar', 'NULL', $char_d, '', '', 
        'user_custnum',           'int', 'NULL',      '', '', '',
        'report_salesnum',        'int', 'NULL',      '', '', '',
        'disabled',              'char', 'NULL',       1, '', '', 
      ],
      'primary_key'  => 'usernum',
      'unique'       => [ [ 'username' ] ],
      'index'        => [ [ 'user_custnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'user_custnum' ],
                            table      => 'cust_main',
                            references => [ 'custnum' ],
                          },
                          { columns    => [ 'report_salesnum' ],
                            table      => 'sales',
                            references => [ 'salesnum' ],
                          },
                        ],
    },

    'access_user_pref' => {
      'columns' => [
        'prefnum',    'serial',       '', '', '', '',
        'usernum',     'int',       '', '', '', '',
        'prefname', 'varchar', '', $char_d, '', '', 
        'prefvalue', 'text', 'NULL', '', '', '', 
        'expiration', @date_type, '', '',
      ],
      'primary_key'  => 'prefnum',
      'unique'       => [],
      'index'        => [ [ 'usernum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
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
      'primary_key'  => 'usergroupnum',
      'unique'       => [ [ 'usernum', 'groupnum' ] ],
      'index'        => [ [ 'usernum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                          { columns    => [ 'groupnum' ],
                            table      => 'access_group',
                          },
                        ],
     },

    'access_groupagent' => {
      'columns' => [
        'groupagentnum', 'serial', '', '', '', '',
        'groupnum',         'int', '', '', '', '',
        'agentnum',         'int', '', '', '', '',
      ],
      'primary_key'  => 'groupagentnum',
      'unique'       => [ [ 'groupnum', 'agentnum' ] ],
      'index'        => [ [ 'groupnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'groupnum' ],
                            table      => 'access_group',
                          },
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
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

    'sched_item' => {
      'columns' => [
        'itemnum',   'serial',      '', '', '', '', 
        'usernum',      'int',  'NULL', '', '', '', 
        #'itemname', 'varchar', $char_d, '', '', '',
        'disabled',    'char',  'NULL',  1, '', '', 
      ],
      'primary_key'  => 'itemnum',
      'unique'       => [ [ 'usernum' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'usernum' ],
                            table      => 'access_user',
                          },
                        ],
    },

    #'sched_item_class'

    'sched_avail' => {
      'columns' => [
        'availnum',      'serial', '', '', '', '', 
        'itemnum',          'int', '', '', '', '',
        'wday',             'int', '', '', '', '',
        'stime',            'int', '', '', '', '',
        'etime',            'int', '', '', '', '',
        'override_date',    @date_type,    '', '',
      ],
      'primary_key'  => 'availnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'itemnum' ],
                            table      => 'sched_item',
                          },
                        ],
    },

    'svc_phone' => {
      'columns' => [
        'svcnum',                         'int',     '',      '', '', '', 
        'countrycode',                'varchar',     '',       3, '', '', 
        'phonenum',                   'varchar',     '',      25, '', '', #12 ?
        'sim_imsi',                   'varchar', 'NULL',      15, '', '',
        'pin',                        'varchar', 'NULL', $char_d, '', '',
        'sip_password',               'varchar', 'NULL', $char_d, '', '',
        'phone_name',                 'varchar', 'NULL', $char_d, '', '',
        'pbxsvc',                         'int', 'NULL',      '', '', '',
        'domsvc',                         'int', 'NULL',      '', '', '', 
        'locationnum',                    'int', 'NULL',      '', '', '',
        'forwarddst',                 'varchar', 'NULL',      15, '', '', 
        'email',                      'varchar', 'NULL',     255, '', '', 
        'lnp_status',                 'varchar', 'NULL', $char_d, '', '',
        'portable',                      'char', 'NULL',       1, '', '', 
        'lrn',                           'char', 'NULL',      10, '', '', 
        'lnp_desired_due_date',           'int', 'NULL',      '', '', '',
        'lnp_due_date',                   'int', 'NULL',      '', '', '',
        'lnp_other_provider',         'varchar', 'NULL', $char_d, '', '',
        'lnp_other_provider_account', 'varchar', 'NULL', $char_d, '', '',
        'lnp_reject_reason',          'varchar', 'NULL', $char_d, '', '',
        'sms_carrierid',                  'int', 'NULL',      '', '', '',
        'sms_account',                'varchar', 'NULL', $char_d, '', '',
        'max_simultaneous',               'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [ [ 'sms_carrierid', 'sms_account'] ],
      'index'        => [ ['countrycode', 'phonenum'], ['pbxsvc'], ['domsvc'],
                          ['locationnum'], ['sms_carrierid'],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'pbxsvc' ],
                            table      => 'svc_pbx', #'cust_svc',
                            references => [ 'svcnum' ],
                          },
                          { columns    => [ 'domsvc' ],
                            table      => 'svc_domain', #'cust_svc',
                            references => [ 'svcnum' ],
                          },
                          { columns    => [ 'locationnum' ],
                            table      => 'cust_location',
                          },
                          { columns    => [ 'sms_carrierid' ],
                            table      => 'cdr_carrier',
                            references => [ 'carrierid' ],
                          },
                        ],
    },

    'phone_device' => {
      'columns' => [
        'devicenum', 'serial',     '', '', '', '',
        'devicepart',   'int',     '', '', '', '',
        'svcnum',       'int',     '', '', '', '', 
        'mac_addr', 'varchar', 'NULL', 12, '', '', 
      ],
      'primary_key'  => 'devicenum',
      'unique'       => [ [ 'mac_addr' ], ],
      'index'        => [ [ 'devicepart' ], [ 'svcnum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'devicepart' ],
                            table      => 'part_device',
                          },
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_phone',
                          },
                        ],
    },

    'part_device' => {
      'columns' => [
        'devicepart', 'serial',  '',      '', '', '',
        'devicename', 'varchar', '', $char_d, '', '',
        'inventory_classnum', 'int', 'NULL', '', '', '',
      ],
      'primary_key'  => 'devicepart',
      'unique'       => [ [ 'devicename' ] ], #?
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'inventory_classnum' ],
                            table      => 'inventory_class',
                            references => [ 'classnum' ],
                          },
                        ],
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
      'primary_key'  => 'availnum',
      'unique'       => [],
      'index'        => [ ['exportnum','countrycode','state'],    #npa search
                          ['exportnum','countrycode','npa'],      #nxx search
                          ['exportnum','countrycode','npa','nxx'],#station srch
                          [ 'exportnum','countrycode','npa','nxx','station'], #
                          [ 'svcnum' ],
                          [ 'availbatch' ],
                          [ 'latanum' ],
                        ],
      'foreign_keys' => [
                          { columns    => [ 'exportnum' ],
                            table      => 'part_export',
                          },
                          { columns    => [ 'latanum' ],
                            table      => 'lata',
                          },
                          { columns    => [ 'msanum' ],
                            table      => 'msa',
                          },
                          { columns    => [ 'ordernum' ],
                            table      => 'did_order',
                          },
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_phone',
                          },
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
      'primary_key'  => 'orderitemnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'ordernum' ],
                            table      => 'did_order',
                          },
                          { columns    => [ 'msanum' ],
                            table      => 'msa',
                          },
                          { columns    => [ 'latanum' ],
                            table      => 'lata',
                          },
                          { columns    => [ 'ratecenternum' ],
                            table      => 'rate_center',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
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
      'primary_key'  => 'ordernum',
      'unique'       => [ [ 'vendornum', 'vendor_order_id' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'vendornum' ],
                            table      => 'did_vendor',
                          },
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                        ],
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
        'unsuspend_pkgpart', 'int',  'NULL', '', '', '',
        'unsuspend_hold','char',    'NULL', 1, '', '',
      ],
      'primary_key'  => 'reasonnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'reason_type' ],
                            table      => 'reason_type',
                            references => [ 'typenum' ],
                          },
                          { columns    => [ 'unsuspend_pkgpart' ],
                            table      => 'part_pkg',
                            references => [ 'pkgpart' ],
                          },
                        ],
    },

    'conf' => {
      'columns' => [
        'confnum',  'serial',     '',      '', '', '', 
        'agentnum', 'int',    'NULL',      '', '', '', 
        'locale',   'varchar','NULL',      16, '', '',
        'name',     'varchar',    '', $char_d, '', '', 
        'value',    'text',   'NULL',      '', '', '',
      ],
      'primary_key'  => 'confnum',
      'unique'       => [ [ 'agentnum', 'locale', 'name' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'pkg_referral' => {
      'columns' => [
        'pkgrefnum',     'serial', '', '', '', '',
        'pkgnum',        'int',    '', '', '', '',
        'refnum',        'int',    '', '', '', '',
      ],
      'primary_key'  => 'pkgrefnum',
      'unique'       => [ [ 'pkgnum', 'refnum' ] ],
      'index'        => [ [ 'pkgnum' ], [ 'refnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'pkgnum' ],
                            table      => 'cust_pkg',
                          },
                          { columns    => [ 'refnum' ],
                            table      => 'part_referral',
                          },
                        ],
    },

    'svc_pbx' => {
      'columns' => [
        'svcnum',           'int',     '',      '', '', '', 
        'id',               'int', 'NULL',      '', '', '', 
        'title',        'varchar', 'NULL', $char_d, '', '', 
        'max_extensions',   'int', 'NULL',      '', '', '',
        'max_simultaneous', 'int', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [ [ 'id' ] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
    },

    'pbx_extension' => {
      'columns' => [
        'extensionnum',  'serial',     '',      '', '', '',
        'svcnum',           'int',     '',      '', '', '',
        'extension',    'varchar',     '', $char_d, '', '',
        'pin',          'varchar', 'NULL', $char_d, '', '',
        'sip_password', 'varchar', 'NULL', $char_d, '', '',
        'phone_name',   'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'extensionnum',
      'unique'       => [ [ 'svcnum', 'extension' ] ],
      'index'        => [ [ 'svcnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_pbx',
                          },
                        ],
    },

    'pbx_device' => {
      'columns' => [
        'devicenum', 'serial',     '', '', '', '',
        'devicepart',   'int',     '', '', '', '',
        'svcnum',       'int',     '', '', '', '', 
        'mac_addr', 'varchar', 'NULL', 12, '', '', 
      ],
      'primary_key'  => 'devicenum',
      'unique'       => [ [ 'mac_addr' ], ],
      'index'        => [ [ 'devicepart' ], [ 'svcnum' ], ],
      'foreign_keys' => [
                          { columns    => [ 'devicepart' ],
                            table      => 'part_device',
                          },
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_pbx',
                          },
                        ],
    },

    'extension_device' => {
      'columns' => [
        'extensiondevicenum', 'serial', '', '', '', '',
        'extensionnum',          'int', '', '', '', '',
        'devicenum',             'int', '', '', '', '',
      ],
      'primary_key'  => 'extensiondevicenum',
      'unique'       => [ [ 'extensionnum', 'devicenum' ] ],
      'index'        => [],#both?  which way do we need to query?
      'foreign_keys' => [
                          { columns  => [ 'extensionnum' ],
                            table    => 'pbx_extension',
                          },
                          { columns  => [ 'devicenum' ],
                            table    => 'pbx_device',
                          },
                        ],
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
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [ ['username'], ['domsvc'], ['listnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'domsvc' ],
                            table      => 'svc_domain', #'cust_svc',
                            references => [ 'svcnum' ],
                          },
                          { columns    => [ 'listnum' ],
                            table      => 'mailinglist',
                          },
                        ],
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
      'primary_key'  => 'membernum',
      'unique'       => [],
      'index'        => [['listnum'],['svcnum'],['contactemailnum'],['email']],
      'foreign_keys' => [
                          { columns    => [ 'listnum' ],
                            table      => 'mailinglist',
                          },
                          { columns    => [ 'svcnum' ],
                            table      => 'svc_acct',
                          },
                          { columns    => [ 'contactemailnum' ],
                            table      => 'contact_email',
                          },
                        ],
    },

    'bill_batch' => {
      'columns' => [
        'batchnum',         'serial',     '',  '', '', '',
        'agentnum',            'int', 'NULL',  '', '', '',
        'status',             'char', 'NULL', '1', '', '',
        'pdf',                'blob', 'NULL',  '', '', '',
      ],
      'primary_key'  => 'batchnum',
      'unique'       => [],
      'index'        => [ ['agentnum'] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'cust_bill_batch' => {
      'columns' => [
        'billbatchnum',     'serial',     '', '', '', '',
        'batchnum',            'int',     '', '', '', '',
        'invnum',              'int',     '', '', '', '',
      ],
      'primary_key'  => 'billbatchnum',
      'unique'       => [],
      'index'        => [ [ 'batchnum' ], [ 'invnum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'batchnum' ],
                            table      => 'bill_batch',
                          },
                          { columns    => [ 'invnum' ],
                            table      => 'cust_bill',
                          },
                        ],
    },

    'cust_bill_batch_option' => {
      'columns' => [
        'optionnum', 'serial', '', '', '', '', 
        'billbatchnum', 'int', '', '', '', '', 
        'optionname', 'varchar', '', $char_d, '', '', 
        'optionvalue', 'text', 'NULL', '', '', '', 
      ],
      'primary_key'  => 'optionnum',
      'unique'       => [],
      'index'        => [ [ 'billbatchnum' ], [ 'optionname' ] ],
      'foreign_keys' => [
                          { columns    => [ 'billbatchnum' ],
                            table      => 'cust_bill_batch',
                          },
                        ],
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
      'primary_key'  => 'msgnum',
      'unique'       => [ ],
      'index'        => [ ['agentnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'template_content' => {
      'columns' => [
        'contentnum', 'serial',     '',      '', '', '',
        'msgnum',        'int',     '',      '', '', '',
        'locale',    'varchar', 'NULL',      16, '', '',
        'subject',   'varchar', 'NULL',     512, '', '',
        'body',         'text', 'NULL',      '', '', '',
      ],
      'primary_key'  => 'contentnum',
      'unique'       => [ ['msgnum', 'locale'] ],
      'index'        => [ ],
      'foreign_keys' => [
                          { columns    => [ 'msgnum' ],
                            table      => 'msg_template',
                          },
                        ],
    },

    'cust_msg' => {
      'columns' => [
        'custmsgnum', 'serial',     '',     '', '', '',
        'custnum',       'int', 'NULL',     '', '', '',
        'msgnum',        'int', 'NULL',     '', '', '',
        '_date',    @date_type,                 '', '',
        'env_from',  'varchar', 'NULL',    255, '', '',
        'env_to',    'varchar', 'NULL',    255, '', '',
        'header',       'blob', 'NULL',     '', '', '',
        'body',         'blob', 'NULL',     '', '', '',
        'error',     'varchar', 'NULL',    255, '', '',
        'status',    'varchar',     '',$char_d, '', '',
        'msgtype',   'varchar', 'NULL',     16, '', '',
      ],
      'primary_key'  => 'custmsgnum',
      'unique'       => [ ],
      'index'        => [ ['custnum'], ],
      'foreign_keys' => [
                          { columns    => [ 'custnum' ],
                            table      => 'cust_main',
                          },
                          { columns    => [ 'msgnum' ],
                            table      => 'msg_template',
                          },
                        ],
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
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [], #recnum
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'recnum' ],
                            table      => 'domain_record',
                          },
                        ],
    },

    'svc_port' => {
      'columns' => [
        'svcnum',                'int',     '',      '', '', '', 
        'serviceid', 'varchar', '', 64, '', '', #srvexport / reportfields
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [], #recnum
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                        ],
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

    'upgrade_journal' => {
      'columns' => [
        'upgradenum', 'serial', '', '', '', '',
        '_date', 'int', '', '', '', '',
        'upgrade', 'varchar', '', $char_d, '', '',
        'status', 'varchar', '', $char_d, '', '',
        'statustext', 'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key' => 'upgradenum',
      'unique' => [],
      'index' => [ [ 'upgrade' ] ],
    },

    'upload_target' => {
      'columns' => [
        'targetnum', 'serial', '', '', '', '',
        'agentnum', 'int', 'NULL', '', '', '',
        'protocol', 'varchar', '', 10, '', '',
        'hostname', 'varchar', '', $char_d, '', '',
        'port', 'int', 'NULL', '', '', '',
        'username', 'varchar', '', $char_d, '', '',
        'password', 'varchar', 'NULL', $char_d, '', '',
        'path', 'varchar', 'NULL', $char_d, '', '',
        'subject', 'varchar', 'NULL', '255', '', '',
        'handling', 'varchar', 'NULL', $char_d, '', '',
      ],
      'primary_key'   => 'targetnum',
      'unique'        => [ [ 'targetnum' ] ],
      'index'         => [],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'log' => {
      'columns' => [
        'lognum',     'serial', '', '', '', '',
        '_date',      'int', '', '', '', '',
        'agentnum',   'int', 'NULL', '', '', '',
        'tablename',  'varchar', 'NULL', $char_d, '', '',
        'tablenum',   'int',  'NULL', '', '', '', 
        'level',      'int',  '', '', '', '',
        'message',    'text', '', '', '', '',
      ],
      'primary_key'  => 'lognum',
      'unique'       => [],
      'index'        => [ ['_date'], ['level'] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'log_context' => {
      'columns' => [
        'logcontextnum', 'serial', '', '', '', '',
        'lognum', 'int', '', '', '', '',
        'context', 'varchar', '', 32, '', '',
      ],
      'primary_key'  => 'logcontextnum',
      'unique'       => [ [ 'lognum', 'context' ] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'lognum' ],
                            table      => 'log',
                          },
                        ],
    },

    'svc_alarm' => {
      'columns' => [
        'svcnum',          'int',      '',      '', '', '', 
        'alarmsystemnum',  'int',      '',      '', '', '',
        'alarmtypenum',    'int',      '',      '', '', '',
        'alarmstationnum', 'int',      '',      '', '', '',
        'acctnum',      'varchar',     '', $char_d, '', '',
        '_password',    'varchar',     '', $char_d, '', '',
        'location',     'varchar', 'NULL', $char_d, '', '',
        #installer (rep)
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'alarmsystemnum' ],
                            table      => 'alarm_system',
                          },
                          { columns    => [ 'alarmtypenum' ],
                            table      => 'alarm_type',
                          },
                          { columns    => [ 'alarmstationnum' ],
                            table      => 'alarm_station',
                          },
                        ],
    },

    'alarm_system' => { #vendors
      'columns' => [
        'alarmsystemnum',  'serial',     '',      '', '', '',
        'agentnum',           'int', 'NULL',      '', '', '',
        'systemname',     'varchar',     '', $char_d, '', '',
        'disabled',          'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'alarmsystemnum',
      'unique'      => [ ['agentnum', 'systemname'] ],
      'index'       => [ ['agentnum'], ['disabled'] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'alarm_type' => { #inputs and outputs
      'columns' => [
        'alarmtypenum', 'serial',     '',      '', '', '',
        'agentnum',        'int', 'NULL',      '', '', '',
        'inputs',          'int',     '', '', '', '',
        'outputs',         'int',     '', '', '', '',
        'disabled',       'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'alarmtypenum',
      'unique'      => [ ['agentnum', 'inputs', 'outputs'] ],
      'index'       => [ ['agentnum'], ['disabled'] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'alarm_station' => { #central station (where the alarm reports to)
      'columns' => [
        'alarmstationnum', 'serial',     '',      '', '', '',
        'agentnum',           'int', 'NULL',      '', '', '',
        'stationname',    'varchar',     '', $char_d, '', '',
        'disabled',          'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'alarmstationnum',
      'unique'      => [ ['agentnum', 'stationname'], ],
      'index'       => [ ['agentnum'], ['disabled'] ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'svc_cable' => {
      'columns' => [
        'svcnum',        'int',     '',      '', '', '', 
        'providernum',   'int', 'NULL',      '', '', '',
        'ordernum',  'varchar', 'NULL', $char_d, '', '',
        'modelnum',      'int', 'NULL',      '', '', '',
        'serialnum', 'varchar', 'NULL', $char_d, '', '',
        'mac_addr',  'varchar', 'NULL',      12, '', '', 
      ],
      'primary_key'  => 'svcnum',
      'unique'       => [],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'svcnum' ],
                            table      => 'cust_svc',
                          },
                          { columns    => [ 'providernum' ],
                            table      => 'cable_provider',
                          },
                          { columns    => [ 'modelnum' ],
                            table      => 'cable_model',
                          },
                        ],
    },

    'cable_model' => {
      'columns' => [
        'modelnum',    'serial',     '',      '', '', '',
        'model_name', 'varchar',     '', $char_d, '', '',
        'disabled',      'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'modelnum',
      'unique' => [ [ 'model_name' ], ],
      'index'  => [],
    },

    'cable_provider' => {
      'columns' => [
        'providernum', 'serial',     '',      '', '', '',
        'provider',   'varchar',     '', $char_d, '', '',
        'disabled',      'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'providernum',
      'unique' => [ [ 'provider' ], ],
      'index'  => [],
    },

    'svc_conferencing' => {
      'columns' => [
        'svcnum',            'int',     '',      '', '', '',
        'conf_id',           'int', 'NULL',      '', '', '', #"system assigned"
        'conf_name',     'varchar',     '', $char_d, '', '',
        'conf_password', 'varchar',     '', $char_d, '', '',
        'access_code',   'varchar',     '',      16, '', '',
        'duration',          'int',     '',      '', '', '',
        'participants',      'int',     '',      '', '', '',
        'conftypenum',       'int',     '',      '', '', '',
        'confqualitynum',    'int',     '',      '', '', '',
        'opt_recording',    'char', 'NULL',       1, '', '',
        'opt_sip',          'char', 'NULL',       1, '', '',
        'opt_phone',        'char', 'NULL',       1, '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [],
      'index'  => [],
      'foreign_keys' => [
                          { columns => [ 'svcnum' ],
                            table   => 'cust_svc',
                          },
                          { columns => [ 'conftypenum' ],
                            table   => 'conferencing_type',
                          },
                          { columns => [ 'confqualitynum' ],
                            table   => 'conferencing_quality',
                          },
                        ],
    },

    'conferencing_type' => {
      'columns' => [
        'conftypenum',  'int',     '',      '', '', '',
        'typeid'      , 'int',     '',      '', '', '',
        'typename', 'varchar',     '', $char_d, '', '',
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'conftypenum',
      'unique'      => [ [ 'typeid', 'disabled' ], [ 'typename', 'disabled' ] ],
      'index'       => [],
    },

    'conferencing_quality' => {
      'columns' => [
        'confqualitynum',  'int',     '',      '', '', '',
        'qualityid'      , 'int',     '',      '', '', '',
        'qualityname', 'varchar',     '', $char_d, '', '',
        'disabled',       'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'confqualitynum',
      'unique'      => [ [ 'qualityid', 'disabled' ], [ 'qualityname', 'disabled' ] ],
      'index'       => [],
    },

    'svc_video' => {
      'columns' => [
        'svcnum',            'int', '', '', '', '',
        'smartcard_num', 'varchar', '', 16, '', '',
        'mac_addr',      'varchar', '', 12, '', '', 
        'duration',          'int', '', '', '', '',
      ],
      'primary_key' => 'svcnum',
      'unique' => [], # [ 'smartcard_num' ], [ 'mac_addr' ], ],
      'index'  => [],
      'foreign_keys' => [
                          { columns => [ 'svcnum' ],
                            table   => 'cust_svc',
                          },
                        ],
    },

    'vend_main' => {
      'columns' => [
        'vendnum',   'serial',     '',      '', '', '',
        'vendname', 'varchar',     '', $char_d, '', '',
        'classnum',     'int',     '',      '', '', '',
        'disabled',    'char', 'NULL',       1, '', '', 
      ],
      'primary_key'  => 'vendnum',
      'unique'       => [ ['vendname', 'disabled'] ],
      'index'        => [],
      'foreign_keys' => [
                          { columns    => [ 'classnum' ],
                            table      => 'vend_class',
                          },
                        ],
    },

    'vend_class' => {
      'columns' => [
        'classnum',     'serial',     '',      '', '', '', 
        'classname',   'varchar',     '', $char_d, '', '', 
        'disabled',       'char', 'NULL',       1, '', '', 
      ],
      'primary_key' => 'classnum',
      'unique'      => [],
      'index'       => [ ['disabled'] ],
    },

    'vend_bill' => {
      'columns' => [
        'vendbillnum',    'serial',     '',      '', '', '', 
        'vendnum',           'int',     '',      '', '', '', 
        '_date',        @date_type,                  '', '', 
        'charged',     @money_type,                  '', '', 
      ],
      'primary_key'  => 'vendbillnum',
      'unique'       => [],
      'index'        => [ ['vendnum'], ['_date'], ],
      'foreign_keys' => [
                          { columns    => [ 'vendnum' ],
                            table      => 'vend_main',
                          },
                        ],
    },

    'vend_pay' => {
      'columns' => [
        'vendpaynum',   'serial',    '',       '', '', '',
        'vendnum',         'int',    '',       '', '', '', 
        '_date',     @date_type,                   '', '', 
        'paid',      @money_type,                  '', '', 
      ],
      'primary_key'  => 'vendpaynum',
      'unique'       => [],
      'index'        => [ [ 'vendnum' ], [ '_date' ], ],
      'foreign_keys' => [
                          { columns    => [ 'vendnum' ],
                            table      => 'vend_main',
                          },
                        ],
    },

    'vend_bill_pay' => {
      'columns' => [
        'vendbillpaynum', 'serial',     '',   '', '', '', 
        'vendbillnum',       'int',     '',   '', '', '', 
        'vendpaynum',        'int',     '',   '', '', '', 
        'amount',  @money_type, '', '', 
        #? '_date',   @date_type, '', '', 
      ],
      'primary_key'  => 'vendbillpaynum',
      'unique'       => [],
      'index'        => [ [ 'vendbillnum' ], [ 'vendpaynum' ] ],
      'foreign_keys' => [
                          { columns    => [ 'vendbillnum' ],
                            table      => 'vend_bill',
                          },
                          { columns    => [ 'vendpaynum' ],
                            table      => 'vend_pay',
                          },
                        ],
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
      'primary_key'  => 'componentnum',
      'unique'       => [ [ 'derivenum', 'serviceid' ], ],
      'index'        => [ [ 'derivenum', ], ],
      'foreign_keys' => [
                          { columns    => [ 'derivenum' ],
                            table      => 'torrus_srvderive',
                          },
                        ],
    },

    'invoice_mode' => {
      'columns' => [
        'modenum',      'serial', '', '', '', '',
        'agentnum',        'int', 'NULL', '', '', '',
        'modename',    'varchar', '', 32, '', '',
      ],
      'primary_key' => 'modenum',
      'unique'      => [ ],
      'index'       => [ ],
      'foreign_keys' => [
                          { columns    => [ 'agentnum' ],
                            table      => 'agent',
                          },
                        ],
    },

    'invoice_conf' => {
      'columns' => [
        'confnum',              'serial',   '', '', '', '',
        'modenum',              'int',      '', '', '', '',
        'locale',               'varchar',  'NULL', 16, '', '',
        'notice_name',          'varchar',  'NULL', 64, '', '',
        'subject',              'varchar',  'NULL', 64, '', '',
        'htmlnotes',            'text',     'NULL', '', '', '',
        'htmlfooter',           'text',     'NULL', '', '', '',
        'htmlsummary',          'text',     'NULL', '', '', '',
        'htmlreturnaddress',    'text',     'NULL', '', '', '',
        'latexnotes',           'text',     'NULL', '', '', '',
        'latexfooter',          'text',     'NULL', '', '', '',
        'latexsummary',         'text',     'NULL', '', '', '',
        'latexsmallfooter',     'text',     'NULL', '', '', '',
        'latexreturnaddress',   'text',     'NULL', '', '', '',
        'with_latexcoupon',     'char',     'NULL', '1', '', '',
        'lpr',                  'varchar',  'NULL', $char_d, '', '',
      ],
      'primary_key'  => 'confnum',
      'unique'       => [ [ 'modenum', 'locale' ] ],
      'index'        => [ ],
      'foreign_keys' => [
                          { columns    => [ 'modenum' ],
                            table      => 'invoice_mode',
                          },
                        ],
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

