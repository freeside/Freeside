package FS::access_right;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::access_right - Object methods for access_right records

=head1 SYNOPSIS

  use FS::access_right;

  $record = new FS::access_right \%hash;
  $record = new FS::access_right { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_right object represents a granted access right.  FS::access_right
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item rightnum - primary key

=item righttype - 

=item rightobjnum - 

=item rightname - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new right.  To add the right to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'access_right'; }

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

Checks all fields to make sure this is a valid right.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('rightnum')
    || $self->ut_text('righttype')
    || $self->ut_text('rightobjnum')
    || $self->ut_text('rightname')
  ;
  return $error if $error;

  $self->SUPER::check;
}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data { # class method
  my ($class, %opts) = @_;

  my @unmigrated = ( qsearch( 'access_right',
                              { 'righttype'=>'FS::access_group',
                                'rightname'=>'Engineering configuration',
                              }
                            ), 
                     qsearch( 'access_right',
                              { 'righttype'=>'FS::access_group',
                                'rightname'=>'Engineering global configuration',
                              }
                            )
                   ); 
  foreach ( @unmigrated ) {
    my $rightname = $_->rightname;
    $rightname =~ s/Engineering/Dialup/;
    $_->rightname($rightname);
    my $error = $_->replace;
    die "Failed to update access right: $error"
      if $error;
    my $broadband = new FS::access_right { $_->hash };
    $rightname =~ s/Dialup/Broadband/;
    $broadband->rightnum('');
    $broadband->rightname($rightname);
    $error = $broadband->insert;
    die "Failed to insert access right: $error"
      if $error;
  }

  my %migrate = (
    'Post payment'    => [ 'Post check payment', 'Post cash payment' ],
    'Process payment' => [ 'Process credit card payment', 'Process Echeck payment' ],
    'Post refund'     => [ 'Post check refund', 'Post cash refund' ],
    'Refund payment'  => [ 'Refund credit card payment', 'Refund Echeck payment' ],
  );

  foreach my $oldright (keys %migrate) {
    my @old = qsearch('access_right', { 'righttype'=>'FS::access_group',
                                        'rightname'=>$oldright,
                                      }
                     );

    foreach my $old ( @old ) {

      foreach my $newright ( @{ $migrate{$oldright} } ) {
        my %hash = (
          'righttype'   => 'FS::access_group',
          'rightobjnum' => $old->rightobjnum,
          'rightname'   => $newright,
        );
        next if qsearchs('access_right', \%hash);
        my $access_right = new FS::access_right \%hash;
        my $error = $access_right->insert;
        die $error if $error;
      }

      #after the WEST stuff is sorted, etc.
      #my $error = $old->delete;
      #die $error if $error;

    }

  }

  my @all_groups = qsearch('access_group', {});

  my %onetime = (
    'List customers' => 'List all customers',
    'List packages'  => 'Summarize packages',
  );

  foreach my $old_acl ( keys %onetime ) {
    my $new_acl = $onetime{$old_acl}; #support arrayref too?
    ( my $journal = 'ACL_'.lc($new_acl) ) =~ s/ /_/g;
    next if FS::upgrade_journal->is_done($journal);

    # grant $new_acl to all groups who have $old_acl
    for my $group (@all_groups) {
      if ( $group->access_right($old_acl) ) {
        my $access_right = FS::access_right->new( {
            'righttype'   => 'FS::access_group',
            'rightobjnum' => $group->groupnum,
            'rightname'   => $new_acl,
        } );
        my $error = $access_right->insert;
        die $error if $error;
      }
    }
    
    FS::upgrade_journal->set_done($journal);
  }

  ### ACL_download_report_data
  if ( !FS::upgrade_journal->is_done('ACL_download_report_data') ) {

    # grant to everyone
    for my $group (@all_groups) {
      my $access_right = FS::access_right->new( {
          'righttype'   => 'FS::access_group',
          'rightobjnum' => $group->groupnum,
          'rightname'   => 'Download report data',
      } );
      my $error = $access_right->insert;
      die $error if $error;
    }

    FS::upgrade_journal->set_done('ACL_download_report_data');
  }

  '';

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

