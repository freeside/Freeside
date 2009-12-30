package FS::cust_bill_pkg_detail;

use strict;
use vars qw( @ISA $me $DEBUG %GetInfoType );
use HTML::Entities;
use FS::Record qw( qsearch qsearchs dbdef dbh );
use FS::cust_bill_pkg;
use FS::usage_class;
use FS::Conf;

@ISA = qw(FS::Record);
$me = '[ FS::cust_bill_pkg_detail ]';
$DEBUG = 0;

=head1 NAME

FS::cust_bill_pkg_detail - Object methods for cust_bill_pkg_detail records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_detail;

  $record = new FS::cust_bill_pkg_detail \%hash;
  $record = new FS::cust_bill_pkg_detail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_detail object represents additional detail information for
an invoice line item (see L<FS::cust_bill_pkg>).  FS::cust_bill_pkg_detail
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item detailnum - primary key

=item billpkgnum - link to cust_bill_pkg

=item amount - price of this line item detail

=item format - '' for straight text and 'C' for CSV in detail

=item classnum - link to usage_class

=item duration - granularized number of seconds for this call

=item regionname -

=item phonenum -

=item detail - detail description

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new line item detail.  To add the line item detail to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_bill_pkg_detail'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid line item detail.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $conf = new FS::Conf;

  my $phonenum = $self->phonenum;
  my $phonenum_check_method;
  if ( $conf->exists('svc_phone-allow_alpha_phonenum') ) {
    $phonenum =~ s/\W//g;
    $phonenum_check_method = 'ut_alphan';
  } else {
    $phonenum =~ s/\D//g;
    $phonenum_check_method = 'ut_numbern';
  }
  $self->phonenum($phonenum);

  $self->ut_numbern('detailnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum')
    #|| $self->ut_moneyn('amount')
    || $self->ut_floatn('amount')
    || $self->ut_enum('format', [ '', 'C' ] )
    || $self->ut_numbern('duration')
    || $self->ut_textn('regionname')
    || $self->ut_text('detail')
    || $self->ut_foreign_keyn('classnum', 'usage_class', 'classnum')
    || $self->$phonenum_check_method('phonenum')
    || $self->SUPER::check
    ;

}

=item formatted [ OPTION => VALUE ... ]

Returns detail information for the invoice line item detail formatted for
display.

Currently available options are: I<format> I<escape_function>

If I<format> is set to html or latex then the format is improved
for tabular appearance in those environments if possible.

If I<escape_function> is set then the format is processed by this
function before being returned.

If I<format_function> is set then the detail is handed to this callback
for processing.

=cut

