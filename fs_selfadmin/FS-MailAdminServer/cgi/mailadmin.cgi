#!/usr/bin/perl
########################################################################
#                                                                      #
#    mailadmin.cgi                NCI2000                              #
#                                 Jeff Finucane <jeff@nci2000.net>     #
#                                 26 April 2001                        #
#                                                                      #
########################################################################

use DBI;
use strict;
use CGI;
use FS::MailAdminClient qw(authenticate list_packages list_mailboxes delete_mailbox password_mailbox add_mailbox list_forwards list_pkg_forwards delete_forward add_forward);

my $sessionfile = '/usr/local/apache/htdocs/mailadmin/adminsess';   # session file
my $tmpdir = '/usr/local/apache/htdocs/mailadmin/tmp';		# Location to store temp files
my $cookiedomain = ".your.dom";      # domain if THIS server, should prepend with a '.'
my $cookieexpire = '+12h';              # expire the cookie session after this much idle time
my $sessexpire = 43200;                 # expire session after this long of no use (in seconds)

my $body = "<body bgcolor=dddddd>";

#### Should not have to change anything under this line ####
my $printmainpage = 1;
my $i = 0;
my $printheader = 1;
my $query = new CGI;
my $cgi = $query->url();
my $now = getdatetime();
my $current_package = 0;
my $current_account = 0;
my $current_domname = "";

# if they are trying to login we wont check the session yet
if ($query->param('login') eq '' && $query->param('action') ne 'login') {
  checksession();
  printheader();
}

