package FS::UI::Gtk;

use strict;
use Gtk;
use FS::UID qw(adminsuidsetup);

die "Can't initialize Gtk interface; $FS::UI::Base::_lock used"
  if $FS::UI::Base::_lock;
$FS::UI::Base::_lock = "FS::UI::Gtk";

=head1 NAME

FS::UI::Gtk - Base class for Gtk user-interface objects

=head1 SYNOPSIS

  use FS::UI::Gtk;
  use FS::UI::some_table;

  $interface = new FS::UI::some_table;

  $error = $interface->browse;
  $error = $interface->search;
  $error = $interface->view;
  $error = $interface->edit;
  $error = $interface->process;

=head1 DESCRIPTION

An FS::UI::Gtk object represents a Gtk user interface object.

=head1 METHODS

=over 4

=item new

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { @_ };

  bless ( $self, $class );

  $self->{'_user'} = 'ivan'; #Pop up login window?
  $self->{'_dbh'} = FS::UID::adminsuidsetup $self->{'_user'};



  $self;
}

sub activate {
  my $self = shift;

  my $vbox = new Gtk::VBox ( 0, 4 );

  foreach my $widget ( @{ $self->{'Widgets'} } ) {
    $widget->_gtk->show;
    $vbox->pack_start ( $widget->_gtk, 1, 1, 4 );
  }
  $vbox->show;

  my $window = new Gtk::Window "toplevel";
  $self->{'_gtk'} = $window;
  $window->set_title( $self->title );
  $window->add ( $vbox );
  $window->show;
  main Gtk;
}

=item interface

Returns the string `Gtk'.  Useful for the author of a table-specific UI class
to conditionally specify certain behaviour.

=cut 

sub interface { 'Gtk'; }

=back

=cut

package FS::UI::_Widget;

use vars qw( $AUTOLOAD );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { @_ };
  bless ( $self, $class );
}

sub _gtk {
  my $self = shift;
  $self->{'_gtk'};
}

sub AUTOLOAD {
  my $self = shift;
  my $value = shift;
  my($field)=$AUTOLOAD;
  $field =~ s/.*://;
  if ( defined($value) ) {
    $self->{$field} = $value;
  } else {
    $self->{$field};
  }    
}

package FS::UI::_Text;

use vars qw ( @ISA );

@ISA = qw ( FS::UI::_Widget );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{'_gtk'} = new Gtk::Label ( shift );
  bless ( $self, $class );
}

package FS::UI::_Link;

use vars qw ( @ISA );

@ISA = qw ( FS::UI::_Widget );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { @_ };
  $self->{'_gtk'} = new_with_label Gtk::Button ( $self->{'text'} );
  $self->{'_gtk'}->signal_connect( 'clicked', sub {
      print "STUB: (Gtk) FS::UI::_Link";
    }, "hi", "there" );
  bless ( $self, $class );
}


package FS::UI::_Table;

use vars qw ( @ISA );

@ISA = qw ( FS::UI::_Widget );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { @_ };
  bless ( $self, $class );

  $self->{'_gtk'} = new Gtk::Table (
    $self->rows,
    $self->columns,
    0, #homogeneous
  );

  $self;
}

sub attach {
  my $self = shift;
  my ( $row, $column, $widget, $rowspan, $colspan ) = @_;
  $rowspan ||= 1;
  $colspan ||= 1;
  $self->_gtk->attach_defaults(
    $widget->_gtk,
    $column,
    $column + $colspan,
    $row,
    $row + $rowspan,
  );
  $widget->_gtk->show;
}

package FS::UI::_Tableborder;

use vars qw ( @ISA );

@ISA = qw ( FS::UI::_Table );

=head1 VERSION

$Id: Gtk.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

This documentation is incomplete.

_Tableborder is just a _Table now.  _Tableborders should scroll (but not the
headers) and need and need more decoration. (data in white section ala gtksql
and sliding field widths) headers should be buttons that callback to sort on
their fields.

There should be a persistant, per-(freeside)-user store for window positions
and sizes and sort fields etc (see L<FS::UI::CGI/BUGS>.

Still some small bits of widget code same as FS::UI::CGI.

=head1 SEE ALSO

L<FS::UI::Base>

=head1 HISTORY

$Log: Gtk.pm,v $
Revision 1.1  1999-08-04 09:03:53  ivan
initial checkin of module files for proper perl installation

Revision 1.1  1999/01/20 09:30:36  ivan
skeletal cross-UI UI code.


=cut

1;

