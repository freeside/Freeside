#=================================================================
# SQL-Ledger Accounting
# Copyright (C) 2000
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
# Contributors: Thomas Bayen <bayen@gmx.de>
#               Antti Kaihola <akaihola@siba.fi>
#               Moritz Bunkus (tex)
#               Jim Rawlings <jim@your-dba.com> (DB2)
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
#
# main package
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

  $self->{menubar} = 1 if $self->{path} =~ /lynx/i;

  if (substr($self->{action}, 0, 1) !~ /( |\.)/) {
    $self->{action} = lc $self->{action};
    $self->{action} =~ s/(( |-|,|#|\/)|\.$)/_/g;
  }

  $self->{version} = "2.4.4";
  $self->{dbversion} = "2.4.4";

  bless $self, $type;
  
}


sub debug {
  my ($self) = @_;
  
  print "\n";
  
  map { print "$_ = $self->{$_}\n" } (sort keys %$self);
  
} 

  
sub escape {
  my ($self, $str, $beenthere) = @_;

  # for Apache 2 we escape strings twice
  if (($ENV{SERVER_SIGNATURE} =~ /Apache\/2\.(\d+)\.(\d+)/) && !$beenthere) {
    $str = $self->escape($str, 1) if $2 < 44;
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


sub quote {
  my ($self, $str) = @_;

  if ($str && ! ref($str)) {
    $str =~ s/"/&quot;/g;
  }

  $str;

}


sub hide_form {
  my $self = shift;

  map { print qq|<input type=hidden name=$_ value="|.$self->quote($self->{$_}).qq|">\n| } sort keys %$self;
  
}

  
sub error {
  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;

    delete $self->{pre};

    if (!$self->{header}) {
      $self->header;
    }

    print qq|<body><h2 class=error>Error!</h2>

    <p><b>$msg</b>|;

    exit;

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

    delete $self->{pre};

    if (!$self->{header}) {
      $self->header;
      print qq|
      <body>|;
      $self->{header} = 1;
    }

    print "<br><b>$msg</b>";

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

  my $rows = 0;

  map { $rows += int (((length) - 2)/$cols) + 1 } split /\r/, $str;

  $maxrows = $rows unless defined $maxrows;

  return ($rows > $maxrows) ? $maxrows : $rows;

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
  my ($self, $init) = @_;

  return if $self->{header};

  my ($stylesheet, $favicon, $charset);

  if ($ENV{HTTP_USER_AGENT}) {

    if ($self->{stylesheet} && (-f "css/$self->{stylesheet}")) {
      $stylesheet = qq|<LINK REL="stylesheet" HREF="css/$self->{stylesheet}" TYPE="text/css" TITLE="SQL-Ledger stylesheet">
  |;
    }

    if ($self->{favicon} && (-f "$self->{favicon}")) {
      $favicon = qq|<LINK REL="shortcut icon" HREF="$self->{favicon}" TYPE="image/x-icon">
  |;
    }

    if ($self->{charset}) {
      $charset = qq|<META HTTP-EQUIV="Content-Type" CONTENT="text/plain; charset=$self->{charset}">
  |;
    }

    $self->{titlebar} = ($self->{title}) ? "$self->{title} - $self->{titlebar}" : $self->{titlebar};

    $self->set_cookie($init);

    print qq|Content-Type: text/html

<head>
  <title>$self->{titlebar}</title>
  $favicon
  $stylesheet
  $charset
</head>

$self->{pre}
|;
  }

  $self->{header} = 1;

}


sub set_cookie {
  my ($self, $init) = @_;

  $self->{timeout} = ($self->{timeout} > 0) ? $self->{timeout} : 3600;

  if ($self->{endsession}) {
    $_ = time;
  } else {
    $_ = time + $self->{timeout};
  }

  if ($ENV{HTTP_USER_AGENT}) {

    my @d = split / +/, scalar gmtime($_);
    my $today = "$d[0], $d[2]-$d[1]-$d[4] $d[3] GMT";

    if ($init) {
      $self->{sessionid} = time;
    }
    print qq|Set-Cookie: SQL-Ledger-$self->{login}=$self->{sessionid}; expires=$today; path=/;\n| if $self->{login};
  }

}

 
sub redirect {
  my ($self, $msg) = @_;

  if ($self->{callback}) {

    ($script, $argv) = split(/\?/, $self->{callback});
    exec ("perl", "$script", $argv);
   
  } else {
    
    $self->info($msg);
    exit;
  }

}


sub sort_columns {
  my ($self, @columns) = @_;

  if ($self->{sort}) {
    if (@columns) {
      @columns = grep !/^$self->{sort}$/, @columns;
      splice @columns, 0, 0, $self->{sort};
    }
  }

  @columns;
  
}


sub sort_order {
  my ($self, $columns, $ordinal) = @_;

  # setup direction
  if ($self->{direction}) {
    if ($self->{sort} eq $self->{oldsort}) {
      if ($self->{direction} eq 'ASC') {
	$self->{direction} = "DESC";
      } else {
	$self->{direction} = "ASC";
      }
    }
  } else {
    $self->{direction} = "ASC";
  }
  $self->{oldsort} = $self->{sort};

  my $sortorder = join ',', $self->sort_columns(@{$columns});
  
  if ($ordinal) {
    map { $sortorder =~ s/$_/$ordinal->{$_}/ } keys %$ordinal;
  }
  my @a = split /,/, $sortorder;
  $a[0] = "$a[0] $self->{direction}";
  $sortorder = join ',', @a;

  $sortorder;

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

      if ($myconfig->{numberformat} eq "1'000.00") {
	$amount =~ s/\d{3,}?/$&'/g;
	$amount =~ s/'$//;
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

  if ($myconfig->{numberformat} eq "1'000.00") {
    $amount =~ s/'//g;
  }

  $amount =~ s/,//g;
  
  return ($amount * 1);

}


sub round_amount {
  my ($self, $amount, $places) = @_;

#  $places = 3 if $places == 2;
  
  if (($places * 1) >= 0) {
    # add 1/10^$places+3
    sprintf("%.${places}f", $amount + (1 / (10 ** ($places + 3))) * (($amount > 0) ? 1 : -1));
  } else {
    $places *= -1;
    sprintf("%.f", $amount / (10 ** $places) + (($amount > 0) ? 0.1 : -0.1)) * (10 ** $places);
  }

}


sub parse_template {
  my ($self, $myconfig, $userspath) = @_;

  my ($chars_per_line, $lines_on_first_page, $lines_on_second_page) = (0, 0, 0);
  my ($current_page, $current_line) = (1, 1);
  my $pagebreak = "";
  my $sum = 0;

  my $subdir = "";
  my $err = "";

  if ($self->{language_code}) {
    if (-f "$self->{templates}/$self->{language_code}/$self->{IN}") {
      open(IN, "$self->{templates}/$self->{language_code}/$self->{IN}") or $self->error("$self->{IN} : $!");
    } else {
      open(IN, "$self->{templates}/$self->{IN}") or $self->error("$self->{IN} : $!");
    }
  } else {
    open(IN, "$self->{templates}/$self->{IN}") or $self->error("$self->{IN} : $!");
  }

  @_ = <IN>;
  close(IN);
  
  $self->{copies} = 1 if (($self->{copies} *= 1) <= 0);
  
  # OUT is used for the media, screen, printer, email
  # for postscript we store a copy in a temporary file
  my $fileid = time;
  my $tmpfile = $self->{IN};
  $tmpfile =~ s/\./\.$self->{fileid}./ if $self->{fileid};
  $self->{tmpfile} = "$userspath/${fileid}.${tmpfile}";
  
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


    # detect pagebreak block and its parameters
    if (/\s*<%pagebreak ([0-9]+) ([0-9]+) ([0-9]+)%>/) {
      $chars_per_line = $1;
      $lines_on_first_page = $2;
      $lines_on_second_page = $3;
      
      while ($_ = shift) {
        last if (/\s*<%end pagebreak%>/);
        $pagebreak .= $_;
      }
    }

    
    if (/\s*<%foreach /) {
      
      # this one we need for the count
      chomp $var;
      $var =~ s/\s*<%foreach (.+?)%>/$1/;
      while ($_ = shift) {
	last if (/\s*<%end /);

	# store line in $par
	$par .= $_;
      }
      
      # display contents of $self->{number}[] array
      for $i (0 .. $#{ $self->{$var} }) {

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

	# don't parse par, we need it for each line
	print OUT $self->format_line($par, $i);
	
      }
      next;
    }

    # if not comes before if!
    if (/\s*<%if not /) {
      # check if it is not set and display
      chop;
      s/\s*<%if not (.+?)%>/$1/;

      unless ($self->{$_}) {
	while ($_ = shift) {
	  last if (/\s*<%end /);

	  # store line in $par
	  $par .= $_;
	}
	
	$_ = $par;
	
      } else {
	while ($_ = shift) {
	  last if (/\s*<%end /);
	}
	next;
      }
    }
 
    if (/\s*<%if /) {
      # check if it is set and display
      chop;
      s/\s*<%if (.+?)%>/$1/;

      if ($self->{$_}) {
	while ($_ = shift) {
	  last if (/\s*<%end /);

	  # store line in $par
	  $par .= $_;
	}
	
	$_ = $par;
	
      } else {
	while ($_ = shift) {
	  last if (/\s*<%end /);
	}
	next;
      }
    }
   
    # check for <%include filename%>
    if (/\s*<%include /) {
      
      # get the filename
      chomp $var;
      $var =~ s/\s*<%include (.+?)%>/$1/;

      # mangle filename
      $var =~ s/(\/|\.\.)//g;

      # prevent the infinite loop!
      next if ($self->{"$var"});

      unless (open(INC, "$self->{templates}/$var")) {
        $err = $!;
	$self->cleanup;
	$self->error("$self->{templates}/$var : $err");
      }
      unshift(@_, <INC>);
      close(INC);

      $self->{"$var"} = 1;

      next;
    }
    
    print OUT $self->format_line($_);
    
  }

  close(OUT);


  # Convert the tex file to postscript
  if ($self->{format} =~ /(postscript|pdf)/) {

    use Cwd;
    $self->{cwd} = cwd();
    $self->{tmpdir} = "$self->{cwd}/$userspath";

    unless (chdir("$userspath")) {
      $err = $!;
      $self->cleanup;
      $self->error("chdir : $err");
    }

    $self->{tmpfile} =~ s/$userspath\///g;

    if ($self->{format} eq 'postscript') {
      system("latex --interaction=nonstopmode $self->{tmpfile} > $self->{tmpfile}.err");
      $self->error($self->cleanup) if ($?);
 
      $self->{tmpfile} =~ s/tex$/dvi/;
 
      system("dvips $self->{tmpfile} -o -q");
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
      
      map { $mail->{$_} = $self->{$_} } qw(cc bcc subject message version format charset);
      $mail->{to} = qq|$self->{email}|;
      $mail->{from} = qq|"$myconfig->{name}" <$myconfig->{email}>|;
      $mail->{fileid} = "$fileid.";

      # if we send html or plain text inline
      if (($self->{format} =~ /(html|txt)/) && ($self->{sendmode} eq 'inline')) {
	my $br = "";
	$br = "<br>" if $self->{format} eq 'html';
	  
	$mail->{contenttype} = "text/$self->{format}";

        $mail->{message} =~ s/\r\n/$br\n/g;
	$myconfig->{signature} =~ s/\\n/$br\n/g;
	$mail->{message} .= "$br\n-- $br\n$myconfig->{signature}\n$br" if $myconfig->{signature};
	
	unless (open(IN, $self->{tmpfile})) {
	  $err = $!;
	  $self->cleanup;
	  $self->error("$self->{tmpfile} : $err");
	}

	while (<IN>) {
	  $mail->{message} .= $_;
	}

	close(IN);

      } else {
	
	@{ $mail->{attachments} } = ($self->{tmpfile});

	$myconfig->{signature} =~ s/\\n/\r\n/g;
	$mail->{message} .= "\r\n-- \r\n$myconfig->{signature}" if $myconfig->{signature};

      }
 
      if ($err = $mail->send($out)) {
	$self->cleanup;
	$self->error($err);
      }
      
    } else {
      
      $self->{OUT} = $out;
      unless (open(IN, $self->{tmpfile})) {
        $err = $!;
	$self->cleanup;
	$self->error("$self->{tmpfile} : $err");
      }

      binmode(IN);

      $self->{copies} = 1 if $self->{media} =~ /(screen|email|queue)/;

      chdir("$self->{cwd}");
      
      for my $i (1 .. $self->{copies}) {
	if ($self->{OUT}) {
	  unless (open(OUT, $self->{OUT})) {
            $err = $!;
	    $self->cleanup;
	    $self->error("$self->{OUT} : $err");
	  }
	} else {

	  # launch application
	  print qq|Content-Type: application/$self->{format}
Content-Disposition: attachment; filename="$self->{tmpfile}"\n\n|;

	  unless (open(OUT, ">-")) {
	    $err = $!;
	    $self->cleanup;
	    $self->error("STDOUT : $err");
	  }

	}

	binmode(OUT);
       
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

}


sub format_line {
  my $self = shift;

  $_ = shift;
  my $i = shift;
  my ($str, $pos, $l, $item, $newstr);
  my $var = "";
  my %a;

  while (/<%(.+?)%>/) {

    %a = ();

    foreach $item (split / /, $1) {
      my ($key, $value) = split /=/, $item;
      if (defined $value) {
	$a{$key} = $value;
      } else {
	$var = $item;
      }
    }

    $str = (defined $i) ? $self->{$var}[$i] : $self->{$var};

    if ($a{align} || $a{width} || $a{offset}) {

      $str =~ s/(|\n)+/" " x $a{offset}/ge;
      $l = length $str;

      if ($l > $a{width}) {
	if (($pos = rindex $str, " ", $a{width}) > 0) {
	  $newstr = substr($str, 0, $pos);
	  $newstr .= "\n";
	  $str = substr($str, $pos + 1);

	  while (length $str > $a{width}) {
	    if (($pos = rindex $str, " ", $a{width}) > 0) {
	      $newstr .= (" " x $a{offset}).substr($str, 0, $pos);
	      $newstr .= "\n";
	      $str = substr($str, $pos + 1);
	    } else {
	      $newstr .= (" " x $a{offset}).substr($str, 0, $a{width});
	      $newstr .= "\n";
	      $str = substr($str, $a{width} + 1);
	    }
	  }
	}
	$l = length $str;
	$str .= " " x ($a{width} - $l);
	$newstr .= (" " x $a{offset}).$str;
	$str = $newstr;

	$l = $a{width};
      }

      # pad left, right or center
      $pos = lc $a{align};
      $l = ($a{width} - $l);
      
      my $pad = " " x $l;
      
      if ($pos eq 'right') {
	$str = "$pad$str";
      }

      if ($pos eq 'left') {
	$str = "$str$pad";
      }

      if ($pos eq 'center') {
	$pad = " " x ($l/2);
	$str = "$pad$str";
	$pad = " " x ($l/2 + 1) if ($l % 2);
	$str .= "$pad";
      }
    }

    s/<%(.+?)%>/$str/;

  }

  $_;

}


sub cleanup {
  my $self = shift;

  chdir("$self->{tmpdir}");
  
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

  my %replace = ( 'order' => { html => [ '<', '>', quotemeta('\n'), '' ],
                               txt  => [ quotemeta('\n') ],
                               tex  => [ '&', quotemeta('\n'), '',
					   '\$', '%', '_', '#', quotemeta('^'),
					   '{', '}', '<', '>', '£',
					   quotemeta('\\\\') ] },
                   html => { '<' => '&lt;', '>' => '&gt;',
                quotemeta('\n') => '<br>', '' => '<br>'
		            },
		   txt  => { quotemeta('\n') },
	           tex  => {
	        '&' => '\&', '\$' => '\$', '%' => '\%', '_' => '\_',
		'#' => '\#', quotemeta('^') => '\^\\', '{' => '\{', '}' => '\}',
		'<' => '$<$', '>' => '$>$',
		quotemeta('\n') => '\newline ', '' => '\newline ',
		'£' => '\pounds ', quotemeta('\\\\') => '$\backslash$'
                            }
	        );

  foreach my $key (@{ $replace{order}{$format} }) {
    map { $self->{$_} =~ s/$key/$replace{$format}{$key}/g; } @fields;
  }

}


sub datetonum {
  my ($self, $date, $myconfig) = @_;

  if ($date && $date =~ /\D/) {

    if ($myconfig->{dateformat} =~ /^yy/) {
      ($yy, $mm, $dd) = split /\D/, $date;
    }
    if ($myconfig->{dateformat} =~ /^mm/) {
      ($mm, $dd, $yy) = split /\D/, $date;
    }
    if ($myconfig->{dateformat} =~ /^dd/) {
      ($dd, $mm, $yy) = split /\D/, $date;
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
    $dbh->do($myconfig->{dboptions});
  }

  $dbh;

}


sub dbquote {
  my ($self, $var, $type) = @_;

  my $rv = 'NULL';
  
  # DBI does not return NULL for SQL_DATE if the date is empty, bug ?
  if (defined $var) {
    if (defined $type) {
      if ($type eq 'SQL_DATE') {
	$rv = "'$var'" if $var;
      } elsif ($type eq 'SQL_INT.*') {
	$rv = int $var;
      } else {
	if ($type !~ /SQL_.*CHAR/) {
	  $rv = $var * 1;
	} else {
	  $var =~ s/'/''/g;
	  $rv = "'$var'";
	}
      }
    } else {
      $var =~ s/'/''/g;
      $rv = "'$var'";
    }
  }

  $rv;

}


sub update_balance {
  my ($self, $dbh, $table, $field, $where, $value) = @_;

  # if we have a value, go do it
  if ($value != 0) {
    # retrieve balance from table
    my $query = "SELECT $field FROM $table WHERE $where FOR UPDATE";
    my ($balance) = $dbh->selectrow_array($query);

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
	         AND transdate = '$transdate'
		 FOR UPDATE|;
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


sub save_exchangerate {
  my ($self, $myconfig, $currency, $transdate, $rate, $fld) = @_;

  my $dbh = $self->dbconnect($myconfig);

  my ($buy, $sell) = (0, 0);
  $buy = $rate if $fld eq 'buy';
  $sell = $rate if $fld eq 'sell';
  
  $self->update_exchangerate($dbh, $currency, $transdate, $buy, $sell);

  $dbh->disconnect;
  
}


sub get_exchangerate {
  my ($self, $dbh, $curr, $transdate, $fld) = @_;
  
  my $query = qq|SELECT $fld FROM exchangerate
                 WHERE curr = '$curr'
		 AND transdate = '$transdate'|;
  my ($exchangerate) = $dbh->selectrow_array($query);

  $exchangerate;

}


sub check_exchangerate {
  my ($self, $myconfig, $currency, $transdate, $fld) = @_;

  return "" unless $transdate;
  
  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|SELECT $fld FROM exchangerate
                 WHERE curr = '$currency'
		 AND transdate = '$transdate'|;
  my ($exchangerate) = $dbh->selectrow_array($query);
  
  $dbh->disconnect;
  
  $exchangerate;
  
}


sub add_shipto {
  my ($self, $dbh, $id) = @_;

  my $shipto;
  foreach my $item (qw(name address1 address2 city state zipcode country contact phone fax email)) {
    if ($self->{"shipto$item"}) {
      $shipto = 1 if ($self->{$item} ne $self->{"shipto$item"});
    }
  }

  if ($shipto) {
    my $query = qq|INSERT INTO shipto (trans_id, shiptoname, shiptoaddress1,
                   shiptoaddress2, shiptocity, shiptostate,
		   shiptozipcode, shiptocountry, shiptocontact,
		   shiptophone, shiptofax, shiptoemail) VALUES ($id, |
		   .$dbh->quote($self->{shiptoname}).qq|, |
		   .$dbh->quote($self->{shiptoaddress1}).qq|, |
		   .$dbh->quote($self->{shiptoaddress2}).qq|, |
		   .$dbh->quote($self->{shiptocity}).qq|, |
		   .$dbh->quote($self->{shiptostate}).qq|, |
		   .$dbh->quote($self->{shiptozipcode}).qq|, |
		   .$dbh->quote($self->{shiptocountry}).qq|, |
		   .$dbh->quote($self->{shiptocontact}).qq|,
		   '$self->{shiptophone}', '$self->{shiptofax}',
		   '$self->{shiptoemail}')|;
    $dbh->do($query) || $self->dberror($query);
  }

}


sub get_employee {
  my ($self, $dbh) = @_;

  my $login = $self->{login};
  $login =~ s/@.*//;
  my $query = qq|SELECT name, id FROM employee 
                 WHERE login = '$login'|;
  my (@a) = $dbh->selectrow_array($query);
  $a[1] *= 1;
  
  @a;

}


# this sub gets the id and name from $table
sub get_name {
  my ($self, $myconfig, $table) = @_;

  # connect to database
  my $dbh = $self->dbconnect($myconfig);
  
  my $name = $self->like(lc $self->{$table});
  my $query = qq~SELECT c.id, c.name, c.address1, c.address2,
		 c.city, c.state, c.zipcode, c.country
                 FROM $table c
		 WHERE lower(c.name) LIKE '$name'
		 ORDER BY c.name~;

  if ($self->{openinvoices}) {
    $query = qq~SELECT DISTINCT c.id, c.name, c.address1, c.address2,
		c.city, c.state, c.zipcode, c.country
		FROM $self->{arap} a
		JOIN $table c ON (a.${table}_id = c.id)
		WHERE a.amount != a.paid
		AND lower(c.name) LIKE '$name'
		ORDER BY c.name~;
  }
    
  my $sth = $dbh->prepare($query);

  $sth->execute || $self->dberror($query);

  my $i = 0;
  @{ $self->{name_list} } = ();
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
  my ($self, $myconfig, $table, $module, $dbh, $enddate) = @_;
  
  my $ref;
  my $closedb;
  if (! defined $dbh) {
    $dbh = $self->dbconnect($myconfig);
    $closedb = 1;
  }
  my $sth;
  
  my $query = qq|SELECT count(*) FROM $table|;
  my $where;
  
  if (defined $enddate) {
    $where = qq|AND (enddate IS NULL OR enddate >= '$enddate')|;
    $query .= qq| WHERE 1=1
                 $where|;
  }
  my ($count) = $dbh->selectrow_array($query);

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT id, name
		FROM $table
		WHERE 1=1
		$where
		ORDER BY name|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $self->{"all_$table"} }, $ref;
    }
    $sth->finish;
    
  }

  
  # get self
  if (! $self->{employee_id}) {
    ($self->{employee}, $self->{employee_id}) = split /--/, $self->{employee};
    ($self->{employee}, $self->{employee_id}) = $self->get_employee($dbh) unless $self->{employee_id};
  }
  
  # setup sales contacts
  $query = qq|SELECT id, name
	      FROM employee
	      WHERE sales = '1'
	      $where
	      ORDER BY name|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_employees} }, $ref;
  }
  $sth->finish;


  if ($module eq 'AR') {
    # prepare query for departments
    $query = qq|SELECT id, description
		FROM department
		WHERE role = 'P'
		ORDER BY 2|;
     
  } else {
    $query = qq|SELECT id, description
		FROM department
		ORDER BY 2|;
  }
  
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_departments} }, $ref;
  }
  $sth->finish;


  # get projects
  $query = qq|SELECT *
              FROM project
	      ORDER BY projectnumber|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{all_projects} = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_projects} }, $ref;
  }
  $sth->finish;
  
  # get language codes
  $query = qq|SELECT *
              FROM language
	      ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{all_languages} = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_languages} }, $ref;
  }
  $sth->finish;

  $self->all_years($dbh, $myconfig);

  $dbh->disconnect if $closedb;

}


