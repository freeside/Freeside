######################################################################
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Christopher Browne
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#######################################################################
#
# two frame layout with refractured menu
#
# CHANGE LOG:
#   DS. 2002-03-25  Created
#######################################################################

$menufile = "menu.ini";
use SL::Menu;


1;
# end of main


sub display {

  $framesize = ($ENV{HTTP_USER_AGENT} =~ /links/i) ? "240" : "135";

  $form->header;

  print qq|

<FRAMESET COLS="$framesize,*" BORDER="1">

  <FRAME NAME="acc_menu" SRC="$form->{script}?login=$form->{login}&password=$form->{password}&action=acc_menu&path=$form->{path}">
  <FRAME NAME="main_window" SRC="login.pl?login=$form->{login}&password=$form->{password}&action=company_logo&path=$form->{path}">

</FRAMESET>

</BODY>
</HTML>
|;

}



sub acc_menu {

  my $menu = new Menu "$menufile";
  $menu = new Menu "custom_$menufile" if (-f "custom_$menufile");
  $menu = new Menu "$form->{login}_$menufile" if (-f "$form->{login}_$menufile");
  
  $form->{title} = $locale->text('Accounting Menu');
  
  $form->header;

  print qq|
<body class=menu>

|;

  &section_menu($menu);

  print qq|
</body>
</html>
|;

}


sub section_menu {
  my ($menu, $level) = @_;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);

  while (@menuorder) {
    $item = shift @menuorder;
    $label = $item;
    $label =~ s/$level--//g;

    my $spacer = "&nbsp;" x (($item =~ s/--/--/g) * 2);

    $label =~ s/.*--//g;
    $label = $locale->text($label);
    $label =~ s/ /&nbsp;/g;

    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};
    
    if ($menu->{$item}{submenu}) {
      $menu->{$item}{$item} = !$form->{$item};

      if ($form->{level} && $item =~ /^$form->{level}/) {

        # expand menu
	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a>|;

	# remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;
	
	&section_menu($menu, $item);

	print qq|<br>\n|;

      } else {
	
	print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label&nbsp;...</a>|;

        # remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;

      }

      
    } else {
    
      if ($menu->{$item}{module}) {
	if ($form->{$item} && $form->{level} eq $item) {
	  $menu->{$item}{$item} = !$form->{$item};
	  print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a>|;
	  
	  # remove same level items
	  map { shift @menuorder } grep /^$item/, @menuorder;
	  
	  &section_menu($menu, $item);

	} else {
	  print qq|<br>\n$spacer|.$menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a>|;
	}
	
      } else {
	
	print qq|<br><b>$label</b>|;
	
	&section_menu($menu, $item);

	print qq|<br>\n|;
	
      }
    }
  }
}


