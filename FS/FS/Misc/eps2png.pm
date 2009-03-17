package FS::Misc::eps2png;

#based on eps2png by Johan Vromans
#Copyright 1994,2008 by Johan Vromans.
#This program is free software; you can redistribute it and/or
#modify it under the terms of the Perl Artistic License or the
#GNU General Public License as published by the Free Software
#Foundation; either version 2 of the License, or (at your option) any
#later version.

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use File::Temp;
use File::Slurp qw( slurp );
#use FS::UID;

@ISA = qw( Exporter );
@EXPORT_OK = qw( eps2png );

################ Program parameters ################

# Some GhostScript programs can produce GIF directly.
# If not, we need the PBM package for the conversion.
# NOTE: This will be changed upon install.
my $use_pbm = 0;

my $res = 82;			# default resolution
my $scale = 1;			# default scaling
my $mono = 0;			# produce BW images if non-zero
my $format;			# output format
my $gs_format;			# GS output type
my $output;			# output, defaults to STDOUT
my $antialias = 8; #4;              # antialiasing
my $DEF_width;			# desired widht
my $DEF_height;		# desired height
#my $DEF_width = 90;			# desired widht
#my $DEF_height = 36;		# desired height

my ($verbose,$trace,$test,$debug) = (0,0,0,0);
#handle_options ();
set_out_type ('png'); # unless defined $format;
warn "Producing $format ($gs_format) image.\n" if $verbose;

$trace |= $test | $debug;
$verbose |= $trace;

################ Presets ################

################ The Process ################

my $err = 0;

sub eps2png {
    my( $eps, %options ) = @_; #well, no options yet

    my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
    my $eps_file = new File::Temp( TEMPLATE => 'image.XXXXXXXX',
                                   DIR      => $dir,
                                   SUFFIX   => '.eps',
                                   #UNLINK   => 0,
                                 ) or die "can't open temp file: $!\n";
    print $eps_file $eps;
    close $eps_file;

    my @eps = split(/\r?\n/, $eps);

    warn "converting eps (". length($eps). " bytes, ". scalar(@eps). " lines)\n"
      if $verbose;

    my $line = shift @eps; #<EPS>;
    unless ( $eps =~ /^%!PS-Adobe.*EPSF-/ ) {
	warn "not EPS file (no %!PS-Adobe header)\n";
        return; #empty png file?
    }

    my $ps = "";		# PostScript input data
    my $xscale;
    my $yscale;
    my $gotbb;

    # Prevent derived values from propagating.
    my $width = $DEF_width;
    my $height = $DEF_height;

    while ( @eps ) {

        $line = shift(@eps)."\n";

	# Search for BoundingBox.
	if ( $line =~ /^%%BoundingBox:\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/i ) {
	    $gotbb++;
	    warn "$eps_file: x0=$1, y0=$2, w=", $3-$1, ", h=", $4-$2
		if $verbose;

	    if ( defined $width ) {
		$res = 72;
		$xscale = $width / ($3 - $1);
		if ( defined $height ) {
		    $yscale = $height / ($4 - $2);
		}
		else {
		    $yscale = $xscale;
		    $height = ($4 - $2) * $yscale;
		}
	    }
	    elsif ( defined $height ) {
		$res = 72;
		$yscale = $height / ($4 - $2);
		if ( defined $width ) {
		    $xscale = $width / ($3 - $1);
		}
		else {
		    $xscale = $yscale;
		    $width = ($3 - $1) * $xscale;
		}
	    }
	    unless ( defined $xscale ) {
		$xscale = $yscale = $scale;
		# Calculate actual width.
		$width  = $3 - $1;
		$height = $4 - $2;
		# Normal PostScript resolution is 72.
		$width  *= $res/72 * $xscale;
		$height *= $res/72 * $yscale;
		# Round up.
		$width  = int ($width + 0.5) + 1;
		$height = int ($height + 0.5) + 1;
	    }
	    warn ", width=$width, height=$height\n" if $verbose;

	    # Scale.
	    $ps .= "$xscale $yscale scale\n"
	      if $xscale != 1 || $yscale != 1;

	    # Create PostScript code to translate coordinates.
	    $ps .= (0-$1) . " " . (0-$2) . " translate\n"
	      unless $1 == 0 && $2 == 0;

	    # Include the image, show and quit.
	    $ps .= "($eps_file) run\n".
	      "showpage\n".
		"quit\n";

	    last;
	}
	elsif ( $line =~ /^%%EndComments/i ) {
	    last;
	}
    }

    unless ( $gotbb ) {
	warn "No bounding box in $eps_file\n";
	return;
    }

    #it would be better to ask gs to spit out files on stdout, but c'est la vie

    #my $out_file;		# output file
    #my $pbm_file;		# temporary file for PBM conversion

    my $out_file = new File::Temp( TEMPLATE => 'image.XXXXXXXX',
                                   DIR      => $dir,
                                   SUFFIX   => '.png',
                                   #UNLINK   => 0,
                                 ) or die "can't open temp file: $!\n";

    my $pbm_file = new File::Temp( TEMPLATE => 'image.XXXXXXXX',
                                   DIR      => $dir,
                                   SUFFIX   => '.pbm',
                                   #UNLINK   => 0,
                                 ) or die "can't open temp file: $!\n";

    # Note the temporary PBM file is created where the output file is
    # located, since that will guarantee accessibility (and a valid
    # filename).
    warn "Creating $out_file\n" if $verbose;

    my $gs0 = "gs -q -dNOPAUSE -r$res -g${width}x$height";
    my $gs1 = "-";
    $gs0 .= " -dTextAlphaBits=$antialias -dGraphicsAlphaBits=$antialias"
      if $antialias;
    if ( $format eq 'png' ) {
	mysystem ("$gs0 -sDEVICE=". ($mono ? "pngmono" : $gs_format).
		  " -sOutputFile=$out_file $gs1", $ps);
    }
    elsif ( $format eq 'jpg' ) {
	mysystem ("$gs0 -sDEVICE=". ($mono ? "jpeggray" : $gs_format).
		  " -sOutputFile=$out_file $gs1", $ps);
    }
    elsif ( $format eq 'gif' ) {
	if ( $use_pbm ) {
	    # Convert to PPM and use some of the PBM converters.
	    mysystem ("$gs0 -sDEVICE=". ($mono ? "pbm" : "ppm").
		      " -sOutputFile=$pbm_file $gs1", $ps);
	    # mysystem ("pnmcrop $pbm_file | ppmtogif > $out_file");
	    mysystem ("ppmtogif $pbm_file > $out_file");
	    unlink ($pbm_file);
	}
	else {
	    # GhostScript has GIF drivers built-in.
	    mysystem ("$gs0 -sDEVICE=". ($mono ? "gifmono" : "gif8").
		      " -sOutputFile=$out_file $gs1", $ps);
	}
    }
    else {
	warn "ASSERT ERROR: Unhandled output type: $format\n";
	exit (1);
    }

#    unless ( -s $out_file ) {
#	warn "Problem creating $out_file for $eps_file\n";
#	$err++;
#    }

    slurp($out_file);

}

