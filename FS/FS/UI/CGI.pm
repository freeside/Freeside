package FS::UI::CGI;

use strict;
use CGI;
#use CGI::Switch;  #when FS::UID user and preference callback stuff is fixed
use CGI::Carp qw(fatalsToBrowser);
use HTML::Table;
use FS::UID qw(adminsuidsetup);
#use FS::Record qw( qsearch fields );

die "Can't initialize CGI interface; $FS::UI::Base::_lock used"
  if $FS::UI::Base::_lock;
$FS::UI::Base::_lock = "FS::UI::CGI";

=head1 NAME

FS::UI::CGI - Base class for CGI user-interface objects

=head1 SYNOPSIS

  use FS::UI::CGI;
  use FS::UI::some_table;

  $interface = new FS::UI::some_table;

  $error = $interface->browse;
  $error = $interface->search;
  $error = $interface->view;
  $error = $interface->edit;
  $error = $interface->process;

=head1 DESCRIPTION

An FS::UI::CGI object represents a CGI interface object.

=head1 METHODS

=over 4

=item new

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { @_ };

  $self->{'_cgi'} = new CGI;
  $self->{'_user'} = $self->{'_cgi'}->remote_user;
  $self->{'_dbh'} = FS::UID::adminsuidsetup $self->{'_user'};

  bless ( $self, $class);
}

sub activate {
  my $self = shift;
  print $self->_header,
        join ( "<BR>", map $_->sprint, @{ $self->{'Widgets'} } ),
        $self->_footer,
  ;
}

=item _header

=cut

sub _header {
  my $self = shift;
  my $cgi = $self->{'_cgi'};

  $cgi->header( '-expires' => 'now' ), '<HTML>', 
    '<HEAD><TITLE>', $self->title, '</TITLE></HEAD>',
    '<BODY BGCOLOR="#ffffff">',
    '<FONT COLOR="#ff0000" SIZE=7>', $self->title, '</FONT><BR><BR>',
  ;
}

=item _footer

=cut

sub _footer {
  "</BODY></HTML>";
}

=item interface

Returns the string `CGI'.  Useful for the author of a table-specific UI class
to conditionally specify certain behaviour.

=cut

sub interface { 'CGI'; }

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

@ISA = qw ( FS::UI::_Widget);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self->{'_text'} = shift;
  bless ( $self, $class );
}

sub sprint {
  my $self = shift;
  $self->{'_text'};
}

package FS::UI::_Link;

use vars qw ( @ISA $BASE_URL );

@ISA = qw ( FS::UI::_Widget);
$BASE_URL = "http://rootwood.sisd.com/freeside";

sub sprint {
  my $self = shift;
  my $table = $self->{'table'};
  my $method = $self->{'method'};

  # i will be cleaned up when we're done moving from the old webinterface!
  my @arg = @{$self->{'arg'}};
  my $yuck = join( "&", @arg);
  qq(<A HREF="$BASE_URL/$method/$table.cgi?$yuck">). $self->{'text'}. "<\A>";
}

package FS::UI::_Table;

use vars qw ( @ISA );

@ISA = qw ( FS::UI::_Widget);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class eq $proto ? { @_ } : $proto;
  bless ( $self, $class );
  $self->{'_table'} = new HTML::Table ( $self->rows, $self->columns );
  $self;
}

sub attach {
  my $self = shift;
  my ( $row, $column, $widget, $rowspan, $colspan ) = @_;
  $self->{"_table"}->setCell( $row+1, $column+1, $widget->sprint );
  $self->{"_table"}->setCellRowSpan( $row+1, $column+1, $rowspan ) if $rowspan;
  $self->{"_table"}->setCellColSpan( $row+1, $column+1, $colspan ) if $colspan;
}

sub sprint {
  my $self = shift;
  $self->{'_table'}->getTable;
}

package FS::UI::_Tableborder;

use vars qw ( @ISA );

@ISA = qw ( FS::UI::_Table );

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class eq $proto ? { @_ } : $proto;
  bless ( $self, $class );
  $self->SUPER::new(@_);
  $self->{'_table'}->setBorder;
  $self;
}

=head1 VERSION

$Id: CGI.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

This documentation is incomplete.

In _Tableborder, headers should be links that sort on their fields.

_Link uses a constant $BASE_URL

_Link passes the arguments as a manually-constructed GET string instead
of POSTing, for compatability while the web interface is upgraded.  Once
this is done it should pass arguements properly (i.e. as a POST, 8-bit clean)

Still some small bits of widget code same as FS::UI::Gtk.

=head1 SEE ALSO

L<FS::UI::Base>

=head1 HISTORY

$Log: CGI.pm,v $
Revision 1.1  1999-08-04 09:03:53  ivan
initial checkin of module files for proper perl installation

Revision 1.1  1999/01/20 09:30:36  ivan
skeletal cross-UI UI code.


=cut

1;

