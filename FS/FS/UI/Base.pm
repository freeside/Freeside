package FS::UI::Base;

use strict;
use vars qw ( @ISA );
use FS::Record qw( fields qsearch );

@ISA = ( $FS::UI::Base::_lock );

=head1 NAME

FS::UI::Base - Base class for all user-interface objects

=head1 SYNOPSIS

  use FS::UI::SomeInterface;
  use FS::UI::some_table;

  $interface = new FS::UI::some_table;

  $error = $interface->browse;
  $error = $interface->search;
  $error = $interface->view;
  $error = $interface->edit;
  $error = $interface->process;

=head1 DESCRIPTION

An FS::UI::Base object represents a user interface object.  FS::UI::Base
is intended as a base class for table-specfic classes to inherit from, i.e.
FS::UI::cust_main.  The simplest case, which will provide a default UI for your
new table, is as follows:

  package FS::UI::table_name;
  use vars qw ( @ISA );
  use FS::UI::Base;
  @ISA = qw( FS::UI::Base );
  sub db_table { 'table_name'; }

Currently available interfaces are:
  FS::UI::Gtk, an X-Windows UI implemented using the Gtk+ toolkit
  FS::UI::CGI, a web interface implemented using CGI.pm, etc.

=head1 METHODS

=over 4

=item new

=cut

=item browse

=cut

sub browse {
  my $self = shift;

  my @fields = $self->list_fields;

  #begin browse-specific stuff

  $self->title( "Browse ". $self->db_names ) unless $self->title;
  my @records = qsearch ( $self->db_table, {} );

  #end browse-specific stuff

  $self->addwidget ( new FS::UI::_Text ( $self->db_description ) );

  my @header = $self->list_header;
  my @headerspan = $self->list_headerspan;
  my %callback = $self->db_callback;

  my $columns;

  my $table = new FS::UI::_Tableborder (
    'rows' => 1 + scalar(@records),
    'columns' => $columns || scalar(@fields),
  );

  my $c = 0;
  foreach my $header ( @header ) {
    my $headerspan = shift(@headerspan) || 1;
    $table->attach(
      0, $c, new FS::UI::_Text ( $header ), 1, $headerspan
    );
    $c += $headerspan;
  }

  my $r = 1;
  
  foreach my $record ( @records ) {
    $c = 0;
    foreach my $field ( @fields ) {
      my $value = $record->getfield($field);
      my $widget;
      if ( $callback{$field} ) {
        $widget = &{ $callback{$field} }( $value, $record );
      } else {
        $widget = new FS::UI::_Text ( $value );
      }
      $table->attach( $r, $c++, $widget, 1, 1 );
    }
    $r++;
  }

  $self->addwidget( $table );

  $self->activate;

}

=item title

=cut

sub title {
  my $self = shift;
  my $value = shift;
  if ( defined($value) ) {
    $self->{'title'} = $value;
  } else {
    $self->{'title'};
  }
}

=item addwidget

=cut

sub addwidget {
  my $self = shift;
  my $widget = shift;
  push @{ $self->{'Widgets'} }, $widget;
}

#fallback methods

sub db_description {}

sub db_name {}

sub db_names {
  my $self = shift;
  $self->db_name. 's';
}

sub list_fields {
  my $self = shift;
  fields( $self->db_table );
}

sub list_header {
  my $self = shift;
  $self->list_fields
}

sub list_headerspan {
  my $self = shift;
  map 1, $self->list_header;
}

sub db_callback {}

=back

=head1 VERSION

$Id: Base.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

This documentation is incomplete.

There should be some sort of per-(freeside)-user preferences and the ability
for specific FS::UI:: modules to put their own values there as well.

=head1 SEE ALSO

L<FS::UI::Gtk>, L<FS::UI::CGI>

=head1 HISTORY

$Log: Base.pm,v $
Revision 1.1  1999-08-04 09:03:53  ivan
initial checkin of module files for proper perl installation

Revision 1.1  1999/01/20 09:30:36  ivan
skeletal cross-UI UI code.


=cut

1;