if ($query->param('login') ne '') {

   my $username = $query->param('username');
   my $password = $query->param('password');

   if (!checkuserpass($username, $password)) {
      printheader();
      error('not_admin');
   }

   my @alpha = ('A'..'Z', 'a'..'z', 0..9);
   my $sessid = '';
   for (my $i = 0; $i < 10; $i++) {
       $sessid .= @alpha[rand(@alpha)];
   }

   my $cookie1 = $query->cookie(-name=>'username',
				-value=>$username,
				-expires=>$cookieexpire,
				-domain=>$cookiedomain);

   my $cookie2 = $query->cookie(-name=>'ma_sessionid',
				-value=>$sessid,
				-expires=>$cookieexpire,
				-domain=>$cookiedomain);

   my $now = time();
   open(NEWSESS, ">>$sessionfile") || error('open');
   print NEWSESS "$username $sessid $now 0 0\n";
   close(NEWSESS);

   print $query->header(-COOKIE=>[$cookie1, $cookie2]);
 
   $printmainpage = 1;

} elsif ($query->param('action') eq 'blankframe') {
   
  print "<html>$body</body></html>\n";
   $printmainpage = 0;

} elsif ($query->param('action') eq 'list_packages') {

  my $username = $query->cookie(-name=>'username');  # session checked
  my $list = list_packages($username);
  print "<html>$body\n";
  print "<center><table border=0>\n";
  print "<tr><td></td><td><p>Package Number</td><td><p>Description</td></tr>\n";
  foreach my $package ( @{$list} ) {
    print "<tr>";
    print "<td></td><td><p>$package->{'pkgnum'}</td><td><p>$package->{'domain'}</td>\n";
    print "<td></td><td><a href=\"$cgi\?action=select&package=$package->{'pkgnum'}&account=$package->{'account'}&domname=$package->{'domain'}\" target=\"rightmainframe\">select</td>\n";
    print "</tr>";
  }
  print "</table>\n";
  print "</body></html>\n";
  $printmainpage=0;

} elsif ($query->param('action') eq 'list_mailboxes') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username)  unless $current_package;
  my $list = list_mailboxes($username, $current_package);
  my $forwardlist = list_pkg_forwards($username, $current_package);
  print "<html>$body\n";
  print "<center><table border=0>\n";
  print "<tr><td></td><td><p>Username</td><td><p>Password</td></tr>\n";
  foreach my $account ( @{$list} ) {
    print "<tr>";
    print "<td></td><td><p>$account->{'username'}</td><td><p>$account->{'_password'}</td>\n";
    print "<td></td><td><a href=\"$cgi\?action=change&account=$account->{'svcnum'}&mailbox=$account->{'username'}\" target=\"rightmainframe\">change</td>\n";
    print "</tr>";

#    my $forwardlist = list_forwards($username, $account->{'svcnum'});
#    foreach my $forward ( @{$forwardlist} ) {
#      my $label = qq!=> ! . $forward->{'dest'};
#      print "<tr><td></td><td></td><td><p>$label</td></tr>\n";
#    }
    foreach my $forward ( @{$forwardlist} ) {
      if ($forward->{'srcsvc'} == $account->{'svcnum'}) {
        my $label = qq!=> ! . $forward->{'dest'};
        print "<tr><td></td><td></td><td><p>$label</td></tr>\n";
      }
    }

  }
  print "</table>\n";
  print "</body></html>\n";
  $printmainpage=0;

} elsif ($query->param('action') eq 'select') {

  my $username = $query->cookie(-name=>'username');  # session checked
  $current_package = $query->param('package');
  $current_account = $query->param('account');
  $current_domname = $query->param('domname');
  set_package();
  print "<html>$body\n";
  print "<form name=form1 action=\"$cgi\" method=post target=\"rightmainframe\">\n";
  print "<center>\n";
  print "<p>Selected package $current_package\n";
  print "</center>\n";
  print "</form>\n";
  print "</body></html>\n";
  $printmainpage=0;

} elsif ($query->param('action') eq 'change') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $account  = $query->param('account');
  my $mailbox  = $query->param('mailbox');
  my $list = list_forwards($username, $account);
  print "<html>$body\n";
  print "<form name=form1 action=\"$cgi\" method=post target=\"rightmainframe\">\n";
  print "<center><table border=0>\n";
  print "<tr><td></td><td><p>Username</td><td><p>$mailbox</td></tr>\n";
  print "<input type=hidden name=\"account\" value=\"$account\">\n";
  print "<input type=hidden name=\"mailbox\" value=\"$mailbox\">\n";
  foreach my $forward ( @{$list} ) {
    my $label = qq!=> ! . $forward->{'dest'};
#    print "<tr><td></td><td></td><td><p>$label</td></tr>\n";
    print "<tr><td></td><td></td><td><p>$label</td><td><a href=\"$cgi\?action=deleteforward&service=$forward->{'svcnum'}&mailbox=$mailbox&dest=$forward->{'dest'}\" target=\"rightmainframe\">remove</td></tr>\n";
  }
  print "<tr><td></td><td><p>Password</td><td><input type=text name=\"_password\" value=\"\"></td></tr>\n";
  print "</table>\n";
  print "<input type=submit name=\"deleteaccount\" value=\"Delete This User\">\n";
  print "<input type=submit name=\"changepassword\" value=\"Change The Password\">\n";
  print "<input type=submit name=\"addforward\" value=\"Add Forwarding\">\n";
  print "</center>\n";
  print "</form>\n";
  print "<br>\n";
  print "<p> You may delete this user and all mailforwarding by pressing <B>Delete This User</B>.\n";
  print "<p> To set or change the password for this user, type the new password in the box next to <B>Password</B> and press <B>Change The Password</B>.\n";
  print "<p> If you would like to have mail destined for this user forwarded to another email address then press the <B>Add Forwarding</B> button.\n";
  print "</body></html>\n";
  $printmainpage=0;

} elsif ($query->param('deleteaccount') ne '') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $account  = $query->param('account');
  my $mailbox  = $query->param('mailbox');
  print "<html>$body\n";
  print "<form name=form1 action=\"$cgi\" method=post target=\"rightmainframe\">\n";
  print "<p>Are you certain you want to delete user $mailbox?\n";
  print "<p><input type=hidden name=\"account\" value=\"$account\">\n";
  print "<input type=submit name=\"deleteaccounty\" value=\"Confirm\">\n";
  print "</body></html>\n";
  $printmainpage=0;

} elsif ($query->param('deleteaccounty') ne '') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $account  = $query->param('account');
  
  if  ( my $error = delete_mailbox ( {
      'authuser'         => $username,
      'account'          => $account,
    } ) ) {
    print "<html>$body\n";
    print "<p>$error\n";
    print "</body></html>\n";
      
  } else {
    print "<html>$body\n";
    print "<p>Deleted\n";
    print "</body></html>\n";
  }

  $printmainpage=0;

} elsif ($query->param('changepassword') ne '') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $account  = $query->param('account');
  my $_password  = $query->param('_password');
  
  if  ( my $error = password_mailbox ( {
      'authuser'         => $username,
      'account'          => $account,
      '_password'        => $_password,
    } ) ) {
    print "<html>$body\n";
    print "<p>$error\n";
    print "</body></html>\n";
      
  } else {
    print "<html>$body\n";
    print "<p>Changed\n";
    print "</body></html>\n";
  }

  $printmainpage=0;

} elsif ($query->param('action') eq 'newmailbox') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  print "<html>$body\n";
  print "<form name=form1 action=\"$cgi\" method=post target=\"rightmainframe\">\n";
  print "<center><table border=0>\n";
  print "<tr><td></td><td><p>Username </td><td><input type=text name=\"account\" value=\"\"></td><td>@ " . $current_domname . "</td></tr>\n";
  print "<tr><td></td><td><p>Password</td><td><input type=text name=\"_password\" value=\"\"></td></tr>\n";
  print "</table>\n";
  print "<input type=submit name=\"addmailbox\" value=\"Add This User\">\n";
  print "</center>\n";
  print "</form>\n";
  print "<br>\n";
  print "<p>Use this screen to add a new mailbox user.  If the domain name of the email address (the part after the <B>@</B> sign) is not what you expect then you may need to use <B>List Packages</B> to select the package with the correct domain.\n";
  print "<p>Enter the first portion of the email address in the box adjacent to <B>Username</B> and enter the password for that user in the space next to <B>Password</B>.  Then press the button labeled <B>Add The User</B>.\n";
  print "<p>If you do not want to add a new user at this time then select a choice from the menu at the left, such as <B>List Mailboxes</B>.\n";
  print "</body></html>\n";
  $printmainpage=0;

} elsif ($query->param('addmailbox') ne '') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $account  = $query->param('account');
  my $_password  = $query->param('_password');
  
  if  ( my $error = add_mailbox ( {
      'authuser'         => $username,
      'package'          => $current_package,
      'account'          => $account,
      '_password'        => $_password,
    } ) ) {
    print "<html>$body\n";
    print "<p>$error\n";
    print "</body></html>\n";
      
  } else {
    print "<html>$body\n";
    print "<p>Created\n";
    print "</body></html>\n";
  }

  $printmainpage=0;

} elsif ($query->param('action') eq 'deleteforward') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $svcnum   = $query->param('service');
  my $mailbox  = $query->param('mailbox');
  my $dest  = $query->param('dest');
  print "<html>$body\n";
  print "<form name=form1 action=\"$cgi\" method=post target=\"rightmainframe\">\n";
  print "<p>Are you certain you want to remove the forwarding from $mailbox to $dest?\n";
  print "<p><input type=hidden name=\"service\" value=\"$svcnum\">\n";
  print "<input type=submit name=\"deleteforwardy\" value=\"Confirm\">\n";
  print "</body></html>\n";
  $printmainpage=0;

} elsif ($query->param('deleteforwardy') ne '') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $service  = $query->param('service');
  
  if  ( my $error = delete_forward ( {
      'authuser'        => $username,
      'svcnum'          => $service,
    } ) ) {
    print "<html>$body\n";
    print "<p>$error\n";
    print "</body></html>\n";
      
  } else {
    print "<html>$body\n";
    print "<p>Forwarding Removed\n";
    print "</body></html>\n";
  }

  $printmainpage=0;

} elsif ($query->param('addforward') ne '') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $account  = $query->param('account');
  my $mailbox  = $query->param('mailbox');
  
  print "<html>$body\n";
  print "<form name=form1 action=\"$cgi\" method=post target=\"rightmainframe\">\n";
  print "<center><table border=0>\n";
  print "<input type=hidden name=\"account\" value=\"$account\">\n";
  print "<input type=hidden name=\"mailbox\" value=\"$mailbox\">\n";
  print "<tr><td>Forward mail from </td><td><p>$mailbox:</td><td> to </td></tr>\n";
  print "<tr><td></td><td><p>Destination:</td><td><input type=text name=\"dest\" value=\"\"></td></tr>\n";
  print "</table>\n";
  print "<input type=submit name=\"addforwarddst\" value=\"Add the Forwarding\">\n";
  print "</center>\n";
  print "</form>\n";
  print "<br>\n";
  print "<p> If you would like mail originally destined for the above address to be forwarded to a different email address then type that email address in the box next to <B>Destination:</B> and press the <B>Add the Forwarding</B> button.\n";
  print "<p> If you do not want to add mail forwarding then select a choice from the menu at the left, such as <B>List Accounts</B>.\n";

  $printmainpage=0;

} elsif ($query->param('addforwarddst') ne '') {

  my $username = $query->cookie(-name=>'username');  # session checked
  select_package($username) unless $current_package;
  my $account  = $query->param('account');
  my $dest  = $query->param('dest');
  
  if  ( my $error = add_forward ( {
      'authuser'         => $username,
      'package'          => $current_package,
      'source'           => $account,
      'dest'             => $dest,
    } ) ) {
    print "<html>$body\n";
    print "<p>$error\n";
    print "</body></html>\n";
      
  } else {
    print "<html>$body\n";
    print "<p>Forwarding Created\n";
    print "</body></html>\n";
  }

  $printmainpage=0;

} elsif ($query->param('action') eq 'navframe') {

  print "<html><body bgcolor=bbbbbb>\n";
  print "<center><h2>NCI2000 MAIL ADMIN Web Interface</h2></center>\n";

  print "<br><center>Choose Action:</center><br>\n";
  print "<center><table border=0>\n";
  print "<ul>\n";
  print "<tr><td><li><a href=\"$cgi\?action=logout\" target=\"_top\">Log Off</a></td><tr>\n";
  print "<tr><td><li><a href=\"$cgi\?action=list_packages\" target=\"rightmainframe\">List Packages</a></td><tr>\n";
  print "<tr><td><li><a href=\"$cgi\?action=list_mailboxes\" target=\"rightmainframe\">List Accounts</a></td><tr>\n";
  print "<tr><td><li><a href=\"$cgi\?action=newmailbox\" target=\"rightmainframe\">Add Account</a></td><tr>\n";
  print "</ul>\n";
  print "</table></center>\n";

  print "<br><br><br>\n";
  print "</body></html>\n";

  $printmainpage = 0;

} elsif ($query->param('action') eq 'rightmainframe') {

  print "<html>$body\n";
  print "<br><br><br>\n";
  print "<font size=4><----- Please choose function on the left menu</font>\n";
  print "<br><br>\n";
  print "<p> Choose <B>Log Off</B> when you are finished.  This helps prevent unauthorized access to your accounts.\n";
  print "<p> Use <B>List Packages</B> when you administer multiple packages.  When you have multiple domains at NCI2000 you are likely to have multiple packages.  Use of <B>List Packages</B> is not necessary if administer only one package.\n";
  print "<p> Use <B>List Accounts</B> to view your current arrangement of mailboxes.  From this list you my choose to make changes to existing mailboxes or delete mailboxes.  If you would like to modify the forwarding associated with a mailbox then choose it from this list.\n";
  print "<p> Use <B>Add Account</B> when you would like an additional mailbox.  After you have added the mailbox you may choose to make additional changes from the list provided by <B>List Accounts<B>.\n";
  print "</body></html>\n";

  $printmainpage = 0;

}


