#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2003
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
# Contributors: Thomas Bayen <bayen@gmx.de>
#               Antti Kaihola <akaihola@siba.fi>
#               Moritz Bunkus (tex code)
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
#======================================================================
# Utilities for parsing forms
# and supporting routines for linking account numbers
# used in AR, AP and IS, IR modules
#
#======================================================================

package Form;


sub new {
  my $type = shift;
  
  my $self = {};

  read(STDIN, $_, $ENV{CONTENT_LENGTH});
  
  if ($ENV{QUERY_STRING}) {
    $_ = $ENV{QUERY_STRING};
  }

  if ($ARGV[0]) {
    $_ = $ARGV[0];
  }

  foreach $item (split(/&/)) {
    ($key, $value) = split(/=/, $item);
    $self->{$key} = &unescape("",$value);
  }

  $self->{action} = lc $self->{action};
  $self->{action} =~ s/( |-|,)/_/g;

  $self->{version} = "2.0.8";
  $self->{dbversion} = "2.0.8";

  bless $self, $type;
  
}


sub debug {
  my ($self) = @_;
  
  print "\n";
  
  map { print "$_ = $self->{$_}\n" } (sort keys %{$self});
  
} 

  
sub escape {
  my ($self, $str, $beenthere) = @_;

  # for Apache 2 we escape strings twice
  if (($ENV{SERVER_SOFTWARE} =~ /Apache\/2/) && !$beenthere) {
    $str = $self->escape($str, 1);
  }
	    
  $str =~ s/([^a-zA-Z0-9_.-])/sprintf("%%%02x", ord($1))/ge;
  $str;

}


sub unescape {
  my ($self, $str) = @_;
  
  $str =~ tr/+/ /;
  $str =~ s/\\$//;

  $str =~ s/%([0-9a-fA-Z]{2})/pack("c",hex($1))/eg;

  $str;

}


sub error {
  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;

    print qq|Content-Type: text/html

    <body bgcolor=ffffff>

    <h2><font color=red>Error!</font></h2>

    <p><b>$msg</b>
    
    </body>
    </html>
    |;

    die "Error: $msg\n";

  } else {
  
    if ($self->{error_function}) {
      &{ $self->{error_function} }($msg);
    } else {
      die "Error: $msg\n";
    }
  }
  
}



sub info {
  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;

    if (!$self->{header}) {
      $self->header;
      print qq|
      <body>|;
    }

    print qq|

    <p><b>$msg</b>
    |;
    
  } else {
  
    if ($self->{info_function}) {
      &{ $self->{info_function} }($msg);
    } else {
      print "$msg\n";
    }
  }
  
}


sub numtextrows {
  my ($self, $str, $cols, $maxrows) = @_;

  my $rows;

  map { $rows += int ((length $_)/$cols) + 1 } (split /\r/, $str);

  $rows = $maxrows if (defined $maxrows && ($rows > $maxrows));
  
  $rows;

}


sub dberror {
  my ($self, $msg) = @_;

  $self->error("$msg\n".$DBI::errstr);
  
}


sub isblank {
  my ($self, $name, $msg) = @_;

  if ($self->{$name} =~ /^\s*$/) {
    $self->error($msg);
  }
}
  

sub header {
  my ($self) = @_;

  my ($nocache, $stylesheet, $charset);
  
  # use expire tag to prevent caching
#  $nocache = qq|<META HTTP-EQUIV="Expires" CONTENT="Tue, 01 Jan 1980 1:00:00 GMT">
#  <META HTTP-EQUIV="Pragma" CONTENT="no-cache">
#|;

  if ($self->{stylesheet} && (-f "css/$self->{stylesheet}")) {
    $stylesheet = qq|<LINK REL="stylesheet" HREF="css/$self->{stylesheet}" TYPE="text/css" TITLE="SQL-Ledger style sheet">
|;
  }

  if ($self->{charset}) {
    $charset = qq|<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=$self->{charset}">
|;
  }

  $self->{titlebar} = ($self->{title}) ? "$self->{title} - $self->{titlebar}" : $self->{titlebar};
  
  print qq|Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<head>
  <title>$self->{titlebar}</title>
  $nocache
  $stylesheet
  $charset
</head>

|;

}


