######################################################################
# SQL-Ledger Accounting
# Copyright (c) 2004
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
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

$menufile = "menu.ini";
use SL::Menu;


1;
# end of main


sub display {

  $menuwidth = ($myconfig{menuwidth}) ? $myconfig{menuwidth} : ($ENV{HTTP_USER_AGENT} =~ /links/i) ? "240" : "155";

  $form->header(1);

  print qq|

<FRAMESET COLS="$menuwidth,*" BORDER="1">

  <FRAME NAME="acc_menu" SRC="$form->{script}?login=$form->{login}&sessionid=$form->{sessionid}&action=acc_menu&path=$form->{path}">
  <FRAME NAME="main_window" SRC="am.pl?login=$form->{login}&sessionid=$form->{sessionid}&action=company_logo&path=$form->{path}">

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
<script type="text/javascript">
function SwitchMenu(obj) {
	if (document.getElementById) {
	var el = document.getElementById(obj);
	var ar = document.getElementById("cont").getElementsByTagName("DIV");

		if (el.style.display == "none") {
			el.style.display = "block"; //display the block of info
		} else {
			el.style.display = "none";
		}

	}
}
function ChangeClass(menu, newClass) {
	 if (document.getElementById) {
	 	document.getElementById(menu).className = newClass;
	 }
}
document.onselectstart = new Function("return false");
</script>

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

 print qq|
	<div id="cont">
	|;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);
  
  while (@menuorder){
    $i++;
    $item = shift @menuorder;
    $label = $item;
    $label =~ s/.*--//g;
    $label = $locale->text($label);

    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};

    if ($menu->{$item}{submenu}) {
      
	$display = "display: none;" unless $level eq ' ';

	print qq|
<div id="menu$i" class="menuOut" onclick="SwitchMenu('sub$i')" onmouseover="ChangeClass('menu$i','menuOver')" onmouseout="ChangeClass('menu$i','menuOut')">$label</div>
	<div class="submenu" id="sub$i" style="$display">|;
	
	# remove same level items
	map { shift @menuorder } grep /^$item/, @menuorder;

	&section_menu($menu, $item);
	
	print qq|

		</div>
		|;

    } else {

      if ($menu->{$item}{module}) {
	if ($level eq "") {
	  print qq|<div id="menu$i" class="menuOut" onmouseover="ChangeClass('menu$i','menuOver')" onmouseout="ChangeClass('menu$i','menuOut')"> |. 
	  $menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a></div>|;

	  # remove same level items
	  map { shift @menuorder } grep /^$item/, @menuorder;

          &section_menu($menu, $item);

	} else {
	
	  print qq|<div class="submenu"> |.
          $menu->menuitem(\%myconfig, \%$form, $item, $level).qq|$label</a></div>|;
	}

      } else {

	$display = "display: none;" unless $item eq ' ';

	print qq|
<div id="menu$i" class="menuOut" onclick="SwitchMenu('sub$i')" onmouseover="ChangeClass('menu$i','menuOver')" onmouseout="ChangeClass('menu$i','menuOut')">$label</div>
	<div class="submenu" id="sub$i" style="$display">|;
	
	&section_menu($menu, $item);
	
	print qq|

		</div>
		|;

      }

    }

  }

  print qq|
	</div>
	|;
}


sub menubar {

  1;

}


