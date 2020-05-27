package FS::Misc::DepositSlip;
use base 'Exporter';

use strict;
use warnings;
use vars qw( @EXPORT_OK );

#use Date::Format;
use IPC::Run qw( run timeout );   # for _xelatex
use Text::Template;

@EXPORT_OK = qw( deposit_slip_pdf );

=item deposit_slip_pdf

=cut

sub deposit_slip_pdf {
  my %arg = @_;
  my $conf = $arg{'conf'};
  my @cust_pay = @{ $arg{'cust_pay'} };

  if ( scalar(@cust_pay) > 25 ) {
    return 'ERROR: Maxiumum of 25 items per deposit slip at this time';
  }

  my $text_template = new Text::Template(
    TYPE       => 'STRING',
    SOURCE     => slip_template(),
    DELIMITERS => [ '[@--', '--@]' ],
  );

  $text_template->compile() or die $Text::Template::ERROR;

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  chdir($dir);

  #my $date = time2str( $self->conf->config('date_format_long') || '%b %o, %Y',
  #                     time #XXX future deposit date
  #                   );

  my $total = 0;
  foreach my $cust_pay (@cust_pay) {
    $total += $cust_pay->paid;
  }
  $total = sprintf('%.2f', $total + 0.00000001); #so FP math errors round out
  my ($total_dollars, $total_cents) = split(/\./, $total);

  my $gtotal = sprintf('%11.2f', $total);
  $gtotal =~ s/\.//;
  my @gtotal = split('', $gtotal);

  #XXX agent virt for company name, address
  my %fill_in = (
    'company_name'    => _latex_escape($conf->config('company_name')),
    'company_address' => join('\\\\', map _latex_escape($_),
                           $conf->config('company_address') ),

    'bank_name'       => _latex_escape($conf->config('deposit_slip-bank_name')),
    'bank_address'    => join('\\\\', map _latex_escape($_),
                           $conf->config('deposit_slip-bank_address') ),

    'bank_routingnumber' => _latex_escape(
                              $conf->config('deposit_slip-bank_routingnumber')),
    'bank_accountnumber' => _latex_escape(
                              $conf->config('deposit_slip-bank_accountnumber')),

    #already defaulting to today
    #'depositdate'     => _latex_escape($date),

    'currency_dollars'   => '',
    'currency_cents'     => '',
    'coin_dollars'       => '',
    'coin_cents'         => '',
    'checks_dollars'     => '',
    'checks_cents'       => '',

    'reverse_dollars'    => '',
    'reverse_cents'      => '',
    'total_dollars'      => $total_dollars,
    'total_cents'        => $total_cents,

    'cust_pay'           => \@cust_pay,

    'totalitems'         => scalar(@cust_pay),

    'grandtotalboxone'   => $gtotal[0],
    'grandtotalboxtwo'   => $gtotal[1],
    'grandtotalboxthree' => $gtotal[2],
    'grandtotalboxfour'  => $gtotal[3],
    'grandtotalboxfive'  => $gtotal[4],
    'grandtotalboxsix'   => $gtotal[5],
    'grandtotalboxseven' => $gtotal[6],
    'grandtotalboxeight' => $gtotal[7],
    'grandtotalboxnine'  => $gtotal[8],
    'grandtotalboxten'   => $gtotal[9],
  );

  #XXX better unique filename
  my $file = "deposit$$";

  open(DEPOSIT_TEX, ">$file.tex") or die $!;
  print DEPOSIT_TEX $text_template->fill_in( HASH => \%fill_in );
  close DEPOSIT_TEX or die $!;

  _xelatex($file);

  #XXX use File::Slurp
  my $pdf = '';
  open(PDF, "<$file.pdf") or die $!;

  unlink("$file.log", "$file.aux", "$file.pdf", "$file.tex");

  while (<PDF>) {
    $pdf .= $_;
  }
  close PDF;

  return $pdf;

} 

#some false laziness w/_pslatex in Misc.pm
sub _xelatex {
  my $file = shift;

  #my $sfile = shell_quote $file;

  my @cmd = (
    'xelatex',
    '-interaction=batchmode',
    "$file.tex"
  );

  my $timeout = 30; #? should be more than enough

  for ( 1, 2 ) {

    local($SIG{CHLD}) = sub {};
    run( \@cmd, '>'=>'/dev/null', '2>'=>'/dev/null', timeout($timeout) )
      or warn "bad exit status from xelatex pass $_\n";

  }

  return if -e "$file.pdf" && -s "$file.pdf";
  die "xelatex $file.tex failed, see $file.log for details?\n";

}