sub redirect {
  my ($self, $msg) = @_;

  if ($self->{callback}) {

    ($script, $argv) = split(/\?/, $self->{callback});

    exec ("perl", "$script", $argv);
   
  } else {
    
    if ($ENV{HTTP_USER_AGENT}) {
      $msg =~ s/\n/<br>/g;

      print qq|Content-Type: text/html

<body bgcolor=ffffff>

<h2>$msg</h2>

</body>
</html>
|;

    } else {
      print "$msg\n";
    }

    exit;
    
  }

}


sub sort_columns {
  my ($self, @columns) = @_;

  @columns = grep !/^$self->{sort}$/, @columns;
  splice @columns, 0, 0, $self->{sort};

  @columns;
  
}


sub format_amount {
  my ($self, $myconfig, $amount, $places, $dash) = @_;

  if ($places =~ /\d/) {
    $amount = $self->round_amount($amount, $places);
  }

  # is the amount negative
  my $negative = ($amount < 0);
  
  if ($amount != 0) {
    if ($myconfig->{numberformat} && ($myconfig->{numberformat} ne '1000.00')) {
      my ($whole, $dec) = split /\./, "$amount";
      $whole =~ s/-//;
      $amount = join '', reverse split //, $whole;
      
      if ($myconfig->{numberformat} eq '1,000.00') {
	$amount =~ s/\d{3,}?/$&,/g;
	$amount =~ s/,$//;
	$amount = join '', reverse split //, $amount;
	$amount .= "\.$dec" if ($dec ne "");
      }
      
      if ($myconfig->{numberformat} eq '1.000,00') {
	$amount =~ s/\d{3,}?/$&./g;
	$amount =~ s/\.$//;
	$amount = join '', reverse split //, $amount;
	$amount .= ",$dec" if ($dec ne "");
      }
      
      if ($myconfig->{numberformat} eq '1000,00') {
	$amount = "$whole";
	$amount .= ",$dec" if ($dec ne "");
      }

      if ($dash =~ /-/) {
	$amount = ($negative) ? "($amount)" : "$amount";
      } elsif ($dash =~ /DRCR/) {
	$amount = ($negative) ? "$amount DR" : "$amount CR";
      } else {
	$amount = ($negative) ? "-$amount" : "$amount";
      }
    }
  } else {
    if ($dash eq "0" && $places) {
      if ($myconfig->{numberformat} eq '1.000,00') {
	$amount = "0".","."0" x $places;
      } else {
	$amount = "0"."."."0" x $places;
      }
    } else {
      $amount = ($dash ne "") ? "$dash" : "";
    }
  }

  $amount;

}


sub parse_amount {
  my ($self, $myconfig, $amount) = @_;

  if (($myconfig->{numberformat} eq '1.000,00') ||
      ($myconfig->{numberformat} eq '1000,00')) {
    $amount =~ s/\.//g;
    $amount =~ s/,/\./;
  }

  $amount =~ s/,//g;
  
  return ($amount * 1);

}


sub round_amount {
  my ($self, $amount, $places) = @_;

#  $places = 3 if $places == 2;
  
  if (($places * 1) >= 0) {
    # compensate for perl behaviour, add 1/10^$places+3
    sprintf("%.${places}f", $amount + (1 / (10 ** ($places + 3))) * (($amount > 0) ? 1 : -1));
  } else {
    $places *= -1;
    sprintf("%.f", $amount / (10 ** $places) + (($amount > 0) ? 0.1 : -0.1)) * (10 ** $places);
  }

}