# this is only used for reports
sub all_projects {
  my ($self, $myconfig) = @_;
  
  my $dbh = $self->dbconnect($myconfig);
  
  my $query = qq|SELECT *
                 FROM project
	         ORDER BY projectnumber|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{all_projects} = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_projects} }, $ref;
  }
  $sth->finish;
  
  $dbh->disconnect;

}


sub all_departments {
  my ($self, $myconfig, $table) = @_;
  
  my $dbh = $self->dbconnect($myconfig);
  my $where = "1 = 1";
  
  if (defined $table) {
    if ($table eq 'customer') {
      $where = " role = 'P'";
    }
  }
  
  my $query = qq|SELECT id, description
                 FROM department
	         WHERE $where
	         ORDER BY 2|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_departments} }, $ref;
  }
  $sth->finish;
  
  $self->all_years($dbh, $myconfig);
  
  $dbh->disconnect;

}


sub all_years {
  my ($self, $dbh, $myconfig) = @_;
  
  # get years
  my $query = qq|SELECT (SELECT MIN(transdate) FROM acc_trans),
                     (SELECT MAX(transdate) FROM acc_trans)
              FROM defaults|;
  my ($startdate, $enddate) = $dbh->selectrow_array($query);

  if ($myconfig->{dateformat} =~ /^yy/) {
    ($startdate) = split /\W/, $startdate;
    ($enddate) = split /\W/, $enddate;
  } else { 
    (@_) = split /\W/, $startdate;
    $startdate = @_[2];
    (@_) = split /\W/, $enddate;
    $enddate = @_[2]; 
  }

  while ($enddate >= $startdate) {
    push @{ $self->{all_years} }, $enddate--;
  }

  %{ $self->{all_month} } = ( '01' => 'January',
			  '02' => 'February',
			  '03' => 'March',
			  '04' => 'April',
			  '05' => 'May ',
			  '06' => 'June',
			  '07' => 'July',
			  '08' => 'August',
			  '09' => 'September',
			  '10' => 'October',
			  '11' => 'November',
			  '12' => 'December' );
  
}