if ($query->param('action') eq 'login') {

    printheader();
    printlogin();

} elsif ($query->param('action') eq 'logout') {

    destroysession();
    printheader();
    printlogin();

} elsif ($printmainpage) {


  print "<html><head><title>NCI2000 MAIL ADMIN Web Interface</title></head>\n";
  print "<FRAMESET cols=\"160,*\" BORDER=\"3\">\n";
  print "<FRAME NAME=\"navframe\" src=\"$cgi?action=navframe\">\n";
  print "<FRAME NAME=\"rightmainframe\" src=\"$cgi?action=rightmainframe\">\n";
  print "</FRAMESET>\n";
  print "</html>\n";


}

sub getdatetime {
  my $today = localtime(time());
  my ($day,$mon,$dayofmon,$time,$year) = split(/\s+/,$today);
  my @datemonths = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");

  my $numidx = "01";
  my ($nummon);
  foreach my $mons (@datemonths) {
    if ($mon eq $mons) {
     $nummon = $numidx;
    }
    $numidx++;
  }

  return "$year-$nummon-$dayofmon $time";

}

sub error {

  my $error = shift;
  my $arg1 = shift;

   printheader();

   if ($error eq 'not_admin') {
     print "<html><head><title>Error!</title></head>\n";
     print "$body\n";
     print "<center><h1><font face=arial>Error!</font></h1></center>\n";
     print "<font face=arial>Unauthorized attempt to access mail administration.</font>\n";
     print "<br><font face=arial>Please login again if you think this is an error.</font>\n";
     print "<form><input type=button value=\"<<Back\" OnClick=\"history.back()\"></form>\n";
     print "</body></html>\n";
   } elsif ($error eq 'exists') {
     print "<html><head><title>Error!</title></head>\n";
     print "$body\n";
     print "<center><h1><font face=arial>Error!</font></h1></center>\n";
     print "<font face=arial>The user you are trying to enter already exists. Please go back and enter a different username</font>\n";
     print "</font></body></html>\n";
   } elsif ($error eq 'ingroup') {
     print "<html><head><title>Error!</title></head>\n";
     print "$body\n";
     print "<center><h1><font face=arial>Error!</font></h1></center>\n";
     print "<font face=arial>This user is already in the group <i>$arg1</i>. Please go back and deselect group <i>$arg1</i> from the list.</font>\n";
     print "<form><input type=button value=\"<<Back\" OnClick=\"history.back()\"></form>\n";
     print "</font></body></html>\n";
   } elsif ($error eq 'sess_expired') {
     print "<html>$body\n";
     print "<center><font size=4>Your session has expired.</font></center>\n";
     print "<br><br><center>Please login again <a href=\"$cgi\?action=login\" target=\"_top\"> HERE</a></center>\n";
     print "</body></html>\n";
   } elsif ($error eq 'open') {
     print "<html>$body\n";
     print "<center><font size=4>Unable to open or rename file.</font></center>\n";
     print "<br><br><center>If this continues, please contact your administrator</center>\n";
     print "</body></html>\n";
   }


   exit;

}