sub parse_template {
  my ($self, $myconfig, $userspath) = @_;

  # { Moritz Bunkus
  # Some variables used for page breaks
  my ($chars_per_line, $lines_on_first_page, $lines_on_second_page) = (0, 0, 0);
  my ($current_page, $current_line) = (1, 1);
  my $pagebreak = "";
  my $sum = 0;
  # } Moritz Bunkus

  open(IN, "$self->{templates}/$self->{IN}") or $self->error("$self->{IN} : $!");

  @_ = <IN>;
  close(IN);
  
  $self->{copies} = 1 if (($self->{copies} *= 1) <= 0);
  
  # OUT is used for the media, screen, printer, email
  # for postscript we store a copy in a temporary file
  my $fileid = time;
  $self->{tmpfile} = "$userspath/${fileid}.$self->{IN}";
  if ($self->{format} =~ /(postscript|pdf)/ || $self->{media} eq 'email') {
    $out = $self->{OUT};
    $self->{OUT} = ">$self->{tmpfile}";
  }
  
  
  if ($self->{OUT}) {
    open(OUT, "$self->{OUT}") or $self->error("$self->{OUT} : $!");
  } else {
    open(OUT, ">-") or $self->error("STDOUT : $!");
    $self->header;
  }


  # first we generate a tmpfile
  # read file and replace <%variable%>
  while ($_ = shift) {
      
    $par = "";
    $var = $_;


    # { Moritz Bunkus
    # detect pagebreak block and its parameters
    if (/<%pagebreak ([0-9]+) ([0-9]+) ([0-9]+)%>/) {
      $chars_per_line = $1;
      $lines_on_first_page = $2;
      $lines_on_second_page = $3;
      
      while ($_ = shift) {
        last if (/<\%end pagebreak%>/);
        $pagebreak .= $_;
      }
    }
    # } Moritz Bunkus

    
    if (/<%foreach /) {
      
      # this one we need for the count
      chomp $var;
      $var =~ s/<%foreach (.+?)%>/$1/;
      while ($_ = shift) {
	last if (/<%end /);

	# store line in $par
	$par .= $_;
      }
      
      # display contents of $self->{number}[] array
      for $i (0 .. $#{ $self->{$var} }) {

        # { Moritz Bunkus
        # Try to detect whether a manual page break is necessary
        # but only if there was a <%pagebreak ...%> block before
	
        if ($chars_per_line) {
          my $lines = int(length($self->{"description"}[$i]) / $chars_per_line + 0.95);
          my $lpp;
	  
          if ($current_page == 1) {
            $lpp = $lines_on_first_page;
          } else {
            $lpp = $lines_on_second_page;
          }

          # Yes we need a manual page break
          if (($current_line + $lines) > $lpp) {
            my $pb = $pagebreak;
	    
            # replace the special variables <%sumcarriedforward%>
            # and <%lastpage%>
	    
            my $psum = $self->format_amount($myconfig, $sum, 2);
            $pb =~ s/<%sumcarriedforward%>/$psum/g;
            $pb =~ s/<%lastpage%>/$current_page/g;
            
	    # only "normal" variables are supported here
            # (no <%if, no <%foreach, no <%include)
            
	    $pb =~ s/<%(.+?)%>/$self->{$1}/g;
            
	    # page break block is ready to rock
            print(OUT $pb);
            $current_page++;
            $current_line = 1;
          }
          $current_line += $lines;
        }
        $sum += $self->parse_amount($myconfig, $self->{"linetotal"}[$i]);
        # } Moritz Bunkus


	# don't parse par, we need it for each line
	$_ = $par;
	s/<%(.+?)%>/$self->{$1}[$i]/mg;
	print OUT;
      }
      next;
    }

    # if not comes before if!
    if (/<%if not /) {
      # check if it is not set and display
      chop;
      s/<%if not (.+?)%>/$1/;

      unless ($self->{$_}) {
	while ($_ = shift) {
	  last if (/<%end /);

	  # store line in $par
	  $par .= $_;
	}
	
	$_ = $par;
	
      } else {
	while ($_ = shift) {
	  last if (/<%end /);
	}
	next;
      }
    }
 
    if (/<%if /) {
      # check if it is set and display
      chop;
      s/<%if (.+?)%>/$1/;

      if ($self->{$_}) {
	while ($_ = shift) {
	  last if (/<%end /);

	  # store line in $par
	  $par .= $_;
	}
	
	$_ = $par;
	
      } else {
	while ($_ = shift) {
	  last if (/<%end /);
	}
	next;
      }
    }
   
    # check for <%include filename%>
    if (/<%include /) {
      
      # get the filename
      chomp $var;
      $var =~ s/<%include (.+?)%>/$1/;

      # mangle filename if someone tries to be cute
      $var =~ s/\///g;

      # prevent the infinite loop!
      next if ($self->{"$var"});

      open(INC, "$self->{templates}/$var") or $self->error($self->cleanup."$self->{templates}/$var : $!");
      unshift(@_, <INC>);
      close(INC);

      $self->{"$var"} = 1;

      next;
    }
    
    s/<%(.+?)%>/$self->{$1}/g;
    print OUT;
  }

  close(OUT);


  # { Moritz Bunkus
  # Convert the tex file to postscript
  if ($self->{format} =~ /(postscript|pdf)/) {

    use Cwd;
    $self->{cwd} = cwd();
    chdir("$userspath") or $self->error($self->cleanup."chdir : $!");

    $self->{tmpfile} =~ s/$userspath\///g;

    # DS. added screen and email option in addition to printer
    # screen
    if ($self->{format} eq 'postscript') {
      system("latex --interaction=nonstopmode $self->{tmpfile} > $self->{tmpfile}.err");
      $self->error($self->cleanup) if ($?);
      
      $self->{tmpfile} =~ s/tex$/dvi/;

      system("dvips $self->{tmpfile} -o -q > /dev/null");
      $self->error($self->cleanup."dvips : $!") if ($?);
      $self->{tmpfile} =~ s/dvi$/ps/;
    }
    if ($self->{format} eq 'pdf') {
      system("pdflatex --interaction=nonstopmode $self->{tmpfile} > $self->{tmpfile}.err");
      $self->error($self->cleanup) if ($?);
      $self->{tmpfile} =~ s/tex$/pdf/;
    }

  }

  if ($self->{format} =~ /(postscript|pdf)/ || $self->{media} eq 'email') {

    if ($self->{media} eq 'email') {
      
      use SL::Mailer;

      my $mail = new Mailer;
      
      $self->{email} =~ s/,/>,</g;
      
      map { $mail->{$_} = $self->{$_} } qw(cc bcc subject message version format charset);
      $mail->{to} = qq|"$self->{name}" <$self->{email}>|;
      $mail->{from} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
      $mail->{fileid} = "$fileid.";

      # if we send html or plain text inline
      if (($self->{format} eq 'html') && ($self->{sendmode} eq 'inline')) {
	$mail->{contenttype} = "text/html";

        $mail->{message} =~ s/\r\n/<br>\n/g;
	$myconfig->{signature} =~ s/\\n/<br>\n/g;
	$mail->{message} .= "<br>\n--<br>\n$myconfig->{signature}\n<br>";
	
	open(IN, $self->{tmpfile}) or $self->error($self->cleanup."$self->{tmpfile} : $!");
	while (<IN>) {
	  $mail->{message} .= $_;
	}

	close(IN);

      } else {
	
	@{ $mail->{attachments} } = ($self->{tmpfile});

	$myconfig->{signature} =~ s/\\n/\r\n/g;
	$mail->{message} .= "\r\n--\r\n$myconfig->{signature}";

      }
 
      my $err = $mail->send($out);
      $self->error($self->cleanup."$err") if ($err);
      
    } else {
      
      $self->{OUT} = $out;
      open(IN, $self->{tmpfile}) or $self->error($self->cleanup."$self->{tmpfile} : $!");

      $self->{copies} = 1 unless $self->{media} eq 'printer';
      
      for my $i (1 .. $self->{copies}) {
	  
	if ($self->{OUT}) {
	  open(OUT, $self->{OUT}) or $self->error($self->cleanup."$self->{OUT} : $!");
	} else {
	  open(OUT, ">-") or $self->error($self->cleanup."$!: STDOUT");
	  
	  # launch application
	  print qq|Content-Type: application/$self->{format}; name="$self->{tmpfile}"
  Content-Disposition: filename="$self->{tmpfile}"

  |;
	}
       
	while (<IN>) {
	  print OUT $_;
	}
	close(OUT);
	seek IN, 0, 0;
      }

      close(IN);
    }

    $self->cleanup;

  }
  # } Moritz Bunkus

}


