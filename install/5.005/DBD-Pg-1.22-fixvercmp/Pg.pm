
#  $Id: Pg.pm,v 1.1 2004-04-29 09:21:28 ivan Exp $
#
#  Copyright (c) 1997,1998,1999,2000 Edmund Mergl
#  Copyright (c) 2002 Jeffrey W. Baker
#  Portions Copyright (c) 1994,1995,1996,1997 Tim Bunce
#
#  You may distribute under the terms of either the GNU General Public
#  License or the Artistic License, as specified in the Perl README file.


require 5.004;

$DBD::Pg::VERSION = '1.22';

{
    package DBD::Pg;

    use DBI ();
    use DynaLoader ();
    use Exporter ();
    @ISA = qw(DynaLoader Exporter);

    %EXPORT_TAGS = (
	pg_types => [ qw(
           PG_BOOL PG_BYTEA PG_CHAR PG_INT8 PG_INT2 PG_INT4 PG_TEXT PG_OID
           PG_FLOAT4 PG_FLOAT8 PG_ABSTIME PG_RELTIME PG_TINTERVAL PG_BPCHAR
           PG_VARCHAR PG_DATE PG_TIME PG_DATETIME PG_TIMESPAN PG_TIMESTAMP
	)]);

    Exporter::export_ok_tags('pg_types');

    require_version DBI 1.00;

    bootstrap DBD::Pg $VERSION;

    $err = 0;		# holds error code   for DBI::err
    $errstr = "";	# holds error string for DBI::errstr
    $drh = undef;	# holds driver handle once initialized

    sub driver{
	return $drh if $drh;
	my($class, $attr) = @_;

	$class .= "::dr";

	# not a 'my' since we use it above to prevent multiple drivers

	$drh = DBI::_new_drh($class, {
	    'Name' => 'Pg',
	    'Version' => $VERSION,
	    'Err'    => \$DBD::Pg::err,
	    'Errstr' => \$DBD::Pg::errstr,
	    'Attribution' => 'PostgreSQL DBD by Edmund Mergl',
	});

	$drh;
    }

    ## Used by both the dr and db packages
    sub pg_server_version {
		my $dbh = shift;
		return $dbh->{pg_server_version} if defined $dbh->{pg_server_version};
        my ($version) = $dbh->selectrow_array("SELECT version();");
        return 0 unless $version =~ /^PostgreSQL ([\d\.]+)/;
        $dbh{pg_server_version} = $1;
        return $dbh{pg_server_version};
	}

    sub pg_use_catalog {
      my $dbh = shift;
      my $version = DBD::Pg::pg_server_version($dbh);
      $version =~ /^(\d+\.\d+)/;
      return $1 < 7.3 ? "" : "pg_catalog.";
    }

    1;
}


{   package DBD::Pg::dr; # ====== DRIVER ======
    use strict;

    sub data_sources {
        my $drh = shift;
        my $dbh = DBD::Pg::dr::connect($drh, 'dbname=template1') or return undef;
        $dbh->{AutoCommit} = 1;
        my $CATALOG = DBD::Pg::pg_use_catalog($dbh);
        my $sth = $dbh->prepare("SELECT datname FROM ${CATALOG}pg_database ORDER BY datname");
        $sth->execute or return undef;
        my (@sources, @datname);
        while (@datname = $sth->fetchrow_array) {
            push @sources, "dbi:Pg:dbname=$datname[0]";
        }
        $sth->finish;
        $dbh->disconnect;
        return @sources;
    }


    sub connect {
        my($drh, $dbname, $user, $auth)= @_;

        # create a 'blank' dbh

        my $Name = $dbname;
        $Name =~ s/^.*dbname\s*=\s*//;
        $Name =~ s/\s*;.*$//;

        $user = "" unless defined($user);
        $auth = "" unless defined($auth);

        $user = $ENV{DBI_USER} if $user eq "";
        $auth = $ENV{DBI_PASS} if $auth eq "";

        $user = "" unless defined($user);
        $auth = "" unless defined($auth);

        my($dbh) = DBI::_new_dbh($drh, {
            'Name' => $Name,
            'User' => $user, 'CURRENT_USER' => $user,
        });

        # Connect to the database..
        DBD::Pg::db::_login($dbh, $dbname, $user, $auth) or return undef;

        $dbh;
    }

}