sub create_links {
  my ($self, $module, $myconfig, $table) = @_;
 
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
    
    foreach my $key (split /:/, $ref->{link}) {
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
		a.taxincluded, a.curr AS currency, a.notes, a.intnotes,
		c.name AS $table, a.department_id, d.description AS department,
		a.amount AS oldinvtotal, a.paid AS oldtotalpaid,
		a.employee_id, e.name AS employee, c.language_code
		FROM $arap a
		JOIN $table c ON (a.${table}_id = c.id)
		LEFT JOIN employee e ON (e.id = a.employee_id)
		LEFT JOIN department d ON (d.id = a.department_id)
		WHERE a.id = $self->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    
    $ref = $sth->fetchrow_hashref(NAME_lc);
    foreach $key (keys %$ref) {
      $self->{$key} = $ref->{$key};
    }
    $sth->finish;


    # get printed, emailed
    $query = qq|SELECT s.printed, s.emailed, s.spoolfile, s.formname
                FROM status s
		WHERE s.trans_id = $self->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $self->{printed} .= "$ref->{formname} " if $ref->{printed};
      $self->{emailed} .= "$ref->{formname} " if $ref->{emailed};
      $self->{queued} .= "$ref->{formname} $ref->{spoolfile} " if $ref->{spoolfile};
    }
    $sth->finish;
    map { $self->{$_} =~ s/ +$//g } qw(printed emailed queued);


    # get amounts from individual entries
    $query = qq|SELECT c.accno, c.description, a.source, a.amount, a.memo,
                a.transdate, a.cleared, a.project_id, p.projectnumber
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		LEFT JOIN project p ON (p.id = a.project_id)
		WHERE a.trans_id = $self->{id}
		AND a.fx_transaction = '0'
		ORDER BY transdate|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    
    my $fld = ($table eq 'customer') ? 'buy' : 'sell';

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

    if (! $self->{"$self->{vc}_id"}) {
      $self->lastname_used($dbh, $myconfig, $table, $module);
    }

  }

  $self->all_vc($myconfig, $table, $module, $dbh, $self->{transdate});
 
  $dbh->disconnect;

}


