#!/usr/local/bin/perl -Tw
#
# ivan@voicenet.com 97-jul-21

package FS::svc_table;

use strict;
use Exporter;
use FS::Record qw(fields qsearchs);

@FS::svc_table::ISA = qw(FS::Record Exporter);

# Usage: $record = create FS::svc_table ( \%hash );
#        $record = create FS::svc_table ( { field=>value, ... } );
sub create {
  my($proto,$hashref)=@_;

  my($field);
  foreach $field (fields('svc_table')) {
    $hashref->{$field}='' unless defined $hashref->{$field};
  }

  $proto->new('svc_table',$hashref);

}

# Usage: $error = $record -> insert;
sub insert {
  my($self)=@_;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error=$self->check;
  return $error if $error;

  $error = $self->add;
  return $error if $error;

  ''; #no error
}

# Usage: $error = $record -> delete;
sub delete {
  my($self)=@_;
  my($error);

  $error = $self->del;
  return $error if $error;

}

# Usage: $error = $newrecord -> replace($oldrecord)
sub replace {
  my($new,$old)=@_;
  my($error);

  return "(Old) Not a svc_table record!" unless $old->table eq "svc_table";
  return "Can't change svcnum!"
    unless $old->getfield('svcnum') eq $new->getfield('svcnum');

  $error=$new->check;
  return $error if $error;

  $error = $new->rep($old);
  return $error if $error;

  ''; #no error
}

# Usage: $error = $record -> suspend;
sub suspend {
  ''; #no error (stub)
}

# Usage: $error = $record -> unsuspend;
sub unsuspend {
  ''; #no error (stub)
}

# Usage: $error = $record -> cancel;
sub cancel {
  ''; #no error (stub)
}

# Usage: $error = $record -> check;
sub check {
  my($self)=@_;
  return "Not a svc_table record!" unless $self->table eq "svc_table";
  my($recref) = $self->hashref;

  $recref->{svcnum} =~ /^(\d+)$/ or return "Illegal svcnum";
  $recref->{svcnum} = $1;
  return "Unknown svcnum" unless
    qsearchs('cust_svc',{'svcnum'=> $recref->{svcnum} } );

  #DATA CHECKS GO HERE!

  ''; #no error
}

1;