{   package DBD::Pg::db; # ====== DATABASE ======
    use strict;
    use Carp ();

    sub prepare {
        my($dbh, $statement, @attribs)= @_;

        # create a 'blank' sth

        my $sth = DBI::_new_sth($dbh, {
            'Statement' => $statement,
        });

        DBD::Pg::st::_prepare($sth, $statement, @attribs) or return undef;

        $sth;
    }


    sub ping {
        my($dbh) = @_;

	local $SIG{__WARN__} = sub { } if $dbh->{PrintError};
        local $dbh->{RaiseError} = 0 if $dbh->{RaiseError};
        my $ret = DBD::Pg::db::_ping($dbh);

        return $ret;
    }

	# Column expected in statement handle returned.
	# table_cat, table_schem, table_name, column_name, data_type, type_name,
	# column_size, buffer_length, DECIMAL_DIGITS, NUM_PREC_RADIX, NULLABLE,
	# REMARKS, COLUMN_DEF, SQL_DATA_TYPE, SQL_DATETIME_SUB, CHAR_OCTET_LENGTH,
	# ORDINAL_POSITION, IS_NULLABLE
	# The result set is ordered by TABLE_CAT, TABLE_SCHEM, 
	# TABLE_NAME and ORDINAL_POSITION.

	sub column_info {
		my ($dbh) = shift;
		my @attrs = @_;
		# my ($dbh, $catalog, $schema, $table, $column) = @_;
		my $CATALOG = DBD::Pg::pg_use_catalog($dbh);

		my @wh = ();
		my @flds = qw/catname n.nspname c.relname a.attname/;

		for my $idx (0 .. $#attrs) {
			next if ($flds[$idx] eq 'catname'); # Skip catalog
			if(defined $attrs[$idx] and length $attrs[$idx]) {
				# Insure that the value is enclosed in single quotes.
				$attrs[$idx] =~ s/^'?(\w+)'?$/'$1'/;
				if ($attrs[$idx] =~ m/[,%]/) {
					# contains a meta character.
					push( @wh, q{( } . join ( " OR "
						, map { m/\%/ 
							? qq{$flds[$idx] ILIKE $_ }
							: qq{$flds[$idx]    = $_ }
							} (split /,/, $attrs[$idx]) )
							. q{ )}
						);
				}
				else {
					push( @wh, qq{$flds[$idx] = $attrs[$idx]} );
				}
			}
		}

		my $wh = ""; # ();
		$wh = join( " AND ", '', @wh ) if (@wh);
		my $version = DBD::Pg::pg_server_version($dbh);
		$version =~ /^(\d+\.\d+)/;
		$version = $1;
		my $showschema = $version < 7.3 ? "NULL::text" : "n.nspname";
		my $schemajoin = $version < 7.3 ? "" : "LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)";
		my $col_info_sql = qq{
			SELECT
				  NULL::text	AS "TABLE_CAT"
				, $showschema	AS "TABLE_SCHEM"
				, c.relname		AS "TABLE_NAME"
				, a.attname		AS "COLUMN_NAME"
				, t.typname		AS "DATA_TYPE"
				, NULL::text	AS "TYPE_NAME"
				, a.attlen		AS "COLUMN_SIZE"
				, NULL::text	AS "BUFFER_LENGTH"
				, NULL::text	AS "DECIMAL_DIGITS"
				, NULL::text	AS "NUM_PREC_RADIX"
				, a.attnotnull	AS "NULLABLE"
				, NULL::text	AS "REMARKS"
				, a.atthasdef	AS "COLUMN_DEF"
				, NULL::text	AS "SQL_DATA_TYPE"
				, NULL::text	AS "SQL_DATETIME_SUB"
				, NULL::text	AS "CHAR_OCTET_LENGTH"
				, a.attnum		AS "ORDINAL_POSITION"
				, a.attnotnull	AS "IS_NULLABLE"
				, a.atttypmod	as atttypmod
				, a.attnotnull	as attnotnull
				, a.atthasdef	as atthasdef
				, a.attnum		as attnum
			FROM 
				  ${CATALOG}pg_attribute	a
				, ${CATALOG}pg_type		t
				, ${CATALOG}pg_class		c
				$schemajoin
			WHERE
					a.attrelid = c.oid
				AND a.attnum  >= 0
				AND t.oid      = a.atttypid
				AND c.relkind  in ('r','v')
				$wh
			ORDER BY 2, 3, 4
		};

		my $sth = $dbh->prepare( $col_info_sql ) or return undef;
		$sth->execute();

		return $sth;
	}

	sub primary_key_info {
        my $dbh = shift;
		my ($catalog, $schema, $table) = @_;
		my @attrs = @_;
        my $CATALOG = DBD::Pg::pg_use_catalog($dbh);

		# TABLE_CAT:, TABLE_SCHEM:, TABLE_NAME:, COLUMN_NAME:, KEY_SEQ:
		# , PK_NAME:

		my @wh = (); my @dat = ();  # Used to hold data for the attributes.

		my $version = DBD::Pg::pg_server_version($dbh);
		$version =~ /^(\d+\.\d+)/;
		$version = $1;

		my @flds = qw/catname u.usename bc.relname/;
		$flds[1] = 'n.nspname' unless ($version < 7.3);

		for my $idx (0 .. $#attrs) {
			next if ($flds[$idx] eq 'catname'); # Skip catalog
			if(defined $attrs[$idx] and length $attrs[$idx]) {
				if ($attrs[$idx] =~ m/[,%_?]/) {
					# contains a meta character.
					push( @wh, q{( } . join ( " OR "
						, map { push(@dat, $_);
							m/[%_?]/ 
							? qq{$flds[$idx] iLIKE ? }
							: qq{$flds[$idx]    = ?  }
							} (split /,/, $attrs[$idx]) )
							. q{ )}
						);
				}
				else {
					push( @dat, $attrs[$idx] );
					push( @wh, qq{$flds[$idx] = ? } );
				}
			}
		}

		my $wh = '';
		$wh = join( " AND ", '', @wh ) if (@wh);

		# Base primary key selection query borrowed from phpPgAdmin.
		my $showschema = $version < 7.3 ? "NULL::text" : "n.nspname";
		my $schemajoin = $version < 7.3 ? "" : "LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = bc.relnamespace)";
		my $pri_key_sql = qq{
			SELECT
				NULL::text		AS "TABLE_CAT"
				, $showschema	AS "TABLE_SCHEM"
				, bc.relname	AS "TABLE_NAME"
				, a.attname		AS "COLUMN_NAME"
				, a.attnum		AS "KEY_SEQ"
				, ic.relname    AS "PK_NAME"
			FROM
				${CATALOG}pg_index i
				, ${CATALOG}pg_attribute a
				, ${CATALOG}pg_class ic
				, ${CATALOG}pg_class bc
				$schemajoin
			WHERE
				i.indrelid = bc.oid
			AND i.indexrelid = ic.oid
			AND
			(
				i.indkey[0] = a.attnum
				OR
				i.indkey[1] = a.attnum
				OR
				i.indkey[2] = a.attnum
				OR
				i.indkey[3] = a.attnum
				OR
				i.indkey[4] = a.attnum
				OR
				i.indkey[5] = a.attnum
				OR
				i.indkey[6] = a.attnum
				OR
				i.indkey[7] = a.attnum
				OR
				i.indkey[8] = a.attnum
				OR
				i.indkey[9] = a.attnum
				OR
				i.indkey[10] = a.attnum
				OR
				i.indkey[11] = a.attnum
				OR
				i.indkey[12] = a.attnum
			)
			AND a.attrelid = bc.oid
			AND i.indproc = '0'::oid
			AND i.indisprimary = 't' 
			$wh
			ORDER BY 2, 3, 5
		};

        my $sth = $dbh->prepare( $pri_key_sql ) or return undef;
        $sth->execute(@dat);

        return $sth;
	}

    sub foreign_key_info {
	# todo: verify schema work as expected
	# add code to handle multiple-column keys correctly
	# return something nicer for pre-7.3?
	# try to clean up SQL, perl code
	# create a test script?

	my $dbh = shift;
	my ($pk_catalog, $pk_schema, $pk_table,
		$fk_catalog, $fk_schema, $fk_table) = @_;

	# this query doesn't work for Postgres before 7.3
	my $version = $dbh->pg_server_version;
	$version =~ /^(\d+)\.(\d)/;
	return undef if ($1.$2 < 73);

	# Used to hold data for the attributes.
	my @dat = ();

	# SQL to find primary/unique keys of a table
	my $pkey_sql = qq{
	SELECT
	NULL::text AS PKTABLE_CAT,
	pknam.nspname AS PKTABLE_SCHEM,
	pkc.relname AS PKTABLE_NAME,
	pka.attname AS PKCOLUMN_NAME,
	NULL::text AS FKTABLE_CAT,
	NULL::text AS FKTABLE_SCHEM,
	NULL::text AS FKTABLE_NAME,
	NULL::text AS FKCOLUMN_NAME,
	pkcon.conkey[1] AS KEY_SEQ,
	CASE
		WHEN pkcon.confupdtype = 'c' THEN 0
		WHEN pkcon.confupdtype = 'r' THEN 1
		WHEN pkcon.confupdtype = 'n' THEN 2
		WHEN pkcon.confupdtype = 'a' THEN 3
		WHEN pkcon.confupdtype = 'd' THEN 4
		END AS UPDATE_RULE,
	CASE
		WHEN pkcon.confdeltype = 'c' THEN 0
		WHEN pkcon.confdeltype = 'r' THEN 1
		WHEN pkcon.confdeltype = 'n' THEN 2
		WHEN pkcon.confdeltype = 'a' THEN 3
		WHEN pkcon.confdeltype = 'd' THEN 4
		END AS DELETE_RULE,
	NULL::text AS FK_NAME,
	pkcon.conname AS PK_NAME,
	CASE
		WHEN pkcon.condeferrable = 'f' THEN 7
		WHEN pkcon.condeferred = 't' THEN 6
		WHEN pkcon.condeferred = 'f' THEN 5
		END AS DEFERRABILITY,
	CASE
		WHEN pkcon.contype = 'p' THEN 'PRIMARY'
		WHEN pkcon.contype = 'u' THEN 'UNIQUE'
		END AS UNIQUE_OR_PRIMARY
	FROM
		pg_constraint AS pkcon
	JOIN
		pg_class pkc ON pkc.oid=pkcon.conrelid
	JOIN
		pg_namespace pknam ON pkcon.connamespace=pknam.oid
	JOIN
		pg_attribute pka ON pka.attnum=pkcon.conkey[1] AND pka.attrelid=pkc.oid
	};

	# SQL to find foreign keys of a table
	my $fkey_sql = qq{
	SELECT
	NULL::text AS PKTABLE_CAT,
	pknam.nspname AS PKTABLE_SCHEM,
	pkc.relname AS PKTABLE_NAME,
	pka.attname AS PKCOLUMN_NAME,
	NULL::text AS FKTABLE_CAT,
	fknam.nspname AS FKTABLE_SCHEM,
	fkc.relname AS FKTABLE_NAME,
	fka.attname AS FKCOLUMN_NAME,
	fkcon.conkey[1] AS KEY_SEQ,
	CASE
		WHEN fkcon.confupdtype = 'c' THEN 0
		WHEN fkcon.confupdtype = 'r' THEN 1
		WHEN fkcon.confupdtype = 'n' THEN 2
		WHEN fkcon.confupdtype = 'a' THEN 3
		WHEN fkcon.confupdtype = 'd' THEN 4
		END AS UPDATE_RULE,
	CASE
		WHEN fkcon.confdeltype = 'c' THEN 0
		WHEN fkcon.confdeltype = 'r' THEN 1
		WHEN fkcon.confdeltype = 'n' THEN 2
		WHEN fkcon.confdeltype = 'a' THEN 3
		WHEN fkcon.confdeltype = 'd' THEN 4
		END AS DELETE_RULE,
	fkcon.conname AS FK_NAME,
	pkcon.conname AS PK_NAME,
	CASE
		WHEN fkcon.condeferrable = 'f' THEN 7
		WHEN fkcon.condeferred = 't' THEN 6
		WHEN fkcon.condeferred = 'f' THEN 5
		END AS DEFERRABILITY,
	CASE
		WHEN pkcon.contype = 'p' THEN 'PRIMARY'
		WHEN pkcon.contype = 'u' THEN 'UNIQUE'
		END AS UNIQUE_OR_PRIMARY
	FROM
		pg_constraint AS fkcon
	JOIN
		pg_constraint AS pkcon ON fkcon.confrelid=pkcon.conrelid
			AND fkcon.confkey=pkcon.conkey
	JOIN
		pg_class fkc ON fkc.oid=fkcon.conrelid
	JOIN
		pg_class pkc ON pkc.oid=fkcon.confrelid
	JOIN
		pg_namespace pknam ON pkcon.connamespace=pknam.oid
	JOIN
		pg_namespace fknam ON fkcon.connamespace=fknam.oid
	JOIN
		pg_attribute fka ON fka.attnum=fkcon.conkey[1] AND fka.attrelid=fkc.oid
	JOIN
		pg_attribute pka ON pka.attnum=pkcon.conkey[1] AND pka.attrelid=pkc.oid
	};

	# if schema are provided, use this SQL
	my $pk_schema_sql = " AND pknam.nspname = ? ";
	my $fk_schema_sql = " AND fknam.nspname = ? ";

	my $key_sql;

	# if $fk_table: generate SQL stub, which will be same
	# whether or not $pk_table supplied
	if ($fk_table)
	{
		$key_sql = $fkey_sql . qq{
		WHERE
			fkc.relname = ?
		};
		push @dat, $fk_table;

		if ($fk_schema)
		{
			$key_sql .= $fk_schema_sql;
			push @dat,$fk_schema;
		}
	}

	# if $fk_table and $pk_table: (defined by DBI, not SQL/CLI)
	# return foreign key of $fk_table that refers to $pk_table
	# (if any)
	if ($pk_table and $fk_table)
	{
		$key_sql .= qq{
		AND
			pkc.relname = ?
		};
		push @dat, $pk_table;

		if ($pk_schema)
		{
			$key_sql .= $pk_schema_sql;
			push @dat,$pk_schema;
		}
	}

	# if $fk_table but no $pk_table:
	# return all foreign keys of $fk_table, and all
	# primary keys of tables to which $fk_table refers
	if (!$pk_table and $fk_table)
	{
		# find primary/unique keys referenced by $fk_table
		# (this one is a little tricky)
		$key_sql .= ' UNION ' . $pkey_sql . qq{
		WHERE
			pkcon.conname IN
		(
		SELECT
			pkcon.conname
		FROM
			pg_constraint AS fkcon
		JOIN
			pg_constraint AS pkcon ON fkcon.confrelid=pkcon.conrelid AND
					fkcon.confkey=pkcon.conkey
		JOIN
			pg_class fkc ON fkc.oid=fkcon.conrelid
		WHERE
			fkc.relname = ?
		)	
		};
		push @dat, $fk_table;

		if ($fk_schema)
		{
			$key_sql .= $pk_schema_sql;
			push @dat,$fk_schema;
		}
	}

	# if $pk_table but no $fk_table:
	# return primary key of $pk_table and all foreign keys
	# that reference $pk_table
	# question: what about unique keys?
	# (DBI and SQL/CLI both state to omit unique keys)

	if ($pk_table and !$fk_table)
	{
		# find primary key (only!) of $pk_table
		$key_sql = $pkey_sql . qq{
		WHERE
			pkc.relname = ?
		AND
			pkcon.contype = 'p'
		};
		@dat = ($pk_table);

		if ($pk_schema)
		{
			$key_sql .= $pk_schema_sql;
			push @dat,$pk_schema;
		}

		# find all foreign keys that reference $pk_table
		$key_sql .= 'UNION ' . $fkey_sql . qq{
		WHERE
			pkc.relname = ?
		AND
			pkcon.contype = 'p'
		};
		push @dat, $pk_table;

		if ($pk_schema)
		{
			$key_sql .= $fk_schema_sql;
			push @dat,$pk_schema;
		}
	}

	return undef unless $key_sql;
	my $sth = $dbh->prepare( $key_sql ) or
		return undef;
	$sth->execute(@dat);

	return $sth;
    }


    sub table_info {         # DBI spec: TABLE_CAT, TABLE_SCHEM, TABLE_NAME, TABLE_TYPE, REMARKS
        my $dbh = shift;
		my ($catalog, $schema, $table, $type) = @_;
		my @attrs = @_;

		my $tbl_sql = ();

        my $version = DBD::Pg::pg_server_version($dbh);
	$version =~ /^(\d+\.\d+)/;
	$version = $1;
        my $CATALOG = DBD::Pg::pg_use_catalog($dbh);

		if ( # Rules 19a
			    (defined $catalog and $catalog eq '%')
			and (defined $schema  and $schema  eq  '')
			and (defined $table   and $table   eq  '')
			) {
				$tbl_sql = q{
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , NULL::text    AS "TABLE_TYPE"
					 , NULL::text    AS "REMARKS"
					};
		}
		elsif (# Rules 19b
			    (defined $catalog and $catalog eq  '')
			and (defined $schema  and $schema  eq '%')
			and (defined $table   and $table   eq  '')
			) {
				$tbl_sql = ($version < 7.3) ? q{
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , NULL::text    AS "TABLE_TYPE"
					 , NULL::text    AS "REMARKS"
                    } : q{
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , n.nspname     AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , NULL::text    AS "TABLE_TYPE"
					 , NULL::text    AS "REMARKS"
					FROM pg_catalog.pg_namespace n
					ORDER BY 1
					};
		}
		elsif (# Rules 19c
			    (defined $catalog and $catalog eq  '')
			and (defined $schema  and $schema  eq  '')
			and (defined $table   and $table   eq  '')
			and (defined $type    and $type    eq  '%')
			) {
				# From the postgresql 7.2.1 manual 3.5 pg_class
				#  'r' = ordinary table
				#, 'i' = index
				#, 'S' = sequence
				#, 'v' = view
				#, 's' = special
				#, 't' = secondary TOAST table 
				$tbl_sql = q{
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , 'table'       AS "TABLE_TYPE"
					 , 'ordinary table - r'    AS "REMARKS"
					union
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , 'index'       AS "TABLE_TYPE"
					 , 'index - i'    AS "REMARKS"
					union
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , 'sequence'     AS "TABLE_TYPE"
					 , 'sequence - S'    AS "REMARKS"
					union
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , 'view'       AS "TABLE_TYPE"
					 , 'view - v'    AS "REMARKS"
					union
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , 'special'       AS "TABLE_TYPE"
					 , 'special - s'    AS "REMARKS"
					union
					SELECT 
					   NULL::text    AS "TABLE_CAT"
					 , NULL::text    AS "TABLE_SCHEM"
					 , NULL::text    AS "TABLE_NAME"
					 , 'secondary'   AS "TABLE_TYPE"
					 , 'secondary TOAST table - t'    AS "REMARKS"
				};
		}
		else {
				# Default SQL
				my $showschema = $version < 7.3 ? "NULL::text" : "n.nspname";
				my $schemajoin = $version < 7.3 ? "" : "LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)";
				my $schemacase = $version < 7.3 ? "CASE WHEN c.relname ~ '^pg_' THEN 'SYSTEM TABLE' ELSE 'TABLE' END" : 
					"CASE WHEN n.nspname ~ '^pg_' THEN 'SYSTEM TABLE' ELSE 'TABLE' END";
				$tbl_sql = qq{
				SELECT NULL::text    AS "TABLE_CAT"
					 , $showschema   AS "TABLE_SCHEM"
					 , c.relname     AS "TABLE_NAME"
					 , CASE
					 	 WHEN c.relkind = 'v' THEN 'VIEW'
					  	 ELSE $schemacase
						END			 AS "TABLE_TYPE"
					 , d.description AS "REMARKS"
				FROM ${CATALOG}pg_user		AS u
				   , ${CATALOG}pg_class		AS c
					 LEFT JOIN 
					 ${CATALOG}pg_description	AS d 
						ON (c.relfilenode = d.objoid AND d.objsubid = 0)
				$schemajoin
				WHERE 
					  ((c.relkind     =  'r'
				  AND c.relhasrules =  FALSE) OR
					  (c.relkind     =  'v'
				  AND c.relhasrules =  TRUE))
				  AND c.relname     !~ '^xin[vx][0-9]+'
				  AND c.relowner    =  u.usesysid
				ORDER BY 1, 2, 3
				};

			# Did we receive any arguments?
			if (@attrs) {
				my @wh = ();
				my @flds = qw/catname n.nspname c.relname c.relkind/;

				for my $idx (0 .. $#attrs) {
					next if ($flds[$idx] eq 'catname'); # Skip catalog
					if(defined $attrs[$idx] and length $attrs[$idx]) {
						# Change the "name" of the types to the real value.
						if ($flds[$idx]  =~ m/relkind/) {
							$attrs[$idx] =~ s/^\'?table\'?/'r'/i;
							$attrs[$idx] =~ s/^\'?index\'?/'i'/i;
							$attrs[$idx] =~ s/^\'?sequence\'?/'S'/i;
							$attrs[$idx] =~ s/^\'?view\'?/'v'/i;
							$attrs[$idx] =~ s/^\'?special\'?/'s'/i;
							$attrs[$idx] =~ s/^\'?secondary\'?/'t'/i;
						}
						# Insure that the value is enclosed in single quotes.
						$attrs[$idx] =~ s/^'?(\w+)'?$/'$1'/;
						if ($attrs[$idx] =~ m/[,%]/) {
							# contains a meta character.
							push( @wh, q{( } . join ( " OR "
								, map { m/\%/ 
									? qq{$flds[$idx] LIKE $_ }
									: qq{$flds[$idx]    = $_ }
									} (split /,/, $attrs[$idx]) )
									. q{ )}
								);
						}
						else {
							push( @wh, qq{$flds[$idx] = $attrs[$idx]} );
						}
					}
				}

				my $wh = ();
				if (@wh) {
					$wh = join( " AND ",'', @wh );
					$tbl_sql = qq{
					SELECT NULL::text    AS "TABLE_CAT"
						 , $showschema   AS "TABLE_SCHEM"
						 , c.relname     AS "TABLE_NAME"
						 , CASE
							 WHEN c.relkind = 'r' THEN 
								CASE WHEN n.nspname ~ '^pg_' THEN 'SYSTEM TABLE' ELSE 'TABLE' END
							 WHEN c.relkind = 'v' THEN 'VIEW'
							 WHEN c.relkind = 'i' THEN 'INDEX'
							 WHEN c.relkind = 'S' THEN 'SEQUENCE'
							 WHEN c.relkind = 's' THEN 'SPECIAL'
							 WHEN c.relkind = 't' THEN 'SECONDARY'
							 ELSE 'UNKNOWN'
							END			 AS "TABLE_TYPE"
						 , d.description AS "REMARKS"
					FROM ${CATALOG}pg_class		AS c
						LEFT JOIN 
						 ${CATALOG}pg_description	AS d 
							ON (c.relfilenode = d.objoid AND d.objsubid = 0)
						$schemajoin
					WHERE 
					  	  c.relname     !~ '^xin[vx][0-9]+'
					  $wh
					ORDER BY 2, 3
					};
				}
			}
		}

        my $sth = $dbh->prepare( $tbl_sql ) or return undef;
        $sth->execute();

        return $sth;
    }


    sub tables {
        my($dbh) = @_;
        my $version = DBD::Pg::pg_server_version($dbh);
	$version =~ /^(\d+\.\d+)/;
	$version = $1;
	my $SQL = ($version < 7.3) ? 
            "SELECT relname  AS \"TABLE_NAME\"
            FROM   pg_class 
            WHERE  relkind = 'r'
            AND    relname !~ '^pg_'
            AND    relname !~ '^xin[vx][0-9]+'
            ORDER BY 1" : 
            "SELECT n.nspname AS \"SCHEMA_NAME\", c.relname  AS \"TABLE_NAME\"
            FROM   pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_namespace n ON (n.oid = c.relnamespace)
            WHERE  c.relkind = 'r'
            AND n.nspname NOT IN ('pg_catalog', 'pg_toast')
            AND pg_catalog.pg_table_is_visible(c.oid)
            ORDER BY 1,2";
        my $sth = $dbh->prepare($SQL) or return undef;
        $sth->execute or return undef;
        my (@tables, @relname);
        while (@relname = $sth->fetchrow_array) {
            push @tables, $version < 7.3 ? $relname[0] : "$relname[0].$relname[1]";
        }
        $sth->finish;

        return @tables;
    }


    sub table_attributes {
        my ($dbh, $table) = @_;
        my $CATALOG = DBD::Pg::pg_use_catalog($dbh);
        my $result = [];    
        my $attrs  = $dbh->selectall_arrayref(
             "select a.attname, t.typname, a.attlen, a.atttypmod, a.attnotnull, a.atthasdef, a.attnum
              from ${CATALOG}pg_attribute a,
                   ${CATALOG}pg_class     c,
                   ${CATALOG}pg_type      t
              where c.relname  = ?
                and a.attrelid = c.oid
                and a.attnum  >= 0
                and t.oid      = a.atttypid
                order by 1 
             ", undef, $table);
    
        return $result unless scalar(@$attrs);

	# Select the array value for tables primary key.
	my $pk_key_sql = qq{SELECT pg_index.indkey
                            FROM   ${CATALOG}pg_class, ${CATALOG}pg_index
                            WHERE
                                   pg_class.oid          = pg_index.indrelid
                            AND    pg_class.relname      = '$table'
                            AND    pg_index.indisprimary = 't'
			};
	# Expand this (returned as a string) a real array.
	my @pk = ();
    my $pkeys = $dbh->selectrow_array( $pk_key_sql );
    if (defined $pkeys) {
    	foreach (split( /\s+/, $pkeys))
	    {
		    push @pk, $_;
	    }
    }
	my $pk_bt = 
		(@pk)   ? "AND    pg_attribute.attnum in (" . join ( ", ", @pk ) . ")"
			: "";
		
        # Get the primary key
        my $pri_key = $dbh->selectcol_arrayref("SELECT pg_attribute.attname
                                               FROM   ${CATALOG}pg_class, ${CATALOG}pg_attribute, ${CATALOG}pg_index
                                               WHERE  pg_class.oid          = pg_attribute.attrelid 
                                               AND    pg_class.oid          = pg_index.indrelid 
					       $pk_bt
                                               AND    pg_index.indisprimary = 't'
                                               AND    pg_class.relname      = ?
					       ORDER BY pg_attribute.attnum
					       ", undef, $table );
        $pri_key = [] unless $pri_key;

        foreach my $attr (reverse @$attrs) {
            my ($col_name, $col_type, $size, $mod, $notnull, $hasdef, $attnum) = @$attr;
            my $col_size = do { 
                if ($size > 0) {
                    $size;
                } elsif ($mod > 0xffff) {
                    my $prec = ($mod & 0xffff) - 4;
                    $mod >>= 16;
                    my $dig = $mod;
                    $dig;
                } elsif ($mod >= 4) {
                    $mod - 4;
                } else {
                    $mod;
                }
            };

            # Get the default value, if any
            my ($default) = $dbh->selectrow_array("SELECT adsrc FROM ${CATALOG}pg_attrdef WHERE  adnum = $attnum") if -1 == $attnum;
            $default = '' unless $default;

            # Test for any constraints
            # Note: as of PostgreSQL 7.3 pg_relcheck has been replaced
            # by pg_constraint. To maintain compatibility, check 
            # version number and execute appropriate query.
	
            my $version = pg_server_version( $dbh );
            
            my $con_query = $version < 7.3
             ? "SELECT rcsrc FROM pg_relcheck WHERE rcname = '${table}_$col_name'"
             : "SELECT consrc FROM pg_catalog.pg_constraint WHERE contype = 'c' AND conname = '${table}_$col_name'";
            my ($constraint) = $dbh->selectrow_array($con_query);
            $constraint = '' unless $constraint;

            # Check to see if this is the primary key
            my $is_primary_key = scalar(grep { /^$col_name$/i } @$pri_key) ? 1 : 0;

            push @$result,
                { NAME        => $col_name,
                  TYPE        => $col_type,
                  SIZE        => $col_size,
                  NOTNULL     => $notnull,
                  DEFAULT     => $default,
                  CONSTRAINT  => $constraint,
                  PRIMARY_KEY => $is_primary_key,
                };
        }

        return $result;
    }


    sub type_info_all {
        my ($dbh) = @_;

	#my $names = {
    #      TYPE_NAME		=> 0,
    #      DATA_TYPE		=> 1,
    #      PRECISION		=> 2,
    #      LITERAL_PREFIX	=> 3,
    #      LITERAL_SUFFIX	=> 4,
    #      CREATE_PARAMS		=> 5,
    #      NULLABLE		=> 6,
    #      CASE_SENSITIVE	=> 7,
    #      SEARCHABLE		=> 8,
    #      UNSIGNED_ATTRIBUTE	=> 9,
    #      MONEY			=>10,
    #      AUTO_INCREMENT	=>11,
    #      LOCAL_TYPE_NAME	=>12,
    #      MINIMUM_SCALE		=>13,
    #      MAXIMUM_SCALE		=>14,
    #    };

	my $names = {
        TYPE_NAME         => 0,
        DATA_TYPE         => 1,
        COLUMN_SIZE       => 2,     # was PRECISION originally
        LITERAL_PREFIX    => 3,
        LITERAL_SUFFIX    => 4,
        CREATE_PARAMS     => 5,
        NULLABLE          => 6,
        CASE_SENSITIVE    => 7,
        SEARCHABLE        => 8,
        UNSIGNED_ATTRIBUTE=> 9,
        FIXED_PREC_SCALE  => 10,    # was MONEY originally
        AUTO_UNIQUE_VALUE => 11,    # was AUTO_INCREMENT originally
        LOCAL_TYPE_NAME   => 12,
        MINIMUM_SCALE     => 13,
        MAXIMUM_SCALE     => 14,
        NUM_PREC_RADIX    => 15,
    };


	#  typname       |typlen|typprtlen|    SQL92
	#  --------------+------+---------+    -------
	#  bool          |     1|        1|    BOOLEAN
	#  text          |    -1|       -1|    like VARCHAR, but automatic storage allocation
	#  bpchar        |    -1|       -1|    CHARACTER(n)    bp=blank padded
	#  varchar       |    -1|       -1|    VARCHAR(n)
	#  int2          |     2|        5|    SMALLINT
	#  int4          |     4|       10|    INTEGER
	#  int8          |     8|       20|    /
	#  money         |     4|       24|    /
	#  float4        |     4|       12|    FLOAT(p)   for p<7=float4, for p<16=float8
	#  float8        |     8|       24|    REAL
	#  abstime       |     4|       20|    /
	#  reltime       |     4|       20|    /
	#  tinterval     |    12|       47|    /
	#  date          |     4|       10|    /
	#  time          |     8|       16|    /
	#  datetime      |     8|       47|    /
	#  timespan      |    12|       47|    INTERVAL
	#  timestamp     |     4|       19|    TIMESTAMP
	#  --------------+------+---------+

        # DBI type definitions / PostgreSQL definitions     # type needs to be DBI-specific (not pg_type)
        #
        # SQL_ALL_TYPES  0	
        # SQL_CHAR       1	1042 bpchar
        # SQL_NUMERIC    2	 700 float4
        # SQL_DECIMAL    3	 700 float4
        # SQL_INTEGER    4	  23 int4
        # SQL_SMALLINT   5	  21 int2
        # SQL_FLOAT      6	 700 float4
        # SQL_REAL       7	 701 float8
        # SQL_DOUBLE     8	  20 int8
        # SQL_DATE       9	1082 date
        # SQL_TIME      10	1083 time
        # SQL_TIMESTAMP 11	1296 timestamp
        # SQL_VARCHAR   12	1043 varchar

	my $ti = [
	  $names,
          # name          type  prec  prefix suffix  create params null case se unsign mon  incr       local   min    max
          #					     
          [ 'bytea',        -2, 4096,  '\'',  '\'',           undef, 1, '1', 3, undef, '0', '0',     'BYTEA', undef, undef, undef ],
          [ 'bool',          0,    1,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0',   'BOOLEAN', undef, undef, undef ],
          [ 'int8',          8,   20, undef, undef,           undef, 1, '0', 2,   '0', '0', '0',   'LONGINT', undef, undef, undef ],
          [ 'int2',          5,    5, undef, undef,           undef, 1, '0', 2,   '0', '0', '0',  'SMALLINT', undef, undef, undef ],
          [ 'int4',          4,   10, undef, undef,           undef, 1, '0', 2,   '0', '0', '0',   'INTEGER', undef, undef, undef ],
          [ 'text',         12, 4096,  '\'',  '\'',           undef, 1, '1', 3, undef, '0', '0',      'TEXT', undef, undef, undef ],
          [ 'float4',        6,   12, undef, undef,     'precision', 1, '0', 2,   '0', '0', '0',     'FLOAT', undef, undef, undef ],
          [ 'float8',        7,   24, undef, undef,     'precision', 1, '0', 2,   '0', '0', '0',      'REAL', undef, undef, undef ],
          [ 'abstime',      10,   20,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0',   'ABSTIME', undef, undef, undef ],
          [ 'reltime',      10,   20,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0',   'RELTIME', undef, undef, undef ],
          [ 'tinterval',    11,   47,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0', 'TINTERVAL', undef, undef, undef ],
          [ 'money',         0,   24, undef, undef,           undef, 1, '0', 2, undef, '1', '0',     'MONEY', undef, undef, undef ],
          [ 'bpchar',        1, 4096,  '\'',  '\'',    'max length', 1, '1', 3, undef, '0', '0', 'CHARACTER', undef, undef, undef ],
          [ 'bpchar',       12, 4096,  '\'',  '\'',    'max length', 1, '1', 3, undef, '0', '0', 'CHARACTER', undef, undef, undef ],
          [ 'varchar',      12, 4096,  '\'',  '\'',    'max length', 1, '1', 3, undef, '0', '0',   'VARCHAR', undef, undef, undef ],
          [ 'date',          9,   10,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0',      'DATE', undef, undef, undef ],
          [ 'time',         10,   16,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0',      'TIME', undef, undef, undef ],
          [ 'datetime',     11,   47,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0',  'DATETIME', undef, undef, undef ],
          [ 'timespan',     11,   47,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0',  'INTERVAL', undef, undef, undef ],
          [ 'timestamp',    10,   19,  '\'',  '\'',           undef, 1, '0', 2, undef, '0', '0', 'TIMESTAMP', undef, undef, undef ]
          #
          # intentionally omitted: char, all geometric types, all array types
        ];
	return $ti;
    }


    # Characters that need to be escaped by quote().
    my %esc = ( "'"  => '\\047', # '\\' . sprintf("%03o", ord("'")), # ISO SQL 2
                '\\' => '\\134', # '\\' . sprintf("%03o", ord("\\")),
              );

    # Set up lookup for SQL types we don't want to escape.
    my %no_escape = map { $_ => 1 }
      DBI::SQL_INTEGER, DBI::SQL_SMALLINT, DBI::SQL_DECIMAL,
      DBI::SQL_FLOAT, DBI::SQL_REAL, DBI::SQL_DOUBLE, DBI::SQL_NUMERIC;

    sub quote {
        my ($dbh, $str, $data_type) = @_;
        return "NULL" unless defined $str;
		return $str if $data_type && $no_escape{$data_type};

        $dbh->DBI::set_err(1, "Use of SQL_BINARY invalid in quote()")
          if $data_type && $data_type == DBI::SQL_BINARY;

		$str =~ s/(['\\\0])/$esc{$1}/g;
		return "'$str'";
    }

}    # end of package DBD::Pg::db

{   package DBD::Pg::st; # ====== STATEMENT ======

    # all done in XS

}

1;

__END__

=head1 NAME

DBD::Pg - PostgreSQL database driver for the DBI module

=head1 SYNOPSIS

  use DBI;

  $dbh = DBI->connect("dbi:Pg:dbname=$dbname", "", "");

  # for some advanced uses you may need PostgreSQL type values:
  use DBD::Oracle qw(:pg_types);

  # See the DBI module documentation for full details

=head1 DESCRIPTION

DBD::Pg is a Perl module which works with the DBI module to provide access to
PostgreSQL databases.

=head1 MODULE DOCUMENTATION

This documentation describes driver specific behavior and restrictions. It is
not supposed to be used as the only reference for the user. In any case
consult the DBI documentation first!

=head1 THE DBI CLASS

=head2 DBI Class Methods

=over 4

=item B<connect>

To connect to a database with a minimum of parameters, use the following
syntax:

  $dbh = DBI->connect("dbi:Pg:dbname=$dbname", "", "");

This connects to the database $dbname at localhost without any user
authentication. This is sufficient for the defaults of PostgreSQL.

The following connect statement shows all possible parameters:

  $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host;port=$port;" .
                      "options=$options;tty=$tty", "$username", "$password");

If a parameter is undefined PostgreSQL first looks for specific environment
variables and then it uses hard coded defaults:

    parameter  environment variable  hard coded default
    --------------------------------------------------
    dbname     PGDATABASE            current userid
    host       PGHOST                localhost
    port       PGPORT                5432
    options    PGOPTIONS             ""
    tty        PGTTY                 ""
    username   PGUSER                current userid
    password   PGPASSWORD            ""

If a host is specified, the postmaster on this host needs to be started with
the C<-i> option (TCP/IP sockets).

The options parameter specifies runtime options for the Postgres
backend. Common usage is to increase the number of buffers with the C<-B>
option. Also important is the C<-F> option, which disables automatic fsync()
call after each transaction. For further details please refer to the
L<postgres>.

For authentication with username and password appropriate entries have to be
made in pg_hba.conf. Please refer to the L<pg_hba.conf> and the L<pg_passwd>
for the different types of authentication. Note that for these two parameters
DBI distinguishes between empty and undefined. If these parameters are
undefined DBI substitutes the values of the environment variables DBI_USER and
DBI_PASS if present.

=item B<available_drivers>

  @driver_names = DBI->available_drivers;

Implemented by DBI, no driver-specific impact.

=item B<data_sources>

  @data_sources = DBI->data_sources('Pg');

The driver supports this method. Note that the necessary database connection to
the database template1 will be done on the localhost without any
user-authentication. Other preferences can only be set with the environment
variables PGHOST, DBI_USER and DBI_PASS.

=item B<trace>

  DBI->trace($trace_level, $trace_file)

Implemented by DBI, no driver-specific impact.

=back

=head2 DBI Dynamic Attributes

See Common Methods.

=head1 METHODS COMMON TO ALL HANDLES

=over 4

=item B<err>

  $rv = $h->err;

Supported by the driver as proposed by DBI. For the connect method it returns
PQstatus. In all other cases it returns PQresultStatus of the current handle.

=item B<errstr>

  $str = $h->errstr;

Supported by the driver as proposed by DBI. It returns the PQerrorMessage
related to the current handle.

=item B<state>

  $str = $h->state;

This driver does not (yet) support the state method.

=item B<trace>

  $h->trace($trace_level, $trace_filename);

Implemented by DBI, no driver-specific impact.

=item B<trace_msg>

  $h->trace_msg($message_text);

Implemented by DBI, no driver-specific impact.

=item B<func>

This driver supports a variety of driver specific functions accessible via the
func interface:

  $attrs = $dbh->func($table, 'table_attributes');

This method returns for the given table a reference to an array of hashes:

  NAME        attribute name
  TYPE        attribute type
  SIZE        attribute size (-1 for variable size)
  NULLABLE    flag nullable
  DEFAULT     default value
  CONSTRAINT  constraint
  PRIMARY_KEY flag is_primary_key

  $lobjId = $dbh->func($mode, 'lo_creat');

Creates a new large object and returns the object-id. $mode is a bit-mask
describing different attributes of the new object. Use the following
constants:

  $dbh->{pg_INV_WRITE}
  $dbh->{pg_INV_READ}

Upon failure it returns undef.

  $lobj_fd = $dbh->func($lobjId, $mode, 'lo_open');

Opens an existing large object and returns an object-descriptor for use in
subsequent lo_* calls. For the mode bits see lo_create. Returns undef upon
failure. Note that 0 is a perfectly correct object descriptor!

  $nbytes = $dbh->func($lobj_fd, $buf, $len, 'lo_write');

Writes $len bytes of $buf into the large object $lobj_fd. Returns the number
of bytes written and undef upon failure.

  $nbytes = $dbh->func($lobj_fd, $buf, $len, 'lo_read');

Reads $len bytes into $buf from large object $lobj_fd. Returns the number of
bytes read and undef upon failure.

  $loc = $dbh->func($lobj_fd, $offset, $whence, 'lo_lseek');

Change the current read or write location on the large object
$obj_id. Currently $whence can only be 0 (L_SET). Returns the current location
and undef upon failure.

  $loc = $dbh->func($lobj_fd, 'lo_tell');

Returns the current read or write location on the large object $lobj_fd and
undef upon failure.

  $lobj_fd = $dbh->func($lobj_fd, 'lo_close');

Closes an existing large object. Returns true upon success and false upon
failure.

  $lobj_fd = $dbh->func($lobj_fd, 'lo_unlink');

Deletes an existing large object. Returns true upon success and false upon
failure.

  $lobjId = $dbh->func($filename, 'lo_import');

Imports a Unix file as large object and returns the object id of the new
object or undef upon failure.

  $ret = $dbh->func($lobjId, 'lo_export', 'filename');

Exports a large object into a Unix file. Returns false upon failure, true
otherwise.

  $ret = $dbh->func($line, 'putline');

Used together with the SQL-command 'COPY table FROM STDIN' to copy large
amount of data into a table avoiding the overhead of using single
insert commands. The application must explicitly send the two characters "\."
to indicate to the backend that it has finished sending its data. See test.pl
for an example on how to use this function.

  $ret = $dbh->func($buffer, length, 'getline');

Used together with the SQL-command 'COPY table TO STDOUT' to dump a complete
table. See test.pl for an example on how to use this function.

  $ret = $dbh->func('pg_notifies');

Returns either undef or a reference to two-element array [ $table,
$backend_pid ] of asynchronous notifications received.

  $fd = $dbh->func('getfd');

Returns fd of the actual connection to server. Can be used with select() and
func('pg_notifies').

=back

=head1 ATTRIBUTES COMMON TO ALL HANDLES

=over 4

=item B<Warn> (boolean, inherited)

Implemented by DBI, no driver-specific impact.

=item B<Active> (boolean, read-only)

Supported by the driver as proposed by DBI. A database handle is active while
it is connected and statement handle is active until it is finished.

=item B<Kids> (integer, read-only)

Implemented by DBI, no driver-specific impact.

=item B<ActiveKids> (integer, read-only)

Implemented by DBI, no driver-specific impact.

=item B<CachedKids> (hash ref)

Implemented by DBI, no driver-specific impact.

=item B<CompatMode> (boolean, inherited)

Not used by this driver.

=item B<InactiveDestroy> (boolean)

Implemented by DBI, no driver-specific impact.

=item B<PrintError> (boolean, inherited)

Implemented by DBI, no driver-specific impact.

=item B<RaiseError> (boolean, inherited)

Implemented by DBI, no driver-specific impact.

=item B<HandleError> (boolean, inherited)

Implemented by DBI, no driver-specific impact.

=item B<ChopBlanks> (boolean, inherited)

Supported by the driver as proposed by DBI. This method is similar to the
SQL-function RTRIM.

=item B<LongReadLen> (integer, inherited)

Implemented by DBI, not used by the driver.

=item B<LongTruncOk> (boolean, inherited)

Implemented by DBI, not used by the driver.

=item B<Taint> (boolean, inherited)

Implemented by DBI, no driver-specific impact.

=item B<private_*>

Implemented by DBI, no driver-specific impact.

=back

=head1 DBI DATABASE HANDLE OBJECTS

=head2 Database Handle Methods

=over 4

=item B<selectrow_array>

  @row_ary = $dbh->selectrow_array($statement, \%attr, @bind_values);

Implemented by DBI, no driver-specific impact.

=item B<selectrow_arrayref>

  $ary_ref = $dbh->selectrow_arrayref($statement, \%attr, @bind_values);

Implemented by DBI, no driver-specific impact.

=item B<selectrow_hashref>

  $hash_ref = $dbh->selectrow_hashref($statement, \%attr, @bind_values);

Implemented by DBI, no driver-specific impact.

=item B<selectall_arrayref>

  $ary_ref = $dbh->selectall_arrayref($statement, \%attr, @bind_values);

Implemented by DBI, no driver-specific impact.

=item B<selectall_hashref>

  $hash_ref = $dbh->selectall_hashref($statement, $key_field);

Implemented by DBI, no driver-specific impact.

=item B<selectcol_arrayref>

  $ary_ref = $dbh->selectcol_arrayref($statement, \%attr, @bind_values);

Implemented by DBI, no driver-specific impact.

=item B<prepare>

  $sth = $dbh->prepare($statement, \%attr);

PostgreSQL does not have the concept of preparing a statement. Hence the
prepare method just stores the statement after checking for place-holders. No
information about the statement is available after preparing it.

=item B<prepare_cached>

  $sth = $dbh->prepare_cached($statement, \%attr);

Implemented by DBI, no driver-specific impact. This method is not useful for
this driver, because preparing a statement has no database interaction.

=item B<do>

  $rv  = $dbh->do($statement, \%attr, @bind_values);

Implemented by DBI, no driver-specific impact. See the notes for the execute
method elsewhere in this document.

=item B<commit>

  $rc  = $dbh->commit;

Supported by the driver as proposed by DBI. See also the notes about
B<Transactions> elsewhere in this document.

=item B<rollback>

  $rc  = $dbh->rollback;

Supported by the driver as proposed by DBI. See also the notes about
B<Transactions> elsewhere in this document.

=item B<disconnect>

  $rc  = $dbh->disconnect;

Supported by the driver as proposed by DBI.

=item B<ping>

  $rc = $dbh->ping;

This driver supports the ping-method, which can be used to check the validity
of a database-handle. The ping method issues an empty query and checks the
result status.

=item B<table_info>

  $sth = $dbh->table_info;

Supported by the driver as proposed by DBI. This method returns all tables and
views which are owned by the current user. It does not select any indexes and
sequences. Also System tables are not selected. As TABLE_QUALIFIER the reltype
attribute is returned and the REMARKS are undefined.

=item B<foreign_key_info>

  $sth = $dbh->foreign_key_info( $pk_catalog, $pk_schema, $pk_table,
                                 $fk_catalog, $fk_schema, $fk_table );

Supported by the driver as proposed by DBI. Unimplemented for Postgres
servers before 7.3 (returns undef).  Currently only returns information
about first column of any multiple-column keys.

=item B<tables>

  @names = $dbh->tables;

Supported by the driver as proposed by DBI. This method returns all tables and
views which are owned by the current user. It does not select any indexes and
sequences, or system tables.

=item B<type_info_all>

  $type_info_all = $dbh->type_info_all;

Supported by the driver as proposed by DBI. Only for SQL data-types and for
frequently used data-types information is provided. The mapping between the
PostgreSQL typename and the SQL92 data-type (if possible) has been done
according to the following table:

	+---------------+------------------------------------+
	| typname       | SQL92                              |
	|---------------+------------------------------------|
	| bool          | BOOL                               |
	| text          | /                                  |
	| bpchar        | CHAR(n)                            |
	| varchar       | VARCHAR(n)                         |
	| int2          | SMALLINT                           |
	| int4          | INT                                |
	| int8          | /                                  |
	| money         | /                                  |
	| float4        | FLOAT(p)   p<7=float4, p<16=float8 |
	| float8        | REAL                               |
	| abstime       | /                                  |
	| reltime       | /                                  |
	| tinterval     | /                                  |
	| date          | /                                  |
	| time          | /                                  |
	| datetime      | /                                  |
	| timespan      | TINTERVAL                          |
	| timestamp     | TIMESTAMP                          |
	+---------------+------------------------------------+

For further details concerning the PostgreSQL specific data-types please read
the L<pgbuiltin>.

=item B<type_info>

  @type_info = $dbh->type_info($data_type);

Implemented by DBI, no driver-specific impact.

=item B<quote>

  $sql = $dbh->quote($value, $data_type);

This module implements its own quote method. In addition to the DBI method it
also doubles the backslash, because PostgreSQL treats a backslash as an escape
character.

B<NOTE:> The undocumented (and invalid) support for the C<SQL_BINARY> data
type is officially deprecated. Use C<PG_BYTEA> with C<bind_param()> instead:

  $rv = $sth->bind_param($param_num, $bind_value,
                         { pg_type => DBD::Pg::PG_BYTEA });

=back

=head2 Database Handle Attributes

=over 4

=item B<AutoCommit>  (boolean)

Supported by the driver as proposed by DBI. According to the classification of
DBI, PostgreSQL is a database, in which a transaction must be explicitly
started. Without starting a transaction, every change to the database becomes
immediately permanent. The default of AutoCommit is on, which corresponds to
the default behavior of PostgreSQL. When setting AutoCommit to off, a
transaction will be started and every commit or rollback will automatically
start a new transaction. For details see the notes about B<Transactions>
elsewhere in this document.

=item B<Driver>  (handle)

Implemented by DBI, no driver-specific impact.

=item B<Name>  (string, read-only)

The default method of DBI is overridden by a driver specific method, which
returns only the database name. Anything else from the connection string is
stripped off. Note, that here the method is read-only in contrast to the DBI
specs.

=item B<RowCacheSize>  (integer)

Implemented by DBI, not used by the driver.

=item B<pg_auto_escape> (boolean)

PostgreSQL specific attribute. If true, then quotes and backslashes in all
parameters will be escaped in the following way:

  escape quote with a quote (SQL)
  escape backslash with a backslash

The default is on. Note, that PostgreSQL also accepts quotes, which are
escaped by a backslash. Any other ASCII character can be used directly in a
string constant.

=item B<pg_enable_utf8> (boolean)

PostgreSQL specific attribute.  If true, then the utf8 flag will be
turned for returned character data (if the data is valid utf8).  For
details about the utf8 flag, see L<Encode>.  This is only relevant under
perl 5.8 and higher.

B<NB>: This attribute is experimental and may be subject to change.

=item B<pg_INV_READ> (integer, read-only)

Constant to be used for the mode in lo_creat and lo_open.

=item B<pg_INV_WRITE> (integer, read-only)

Constant to be used for the mode in lo_creat and lo_open.

=back

=head1 DBI STATEMENT HANDLE OBJECTS

=head2 Statement Handle Methods

=over 4

=item B<bind_param>

  $rv = $sth->bind_param($param_num, $bind_value, \%attr);

Supported by the driver as proposed by DBI.

B<NOTE:> The undocumented (and invalid) support for the C<SQL_BINARY>
SQL type is officially deprecated. Use C<PG_BYTEA> instead:

  $rv = $sth->bind_param($param_num, $bind_value,
                         { pg_type => DBD::Pg::PG_BYTEA });

=item B<bind_param_inout>

Not supported by this driver.

=item B<execute>

  $rv = $sth->execute(@bind_values);

Supported by the driver as proposed by DBI. In addition to 'UPDATE', 'DELETE',
'INSERT' statements, for which it returns always the number of affected rows,
the execute method can also be used for 'SELECT ... INTO table' statements.

=item B<fetchrow_arrayref>

  $ary_ref = $sth->fetchrow_arrayref;

Supported by the driver as proposed by DBI.

=item B<fetchrow_array>

  @ary = $sth->fetchrow_array;

Supported by the driver as proposed by DBI.

=item B<fetchrow_hashref>

  $hash_ref = $sth->fetchrow_hashref;

Supported by the driver as proposed by DBI.

=item B<fetchall_arrayref>

  $tbl_ary_ref = $sth->fetchall_arrayref;

Implemented by DBI, no driver-specific impact.

=item B<finish>

  $rc = $sth->finish;

Supported by the driver as proposed by DBI.

=item B<rows>

  $rv = $sth->rows;

Supported by the driver as proposed by DBI. In contrast to many other drivers
the number of rows is available immediately after executing the statement.

=item B<bind_col>

  $rc = $sth->bind_col($column_number, \$var_to_bind, \%attr);

Supported by the driver as proposed by DBI.

=item B<bind_columns>

  $rc = $sth->bind_columns(\%attr, @list_of_refs_to_vars_to_bind);

Supported by the driver as proposed by DBI.

=item B<dump_results>

  $rows = $sth->dump_results($maxlen, $lsep, $fsep, $fh);

Implemented by DBI, no driver-specific impact.

=item B<blob_read>

  $blob = $sth->blob_read($id, $offset, $len);

Supported by this driver as proposed by DBI. Implemented by DBI but not
documented, so this method might change.

This method seems to be heavily influenced by the current implementation of
blobs in Oracle. Nevertheless we try to be as compatible as possible. Whereas
Oracle suffers from the limitation that blobs are related to tables and every
table can have only one blob (data-type LONG), PostgreSQL handles its blobs
independent of any table by using so called object identifiers. This explains
why the blob_read method is blessed into the STATEMENT package and not part of
the DATABASE package. Here the field parameter has been used to handle this
object identifier. The offset and len parameter may be set to zero, in which
case the driver fetches the whole blob at once.

Starting with PostgreSQL-6.5 every access to a blob has to be put into a
transaction. This holds even for a read-only access.

See also the PostgreSQL-specific functions concerning blobs which are
available via the func-interface.

For further information and examples about blobs, please read the chapter
about Large Objects in the PostgreSQL Programmer's Guide.

=back

=head2 Statement Handle Attributes

=over 4

=item B<NUM_OF_FIELDS>  (integer, read-only)

Implemented by DBI, no driver-specific impact.

=item B<NUM_OF_PARAMS>  (integer, read-only)

Implemented by DBI, no driver-specific impact.

=item B<NAME>  (array-ref, read-only)

Supported by the driver as proposed by DBI.

=item B<NAME_lc>  (array-ref, read-only)

Implemented by DBI, no driver-specific impact.

=item B<NAME_uc>  (array-ref, read-only)

Implemented by DBI, no driver-specific impact.

=item B<TYPE>  (array-ref, read-only)

Supported by the driver as proposed by DBI, with the restriction, that the
types are PostgreSQL specific data-types which do not correspond to
international standards.

=item B<PRECISION>  (array-ref, read-only)

Not supported by the driver.

=item B<SCALE>  (array-ref, read-only)

Not supported by the driver.

=item B<NULLABLE>  (array-ref, read-only)

Not supported by the driver.

=item B<CursorName>  (string, read-only)

Not supported by the driver. See the note about B<Cursors> elsewhere in this
document.

=item B<Statement>  (string, read-only)

Supported by the driver as proposed by DBI.

=item B<RowCache>  (integer, read-only)

Not supported by the driver.

=item B<pg_size>  (array-ref, read-only)

PostgreSQL specific attribute. It returns a reference to an array of integer
values for each column. The integer shows the size of the column in
bytes. Variable length columns are indicated by -1.

=item B<pg_type>  (hash-ref, read-only)

PostgreSQL specific attribute. It returns a reference to an array of strings
for each column. The string shows the name of the data_type.

=item B<pg_oid_status> (integer, read-only)

PostgreSQL specific attribute. It returns the OID of the last INSERT command.

=item B<pg_cmd_status> (integer, read-only)

PostgreSQL specific attribute. It returns the type of the last
command. Possible types are: INSERT, DELETE, UPDATE, SELECT.

=back

=head1 FURTHER INFORMATION

=head2 Transactions

The transaction behavior is now controlled with the attribute AutoCommit. For
a complete definition of AutoCommit please refer to the DBI documentation.

According to the DBI specification the default for AutoCommit is TRUE. In this
mode, any change to the database becomes valid immediately. Any 'begin',
'commit' or 'rollback' statement will be rejected.

If AutoCommit is switched-off, immediately a transaction will be started by
issuing a 'begin' statement. Any 'commit' or 'rollback' will start a new
transaction. A disconnect will issue a 'rollback' statement.

=head2 Large Objects

The driver supports all large-objects related functions provided by libpq via
the func-interface. Please note, that starting with PostgreSQL 6.5 any access
to a large object - even read-only - has to be put into a transaction!

=head2 Cursors

Although PostgreSQL has a cursor concept, it has not been used in the current
implementation. Cursors in PostgreSQL can only be used inside a transaction
block. Because only one transaction block at a time is allowed, this would
have implied the restriction, not to use any nested SELECT statements. Hence
the execute method fetches all data at once into data structures located in
the frontend application. This has to be considered when selecting large
amounts of data!

=head2 Data-Type bool

The current implementation of PostgreSQL returns 't' for true and 'f' for
false. From the Perl point of view a rather unfortunate choice. The DBD::Pg
module translates the result for the data-type bool in a perl-ish like manner:
'f' -> '0' and 't' -> '1'. This way the application does not have to check the
database-specific returned values for the data-type bool, because Perl treats
'0' as false and '1' as true.

Boolean values can be passed to PostgreSQL as TRUE, 't', 'true', 'y', 'yes' or
'1' for true and FALSE, 'f', 'false', 'n', 'no' or '0' for false.

=head2 Schema support

PostgreSQL version 7.3 introduced schema support. Note that the PostgreSQL
schema concept may differ to that of other databases. Please refer to the
PostgreSQL documentation for more details.

Currently DBD::Pg does not provide explicit support for PostgreSQL schemas.
However, schema functionality may be used without any restrictions by
explicitly addressing schema objects, e.g.

  my $res = $dbh->selectall_arrayref("SELECT * FROM my_schema.my_table");

or by manipulating the schema search path with SET search_path, e.g.

  $dbh->do("SET search_path TO my_schema, public");

B<NOTE:> If you create an object with the same name as a PostgreSQL system
object (as contained in the pg_catalog schema) and explicitly set the search
path so that pg_catalog comes after the new object's schema, some DBD::Pg
methods (particularly those querying PostgreSQL system objects) may fail.
This problem should be fixed in a future release of DBD::Pg. Creating objects
with the same name as system objects (or beginning with 'pg_') is not
recommended practice and should be avoided in any case.

=head1 SEE ALSO

L<DBI>

=head1 AUTHORS

DBI and DBD-Oracle by Tim Bunce (Tim.Bunce@ig.co.uk)

DBD-Pg by Edmund Mergl (E.Mergl@bawue.de) and Jeffrey W. Baker
(jwbaker@acm.org). By David Wheeler <david@wheeler.net>, Jason
Stewart <jason@openinformatics.com> and Bruce Momjian
<pgman@candle.pha.pa.us> after v1.13.

Major parts of this package have been copied from DBI and DBD-Oracle.

=head1 COPYRIGHT

The DBD::Pg module is free software. You may distribute under the terms of
either the GNU General Public License or the Artistic License, as specified in
the Perl README file.

=head1 ACKNOWLEDGMENTS

See also B<DBI/ACKNOWLEDGMENTS>.

=cut