#false laxiness w/Template_Mixin.pm
sub _latex_escape {
  my $value = shift;
  $value =~ s/([#\$%&~_\^{}])( )?/"\\$1". ( ( defined($2) && length($2) ) ? "\\$2" : '' )/ge;
  $value =~ s/([<>])/\$$1\$/g;
  $value;
}

sub slip_template { <<'__END__';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Freeside Deposit Slip
% LaTeX Template
% Version 1.1 (May 9, 2020)
%
% This template was created by:
% Vel (enquiries@latextypesetting.com)
% LaTeXTypesetting.com
%
%!TEX program = xelatex
% Note: this template must be compiled with XeLaTeX rather than PDFLaTeX
% due to the custom fonts used. The line above should ensure this happens
% automatically, but if it doesn't, your LaTeX editor should have a simple toggle
% to switch to using XeLaTeX.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%----------------------------------------------------------------------------------------
%	PACKAGES AND OTHER DOCUMENT CONFIGURATIONS
%----------------------------------------------------------------------------------------

\documentclass{article}

%----------------------------------------------------------------------------------------
%	REQUIRED PACKAGES AND MISC CONFIGURATIONS
%----------------------------------------------------------------------------------------

\setlength{\parindent}{0pt} % Stop paragraph indentation

\usepackage{tikz} % Required for custom graphics
\usetikzlibrary{calc} % Required for coordinate calculations within TikZ

% Suppress hyphenation across the whole document
\hyphenpenalty=10000
\exhyphenpenalty=10000

%----------------------------------------------------------------------------------------
%	MARGINS
%----------------------------------------------------------------------------------------

\usepackage[
	paperwidth=8.5in,
	paperheight=3.25in,
	top=0cm, % Top margin
	bottom=1cm, % Bottom margin
	left=1cm, % Left margin
	right=1cm, % Right margin
	footskip=0.6cm, % Space from the bottom margin to the baseline of the footer
	headsep=0.8cm, % Space from the top margin to the baseline of the header
	headheight=0.5cm, % Height of the header
	%showframe % Uncomment to show the frames around the margins for debugging purposes
]{geometry}

%----------------------------------------------------------------------------------------
%	FONTS
%----------------------------------------------------------------------------------------

\usepackage{fontspec} % Required for specifying custom fonts

\defaultfontfeatures{Ligatures=TeX} % To support LaTeX ligatures (`` and --)
\defaultfontfeatures{Path=/usr/local/etc/freeside/} % Specify the location of font files

\newfontface\GNUMicr{GnuMICR.otf} % MICR font from file

\usepackage[default]{sourcesanspro} % Use the Source Sans Pro font for the document body

%----------------------------------------------------------------------------------------
%	HEADERS AND FOOTERS
%----------------------------------------------------------------------------------------

\usepackage{fancyhdr} % Required for customising headers and footers
\pagestyle{fancy} % Enable custom headers and footers

\renewcommand{\headrulewidth}{0pt} % Remove default top horizontal rule

\fancyhf{} % Clear default headers/footers

\fancyfoot[C]{{\Large\GNUMicr\MICR}} % Centre footer

%----------------------------------------------------------------------------------------
%	TABLES
%----------------------------------------------------------------------------------------

\usepackage{booktabs} % Required for better horizontal rules in tables

\usepackage{array} % Required for manipulating table columns

\renewcommand{\arraystretch}{1.35} % Increase the space between table rows

\newcolumntype{R}[1]{>{\raggedleft\arraybackslash}p{#1}} % Define a new right-aligned paragraph column type
\newcolumntype{L}[1]{>{\raggedright\arraybackslash}p{#1}} % Define a new left-aligned (no justification) paragraph column type
\newcolumntype{C}[1]{>{\centering\arraybackslash}p{#1}} % Define a new centred paragraph column type

%----------------------------------------------------------------------------------------
%	CUSTOM COMMANDS
%----------------------------------------------------------------------------------------

\newcommand{\MICR}[1]{\renewcommand{\MICR}{#1}}
\newcommand{\disclaimer}[1]{\renewcommand{\disclaimer}{#1}}
\newcommand{\companyaddress}[1]{\renewcommand{\companyaddress}{#1}}
\newcommand{\bankaddress}[1]{\renewcommand{\bankaddress}{#1}}
\newcommand{\totalitems}[1]{\renewcommand{\totalitems}{#1}}
\newcommand{\grandtotalboxone}[1]{\renewcommand{\grandtotalboxone}{#1}}
\newcommand{\grandtotalboxtwo}[1]{\renewcommand{\grandtotalboxtwo}{#1}}
\newcommand{\grandtotalboxthree}[1]{\renewcommand{\grandtotalboxthree}{#1}}
\newcommand{\grandtotalboxfour}[1]{\renewcommand{\grandtotalboxfour}{#1}}
\newcommand{\grandtotalboxfive}[1]{\renewcommand{\grandtotalboxfive}{#1}}
\newcommand{\grandtotalboxsix}[1]{\renewcommand{\grandtotalboxsix}{#1}}
\newcommand{\grandtotalboxseven}[1]{\renewcommand{\grandtotalboxseven}{#1}}
\newcommand{\grandtotalboxeight}[1]{\renewcommand{\grandtotalboxeight}{#1}}
\newcommand{\grandtotalboxnine}[1]{\renewcommand{\grandtotalboxnine}{#1}}
\newcommand{\grandtotalboxten}[1]{\renewcommand{\grandtotalboxten}{#1}}
\newcommand{\depositdate}[1]{\renewcommand{\depositdate}{#1}}

%\newcommand{\command}[1]{\renewcommand{\command}{#1}}

%----------------------------------------------------------------------------------------
%	DEPOSIT SLIP INFORMATION
%----------------------------------------------------------------------------------------

\MICR{A[@-- $bank_routingnumber --@]A  [@-- $bank_accountnumber --@]C} % Displayed at the bottom of the slip

\disclaimer{Checks and other items are received for deposit subject to the provisions of the Uniform Commercial Code and any applicable collection agreement. Deposits May Not Be Available For Immediate Withdrawal.}

\companyaddress{\textbf{[@-- $company_name --@]}\\[@-- $company_address --@]}

\bankaddress{\textbf{[@-- $bank_name --@]}\\ [@-- $bank_address --@]}

\totalitems{[@-- $totalitems --@]}

\grandtotalboxone{[@-- $grandtotalboxone --@]}
\grandtotalboxtwo{[@-- $grandtotalboxtwo --@]}
\grandtotalboxthree{[@-- $grandtotalboxthree --@]}
\grandtotalboxfour{[@-- $grandtotalboxfour --@]}
\grandtotalboxfive{[@-- $grandtotalboxfive --@]}
\grandtotalboxsix{[@-- $grandtotalboxsix --@]}
\grandtotalboxseven{[@-- $grandtotalboxseven --@]}
\grandtotalboxeight{[@-- $grandtotalboxeight --@]}
\grandtotalboxnine{[@-- $grandtotalboxnine --@]}
\grandtotalboxten{[@-- $grandtotalboxten --@]}

\depositdate{\today}

%----------------------------------------------------------------------------------------

\begin{document}

%----------------------------------------------------------------------------------------
%	DEPOSIT SLIP
%----------------------------------------------------------------------------------------

\begin{tikzpicture}[remember picture, overlay]
	\node [anchor=north, rotate=90, xshift=-0.5\paperheight, yshift=-0.4cm, inner sep=0pt] (title) at (current page.north west) {\textbf{DEPOSIT TICKET}}; % Deposit ticket title text
	
	\node [anchor=north, rotate=90, yshift=-0.4cm, inner sep=0pt] (dateline) at (title.south) {DATE: \rule{0.58\paperheight}{1pt}}; % Date line
	\node [anchor=south, rotate=90, yshift=-0.2cm, inner sep=0pt] (date) at (dateline.north) {\depositdate}; % Date
	
	\node [anchor=north west, rotate=90, yshift=-0.25cm, text width=0.8\paperheight, inner sep=0pt] (disclaimer) at (dateline.south west) {\fontsize{6pt}{7pt}\selectfont \disclaimer\par}; % Disclaimer text
	
	\node [anchor=north east, rotate=90, inner sep=0pt] (table) at (disclaimer.south east) {% Table
		\begin{tabular}{| L{1.8cm} | L{1cm} | L{0.5cm}}
			\cline{2-3}
			\multicolumn{1}{R{1.8cm} |}{} & \scriptsize DOLLARS & \scriptsize CENTS \\\cline{2-3}
			\multicolumn{1}{R{1.8cm} |}{\scriptsize CURRENCY} & [@-- $currency_dollars --@] & [@-- $currency_cents --@]\\\cline{2-3}
			\multicolumn{1}{R{1.8cm} |}{\scriptsize COIN} & [@-- $coin_dollars --@] & [@-- $coin_cents --@]\\\cline{2-3}
			\multicolumn{1}{| R{1.8cm} |}{\vspace{-1.2\baselineskip}\scriptsize CHECKS \newline \tiny (ENTER SEPARATELY)} & [@-- $checks_dollars --@] & [@-- $checks_cents --@]\\[-3pt]\cline{1-3}
[@--
  for (0 .. 24) {
    if ( scalar(@cust_pay) ) {
      my $cust_pay = shift @cust_pay;
      my ($dollars, $cents) = split(/\./, $cust_pay->paid);
      $OUT .= $cust_pay->payinfo. " & $dollars & $cents". '\\\\\\cline{1-3}'. "\n";
    } else {
      $OUT .= ' & & \\\\\\cline{1-3}'. "\n";
    }
  }
--@]
			\fontsize{6pt}{6pt}\selectfont TOTAL OF \newline REVERSE SIDE & [@-- $reverse_dollars --@] & [@-- $reverse_cents --@] \\\cline{1-3}
			\fontsize{10pt}{10pt}\selectfont\textbf{TOTAL} \newline DEPOSIT & [@-- $total_dollars --@] & [@-- $total_cents --@] \\\cline{1-3}
		\end{tabular}
	}; % Table
	\node [anchor=north east, rotate=90, yshift=-0.07cm, inner sep=0pt] (totalguidetext) at (table.south east) {\fontsize{6pt}{6pt}\selectfont PLEASE ENTER TOTAL HERE}; % Total guide text
	\draw [->] ($(totalguidetext.west)-(0, 0.1cm)$) -- ($(totalguidetext.west)-(0cm, 2.7cm)$); % Total guide text arrow
	
	\node [anchor=south west, xshift=0.3cm, text width=0.3\paperwidth, inner sep=0pt] (companyaddress) at (disclaimer.south west) {\Large\companyaddress\par}; % Company and address
	
	\node [anchor=north west, text width=0.3\paperwidth, inner sep=0pt] (bankaddress) at (companyaddress.north east) {\footnotesize\bankaddress\par}; % Financial institution address
	
	\node [anchor=south west, xshift=0.5cm, yshift=1.4cm, text width=0.75cm, inner sep=0pt] (totalitemstext) at (current page.south) {\fontsize{6pt}{6pt}\selectfont TOTAL ITEMS\par}; % Total items text
	\node [rectangle, anchor=west, draw=black, line width=1pt, minimum width=1cm, minimum height=0.5cm, inner sep=0pt] (totalitemsbox) at (totalitemstext.east) {\totalitems}; % Total items box
	
	\node [anchor=west, xshift=1cm, text width=0.4cm, inner sep=0pt] (dollarsign) at (totalitemsbox.east) {\Large\textbf{\$}}; % Dollar sign text
	\node [rectangle, anchor=west, fill=black!7, minimum width=6.7cm, minimum height=1.25cm, inner sep=0pt] (totalbox) at (dollarsign.east) {}; % Grand total grey box
	\node [rectangle, anchor=west, fill=white, xshift=0.3cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxone) at (totalbox.west) {\grandtotalboxone}; % White box 1
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxtwo) at (whiteboxone.east) {\grandtotalboxtwo}; % White box 2
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxthree) at (whiteboxtwo.east) {\grandtotalboxthree}; % White box 3
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxfour) at (whiteboxthree.east) {\grandtotalboxfour}; % White box 4
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxfive) at (whiteboxfour.east) {\grandtotalboxfive}; % White box 5
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxsix) at (whiteboxfive.east) {\grandtotalboxsix}; % White box 6
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxseven) at (whiteboxsix.east) {\grandtotalboxseven}; % White box 7
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxeight) at (whiteboxseven.east) {\grandtotalboxeight}; % White box 8
	\node [anchor=west, xshift=-0.5pt, inner sep=0pt] (centsperiod) at (whiteboxeight.south east) {.}; % Cents period
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxnine) at (whiteboxeight.east) {\grandtotalboxnine}; % White box 9
	\node [rectangle, anchor=west, fill=white, xshift=0.05cm, minimum width=0.55cm, minimum height=0.55cm, inner sep=0pt] (whiteboxten) at (whiteboxnine.east) {\grandtotalboxten}; % White box 10
	\draw [fill=white, draw=white] ($(whiteboxtwo.south east)+(0.02cm, 0cm)$) -- ($(whiteboxtwo.south east)-(0.03cm, 0.1cm)$) -- ($(whiteboxtwo.south east)+(0.07cm, -0.1cm)$) -- cycle; % Triangle 1
	\draw [fill=white, draw=white] ($(whiteboxfive.south east)+(0.02cm, 0cm)$) -- ($(whiteboxfive.south east)-(0.03cm, 0.1cm)$) -- ($(whiteboxfive.south east)+(0.07cm, -0.1cm)$) -- cycle; % Triangle 2
\end{tikzpicture}

%----------------------------------------------------------------------------------------

\end{document}

__END__

}

1;