#print a html header if not printed yet
sub printheader {

  if ($printheader) {
     print "Content-Type: text/html\n\n";
     $printheader = 0;
  }

}


#verify user can access administration
sub checksession {

  my $username = $query->cookie(-name=>'username');
  my $sessionid = $query->cookie(-name=>'ma_sessionid');

  if ($sessionid eq '') {
     printheader();
     if ($query->param()) {
        error('sess_expired');
     } else {
        printlogin();
        exit;
    }
  }

  my $now = time();
  my $founduser = 0;
  open(SESSFILE, "$sessionfile") || error('open');
  error('open') if -l "$tmpdir/adminsess.$$";
  open(NEWSESS, ">$tmpdir/adminsess.$$") || error('open');
  while (<SESSFILE>) {
	chomp();
	my ($user, $sess, $time, $pkgnum, $svcdomain, $domname) = split(/\s+/);
	next if $now - $sessexpire > $time;
	if ($username eq $user && !$founduser) {
		if ($sess eq $sessionid) {
			$founduser = 1;
			print NEWSESS "$user $sess $now $pkgnum $svcdomain $domname\n";
                        $current_package=$pkgnum;
                        $current_account=$svcdomain;
                        $current_domname=$domname;
			next;
		}
	}
	print NEWSESS "$user $sess $time $pkgnum $svcdomain $domname\n";
  }
  close(SESSFILE);
  close(NEWSESS);
  system("mv $tmpdir/adminsess.$$ $sessionfile");
  error('sess_expired') unless $founduser;

  my $cookie1 = $query->cookie(-name=>'username',
				-value=>$username,
				-expires=>$cookieexpire,
				-domain=>$cookiedomain);

  my $cookie2 = $query->cookie(-name=>'ma_sessionid',
				-value=>$sessionid,
				-expires=>$cookieexpire,
				-domain=>$cookiedomain);

  print $query->header(-COOKIE=>[$cookie1, $cookie2]);
  
  $printheader = 0;

  return 0;

}