sub lastname_used {
  my ($self, $dbh, $myconfig, $table, $module) = @_;

  my $arap = ($table eq 'customer') ? "ar" : "ap";
  my $where = "1 = 1";
  my $sth;
  
  if ($self->{type} =~ /_order/) {
    $arap = 'oe';
    $where = "quotation = '0'";
  }
  if ($self->{type} =~ /_quotation/) {
    $arap = 'oe'; 
    $where = "quotation = '1'";
  }
  
  my $query = qq|SELECT id FROM $arap
                 WHERE id IN (SELECT MAX(id) FROM $arap
		              WHERE $where
			      AND ${table}_id > 0)|;
  my ($trans_id) = $dbh->selectrow_array($query);
  
  $trans_id *= 1;

  my $DAYS = ($myconfig->{dbdriver} eq 'DB2') ? "DAYS" : "";
  
  $query = qq|SELECT ct.name AS $table, a.curr AS currency, a.${table}_id,
              current_date + ct.terms $DAYS AS duedate, a.department_id,
	      d.description AS department, ct.notes, ct.curr AS currency
	      FROM $arap a
	      JOIN $table ct ON (a.${table}_id = ct.id)
	      LEFT JOIN department d ON (a.department_id = d.id)
	      WHERE a.id = $trans_id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $self->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

}