sub cleanup {
  my $self = shift;

  my @err = ();
  if (-f "$self->{tmpfile}.err") {
    open(FH, "$self->{tmpfile}.err");
    @err = <FH>;
    close(FH);
  }
  
  if ($self->{tmpfile}) {
    # strip extension
    $self->{tmpfile} =~ s/\.\w+$//g;
    my $tmpfile = $self->{tmpfile};
    unlink(<$tmpfile.*>);
  }


  chdir("$self->{cwd}");
  
  "@err";
  
}


sub format_string {
  my ($self, @fields) = @_;

  my $format = $self->{format};
  if ($self->{format} =~ /(postscript|pdf)/) {
    $format = 'tex';
  }

  my %replace = ( 'order' => { 'html' => [ quotemeta('\n'), '' ],
                               'tex'  => [ '&', quotemeta('\n'), '',
					   '\$', '%', '_', '#', quotemeta('^'),
					   '{', '}', '<', '>', '£' ] },
                  'html' => {
                quotemeta('\n') => '<br>', '' => '<br>'
		            },
	           'tex' => {
	        '&' => '\&', '\$' => '\$', '%' => '\%', '_' => '\_',
		'#' => '\#', quotemeta('^') => '\^\\', '{' => '\{', '}' => '\}',
		'<' => '$<$', '>' => '$>$',
		quotemeta('\n') => '\newline ', '' => '\newline ',
		'£' => '\pounds ',
                            }
	        );

  foreach my $key (@{ $replace{order}{$format} }) {
    map { $self->{$_} =~ s/$key/$replace{$format}{$key}/g; } @fields;
  }

}