sub formatted {
  my ( $self, %opt ) = @_;
  my $format = $opt{format} || '';
  return () unless defined dbdef->table('cust_bill_pkg_detail');

  eval "use Text::CSV_XS;";
  die $@ if $@;
  my $csv = new Text::CSV_XS;

  my $escape_function = sub { shift };

  $escape_function = \&encode_entities
    if $format eq 'html';

  $escape_function =
    sub {
      my $value = shift;
      $value =~ s/([#\$%&~_\^{}])( )?/"\\$1". ( ( defined($2) && length($2) ) ? "\\$2" : '' )/ge;
      $value =~ s/([<>])/\$$1\$/g;
      $value;
    }
  if $format eq 'latex';

  $escape_function = $opt{escape_function} if $opt{escape_function};

  my $format_sub = sub { my $detail = shift;
                         $csv->parse($detail) or return "can't parse $detail";
                         join(' - ', map { &$escape_function($_) }
                                     $csv->fields
                             );
                       };

  $format_sub = sub { my $detail = shift;
                      $csv->parse($detail) or return "can't parse $detail";
                      join('</TD><TD>', map { &$escape_function($_) }
                                        $csv->fields
                          );
                    }
    if $format eq 'html';

  $format_sub = sub { my $detail = shift;
                      $csv->parse($detail) or return "can't parse $detail";
                      #join(' & ', map { '\small{'. &$escape_function($_). '}' }                      #            $csv->fields );
                      my $result = '';
                      my $column = 1;
                      foreach ($csv->fields) {
                        $result .= ' & ' if $column > 1;
                        if ($column > 6) {                     # KLUDGE ALERT!
                          $result .= '\multicolumn{1}{l}{\scriptsize{'.
                                     &$escape_function($_). '}}';
                        }else{
                          $result .= '\scriptsize{'.  &$escape_function($_). '}';
                        }
                        $column++;
                      }
                      $result;
                    }
    if $format eq 'latex';

  $format_sub = $opt{format_function} if $opt{format_function};

  $self->format eq 'C'
    ? &{$format_sub}( $self->detail, $self )
    : &{$escape_function}( $self->detail )
  ;
}


# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data { # class method

  my ($class, %opts) = @_;

  warn "$me upgrading $class\n" if $DEBUG;

  my $columndef = dbdef->table($class->table)->column('classnum');
  unless ($columndef->type eq 'int4') {

    my $dbh = dbh;
    if ( $dbh->{Driver}->{Name} eq 'Pg' ) {

      eval "use DBI::Const::GetInfoType;";
      die $@ if $@;

      my $major_version = 0;
      $dbh->get_info( $GetInfoType{SQL_DBMS_VER} ) =~ /^(\d{2})/
        && ( $major_version = sprintf("%d", $1) );

      if ( $major_version > 7 ) {

        # ideally this would be supported in DBIx-DBSchema and friends

        foreach my $table ( qw( cust_bill_pkg_detail h_cust_bill_pkg_detail ) ){

          warn "updating $table column classnum to integer\n" if $DEBUG;
          my $sql = "ALTER TABLE $table ALTER classnum TYPE int USING ".
            "int4(classnum)";
          my $sth = $dbh->prepare($sql) or die $dbh->errstr;
          $sth->execute or die $sth->errstr;

        }

      } elsif ( $dbh->{pg_server_version} =~ /^704/ ) {  # earlier?

        # ideally this would be supported in DBIx-DBSchema and friends

        #  XXX_FIXME better locking

        foreach my $table ( qw( cust_bill_pkg_detail h_cust_bill_pkg_detail ) ){

          warn "updating $table column classnum to integer\n" if $DEBUG;

          my $sql = "ALTER TABLE $table RENAME classnum TO old_classnum";
          my $sth = $dbh->prepare($sql) or die $dbh->errstr;
          $sth->execute or die $sth->errstr;

          my $def = dbdef->table($table)->column('classnum');
          $def->type('integer');
          $def->length(''); 
          $sql = "ALTER TABLE $table ADD COLUMN ". $def->line($dbh);
          $sth = $dbh->prepare($sql) or die $dbh->errstr;
          $sth->execute or die $sth->errstr;

          $sql = "UPDATE $table SET classnum = int4( text( old_classnum ) )";
          $sth = $dbh->prepare($sql) or die $dbh->errstr;
          $sth->execute or die $sth->errstr;

          $sql = "ALTER TABLE $table DROP old_classnum";
          $sth = $dbh->prepare($sql) or die $dbh->errstr;
          $sth->execute or die $sth->errstr;

        }

      } else {

        die "cust_bill_pkg_detail classnum upgrade unsupported for this Pg version\n";

      }

    } else {

      die "cust_bill_pkg_detail classnum upgrade only supported for Pg 8+\n";

    }

  }


  if ( defined( dbdef->table($class->table)->column('billpkgnum') ) &&
       defined( dbdef->table($class->table)->column('invnum') ) &&
       defined( dbdef->table($class->table)->column('pkgnum') ) 
  ) {

    warn "$me Checking for unmigrated invoice line item details\n" if $DEBUG;

    my @cbpd = qsearch({ 'table'   => $class->table,
                         'hashref' => {},
                         'extra_sql' => 'WHERE invnum IS NOT NULL AND '.
                                        'pkgnum IS NOT NULL',
                      });

    if (scalar(@cbpd)) {
      warn "$me Found unmigrated invoice line item details\n" if $DEBUG;

      foreach my $cbpd ( @cbpd ) {
        my $detailnum = $cbpd->detailnum;
        warn "$me Contemplating detail $detailnum\n" if $DEBUG > 1;
        my $cust_bill_pkg =
          qsearchs({ 'table' => 'cust_bill_pkg',
                     'hashref' => { 'invnum' => $cbpd->invnum,
                                    'pkgnum' => $cbpd->pkgnum,
                                  },
                     'order_by' => 'ORDER BY billpkgnum LIMIT 1',
                  });
        if ($cust_bill_pkg) {
          $cbpd->billpkgnum($cust_bill_pkg->billpkgnum);
          $cbpd->invnum('');
          $cbpd->pkgnum('');
          my $error = $cbpd->replace;

          warn "*** WARNING: error replacing line item detail ".
               "(cust_bill_pkg_detail) $detailnum: $error ***\n"
            if $error;
        } else {
          warn "Found orphaned line item detail $detailnum during upgrade.\n";
        }

      } # foreach $cbpd

    } # if @cbpd

  } # if billpkgnum, invnum, and pkgnum columns defined

  '';

}                         

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_bill_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

