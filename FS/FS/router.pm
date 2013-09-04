package FS::router;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs qsearch dbh );
use FS::addr_block;

@ISA = qw( FS::Record FS::m2m_Common );

=head1 NAME

FS::router - Object methods for router records

=head1 SYNOPSIS

  use FS::router;

  $record = new FS::router \%hash;
  $record = new FS::router { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::router record describes a broadband router, such as a DSLAM or a wireless
 access point.  FS::router inherits from FS::Record.  The following 
fields are currently supported:

=over 4

=item routernum - primary key

=item routername - descriptive name for the router

=item svcnum - svcnum of the owning FS::svc_broadband, if appropriate

=item manual_addr - set to 'Y' to allow services linked to this router 
to have any IP address, rather than one in an address block belonging 
to the router.

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see "insert".

=cut

sub table { 'router'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If the pseudo-field 'blocknum' is set to an L<FS::addr_block> number, then 
that address block will be assigned to this router.  Currently only one
block can be assigned this way.

=cut

sub insert {
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $self = shift;
  my $error = $self->SUPER::insert(@_);
  return $error if $error;
  if ( $self->blocknum ) {
    my $block = FS::addr_block->by_key($self->blocknum);
    if ($block) {
      if ($block->routernum) {
        $error = "block ".$block->cidr." is already assigned to a router";
      } else {
        $block->set('routernum', $self->routernum);
        $block->set('manual_flag', 'Y');
        $error = $block->replace;
      }
    } else {
      $error = "blocknum ".$self->blocknum." not found";
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  $dbh->commit if $oldAutoCommit;
  return $error;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $self = shift;
  my $old = shift || $self->replace_old;
  my $error = $self->SUPER::replace($old, @_);
  return $error if $error;

  if ( defined($self->blocknum) ) {
    #warn "FS::router::replace: blocknum = ".$self->blocknum."\n";
    # then release any blocks we're already holding
    foreach my $block ($self->addr_block) {
      $block->set('routernum', 0);
      $block->set('manual_flag', '');
      $error ||= $block->replace;
    }
    if ( !$error and $self->blocknum > 0 ) {
      # and, if the new blocknum is a real blocknum, assign it
      my $block = FS::addr_block->by_key($self->blocknum);
      if ( $block ) {
        $block->set('routernum', $self->routernum);
        $block->set('manual_flag', '');
        $error ||= $block->replace;
      } else {
        $error = "blocknum ".$self->blocknum." not found";
      }
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  $dbh->commit if $oldAutoCommit;
  return $error;
}

=item check

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('routernum')
    || $self->ut_text('routername')
    || $self->ut_enum('manual_addr', [ '', 'Y' ])
    || $self->ut_agentnum_acl('agentnum', 'Broadband global configuration')
    || $self->ut_foreign_keyn('svcnum', 'cust_svc', 'svcnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item delete

Deallocate all address blocks from this router and delete it.

=cut

sub delete {
    my $self = shift;

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;
 
    my $error;
    foreach my $block ($self->addr_block) {
      $block->set('manual_flag', '');
      $block->set('routernum', 0);
      $error ||= $block->replace;
    }

    $error ||= $self->SUPER::delete;
    if ( $error ) {
       $dbh->rollback if $oldAutoCommit;
       return $error;
    }
  
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    '';
}

=item addr_block

Returns a list of FS::addr_block objects (address blocks) associated
with this object.

=item auto_addr_block

Returns a list of address blocks on which auto-assignment of IP addresses
is enabled.

=cut

sub addr_block {
  my $self = shift;
  return qsearch('addr_block', { routernum => $self->routernum });
}

sub auto_addr_block {
  my $self = shift;
  return () if $self->manual_addr;
  return qsearch('addr_block', { routernum => $self->routernum,
                                 manual_flag => '' });
}

=item part_svc_router

Returns a list of FS::part_svc_router objects associated with this 
object.  This is unlikely to be useful for any purpose other than retrieving 
the associated FS::part_svc objects.  See below.

=cut

sub part_svc_router {
  my $self = shift;
  return qsearch('part_svc_router', { routernum => $self->routernum });
}

=item part_svc

Returns a list of FS::part_svc objects associated with this object.

=cut

sub part_svc {
  my $self = shift;
  return map { qsearchs('part_svc', { svcpart => $_->svcpart }) }
      $self->part_svc_router;
}

=item agent

Returns the agent associated with this router, if any.

=cut

sub agent {
  qsearchs('agent', { 'agentnum' => shift->agentnum });
}

=item cust_svc

Returns the cust_svc associated with this router, if any.  This should be
the service that I<provides connectivity to the router>, not any service 
connected I<through> the router.

=cut

sub cust_svc {
  my $svcnum = shift->svcnum or return undef;
  FS::cust_svc->by_key($svcnum);
}

=back

=head1 SEE ALSO

FS::svc_broadband, FS::router, FS::addr_block, FS::part_svc,
schema.html from the base documentation.

=cut

1;