sub datetonum {
  my ($self, $date, $myconfig) = @_;

  if ($date) {
    # get separator
    my $spc = $myconfig->{dateformat};
    $spc =~ s/\w//g;
    $spc = substr($spc, 1, 1);

    if ($spc eq '.') {
      $spc = '\.';
    }
    if ($spc eq '/') {
      $spc = '\/';
    }

    if ($myconfig->{dateformat} =~ /^yy/) {
      ($yy, $mm, $dd) = split /$spc/, $date;
    }
    if ($myconfig->{dateformat} =~ /^mm/) {
      ($mm, $dd, $yy) = split /$spc/, $date;
    }
    if ($myconfig->{dateformat} =~ /^dd/) {
      ($dd, $mm, $yy) = split /$spc/, $date;
    }
    
    $dd *= 1;
    $mm *= 1;
    $yy = ($yy < 70) ? $yy + 2000 : $yy;
    $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

    $dd = "0$dd" if ($dd < 10);
    $mm = "0$mm" if ($mm < 10);
    
    $date = "$yy$mm$dd";
  }

  $date;
  
}



# Database routines used throughout

sub dbconnect {
  my ($self, $myconfig) = @_;

  # connect to database
  my $dbh = DBI->connect($myconfig->{dbconnect}, $myconfig->{dbuser}, $myconfig->{dbpasswd}) or $self->dberror;

  # set db options
  if ($myconfig->{dboptions}) {
    $dbh->do($myconfig->{dboptions}) || $self->dberror($myconfig->{dboptions});
  }

  $dbh;

}


sub dbconnect_noauto {
  my ($self, $myconfig) = @_;

  # connect to database
  $dbh = DBI->connect($myconfig->{dbconnect}, $myconfig->{dbuser}, $myconfig->{dbpasswd}, {AutoCommit => 0}) or $self->dberror;

  # set db options
  if ($myconfig->{dboptions}) {
    $dbh->do($myconfig->{dboptions}) || $self->dberror($myconfig->{dboptions});
  }

  $dbh;

}


sub update_balance {
  my ($self, $dbh, $table, $field, $where, $value) = @_;

  # if we have a value, go do it
  if ($value != 0) {
    # retrieve balance from table
    my $query = "SELECT $field FROM $table WHERE $where";
    my $sth = $dbh->prepare($query);

    $sth->execute || $self->dberror($query);
    my ($balance) = $sth->fetchrow_array;
    $sth->finish;

    $balance += $value;
    # update balance
    $query = "UPDATE $table SET $field = $balance WHERE $where";
    $dbh->do($query) || $self->dberror($query);
  }
}



sub update_exchangerate {
  my ($self, $dbh, $curr, $transdate, $buy, $sell) = @_;

  # some sanity check for currency
  return if ($curr eq '');

  my $query = qq|SELECT curr FROM exchangerate
                 WHERE curr = '$curr'
	         AND transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  
  my $set;
  if ($buy != 0 && $sell != 0) {
    $set = "buy = $buy, sell = $sell";
  } elsif ($buy != 0) {
    $set = "buy = $buy";
  } elsif ($sell != 0) {
    $set = "sell = $sell";
  }
  
  if ($sth->fetchrow_array) {
    $query = qq|UPDATE exchangerate
                SET $set
		WHERE curr = '$curr'
		AND transdate = '$transdate'|;
  } else {
    $query = qq|INSERT INTO exchangerate (curr, buy, sell, transdate)
                VALUES ('$curr', $buy, $sell, '$transdate')|;
  }
  $sth->finish;
  $dbh->do($query) || $self->dberror($query);
  
}