sub current_date {
  my ($self, $myconfig, $thisdate, $days) = @_;
  
  my $dbh = $self->dbconnect($myconfig);
  my ($sth, $query);

  $days *= 1;
  if ($thisdate) {
    my $dateformat = $myconfig->{dateformat};
    if ($myconfig->{dateformat} !~ /^y/) {
      my @a = split /\D/, $thisdate;
      $dateformat .= "yy" if (length $a[2] > 2);
    }
    
    if ($thisdate !~ /\D/) {
      $dateformat = 'yyyymmdd';
    }
    
    if ($myconfig->{dbdriver} eq 'DB2') {
      $query = qq|SELECT date('$thisdate') + $days DAYS AS thisdate
                  FROM defaults|;
    } else {
      $query = qq|SELECT to_date('$thisdate', '$dateformat') + $days AS thisdate
		  FROM defaults|;
    }

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
  my ($self, $str) = @_;
  
  if ($str !~ /(%|_)/) {
    $str = "%$str%";
  }

  $str =~ s/'/''/g;
  $str;
  
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


sub get_partsgroup {
  my ($self, $myconfig, $p) = @_;

  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|SELECT DISTINCT pg.id, pg.partsgroup
                 FROM partsgroup pg
		 JOIN parts p ON (p.partsgroup_id = pg.id)|;

  if ($p->{searchitems} eq 'part') {
    $query .= qq|
                 WHERE p.inventory_accno_id > 0|;
  }
  if ($p->{searchitems} eq 'service') {
    $query .= qq|
                 WHERE p.inventory_accno_id IS NULL|;
  }
  if ($p->{searchitems} eq 'assembly') {
    $query .= qq|
                 WHERE p.assembly = '1'|;
  }
  if ($p->{searchitems} eq 'labor') {
    $query .= qq|
                 WHERE p.inventory_accno_id > 0 AND p.income_accno_id IS NULL|;
  }

  $query .= qq|
		 ORDER BY partsgroup|;

  if ($p->{all}) {
    $query = qq|SELECT id, partsgroup FROM partsgroup
                ORDER BY partsgroup|;
  } 

  if ($p->{language_code}) {
    $query = qq|SELECT DISTINCT pg.id, pg.partsgroup,
                t.description AS translation
                FROM partsgroup pg
		JOIN parts p ON (p.partsgroup_id = pg.id)
		LEFT JOIN translation t ON (t.trans_id = pg.id AND t.language_code = '$p->{language_code}')
		ORDER BY translation|;
  }

  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{all_partsgroup} = ();
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_partsgroup} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;

}


sub update_status {
  my ($self, $myconfig) = @_;

  # no id return
  return unless $self->{id};

  my $i;
  my $id;
 
  my $dbh = $self->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM status
                 WHERE formname = |.$dbh->quote($self->{formname}).qq|
		 AND trans_id = ?|;
  my $sth = $dbh->prepare($query) || $self->dberror($query);

  if ($self->{formname} =~ /(check|receipt)/) {
    for $i (1 .. $self->{rowcount}) {
      $sth->execute($self->{"id_$i"} * 1) || $self->dberror($query);
      $sth->finish;
    }
  } else {
    $sth->execute($self->{id}) || $self->dberror($query);
    $sth->finish;
  }

  my $printed = ($self->{printed} =~ /$self->{formname}/) ? "1" : "0";
  my $emailed = ($self->{emailed} =~ /$self->{formname}/) ? "1" : "0";
  
  my %queued = split / /, $self->{queued};

  if ($self->{formname} =~ /(check|receipt)/) {
    # this is a check or receipt, add one entry for each lineitem
    my ($accno) = split /--/, $self->{account};
    $query = qq|INSERT INTO status (trans_id, printed, spoolfile, formname,
		chart_id) VALUES (?, '$printed',|
		.$dbh->quote($queued{$self->{formname}}).qq|, |
		.$dbh->quote($self->{formname}).qq|,
		(SELECT id FROM chart WHERE accno = |
		.$dbh->quote($accno).qq|))|;
    $sth = $dbh->prepare($query) || $self->dberror($query);

    for $i (1 .. $self->{rowcount}) {
      if ($self->{"checked_$i"}) {
	$sth->execute($self->{"id_$i"}) || $self->dberror($query);
	$sth->finish;
      }
    }
  } else {
    $query = qq|INSERT INTO status (trans_id, printed, emailed,
		spoolfile, formname)
		VALUES ($self->{id}, '$printed', '$emailed', |
		.$dbh->quote($queued{$self->{formname}}).qq|, |
		.$dbh->quote($self->{formname}).qq|)|;
    $dbh->do($query) || $self->dberror($query);
  }

  $dbh->commit;
  $dbh->disconnect;

}


sub save_status {
  my ($self, $dbh) = @_;

  my ($query, $printed, $emailed);

  my $formnames = $self->{printed};
  my $emailforms = $self->{emailed};

  my $query = qq|DELETE FROM status
                 WHERE formname = '$self->{formname}'
		 AND trans_id = $self->{id}|;
  $dbh->do($query) || $self->dberror($query);

  if ($self->{queued}) {
    $query = qq|DELETE FROM status
                WHERE spoolfile IS NOT NULL
		AND trans_id = $self->{id}|;
    $dbh->do($query) || $self->dberror($query);
   
    my %queued = split / /, $self->{queued};

    foreach my $formname (keys %queued) {
      $printed = ($self->{printed} =~ /$self->{formname}/) ? "1" : "0";
      $emailed = ($self->{emailed} =~ /$self->{formname}/) ? "1" : "0";
      
      $query = qq|INSERT INTO status (trans_id, printed, emailed,
                  spoolfile, formname)
		  VALUES ($self->{id}, '$printed', '$emailed',
		  '$queued{$formname}', '$formname')|;
      $dbh->do($query) || $self->dberror($query);
      $formnames =~ s/$formname//;
      $emailforms =~ s/$formname//;
      
    }
  }

  # save printed, emailed info
  $formnames =~ s/^ +//g;
  $emailforms =~ s/^ +//g;

  my %status = ();
  map { $status{$_}{printed} = 1 } split / +/, $formnames;
  map { $status{$_}{emailed} = 1 } split / +/, $emailforms;
  
  foreach my $formname (keys %status) {
    $printed = ($formnames =~ /$self->{formname}/) ? "1" : "0";
    $emailed = ($emailforms =~ /$self->{formname}/) ? "1" : "0";
    
    $query = qq|INSERT INTO status (trans_id, printed, emailed, formname)
		VALUES ($self->{id}, '$printed', '$emailed', '$formname')|;
    $dbh->do($query) || $self->dberror($query);
  }

}


sub save_intnotes {
  my ($self, $myconfig, $table) = @_;

  # no id return
  return unless $self->{id};

  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|UPDATE $table SET
                 intnotes = |.$dbh->quote($self->{intnotes}).qq|
                 WHERE id = $self->{id}|;
  $dbh->do($query) || $self->dberror($query);

  $dbh->disconnect;

}


sub update_defaults {
  my ($self, $myconfig, $fld, $dbh) = @_;

  my $closedb;
  
  if (! defined $dbh) {
    $dbh = $self->dbconnect_noauto($myconfig);
    $closedb = 1;
  }
  
  my $query = qq|SELECT $fld FROM defaults FOR UPDATE|;
  ($_) = $dbh->selectrow_array($query);

  $_ = "0" unless $_;

  # check for and replace
  # <%DATE%>, <%YYMMDD%> or variations of
  # <%NAME 1 1 3%>, <%BUSINESS%>, <%BUSINESS 10%>, <%CURR...%>
  # <%DESCRIPTION 1 1 3%>, <%ITEM 1 1 3%>, <%PARTSGROUP 1 1 3%> only for parts
  # <%PHONE%> for customer and vendors
  
  my $num = $_;
  $num =~ s/(<%.*?%>)//g;
  ($num) = $num =~ /(\d+)/;
  if (defined $num) {
    my $incnum;
    # if we have leading zeros check how long it is
    if ($num =~ /^0/) {
      my $l = length $num;
      $incnum = $num + 1;
      $l -= length $incnum;

      # pad it out with zeros
      my $padzero = "0" x $l;
      $incnum = ("0" x $l) . $incnum;
    } else {
      $incnum = $num + 1;
    }
      
    s/$num/$incnum/;
  }

  my $dbvar = $_;
  my $var = $_;
  my $str;
  my $param;
  
  if (/<%/) {
    while (/<%/) {
      s/<%.*?%>//;
      last unless $&;
      $param = $&;
      $str = "";
      
      if ($param =~ /<%date%>/i) {
	$str = ($self->split_date($myconfig->{dateformat}, $self->{transdate}))[0];
	$var =~ s/$param/$str/;
      }

      if ($param =~ /<%(name|business|description|item|partsgroup|phone|custom)/i) {
	my $fld = lc $&;
	$fld =~ s/<%//;
	if ($fld =~ /name/) {
	  if ($self->{type}) {
	    $fld = $self->{vc};
	  }
	}

        my $p = $param;
	$p =~ s/(<|>|%)//g;
	my @p = split / /, $p;
	my @n = split / /, uc $self->{$fld};
	if ($#p > 0) {
	  for (my $i = 1; $i <= $#p; $i++) {
	    $str .= substr($n[$i-1], 0, $p[$i]);
	  }
	} else {
	  ($str) = split /--/, $self->{$fld};
	}
	$var =~ s/$param/$str/;

	$var =~ s/\W//g if $fld eq 'phone';
      }
	
      if ($param =~ /<%(yy|mm|dd)/i) {
        my $p = $param;
	$p =~ s/(<|>|%)//g;
	my $spc = $p;
	$spc =~ s/\w//g;
	$spc = substr($spc, 0, 1);
	my %d = ( yy => 1, mm => 2, dd => 3 );
	my @p = ();

	my @a = $self->split_date($myconfig->{dateformat}, $self->{transdate});
	map { push @p, $a[$d{$_}] if ($p =~ /$_/) } sort keys %d;
	$str = join $spc, @p;

	$var =~ s/$param/$str/;
      }
      
      if ($param =~ /<%curr/i) {
	$var =~ s/$param/$self->{currency}/;
      }

    }
  }

  $query = qq|UPDATE defaults
              SET $fld = '$dbvar'|;
  $dbh->do($query) || $form->dberror($query);

  if ($closedb) {
    $dbh->commit;
    $dbh->disconnect;
  }

  $var;

}


sub split_date {
  my ($self, $dateformat, $date) = @_;
  
  my @d = localtime;
  my $mm;
  my $dd;
  my $yy;
  my $rv;

  if (! $date) {
    $dd = $d[3];
    $mm = $d[4]++;
    $yy = substr($d[5],-2);
    $mm *= 1;
    $dd *= 1;
    $mm = "0$mm" if $mm < 10;
    $dd = "0$dd" if $dd < 10;
  }

  if ($dateformat =~ /^yy/) {
    if ($date) {
      if ($date =~ /\D/) {
	($yy, $mm, $dd) = split /\D/, $date;
	$mm *= 1;
	$dd *= 1;
	$mm = "0$mm" if $mm < 10;
	$dd = "0$dd" if $dd < 10;
	$yy = substr($yy, -2);
	$rv = "$yy$mm$dd";
      } else {
	$rv = $date;
      }
    } else {
      $rv = "$yy$mm$dd";
    }
  }
  
  if ($dateformat =~ /^mm/) {
    if ($date) { 
      if ($date =~ /\D/) {
	($mm, $dd, $yy) = split /\D/, $date if $date;
	$mm *= 1;
	$dd *= 1;
	$mm = "0$mm" if $mm < 10;
	$dd = "0$dd" if $dd < 10;
	$yy = substr($yy, -2);
	$rv = "$mm$dd$yy";
      } else {
	$rv = $date;
      }
    } else {
      $rv = "$mm$dd$yy";
    }
  }
  
  if ($dateformat =~ /^dd/) {
    if ($date) {
      if ($date =~ /\D/) {
	($dd, $mm, $yy) = split /\D/, $date if $date;
	$mm *= 1;
	$dd *= 1;
	$mm = "0$mm" if $mm < 10;
	$dd = "0$dd" if $dd < 10;
	$yy = substr($yy, -2);
	$rv = "$dd$mm$yy";
      } else {
	$rv = $date;
      }
    } else {
      $rv = "$dd$mm$yy";
    }
  }

  ($rv, $yy, $mm, $dd);

}
    

sub from_to {
  my ($self, $yy, $mm, $interval) = @_;

  use Time::Local;
  
  my @t;
  my $dd = 1;
  my $fromdate = "$yy${mm}01";
  my $bd = 1;
  
  if (defined $interval) {
    if ($interval == 12) {
      $yy++ if $mm > 1;
    } else {
      if (($mm += $interval) > 12) {
	$mm -= 12;
	$yy++ if $mm > 1;
      }
      if ($interval == 0) {
	@t = localtime(time);
	$dd = $t[3];
	$mm = $t[4] + 1;
	$yy = $t[5] + 1900;
	$bd = 0;
      }
    }
  } else {
    if ($mm++ > 12) {
      $mm -= 12;
      $yy++;
    }
  }

  $mm--;
  @t = localtime(timelocal(0,0,0,$dd,$mm,$yy) - $bd);
  
  $t[4]++;
  $t[4] = substr("0$t[4]",-2);
  $t[3] = substr("0$t[3]",-2);
  
  ($fromdate, "$yy$t[4]$t[3]");
  
}


sub audittrail {
  my ($self, $dbh, $myconfig, $audittrail) = @_;
  
# table, $reference, $formname, $action, $id, $transdate) = @_;

  my $query;
  my $rv;

  # if we have an id add audittrail, otherwise get a new timestamp
  
  if ($audittrail->{id}) {
    $dbh = $self->dbconnect($myconfig) if $myconfig;
    
    $query = qq|SELECT audittrail FROM defaults|;
    
    if ($dbh->selectrow_array($query)) {
      my ($null, $employee_id) = $self->get_employee($dbh);

      if ($self->{audittrail} && !$myconfig) {
	chop $self->{audittrail};
	
	my @a = split /\|/, $self->{audittrail};
	my %newtrail = ();
	my $key;
	my $i;
	my @flds = qw(tablename reference formname action transdate);

	# put into hash and remove dups
	while (@a) {
	  $key = "$a[2]$a[3]";
	  $i = 0;
	  $newtrail{$key} = { map { $_ => $a[$i++] } @flds };
	  splice @a, 0, 5;
	}
	
	$query = qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id, transdate)
	            VALUES ($audittrail->{id}, ?, ?,
		    ?, ?, $employee_id, ?)|;
	my $sth = $dbh->prepare($query) || $self->dberror($query);

	foreach $key (sort { $newtrail{$a}{transdate} cmp $newtrail{$b}{transdate} } keys %newtrail) {
	  $i = 1;
	  map { $sth->bind_param($i++, $newtrail{$key}{$_}) } @flds;

	  $sth->execute || $self->dberror;
	  $sth->finish;
	}
      }

     
      if ($audittrail->{transdate}) {
	$query = qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id, transdate) VALUES (
		    $audittrail->{id}, '$audittrail->{tablename}', |
		    .$dbh->quote($audittrail->{reference}).qq|',
		    '$audittrail->{formname}', '$audittrail->{action}',
		    $employee_id, '$audittrail->{transdate}')|;
      } else {
	$query = qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id) VALUES ($audittrail->{id},
		    '$audittrail->{tablename}', |
		    .$dbh->quote($audittrail->{reference}).qq|,
		    '$audittrail->{formname}', '$audittrail->{action}',
		    $employee_id)|;
      }
      $dbh->do($query);
    }
  } else {
    $dbh = $self->dbconnect($myconfig);
    
    $query = qq|SELECT current_timestamp FROM defaults|;
    my ($timestamp) = $dbh->selectrow_array($query);

    $rv = "$audittrail->{tablename}|$audittrail->{reference}|$audittrail->{formname}|$audittrail->{action}|$timestamp|";
  }

  $dbh->disconnect if $myconfig;
  
  $rv;
  
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
    $spc = substr($spc, 0, 1);

    if ($date =~ /\D/) {
      if ($myconfig->{dateformat} =~ /^yy/) {
	($yy, $mm, $dd) = split /\D/, $date;
      }
      if ($myconfig->{dateformat} =~ /^mm/) {
	($mm, $dd, $yy) = split /\D/, $date;
      }
      if ($myconfig->{dateformat} =~ /^dd/) {
	($dd, $mm, $yy) = split /\D/, $date;
      }
    } else {
      $date = substr($date, 2);
      ($yy, $mm, $dd) = ($date =~ /(..)(..)(..)/);
    }
    
    $dd *= 1;
    $mm--;
    $yy = ($yy < 70) ? $yy + 2000 : $yy;
    $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

    if ($myconfig->{dateformat} =~ /^dd/) {
      $mm++;
      $dd = "0$dd" if ($dd < 10);
      $mm = "0$mm" if ($mm < 10);
      $longdate = "$dd$spc$mm$spc$yy";

      if (defined $longformat) {
	$longdate = "$dd";
	$longdate .= ($spc eq '.') ? ". " : " ";
	$longdate .= &text($self, $self->{$longmonth}[--$mm])." $yy";
      }
    } elsif ($myconfig->{dateformat} =~ /^yy/) {
      $mm++;
      $dd = "0$dd" if ($dd < 10);
      $mm = "0$mm" if ($mm < 10);
      $longdate = "$yy$spc$mm$spc$dd"; 

      if (defined $longformat) {
	$longdate = &text($self, $self->{$longmonth}[--$mm])." $dd $yy";
      }
    } else {
	$mm++;
	$dd = "0$dd" if ($dd < 10);
	$mm = "0$mm" if ($mm < 10);
	$longdate = "$mm$spc$dd$spc$yy"; 

      if (defined $longformat) {
	$longdate = &text($self, $self->{$longmonth}[--$mm])." $dd $yy";
      }
    }

  }

  $longdate;

}


1;