sub destroysession {

  my $username = $query->cookie(-name=>'username');
  my $sessionid = $query->cookie(-name=>'ma_sessionid');

  if ($sessionid eq '') {
     printheader();
     if ($query->param()) {
        error('sess_expired');
     } else {
        printlogin();
        exit;
    }
  }

  my $now = time();
  my $founduser = 0;
  open(SESSFILE, "$sessionfile") || error('open');
  error('open') if -l "$tmpdir/adminsess.$$";
  open(NEWSESS, ">$tmpdir/adminsess.$$") || error('open');
  while (<SESSFILE>) {
	chomp();
	my ($user, $sess, $time, $pkgnum, $svcdomain, $domname) = split(/\s+/);
	next if $now - $sessexpire > $time;
	if ($username eq $user && !$founduser) {
		if ($sess eq $sessionid) {
			$founduser = 1;
			next;
		}
	}
	print NEWSESS "$user $sess $time $pkgnum $svcdomain $domname\n";
  }
  close(SESSFILE);
  close(NEWSESS);
  system("mv $tmpdir/adminsess.$$ $sessionfile");
  error('sess_expired') unless $founduser;

  $printheader = 0;

  return 0;

}

# checks the username and pass against the database
sub checkuserpass {

  my $username = shift;
  my $password = shift;

  my $error = authenticate ( {
      'authuser'         => $username,
      '_password'        => $password,
    } ); 

  if ($error eq "$username OK") {
    return 1;
  }else{
    return 0;
  }

}