sub get_exchangerate {
  my ($self, $dbh, $curr, $transdate, $fld) = @_;
  
  my $query = qq|SELECT $fld FROM exchangerate
                 WHERE curr = '$curr'
		 AND transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my ($exchangerate) = $sth->fetchrow_array;
  $sth->finish;

  $exchangerate;

}


sub delete_exchangerate {
  my ($self, $dbh) = @_;

  my @transdate = ();
  my $transdate;

  my $query = qq|SELECT DISTINCT transdate
                 FROM acc_trans
		 WHERE trans_id = $self->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($transdate = $sth->fetchrow_array) {
    push @transdate, $transdate;
  }
  $sth->finish;

  $query = qq|SELECT transdate FROM acc_trans
              WHERE ar.id = trans_id
	      AND ar.curr = '$self->{currency}'
	      AND transdate IN
	          (SELECT transdate FROM acc_trans
		  WHERE trans_id = $self->{id})
              AND trans_id != $self->{id}
        UNION SELECT transdate FROM acc_trans
	      WHERE ap.id = trans_id
	      AND ap.curr = '$self->{currency}'
	      AND transdate IN
	          (SELECT transdate FROM acc_trans
		  WHERE trans_id = $self->{id})
              AND trans_id != $self->{id}
        UNION SELECT transdate FROM oe
	        WHERE oe.curr = '$self->{currency}'
		AND transdate IN
		    (SELECT transdate FROM acc_trans
		    WHERE trans_id = $self->{id})|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($transdate = $sth->fetchrow_array) {
    @transdate = grep !/^$transdate$/, @transdate;
  }
  $sth->finish;

  foreach $transdate (@transdate) {
    $query = qq|DELETE FROM exchangerate
                WHERE curr = '$self->{currency}'
		AND transdate = '$transdate'|;
    $dbh->do($query) || $self->dberror($query);
  }
  
}


sub check_exchangerate {
  my ($self, $myconfig, $currency, $transdate, $fld) = @_;

  return "" unless $transdate;
  
  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|SELECT $fld FROM exchangerate
                 WHERE curr = '$currency'
		 AND transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my ($exchangerate) = $sth->fetchrow_array;
  $sth->finish;
  $dbh->disconnect;
  
  $exchangerate;
  
}


sub add_shipto {
  my ($self, $dbh, $id) = @_;

  my $shipto;
  foreach my $item (qw(name addr1 addr2 addr3 addr4 contact phone fax email)) {
    if ($self->{"shipto$item"}) {
      $shipto = 1 if ($self->{$item} ne $self->{"shipto$item"});
    }
    $self->{"shipto$item"} =~ s/'/''/g;
  }

  if ($shipto) {
    my $query = qq|INSERT INTO shipto (trans_id, shiptoname, shiptoaddr1,
                   shiptoaddr2, shiptoaddr3, shiptoaddr4, shiptocontact,
		   shiptophone, shiptofax, shiptoemail) VALUES ($id,
		   '$self->{shiptoname}', '$self->{shiptoaddr1}',
		   '$self->{shiptoaddr2}', '$self->{shiptoaddr3}',
		   '$self->{shiptoaddr4}', '$self->{shiptocontact}',
		   '$self->{shiptophone}', '$self->{shiptofax}',
		   '$self->{shiptoemail}')|;
    $dbh->do($query) || $self->dberror($query);
  }

}


sub get_employee {
  my ($self, $dbh) = @_;

  my $query = qq|SELECT name FROM employee 
                 WHERE login = '$self->{login}'|; 
  my $sth = $dbh->prepare($query); 
  $sth->execute || $self->dberror($query); 

  ($self->{employee}) = $sth->fetchrow_array;
  $sth->finish; 

}


# this sub gets the id and name from $table
sub get_name {
  my ($self, $myconfig, $table) = @_;

  # connect to database
  my $dbh = $self->dbconnect($myconfig);
  
  my $name = $self->like(lc $self->{$table});
  my $query = qq~SELECT id, name,
                 addr1 || ' ' || addr2 || ' ' || addr3 || ' ' || addr4 AS address
                 FROM $table
		 WHERE lower(name) LIKE '$name'
		 ORDER BY name~;
  my $sth = $dbh->prepare($query);

  $sth->execute || $self->dberror($query);

  my $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $self->{name_list} }, $ref);
    $i++;
  }
  $sth->finish;
  $dbh->disconnect;

  $i;
  
}


