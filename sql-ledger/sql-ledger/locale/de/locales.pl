#!/usr/bin/perl

# -n do not include custom_ scripts
# -a build all file

use FileHandle;


$basedir = "../..";
$bindir = "$basedir/bin/mozilla";
$menufile = "menu.ini";

foreach $item (@ARGV) {
  $item =~ s/-//g;
  $arg{$item} = 1;
}

opendir DIR, "$bindir" or die "$!";
@progfiles = grep { /\.pl/; !/(_|^\.)/ } readdir DIR;
seekdir DIR, 0;
@customfiles = grep /_/, readdir DIR;
closedir DIR;

# put customized files into @customfiles
@customfiles = () if ($arg{n});

if ($arg{n}) {
  @menufiles = ($menufile);
} else {
  opendir DIR, "$basedir" or die "$!";
  @menufiles = grep { /.*?_$menufile$/ } readdir DIR;
  closedir DIR;
  unshift @menufiles, $menufile;
}


if (-f 'all') {    # use the old all file
  require "all";
  %oldall = %{ $self{texts} };
}
 
# remove the old missing file
if (-f 'missing') {
  unlink "missing";
}
  
foreach $file (@progfiles) {
  
  %locale = ();
  %submit = ();
  %subrt = ();
  @missing = ();
  %missing = ();
  
  $file =~ s/\.pl//;

  # read $file if it exists
  eval { require "$file"; };
  
  &scanfile("$bindir/${file}.pl");

  # scan custom_{module}.pl or {login}_{module}.pl files
  foreach $customfile (@customfiles) {
    if ($customfile =~ /_${file}\.pl/) {
      if (-f "$bindir/$customfile") {
	&scanfile("$bindir/$customfile");
      }
    }
  }
  
  # if this is the menu.pl file
  if ($file eq 'menu') {
    foreach $item (@menufiles) {
      &scanmenu("$basedir/$item");
    }
  }
  
  eval { require "$file.missing"; };
  unlink "$file.missing";

  if (%oldall) {    # use the old all file
    %{ $self{texts} } = %oldall;
  }
    
  map { $self{texts}{$_} = $missing->{$_} if $missing->{$_} } keys %$missing;

  open FH, ">$file" or die "$! : $file";

  print FH q|$self{texts} = {
|;

  foreach $key (sort keys %locale) {
    $text = $self{texts}{$key};
    $count++;
    
    $text =~ s/'/\\'/g;
    $text =~ s/\\$/\\\\/;

    $keytext = $key;
    $keytext =~ s/'/\\'/g;
    $keytext =~ s/\\$/\\\\/;
    
    $all{$keytext} = $text;
    
    if (!$text) {
      $notext++;
      push @missing, $keytext;
      next;
    }
    
    print FH qq|  '$keytext'|.(' ' x (27-length($keytext))).qq| => '$text',\n|;
  }

  print FH q|};

$self{subs} = {
|;
  
  foreach $key (sort keys %subrt) {
    $text = $key;
    $text =~ s/'/\\'/g;
    $text =~ s/\\$/\\\\/;
    print FH qq|  '$text'|.(' ' x (27-length($text))).qq| => '$text',\n|;
  }

  foreach $key (sort keys %submit) {
    $text = ($self{texts}{$key}) ? $self{texts}{$key} : $key;
    $text =~ s/'/\\'/g;
    $text =~ s/\\$/\\\\/;

    $english_sub = $key;
    $english_sub =~ s/'/\\'/g;
    $english_sub =~ s/\\$/\\\\/;
    $english_sub = lc $key;
    
    $translated_sub = lc $text;
    $english_sub =~ s/( |-|,)/_/g;
    $translated_sub =~ s/( |-|,)/_/g;
    print FH qq|  '$translated_sub'|.(' ' x (27-length($translated_sub))).qq| => '$english_sub',\n|;
  }
  
  print FH q|};

1;
|;

  close FH;

  
  if (@missing) {
    open FH, ">$file.missing" or die "$! : missing";

    print FH qq|# module $file
# add the missing texts and run locales.pl to rebuild

\$missing = {
|;

    foreach $text (@missing) {
      print FH qq|  '$text'|.(' ' x (27-length($text))).qq| => '',\n|;
    }

    print FH q|};

1;
|;

    close FH;
    
  }

  
  # redo the old all file
  if ($arg{a}) {
    open FH, ">all" or die "$! : all";

    print FH qq|# These are all the texts to build the translations files.
# to build unique strings edit the module files instead
# this file is just a shortcut to build strings which are the same

\$self{texts} = {
|;

    foreach $text (sort keys %all) {
      print FH qq|  '$text'|.(' ' x (27-length($text))).qq| => '$all{$text}',\n|;
    }

    print FH q|};

1;
|;

    close FH;
    
  }

}

open(FH, "LANGUAGE");
@language = <FH>;
close(FH);
$trlanguage = $language[0];
chomp $trlanguage;

$per = sprintf("%.1f", ($count - $notext) / $count * 100);
print "\n$trlanguage - ${per}%\n";

exit;
# eom


sub scanfile {
  my $file = shift;

  return unless (-f "$file");
  
  my $fh = new FileHandle;
  open $fh, "$file" or die "$! : $file";

  while (<$fh>) {
    # is this another file
    if (/require\s+\W.*\.pl/) {
      my $newfile = $&;
      $newfile =~ s/require\s+\W//;
      $newfile =~ s/\$form->{path}\///;
      &scanfile("$bindir/$newfile");
    }
   
    # is this a sub ?
    if (/^sub /) {
      ($null, $subrt) = split / +/;
      $subrt{$subrt} = 1;
      next;
    }
    
    my $rc = 1;
    
    while ($rc) {
      if (/Locale/) {
	if (!/^use /) {
	  my ($null, $country) = split /,/;
	  $country =~ s/^ +["']//;
	  $country =~ s/["'].*//;
	}
      }

      if (/\$locale->text.*?\W\)/) {
	my $string = $&;
	$string =~ s/\$locale->text\(\s*['"(q|qq)]['\/\\\|~]*//;
	$string =~ s/\W\)+.*$//;

        # if there is no $ in the string record it
	unless ($string =~ /\$\D.*/) {
	  # this guarantees one instance of string
	  $locale{$string} = 1;

          # is it a submit button before $locale->
          if (/type=submit/i) {
	    $submit{$string} = 1;
          }
	}
      }

      # exit loop if there are no more locales on this line
      ($rc) = ($' =~ /\$locale->text/);
      # strip text
      s/^.*?\$locale->text.*?\)//;
    }
  }

  close($fh);

}


sub scanmenu {
  my $file = shift;

  my $fh = new FileHandle;
  open $fh, "$file" or die "$! : $file";

  my @a = grep /^\[/, <$fh>;
  close($fh);

  # strip []
  grep { s/(\[|\])//g } @a;
  
  foreach my $item (@a) {
    $item =~ s/ *$//;
    @b = split /--/, $item;
    foreach $string (@b) {
      chomp $string;
      $locale{$string} = 1 if $string !~ /^\s*$/;
    }
  }
  
}


