#!/usr/local/bin/perl -Tw
#
# ivan@voicenet.com 97-jul-1
# 
# added hfields
# ivan@sisd.com 97-nov-13

package FS::table_name;

use strict;
use Exporter;
#use FS::UID qw(getotaker);
use FS::Record qw(hfields qsearch qsearchs);

@FS::table_name::ISA = qw(FS::Record Exporter);
@FS::table_name::EXPORT_OK = qw(hfields);

# Usage: $record = create FS::table_name ( \%hash );
#        $record = create FS::table_name ( { field=>value, ... } );
sub create {
  my($proto,$hashref)=@_;

  my($field);
  foreach $field (fields('table_name')) {
    $hashref->{$field}='' unless defined $hashref->{$field};
  }

  $proto->new('table_name',$hashref);

}

# Usage: $error = $record -> insert;
sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

# Usage: $error = $record -> delete;
sub delete {
  my($self)=@_;

  $self->del;
}

# Usage: $error = $newrecord -> replace($oldrecord)
sub replace {
  my($new,$old)=@_;
  return "(Old) Not a table_name record!" unless $old->table eq "table_name";

  $new->check or
  $new->rep($old);
}

# Usage: $error = $record -> check;
sub check {
  my($self)=@_;
  return "Not a table_name record!" unless $self->table eq "table_name";
  my($recref) = $self->hashref;

  ''; #no error
}

1;