# the selection sub is used in the AR, AP, IS, IR and OE module
#
sub all_vc {
  my ($self, $myconfig, $table) = @_;
  
  my $dbh = $self->dbconnect($myconfig);
  
  my $query = qq|SELECT count(*) FROM $table|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  my ($count) = $sth->fetchrow_array;
  $sth->finish;
  
  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT id, name
		FROM $table
		ORDER BY name|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $self->{"all_$table"} }, $ref;
    }
    
    $sth->finish;
    
  }

  $dbh->disconnect;

}


sub create_links {
  my ($self, $module, $myconfig, $table) = @_;

  $self->all_vc($myconfig, $table);
  
  # get last customers or vendors
  my ($query, $sth);
  
  my $dbh = $self->dbconnect($myconfig);
  
  my %xkeyref = ();


  # now get the account numbers
  $query = qq|SELECT accno, description, link
              FROM chart
	      WHERE link LIKE '%$module%'
	      ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{accounts} = "";
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /$module/) {
	# cross reference for keys
	$xkeyref{$ref->{accno}} = $key;
	
	push @{ $self->{"${module}_links"}{$key} }, { accno => $ref->{accno},
                                       description => $ref->{description} };

        $self->{accounts} .= "$ref->{accno} " unless $key =~ /tax/;
      }
    }
  }
  $sth->finish;
  
 
  if ($self->{id}) {
    my $arap = ($table eq 'customer') ? 'ar' : 'ap';
    
    $query = qq|SELECT a.invnumber, a.transdate,
                a.${table}_id, a.datepaid, a.duedate, a.ordnumber,
		a.taxincluded, a.curr AS currency, a.notes, c.name AS $table,
		a.amount AS oldinvtotal, a.paid AS oldtotalpaid
		FROM $arap a, $table c
		WHERE a.${table}_id = c.id
		AND a.id = $self->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    
    $ref = $sth->fetchrow_hashref(NAME_lc);
    foreach $key (keys %$ref) {
      $self->{$key} = $ref->{$key};
    }
    $sth->finish;

    # get amounts from individual entries
    $query = qq|SELECT c.accno, c.description, a.source, a.amount,
                a.transdate, a.cleared, a.project_id, p.projectnumber
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		LEFT JOIN project p ON (a.project_id = p.id)
		WHERE a.trans_id = $self->{id}
		AND a.fx_transaction = '0'
		ORDER BY transdate|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    my $fld = ($table eq 'customer') ? 'buy' : 'sell';
    # get exchangerate for currency
    $self->{exchangerate} = $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate}, $fld);
    
    # store amounts in {acc_trans}{$key} for multiple accounts
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{exchangerate} = $self->get_exchangerate($dbh, $self->{currency}, $ref->{transdate}, $fld);

      push @{ $self->{acc_trans}{$xkeyref{$ref->{accno}}} }, $ref;
    }

    $sth->finish;

    $query = qq|SELECT d.curr AS currencies, d.closedto, d.revtrans,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
		FROM defaults d|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $self->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

  } else {
   
    # get date
    $query = qq|SELECT current_date AS transdate,
                d.curr AS currencies, d.closedto, d.revtrans,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
		FROM defaults d|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $self->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    if ($self->{"$self->{vc}_id"}) {
      # only setup currency
      ($self->{currency}) = split /:/, $self->{currencies};
      
    } else {
      
      $self->lastname_used($dbh, $myconfig, $table, $module);
    
      my $fld = ($table eq 'customer') ? 'buy' : 'sell';
      # get exchangerate for currency
      $self->{exchangerate} = $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate}, $fld);
   
    }

  }

  $dbh->disconnect;

}


sub lastname_used {
  my ($self, $dbh, $myconfig, $table, $module) = @_;

  my $arap = ($table eq 'customer') ? "ar" : "ap";
  $arap = 'oe' if ($self->{type} =~ /_order/);

  my $query = qq|SELECT id FROM $arap
                 WHERE id IN (SELECT MAX(id) FROM $arap
		              WHERE ${table}_id > 0)|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  
  my ($trans_id) = $sth->fetchrow_array;
  $sth->finish;
  
  $trans_id *= 1;
  $query = qq|SELECT ct.name, a.curr, a.${table}_id,
              current_date + ct.terms AS duedate
	      FROM $arap a
	      JOIN $table ct ON (a.${table}_id = ct.id)
	      WHERE a.id = $trans_id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  ($self->{$table}, $self->{currency}, $self->{"${table}_id"}, $self->{duedate}) = $sth->fetchrow_array;
  $sth->finish;

}