exit 1 if $err;

################ Subroutines ################

sub mysystem {
    my ($cmd, $data) = @_;
    warn "+ $cmd\n" if $trace;
    if ( $data ) {
	if ( $trace ) {
	    my $dp = ">> " . $data;
	    $dp =~ s/\n(.)/\n>> $1/g;
	    warn "$dp";
	}
	open (CMD, "|$cmd") or die ("$cmd: $!\n");
	print CMD $data;
	close CMD or die ("$cmd close: $!\n");
    }
    else {
	system ($cmd);
    }
}

sub set_out_type {
    my ($opt) = lc (shift (@_));
    if ( $opt =~ /^png(mono|gray|16|256|16m|alpha)?$/ ) {
	$format = 'png';
	$gs_format = $format.(defined $1 ? $1 : '16m');
    }
    elsif ( $opt =~ /^gif(mono)?$/ ) {
	$format = 'gif';
	$gs_format = $format.(defined $1 ? $1 : '');
    }
    elsif ( $opt =~ /^(jpg|jpeg)(gray)?$/ ) {
	$format = 'jpg';
	$gs_format = 'jpeg'.(defined $2 ? $2 : '');
    }
    else {
	warn "ASSERT ERROR: Invalid value to set_out_type: $opt\n";
	exit (1);
    }
}

#			     'antialias|aa=i'   => \$antialias,
#			     'noantialias|noaa' => sub { $antialias = 0 },
#			     'scale=f'     => \$scale,
#			     'width=i'	   => \$width,
#			     'height=i'	   => \$height,
#			     'resolution=i' => \$res,

#    die ("Antialias value must be 0, 1, 2, 4, or 8\n")

#    -width XXX		desired with
#    -height XXX		desired height
#    -resolution XXX	resolution (default = $res)
#    -scale XXX		scaling factor
#    -antialias XX	antialias factor (must be 0, 1, 2, 4 or 8; default: 4)
#    -noantialias	no antialiasing (same as -antialias 0)

1;