#printlogin prints a login page
sub printlogin {

        print "<html>$body\n";
        print "<center><font size=4>Please login to access MAIL ADMIN</font></center>\n";
        print "<form action=\"$cgi\" method=post>\n";
        print "<center>Email Address: &nbsp; <input type=text name=\"username\">\n";
        print "<br>Email Password: <input type=password name=\"password\">\n";
        print "<br><input type=submit name=\"login\" value=\"Login\">\n";
        print "</form></center>\n";
        print "</body></html>\n";
}


#select_package chooses a administrable package if more than one exists
sub select_package {
        my $user = shift;
        my $packages = list_packages($user);
        if (scalar(@{$packages}) eq 1) {
          $current_package = @{$packages}[0]->{'pkgnum'};
          set_package();
        }
        if (scalar(@{$packages}) > 1) {
#          print $query->redirect("$cgi\?action=list_packages");
           print "<p>No package selected.  You must first <a href=\"$cgi\?action=list_packages\" target=\"rightmainframe\">select a package</a>.\n";
          exit;
        }
}

sub set_package {

  my $username = $query->cookie(-name=>'username');
  my $sessionid = $query->cookie(-name=>'ma_sessionid');

  if ($sessionid eq '') {
     printheader();
     if ($query->param()) {
        error('sess_expired');
     } else {
        printlogin();
        exit;
    }
  }

  my $now = time();
  my $founduser = 0;
  open(SESSFILE, "$sessionfile") || error('open');
  error('open') if -l "$tmpdir/adminsess.$$";
  open(NEWSESS, ">$tmpdir/adminsess.$$") || error('open');
  while (<SESSFILE>) {
	chomp();
	my ($user, $sess, $time, $pkgnum, $svcdomain, $domname) = split(/\s+/);
	next if $now - $sessexpire > $time;
	if ($username eq $user && !$founduser) {
		if ($sess eq $sessionid) {
			$founduser = 1;
	                print NEWSESS "$user $sess $time $current_package $current_account $current_domname\n";
			next;
		}
	}
	print NEWSESS "$user $sess $time $pkgnum $svcdomain $domname\n";
  }
  close(SESSFILE);
  close(NEWSESS);
  system("mv $tmpdir/adminsess.$$ $sessionfile");
  error('sess_expired') unless $founduser;

  $printheader = 0;

  return 0;

}