sub current_date {
  my ($self, $myconfig, $thisdate, $days) = @_;
  
  my $dbh = $self->dbconnect($myconfig);
  my ($sth, $query);

  $days *= 1;
  if ($thisdate) {
    my $dateformat = $myconfig->{dateformat};
    $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;
    
    $query = qq|SELECT to_date('$thisdate', '$dateformat') + $days AS thisdate
                FROM defaults|;
     $sth = $dbh->prepare($query);
     $sth->execute || $self->dberror($query);
  } else {
    $query = qq|SELECT current_date AS thisdate
                FROM defaults|;
     $sth = $dbh->prepare($query);
     $sth->execute || $self->dberror($query);
  }

  ($thisdate) = $sth->fetchrow_array;
  $sth->finish;

  $dbh->disconnect;

  $thisdate;

}


sub like {
  my ($self, $string) = @_;
  
  unless ($string =~ /%/) {
    $string = "%$string%";
  }

  $string =~ s/'/''/g;
  $string;
  
}


sub redo_rows {
  my ($self, $flds, $new, $count, $numrows) = @_;

  my @ndx = ();

  map { push @ndx, { num => $new->[$_-1]->{runningnumber}, ndx => $_ } } (1 .. $count);

  my $i = 0;
  # fill rows
  foreach my $item (sort { $a->{num} <=> $b->{num} } @ndx) {
    $i++;
    $j = $item->{ndx} - 1;
    map { $self->{"${_}_$i"} = $new->[$j]->{$_} } @{$flds};
  }

  # delete empty rows
  for $i ($count + 1 .. $numrows) {
    map { delete $self->{"${_}_$i"} } @{$flds}; 
  }

}

  
package Locale;


sub new {
  my ($type, $country, $NLS_file) = @_;
  my $self = {};

  %self = ();
  if ($country && -d "locale/$country") {
    $self->{countrycode} = $country;
    eval { require "locale/$country/$NLS_file"; };
  }

  $self->{NLS_file} = $NLS_file;
  
  push @{ $self->{LONG_MONTH} }, ("January", "February", "March", "April", "May ", "June", "July", "August", "September", "October", "November", "December");
  push @{ $self->{SHORT_MONTH} }, (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec));
  
  bless $self, $type;

}


sub text {
  my ($self, $text) = @_;
  
  return (exists $self{texts}{$text}) ? $self{texts}{$text} : $text;
  
}


sub findsub {
  my ($self, $text) = @_;

  if (exists $self{subs}{$text}) {
    $text = $self{subs}{$text};
  } else {
    if ($self->{countrycode} && $self->{NLS_file}) {
      Form->error("$text not defined in locale/$self->{countrycode}/$self->{NLS_file}");
    }
  }

  $text;

}


sub date {
  my ($self, $myconfig, $date, $longformat) = @_;

  my $longdate = "";
  my $longmonth = ($longformat) ? 'LONG_MONTH' : 'SHORT_MONTH';

  if ($date) {
    # get separator
    $spc = $myconfig->{dateformat};
    $spc =~ s/\w//g;
    $spc = substr($spc, 1, 1);

    if ($spc eq '.') {
      $spc = '\.';
    }
    if ($spc eq '/') {
      $spc = '\/';
    }

    if ($myconfig->{dateformat} =~ /^yy/) {
      ($yy, $mm, $dd) = split /$spc/, $date;
    }
    if ($myconfig->{dateformat} =~ /^mm/) {
      ($mm, $dd, $yy) = split /$spc/, $date;
    }
    if ($myconfig->{dateformat} =~ /^dd/) {
      ($dd, $mm, $yy) = split /$spc/, $date;
    }
    
    $dd *= 1;
    $mm--;
    $yy = ($yy < 70) ? $yy + 2000 : $yy;
    $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

    if ($myconfig->{dateformat} =~ /^dd/) {
      $longdate = "$dd. ".&text($self, $self->{$longmonth}[$mm])." $yy";
    } else {
      $longdate = &text($self, $self->{$longmonth}[$mm])." $dd, $yy";
    }

  }

  $longdate;

}


1;

