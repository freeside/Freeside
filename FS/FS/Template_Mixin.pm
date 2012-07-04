package FS::Template_Mixin;

use strict;
use vars qw( $DEBUG $me
             $money_char $date_format $rdate_format $date_format_long );
             # but NOT $conf
use vars qw( $invoice_lines @buf ); #yuck
use List::Util qw(sum);
use Date::Format;
use Date::Language;
use Text::Template 1.20;
use File::Temp 0.14;
use HTML::Entities;
use Locale::Country;
use FS::UID;
use FS::Record qw( qsearch qsearchs );
use FS::Misc qw( generate_ps generate_pdf );
use FS::pkg_category;
use FS::pkg_class;
use FS::L10N;

$DEBUG = 0;
$me = '[FS::Template_Mixin]';
FS::UID->install_callback( sub { 
  my $conf = new FS::Conf; #global
  $money_char       = $conf->config('money_char')       || '$';  
  $date_format      = $conf->config('date_format')      || '%x'; #/YY
  $rdate_format     = $conf->config('date_format')      || '%m/%d/%Y';  #/YYYY
  $date_format_long = $conf->config('date_format_long') || '%b %o, %Y';
} );

=item print_text HASHREF | [ TIME [ , TEMPLATE [ , OPTION => VALUE ... ] ] ]

Returns an text invoice, as a list of lines.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time>, if specified, is used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_text {
  my $self = shift;
  my( $today, $template, %opt );
  if ( ref($_[0]) ) {
    %opt = %{ shift() };
    $today = delete($opt{'time'}) || '';
    $template = delete($opt{template}) || '';
  } else {
    ( $today, $template, %opt ) = @_;
  }

  my %params = ( 'format' => 'template' );
  $params{'time'} = $today if $today;
  $params{'template'} = $template if $template;
  $params{$_} = $opt{$_} 
    foreach grep $opt{$_}, qw( unsquelch_cdr notice_name );

  $self->print_generic( %params );
}

=item print_latex HASHREF | [ TIME [ , TEMPLATE [ , OPTION => VALUE ... ] ] ]

Internal method - returns a filename of a filled-in LaTeX template for this
invoice (Note: add ".tex" to get the actual filename), and a filename of
an associated logo (with the .eps extension included).

See print_ps and print_pdf for methods that return PostScript and PDF output.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time>, if specified, is used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_latex {
  my $self = shift;
  my $conf = $self->conf;
  my( $today, $template, %opt );
  if ( ref($_[0]) ) {
    %opt = %{ shift() };
    $today = delete($opt{'time'}) || '';
    $template = delete($opt{template}) || '';
  } else {
    ( $today, $template, %opt ) = @_;
  }

  my %params = ( 'format' => 'latex' );
  $params{'time'} = $today if $today;
  $params{'template'} = $template if $template;
  $params{$_} = $opt{$_} 
    foreach grep $opt{$_}, qw( unsquelch_cdr notice_name );

  $template ||= $self->_agent_template
    if $self->can('_agent_template');

  my $pkey = $self->primary_key;
  my $tmp_template = $self->table. '.'. $self->$pkey. '.XXXXXXXX';

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  my $lh = new File::Temp(
    TEMPLATE => $tmp_template,
    DIR      => $dir,
    SUFFIX   => '.eps',
    UNLINK   => 0,
  ) or die "can't open temp file: $!\n";

  my $agentnum = $self->cust_main->agentnum;

  if ( $template && $conf->exists("logo_${template}.eps", $agentnum) ) {
    print $lh $conf->config_binary("logo_${template}.eps", $agentnum)
      or die "can't write temp file: $!\n";
  } else {
    print $lh $conf->config_binary('logo.eps', $agentnum)
      or die "can't write temp file: $!\n";
  }
  close $lh;
  $params{'logo_file'} = $lh->filename;

  if( $conf->exists('invoice-barcode') && $self->can('invoice_barcode') ) {
      my $png_file = $self->invoice_barcode($dir);
      my $eps_file = $png_file;
      $eps_file =~ s/\.png$/.eps/g;
      $png_file =~ /(barcode.*png)/;
      $png_file = $1;
      $eps_file =~ /(barcode.*eps)/;
      $eps_file = $1;

      my $curr_dir = cwd();
      chdir($dir); 
      # after painfuly long experimentation, it was determined that sam2p won't
      #	accept : and other chars in the path, no matter how hard I tried to
      # escape them, hence the chdir (and chdir back, just to be safe)
      system('sam2p', '-j:quiet', $png_file, 'EPS:', $eps_file ) == 0
	or die "sam2p failed: $!\n";
      unlink($png_file);
      chdir($curr_dir);

      $params{'barcode_file'} = $eps_file;
  }

  my @filled_in = $self->print_generic( %params );
  
  my $fh = new File::Temp( TEMPLATE => $tmp_template,
                           DIR      => $dir,
                           SUFFIX   => '.tex',
                           UNLINK   => 0,
                         ) or die "can't open temp file: $!\n";
  binmode($fh, ':utf8'); # language support
  print $fh join('', @filled_in );
  close $fh;

  $fh->filename =~ /^(.*).tex$/ or die "unparsable filename: ". $fh->filename;
  return ($1, $params{'logo_file'}, $params{'barcode_file'});

}

=item print_generic OPTION => VALUE ...

Internal method - returns a filled-in template for this invoice as a scalar.

See print_ps and print_pdf for methods that return PostScript and PDF output.

Non optional options include 
  format - latex, html, template

Optional options include

template - a value used as a suffix for a configuration template

time - a value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

cid - 

unsquelch_cdr - overrides any per customer cdr squelching when true

notice_name - overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

locale - override customer's locale

=cut

#what's with all the sprintf('%10.2f')'s in here?  will it cause any
# (alignment in text invoice?) problems to change them all to '%.2f' ?
# yes: fixed width/plain text printing will be borked
sub print_generic {
  my( $self, %params ) = @_;
  my $conf = $self->conf;
  my $today = $params{today} ? $params{today} : time;
  warn "$me print_generic called on $self with suffix $params{template}\n"
    if $DEBUG;

  my $format = $params{format};
  die "Unknown format: $format"
    unless $format =~ /^(latex|html|template)$/;

  my $cust_main = $self->cust_main || $self->prospect_main;
  $cust_main->payname( $cust_main->first. ' '. $cust_main->getfield('last') )
    unless $cust_main->payname
        && $cust_main->payby !~ /^(CARD|DCRD|CHEK|DCHK)$/;

  my %delimiters = ( 'latex'    => [ '[@--', '--@]' ],
                     'html'     => [ '<%=', '%>' ],
                     'template' => [ '{', '}' ],
                   );

  warn "$me print_generic creating template\n"
    if $DEBUG > 1;

  #create the template
  my $template = $params{template} ? $params{template} : $self->_agent_template;
  my $templatefile = $self->template_conf. $format;
  $templatefile .= "_$template"
    if length($template) && $conf->exists($templatefile."_$template");
  my @invoice_template = map "$_\n", $conf->config($templatefile)
    or die "cannot load config data $templatefile";

  my $old_latex = '';
  if ( $format eq 'latex' && grep { /^%%Detail/ } @invoice_template ) {
    #change this to a die when the old code is removed
    warn "old-style invoice template $templatefile; ".
         "patch with conf/invoice_latex.diff or use new conf/invoice_latex*\n";
    $old_latex = 'true';
    @invoice_template = _translate_old_latex_format(@invoice_template);
  } 

  warn "$me print_generic creating T:T object\n"
    if $DEBUG > 1;

  my $text_template = new Text::Template(
    TYPE => 'ARRAY',
    SOURCE => \@invoice_template,
    DELIMITERS => $delimiters{$format},
  );

  warn "$me print_generic compiling T:T object\n"
    if $DEBUG > 1;

  $text_template->compile()
    or die "Can't compile $templatefile: $Text::Template::ERROR\n";


  # additional substitution could possibly cause breakage in existing templates
  my %convert_maps = ( 
    'latex' => {
                 'notes'         => sub { map "$_", @_ },
                 'footer'        => sub { map "$_", @_ },
                 'smallfooter'   => sub { map "$_", @_ },
                 'returnaddress' => sub { map "$_", @_ },
                 'coupon'        => sub { map "$_", @_ },
                 'summary'       => sub { map "$_", @_ },
               },
    'html'  => {
                 'notes' =>
                   sub {
                     map { 
                       s/%%(.*)$/<!-- $1 -->/g;
                       s/\\section\*\{\\textsc\{(.)(.*)\}\}/<p><b><font size="+1">$1<\/font>\U$2<\/b>/g;
                       s/\\begin\{enumerate\}/<ol>/g;
                       s/\\item /  <li>/g;
                       s/\\end\{enumerate\}/<\/ol>/g;
                       s/\\textbf\{(.*)\}/<b>$1<\/b>/g;
                       s/\\\\\*/<br>/g;
                       s/\\dollar ?/\$/g;
                       s/\\#/#/g;
                       s/~/&nbsp;/g;
                       $_;
                     }  @_
                   },
                 'footer' =>
                   sub { map { s/~/&nbsp;/g; s/\\\\\*?\s*$/<BR>/; $_; } @_ },
                 'smallfooter' =>
                   sub { map { s/~/&nbsp;/g; s/\\\\\*?\s*$/<BR>/; $_; } @_ },
                 'returnaddress' =>
                   sub {
                     map { 
                       s/~/&nbsp;/g;
                       s/\\\\\*?\s*$/<BR>/;
                       s/\\hyphenation\{[\w\s\-]+}//;
                       s/\\([&])/$1/g;
                       $_;
                     }  @_
                   },
                 'coupon'        => sub { "" },
                 'summary'       => sub { "" },
               },
    'template' => {
                 'notes' =>
                   sub {
                     map { 
                       s/%%.*$//g;
                       s/\\section\*\{\\textsc\{(.*)\}\}/\U$1/g;
                       s/\\begin\{enumerate\}//g;
                       s/\\item /  * /g;
                       s/\\end\{enumerate\}//g;
                       s/\\textbf\{(.*)\}/$1/g;
                       s/\\\\\*/ /;
                       s/\\dollar ?/\$/g;
                       $_;
                     }  @_
                   },
                 'footer' =>
                   sub { map { s/~/ /g; s/\\\\\*?\s*$/\n/; $_; } @_ },
                 'smallfooter' =>
                   sub { map { s/~/ /g; s/\\\\\*?\s*$/\n/; $_; } @_ },
                 'returnaddress' =>
                   sub {
                     map { 
                       s/~/ /g;
                       s/\\\\\*?\s*$/\n/;             # dubious
                       s/\\hyphenation\{[\w\s\-]+}//;
                       $_;
                     }  @_
                   },
                 'coupon'        => sub { "" },
                 'summary'       => sub { "" },
               },
  );


  # hashes for differing output formats
  my %nbsps = ( 'latex'    => '~',
                'html'     => '',    # '&nbps;' would be nice
                'template' => '',    # not used
              );
  my $nbsp = $nbsps{$format};

  my %escape_functions = ( 'latex'    => \&_latex_escape,
                           'html'     => \&_html_escape_nbsp,#\&encode_entities,
                           'template' => sub { shift },
                         );
  my $escape_function = $escape_functions{$format};
  my $escape_function_nonbsp = ($format eq 'html')
                                 ? \&_html_escape : $escape_function;

  my %date_formats = ( 'latex'    => $date_format_long,
                       'html'     => $date_format_long,
                       'template' => '%s',
                     );
  $date_formats{'html'} =~ s/ /&nbsp;/g;

  my $date_format = $date_formats{$format};

  my %embolden_functions = ( 'latex'    => sub { return '\textbf{'. shift(). '}'
                                               },
                             'html'     => sub { return '<b>'. shift(). '</b>'
                                               },
                             'template' => sub { shift },
                           );
  my $embolden_function = $embolden_functions{$format};

  my %newline_tokens = (  'latex'     => '\\\\',
                          'html'      => '<br>',
                          'template'  => "\n",
                        );
  my $newline_token = $newline_tokens{$format};

  warn "$me generating template variables\n"
    if $DEBUG > 1;

  # generate template variables
  my $returnaddress;
  if (
         defined( $conf->config_orbase( "invoice_${format}returnaddress",
                                        $template
                                      )
                )
       && length( $conf->config_orbase( "invoice_${format}returnaddress",
                                        $template
                                      )
                )
  ) {

    $returnaddress = join("\n",
      $conf->config_orbase("invoice_${format}returnaddress", $template)
    );

  } elsif ( grep /\S/,
            $conf->config_orbase('invoice_latexreturnaddress', $template) ) {

    my $convert_map = $convert_maps{$format}{'returnaddress'};
    $returnaddress =
      join( "\n",
            &$convert_map( $conf->config_orbase( "invoice_latexreturnaddress",
                                                 $template
                                               )
                         )
          );
  } elsif ( grep /\S/, $conf->config('company_address', $cust_main->agentnum) ) {

    my $convert_map = $convert_maps{$format}{'returnaddress'};
    $returnaddress = join( "\n", &$convert_map(
                                   map { s/( {2,})/'~' x length($1)/eg;
                                         s/$/\\\\\*/;
                                         $_
                                       }
                                     ( $conf->config('company_name', $cust_main->agentnum),
                                       $conf->config('company_address', $cust_main->agentnum),
                                     )
                                 )
                     );

  } else {

    my $warning = "Couldn't find a return address; ".
                  "do you need to set the company_address configuration value?";
    warn "$warning\n";
    $returnaddress = $nbsp;
    #$returnaddress = $warning;

  }

  warn "$me generating invoice data\n"
    if $DEBUG > 1;

  my $agentnum = $cust_main->agentnum;

  my %invoice_data = (

    #invoice from info
    'company_name'    => scalar( $conf->config('company_name', $agentnum) ),
    'company_address' => join("\n", $conf->config('company_address', $agentnum) ). "\n",
    'company_phonenum'=> scalar( $conf->config('company_phonenum', $agentnum) ),
    'returnaddress'   => $returnaddress,
    'agent'           => &$escape_function($cust_main->agent->agent),

    #invoice/quotation info
    'invnum'          => $self->invnum,
    'quotationnum'    => $self->quotationnum,
    'date'            => time2str($date_format, $self->_date),
    'today'           => time2str($date_format_long, $today),
    'terms'           => $self->terms,
    'template'        => $template, #params{'template'},
    'notice_name'     => ($params{'notice_name'} || $self->notice_name),#escape_function?
    'current_charges' => sprintf("%.2f", $self->charged),
    'duedate'         => $self->due_date2str($rdate_format), #date_format?

    #customer info
    'custnum'         => $cust_main->display_custnum,
    'prospectnum'     => $cust_main->prospectnum,
    'agent_custid'    => &$escape_function($cust_main->agent_custid),
    ( map { $_ => &$escape_function($cust_main->$_()) } qw(
      payname company address1 address2 city state zip fax
    )),

    #global config
    'ship_enable'     => $conf->exists('invoice-ship_address'),
    'unitprices'      => $conf->exists('invoice-unitprice'),
    'smallernotes'    => $conf->exists('invoice-smallernotes'),
    'smallerfooter'   => $conf->exists('invoice-smallerfooter'),
    'balance_due_below_line' => $conf->exists('balance_due_below_line'),
   
    #layout info -- would be fancy to calc some of this and bury the template
    #               here in the code
    'topmargin'             => scalar($conf->config('invoice_latextopmargin', $agentnum)),
    'headsep'               => scalar($conf->config('invoice_latexheadsep', $agentnum)),
    'textheight'            => scalar($conf->config('invoice_latextextheight', $agentnum)),
    'extracouponspace'      => scalar($conf->config('invoice_latexextracouponspace', $agentnum)),
    'couponfootsep'         => scalar($conf->config('invoice_latexcouponfootsep', $agentnum)),
    'verticalreturnaddress' => $conf->exists('invoice_latexverticalreturnaddress', $agentnum),
    'addresssep'            => scalar($conf->config('invoice_latexaddresssep', $agentnum)),
    'amountenclosedsep'     => scalar($conf->config('invoice_latexcouponamountenclosedsep', $agentnum)),
    'coupontoaddresssep'    => scalar($conf->config('invoice_latexcoupontoaddresssep', $agentnum)),
    'addcompanytoaddress'   => $conf->exists('invoice_latexcouponaddcompanytoaddress', $agentnum),

    # better hang on to conf_dir for a while (for old templates)
    'conf_dir'        => "$FS::UID::conf_dir/conf.$FS::UID::datasrc",

    #these are only used when doing paged plaintext
    'page'            => 1,
    'total_pages'     => 1,

  );
 
  #localization
  my $lh = FS::L10N->get_handle( $params{'locale'} || $cust_main->locale );
  $invoice_data{'emt'} = sub { &$escape_function($self->mt(@_)) };
  my %info = FS::Locales->locale_info($cust_main->locale || 'en_US');
  # eval to avoid death for unimplemented languages
  my $dh = eval { Date::Language->new($info{'name'}) } ||
           Date::Language->new(); # fall back to English
  # prototype here to silence warnings
  $invoice_data{'time2str'} = sub ($;$$) { $dh->time2str(@_) };
  # eventually use this date handle everywhere in here, too

  my $min_sdate = 999999999999;
  my $max_edate = 0;
  foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
    next unless $cust_bill_pkg->pkgnum > 0;
    $min_sdate = $cust_bill_pkg->sdate
      if length($cust_bill_pkg->sdate) && $cust_bill_pkg->sdate < $min_sdate;
    $max_edate = $cust_bill_pkg->edate
      if length($cust_bill_pkg->edate) && $cust_bill_pkg->edate > $max_edate;
  }

  $invoice_data{'bill_period'} = '';
  $invoice_data{'bill_period'} = time2str('%e %h', $min_sdate) 
    . " to " . time2str('%e %h', $max_edate)
    if ($max_edate != 0 && $min_sdate != 999999999999);

  $invoice_data{finance_section} = '';
  if ( $conf->config('finance_pkgclass') ) {
    my $pkg_class =
      qsearchs('pkg_class', { classnum => $conf->config('finance_pkgclass') });
    $invoice_data{finance_section} = $pkg_class->categoryname;
  } 
  $invoice_data{finance_amount} = '0.00';
  $invoice_data{finance_section} ||= 'Finance Charges'; #avoid config confusion

  my $countrydefault = $conf->config('countrydefault') || 'US';
  foreach ( qw( address1 address2 city state zip country fax) ){
    my $method = 'ship_'.$_;
    $invoice_data{"ship_$_"} = _latex_escape($cust_main->$method);
  }
  foreach ( qw( contact company ) ) { #compatibility
    $invoice_data{"ship_$_"} = _latex_escape($cust_main->$_);
  }
  $invoice_data{'ship_country'} = ''
    if ( $invoice_data{'ship_country'} eq $countrydefault );
  
  $invoice_data{'cid'} = $params{'cid'}
    if $params{'cid'};

  if ( $cust_main->country eq $countrydefault ) {
    $invoice_data{'country'} = '';
  } else {
    $invoice_data{'country'} = &$escape_function(code2country($cust_main->country));
  }

  my @address = ();
  $invoice_data{'address'} = \@address;
  push @address,
    $cust_main->payname.
      ( ( $cust_main->payby eq 'BILL' ) && $cust_main->payinfo
        ? " (P.O. #". $cust_main->payinfo. ")"
        : ''
      )
  ;
  push @address, $cust_main->company
    if $cust_main->company;
  push @address, $cust_main->address1;
  push @address, $cust_main->address2
    if $cust_main->address2;
  push @address,
    $cust_main->city. ", ". $cust_main->state. "  ".  $cust_main->zip;
  push @address, $invoice_data{'country'}
    if $invoice_data{'country'};
  push @address, ''
    while (scalar(@address) < 5);

  $invoice_data{'logo_file'} = $params{'logo_file'}
    if $params{'logo_file'};
  $invoice_data{'barcode_file'} = $params{'barcode_file'}
    if $params{'barcode_file'};
  $invoice_data{'barcode_img'} = $params{'barcode_img'}
    if $params{'barcode_img'};
  $invoice_data{'barcode_cid'} = $params{'barcode_cid'}
    if $params{'barcode_cid'};

  my( $pr_total, @pr_cust_bill ) = $self->previous; #previous balance
#  my( $cr_total, @cr_cust_credit ) = $self->cust_credit; #credits
  #my $balance_due = $self->owed + $pr_total - $cr_total;
  my $balance_due = $self->owed + $pr_total;

  # the customer's current balance as shown on the invoice before this one
  $invoice_data{'true_previous_balance'} = sprintf("%.2f", ($self->previous_balance || 0) );

  # the change in balance from that invoice to this one
  $invoice_data{'balance_adjustments'} = sprintf("%.2f", ($self->previous_balance || 0) - ($self->billing_balance || 0) );

  # the sum of amount owed on all previous invoices
  $invoice_data{'previous_balance'} = sprintf("%.2f", $pr_total);

  # the sum of amount owed on all invoices
  $invoice_data{'balance'} = sprintf("%.2f", $balance_due);

  # info from customer's last invoice before this one, for some 
  # summary formats
  $invoice_data{'last_bill'} = {};
  my $last_bill = $pr_cust_bill[-1];
  if ( $last_bill ) {
    $invoice_data{'last_bill'} = {
      '_date'     => $last_bill->_date, #unformatted
      # all we need for now
    };
  }

  my $summarypage = '';
  if ( $conf->exists('invoice_usesummary', $agentnum) ) {
    $summarypage = 1;
  }
  $invoice_data{'summarypage'} = $summarypage;

  warn "$me substituting variables in notes, footer, smallfooter\n"
    if $DEBUG > 1;

  my $tc = $self->template_conf;
  my @include = ( [ $tc,        'notes' ],
                  [ 'invoice_', 'footer' ],
                  [ 'invoice_', 'smallfooter', ],
                );
  push @include, [ $tc,        'coupon', ]
    unless $params{'no_coupon'};

  foreach my $i (@include) {

    my($base, $include) = @$i;

    my $inc_file = $conf->key_orbase("$base$format$include", $template);
    my @inc_src;

    if ( $conf->exists($inc_file, $agentnum)
         && length( $conf->config($inc_file, $agentnum) ) ) {

      @inc_src = $conf->config($inc_file, $agentnum);

    } else {

      $inc_file = $conf->key_orbase("${base}latex$include", $template);

      my $convert_map = $convert_maps{$format}{$include};

      @inc_src = map { s/\[\@--/$delimiters{$format}[0]/g;
                       s/--\@\]/$delimiters{$format}[1]/g;
                       $_;
                     } 
                 &$convert_map( $conf->config($inc_file, $agentnum) );

    }

    my $inc_tt = new Text::Template (
      TYPE       => 'ARRAY',
      SOURCE     => [ map "$_\n", @inc_src ],
      DELIMITERS => $delimiters{$format},
    ) or die "Can't create new Text::Template object: $Text::Template::ERROR";

    unless ( $inc_tt->compile() ) {
      my $error = "Can't compile $inc_file template: $Text::Template::ERROR\n";
      warn $error. "Template:\n". join('', map "$_\n", @inc_src);
      die $error;
    }

    $invoice_data{$include} = $inc_tt->fill_in( HASH => \%invoice_data );

    $invoice_data{$include} =~ s/\n+$//
      if ($format eq 'latex');
  }

  # let invoices use either of these as needed
  $invoice_data{'po_num'} = ($cust_main->payby eq 'BILL') 
    ? $cust_main->payinfo : '';
  $invoice_data{'po_line'} = 
    (  $cust_main->payby eq 'BILL' && $cust_main->payinfo )
      ? &$escape_function($self->mt("Purchase Order #").$cust_main->payinfo)
      : $nbsp;

  my %money_chars = ( 'latex'    => '',
                      'html'     => $conf->config('money_char') || '$',
                      'template' => '',
                    );
  my $money_char = $money_chars{$format};

  my %other_money_chars = ( 'latex'    => '\dollar ',#XXX should be a config too
                            'html'     => $conf->config('money_char') || '$',
                            'template' => '',
                          );
  my $other_money_char = $other_money_chars{$format};
  $invoice_data{'dollar'} = $other_money_char;

  my @detail_items = ();
  my @total_items = ();
  my @buf = ();
  my @sections = ();

  $invoice_data{'detail_items'} = \@detail_items;
  $invoice_data{'total_items'} = \@total_items;
  $invoice_data{'buf'} = \@buf;
  $invoice_data{'sections'} = \@sections;

  warn "$me generating sections\n"
    if $DEBUG > 1;

  my $previous_section = { 'description' => $self->mt('Previous Charges'),
                           'subtotal'    => $other_money_char.
                                            sprintf('%.2f', $pr_total),
                           'summarized'  => '', #why? $summarypage ? 'Y' : '',
                         };
  $previous_section->{posttotal} = '0 / 30 / 60 / 90 days overdue '. 
    join(' / ', map { $cust_main->balance_date_range(@$_) }
                $self->_prior_month30s
        )
    if $conf->exists('invoice_include_aging');

  my $taxtotal = 0;
  my $tax_section = { 'description' => $self->mt('Taxes, Surcharges, and Fees'),
                      'subtotal'    => $taxtotal,   # adjusted below
                    };
  my $tax_weight = _pkg_category($tax_section->{description})
                        ? _pkg_category($tax_section->{description})->weight
                        : 0;
  $tax_section->{'summarized'} = ''; #why? $summarypage && !$tax_weight ? 'Y' : '';
  $tax_section->{'sort_weight'} = $tax_weight;


  my $adjusttotal = 0;
  my $adjust_section = { 'description' => 
    $self->mt('Credits, Payments, and Adjustments'),
                         'subtotal'    => 0,   # adjusted below
                       };
  my $adjust_weight = _pkg_category($adjust_section->{description})
                        ? _pkg_category($adjust_section->{description})->weight
                        : 0;
  $adjust_section->{'summarized'} = ''; #why? $summarypage && !$adjust_weight ? 'Y' : '';
  $adjust_section->{'sort_weight'} = $adjust_weight;

  my $unsquelched = $params{unsquelch_cdr} || $cust_main->squelch_cdr ne 'Y';
  my $multisection = $conf->exists('invoice_sections', $cust_main->agentnum);
  $invoice_data{'multisection'} = $multisection;
  my $late_sections = [];
  my $extra_sections = [];
  my $extra_lines = ();

  my $default_section = { 'description' => '',
                          'subtotal'    => '', 
                          'no_subtotal' => 1,
                        };

  if ( $multisection ) {
    ($extra_sections, $extra_lines) =
      $self->_items_extra_usage_sections($escape_function_nonbsp, $format)
      if $conf->exists('usage_class_as_a_section', $cust_main->agentnum)
      && $self->can('_items_extra_usage_sections');

    push @$extra_sections, $adjust_section if $adjust_section->{sort_weight};

    push @detail_items, @$extra_lines if $extra_lines;
    push @sections,
      $self->_items_sections( $late_sections,      # this could stand a refactor
                              $summarypage,
                              $escape_function_nonbsp,
                              $extra_sections,
                              $format,             #bah
                            );
    if (    $conf->exists('svc_phone_sections')
         && $self->can('_items_svc_phone_sections')
       )
    {
      my ($phone_sections, $phone_lines) =
        $self->_items_svc_phone_sections($escape_function_nonbsp, $format);
      push @{$late_sections}, @$phone_sections;
      push @detail_items, @$phone_lines;
    }
    if ( $conf->exists('voip-cust_accountcode_cdr')
         && $cust_main->accountcode_cdr
         && $self->can('_items_accountcode_cdr')
       )
    {
      my ($accountcode_section, $accountcode_lines) =
        $self->_items_accountcode_cdr($escape_function_nonbsp,$format);
      if ( scalar(@$accountcode_lines) ) {
          push @{$late_sections}, $accountcode_section;
          push @detail_items, @$accountcode_lines;
      }
    }
  } else {# not multisection
    # make a default section
    push @sections, $default_section;
    # and calculate the finance charge total, since it won't get done otherwise.
    # XXX possibly other totals?
    # XXX possibly finance_pkgclass should not be used in this manner?
    if ( $conf->exists('finance_pkgclass') ) {
      my @finance_charges;
      foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
        if ( grep { $_->section eq $invoice_data{finance_section} }
             $cust_bill_pkg->cust_bill_pkg_display ) {
          # I think these are always setup fees, but just to be sure...
          push @finance_charges, $cust_bill_pkg->recur + $cust_bill_pkg->setup;
        }
      }
      $invoice_data{finance_amount} = 
        sprintf('%.2f', sum( @finance_charges ) || 0);
    }
  }

  unless (    $conf->exists('disable_previous_balance', $agentnum)
           || $conf->exists('previous_balance-summary_only')
           || ! $self->can('_items_previous')
         )
  {

    warn "$me adding previous balances\n"
      if $DEBUG > 1;

    foreach my $line_item ( $self->_items_previous ) {

      my $detail = {
        ext_description => [],
      };
      $detail->{'ref'} = $line_item->{'pkgnum'};
      $detail->{'quantity'} = 1;
      $detail->{'section'} = $multisection ? $previous_section
                                           : $default_section;
      $detail->{'description'} = &$escape_function($line_item->{'description'});
      if ( exists $line_item->{'ext_description'} ) {
        @{$detail->{'ext_description'}} = map {
          &$escape_function($_);
        } @{$line_item->{'ext_description'}};
      }
      $detail->{'amount'} = ( $old_latex ? '' : $money_char).
                            $line_item->{'amount'};
      $detail->{'product_code'} = $line_item->{'pkgpart'} || 'N/A';

      push @detail_items, $detail;
      push @buf, [ $detail->{'description'},
                   $money_char. sprintf("%10.2f", $line_item->{'amount'}),
                 ];
    }

  }
  
  if ( @pr_cust_bill && !$conf->exists('disable_previous_balance', $agentnum) ) 
    {
    push @buf, ['','-----------'];
    push @buf, [ $self->mt('Total Previous Balance'),
                 $money_char. sprintf("%10.2f", $pr_total) ];
    push @buf, ['',''];
  }
 
  if ( $conf->exists('svc_phone-did-summary') && $self->can('_did_summary') ) {
      warn "$me adding DID summary\n"
        if $DEBUG > 1;

      my ($didsummary,$minutes) = $self->_did_summary;
      my $didsummary_desc = 'DID Activity Summary (since last invoice)';
      push @detail_items, 
       { 'description' => $didsummary_desc,
           'ext_description' => [ $didsummary, $minutes ],
       };
  }

  foreach my $section (@sections, @$late_sections) {

    warn "$me adding section \n". Dumper($section)
      if $DEBUG > 1;

    # begin some normalization
    $section->{'subtotal'} = $section->{'amount'}
      if $multisection
         && !exists($section->{subtotal})
         && exists($section->{amount});

    $invoice_data{finance_amount} = sprintf('%.2f', $section->{'subtotal'} )
      if ( $invoice_data{finance_section} &&
           $section->{'description'} eq $invoice_data{finance_section} );

    $section->{'subtotal'} = $other_money_char.
                             sprintf('%.2f', $section->{'subtotal'})
      if $multisection;

    # continue some normalization
    $section->{'amount'}   = $section->{'subtotal'}
      if $multisection;


    if ( $section->{'description'} ) {
      push @buf, ( [ &$escape_function($section->{'description'}), '' ],
                   [ '', '' ],
                 );
    }

    warn "$me   setting options\n"
      if $DEBUG > 1;

    my $multilocation = scalar($cust_main->cust_location); #too expensive?
    my %options = ();
    $options{'section'} = $section if $multisection;
    $options{'format'} = $format;
    $options{'escape_function'} = $escape_function;
    $options{'no_usage'} = 1 unless $unsquelched;
    $options{'unsquelched'} = $unsquelched;
    $options{'summary_page'} = $summarypage;
    $options{'skip_usage'} =
      scalar(@$extra_sections) && !grep{$section == $_} @$extra_sections;
    $options{'multilocation'} = $multilocation;
    $options{'multisection'} = $multisection;

    warn "$me   searching for line items\n"
      if $DEBUG > 1;

    foreach my $line_item ( $self->_items_pkg(%options) ) {

      warn "$me     adding line item $line_item\n"
        if $DEBUG > 1;

      my $detail = {
        ext_description => [],
      };
      $detail->{'ref'} = $line_item->{'pkgnum'};
      $detail->{'quantity'} = $line_item->{'quantity'};
      $detail->{'section'} = $section;
      $detail->{'description'} = &$escape_function($line_item->{'description'});
      if ( exists $line_item->{'ext_description'} ) {
        @{$detail->{'ext_description'}} = @{$line_item->{'ext_description'}};
      }
      $detail->{'amount'} = ( $old_latex ? '' : $money_char ).
                              $line_item->{'amount'};
      $detail->{'unit_amount'} = ( $old_latex ? '' : $money_char ).
                                 $line_item->{'unit_amount'};
      $detail->{'product_code'} = $line_item->{'pkgpart'} || 'N/A';

      $detail->{'sdate'} = $line_item->{'sdate'};
      $detail->{'edate'} = $line_item->{'edate'};
      $detail->{'seconds'} = $line_item->{'seconds'};
  
      push @detail_items, $detail;
      push @buf, ( [ $detail->{'description'},
                     $money_char. sprintf("%10.2f", $line_item->{'amount'}),
                   ],
                   map { [ " ". $_, '' ] } @{$detail->{'ext_description'}},
                 );
    }

    if ( $section->{'description'} ) {
      push @buf, ( ['','-----------'],
                   [ $section->{'description'}. ' sub-total',
                      $section->{'subtotal'} # already formatted this 
                   ],
                   [ '', '' ],
                   [ '', '' ],
                 );
    }
  
  }

  $invoice_data{current_less_finance} =
    sprintf('%.2f', $self->charged - $invoice_data{finance_amount} );

  if ( $multisection && !$conf->exists('disable_previous_balance', $agentnum)
    || $conf->exists('previous_balance-summary_only') )
  {
    unshift @sections, $previous_section if $pr_total;
  }

  warn "$me adding taxes\n"
    if $DEBUG > 1;

  foreach my $tax ( $self->_items_tax ) {

    $taxtotal += $tax->{'amount'};

    my $description = &$escape_function( $tax->{'description'} );
    my $amount      = sprintf( '%.2f', $tax->{'amount'} );

    if ( $multisection ) {

      my $money = $old_latex ? '' : $money_char;
      push @detail_items, {
        ext_description => [],
        ref          => '',
        quantity     => '',
        description  => $description,
        amount       => $money. $amount,
        product_code => '',
        section      => $tax_section,
      };

    } else {

      push @total_items, {
        'total_item'   => $description,
        'total_amount' => $other_money_char. $amount,
      };

    }

    push @buf,[ $description,
                $money_char. $amount,
              ];

  }
  
  if ( $taxtotal ) {
    my $total = {};
    $total->{'total_item'} = $self->mt('Sub-total');
    $total->{'total_amount'} =
      $other_money_char. sprintf('%.2f', $self->charged - $taxtotal );

    if ( $multisection ) {
      $tax_section->{'subtotal'} = $other_money_char.
                                   sprintf('%.2f', $taxtotal);
      $tax_section->{'pretotal'} = 'New charges sub-total '.
                                   $total->{'total_amount'};
      push @sections, $tax_section if $taxtotal;
    }else{
      unshift @total_items, $total;
    }
  }
  $invoice_data{'taxtotal'} = sprintf('%.2f', $taxtotal);

  push @buf,['','-----------'];
  push @buf,[$self->mt( 
              $conf->exists('disable_previous_balance', $agentnum) 
               ? 'Total Charges'
               : 'Total New Charges'
             ),
             $money_char. sprintf("%10.2f",$self->charged) ];
  push @buf,['',''];

  {
    my $total = {};
    my $item = 'Total';
    $item = $conf->config('previous_balance-exclude_from_total')
         || 'Total New Charges'
      if $conf->exists('previous_balance-exclude_from_total');
    my $amount = $self->charged +
                   ( $conf->exists('disable_previous_balance', $agentnum) ||
                     $conf->exists('previous_balance-exclude_from_total')
                     ? 0
                     : $pr_total
                   );
    $total->{'total_item'} = &$embolden_function($self->mt($item));
    $total->{'total_amount'} =
      &$embolden_function( $other_money_char.  sprintf( '%.2f', $amount ) );
    if ( $multisection ) {
      if ( $adjust_section->{'sort_weight'} ) {
        $adjust_section->{'posttotal'} = $self->mt('Balance Forward').' '.
          $other_money_char.  sprintf("%.2f", ($self->billing_balance || 0) );
      } else {
        $adjust_section->{'pretotal'} = $self->mt('New charges total').' '.
          $other_money_char.  sprintf('%.2f', $self->charged );
      } 
    }else{
      push @total_items, $total;
    }
    push @buf,['','-----------'];
    push @buf,[$item,
               $money_char.
               sprintf( '%10.2f', $amount )
              ];
    push @buf,['',''];
  }
  
  unless (    $conf->exists('disable_previous_balance', $agentnum) 
           || ! $self->can('_items_credits')
           || ! $self->can('_items_payments')
         )
  {
    #foreach my $thing ( sort { $a->_date <=> $b->_date } $self->_items_credits, $self->_items_payments
  
    # credits
    my $credittotal = 0;
    foreach my $credit ( $self->_items_credits('trim_len'=>60) ) {

      my $total;
      $total->{'total_item'} = &$escape_function($credit->{'description'});
      $credittotal += $credit->{'amount'};
      $total->{'total_amount'} = '-'. $other_money_char. $credit->{'amount'};
      $adjusttotal += $credit->{'amount'};
      if ( $multisection ) {
        my $money = $old_latex ? '' : $money_char;
        push @detail_items, {
          ext_description => [],
          ref          => '',
          quantity     => '',
          description  => &$escape_function($credit->{'description'}),
          amount       => $money. $credit->{'amount'},
          product_code => '',
          section      => $adjust_section,
        };
      } else {
        push @total_items, $total;
      }

    }
    $invoice_data{'credittotal'} = sprintf('%.2f', $credittotal);

    #credits (again)
    foreach my $credit ( $self->_items_credits('trim_len'=>32) ) {
      push @buf, [ $credit->{'description'}, $money_char.$credit->{'amount'} ];
    }

    # payments
    my $paymenttotal = 0;
    foreach my $payment ( $self->_items_payments ) {
      my $total = {};
      $total->{'total_item'} = &$escape_function($payment->{'description'});
      $paymenttotal += $payment->{'amount'};
      $total->{'total_amount'} = '-'. $other_money_char. $payment->{'amount'};
      $adjusttotal += $payment->{'amount'};
      if ( $multisection ) {
        my $money = $old_latex ? '' : $money_char;
        push @detail_items, {
          ext_description => [],
          ref          => '',
          quantity     => '',
          description  => &$escape_function($payment->{'description'}),
          amount       => $money. $payment->{'amount'},
          product_code => '',
          section      => $adjust_section,
        };
      }else{
        push @total_items, $total;
      }
      push @buf, [ $payment->{'description'},
                   $money_char. sprintf("%10.2f", $payment->{'amount'}),
                 ];
    }
    $invoice_data{'paymenttotal'} = sprintf('%.2f', $paymenttotal);
  
    if ( $multisection ) {
      $adjust_section->{'subtotal'} = $other_money_char.
                                      sprintf('%.2f', $adjusttotal);
      push @sections, $adjust_section
        unless $adjust_section->{sort_weight};
    }

    # create Balance Due message
    { 
      my $total;
      $total->{'total_item'} = &$embolden_function($self->balance_due_msg);
      $total->{'total_amount'} =
        &$embolden_function(
          $other_money_char. sprintf('%.2f', $summarypage 
                                               ? $self->charged +
                                                 $self->billing_balance
                                               : $self->owed + $pr_total
                                    )
        );
      if ( $multisection && !$adjust_section->{sort_weight} ) {
        $adjust_section->{'posttotal'} = $total->{'total_item'}. ' '.
                                         $total->{'total_amount'};
      }else{
        push @total_items, $total;
      }
      push @buf,['','-----------'];
      push @buf,[$self->balance_due_msg, $money_char. 
        sprintf("%10.2f", $balance_due ) ];
    }

    if ( $conf->exists('previous_balance-show_credit')
        and $cust_main->balance < 0 ) {
      my $credit_total = {
        'total_item'    => &$embolden_function($self->credit_balance_msg),
        'total_amount'  => &$embolden_function(
          $other_money_char. sprintf('%.2f', -$cust_main->balance)
        ),
      };
      if ( $multisection ) {
        $adjust_section->{'posttotal'} .= $newline_token .
          $credit_total->{'total_item'} . ' ' . $credit_total->{'total_amount'};
      }
      else {
        push @total_items, $credit_total;
      }
      push @buf,['','-----------'];
      push @buf,[$self->credit_balance_msg, $money_char. 
        sprintf("%10.2f", -$cust_main->balance ) ];
    }
  }

  if ( $multisection ) {
    if (    $conf->exists('svc_phone_sections')
         && $self->can('_items_svc_phone_sections')
       )
    {
      my $total;
      $total->{'total_item'} = &$embolden_function($self->balance_due_msg);
      $total->{'total_amount'} =
        &$embolden_function(
          $other_money_char. sprintf('%.2f', $self->owed + $pr_total)
        );
      my $last_section = pop @sections;
      $last_section->{'posttotal'} = $total->{'total_item'}. ' '.
                                     $total->{'total_amount'};
      push @sections, $last_section;
    }
    push @sections, @$late_sections
      if $unsquelched;
  }

  # make a discounts-available section, even without multisection
  if ( $conf->exists('discount-show_available') 
       and my @discounts_avail = $self->_items_discounts_avail ) {
    my $discount_section = {
      'description' => $self->mt('Discounts Available'),
      'subtotal'    => '',
      'no_subtotal' => 1,
    };

    push @sections, $discount_section;
    push @detail_items, map { +{
        'ref'         => '', #should this be something else?
        'section'     => $discount_section,
        'description' => &$escape_function( $_->{description} ),
        'amount'      => $money_char . &$escape_function( $_->{amount} ),
        'ext_description' => [ &$escape_function($_->{ext_description}) || () ],
    } } @discounts_avail;
  }

  # All sections and items are built; now fill in templates.
  my @includelist = ();
  push @includelist, 'summary' if $summarypage;
  foreach my $include ( @includelist ) {

    my $inc_file = $conf->key_orbase("invoice_${format}$include", $template);
    my @inc_src;

    if ( length( $conf->config($inc_file, $agentnum) ) ) {

      @inc_src = $conf->config($inc_file, $agentnum);

    } else {

      $inc_file = $conf->key_orbase("invoice_latex$include", $template);

      my $convert_map = $convert_maps{$format}{$include};

      @inc_src = map { s/\[\@--/$delimiters{$format}[0]/g;
                       s/--\@\]/$delimiters{$format}[1]/g;
                       $_;
                     } 
                 &$convert_map( $conf->config($inc_file, $agentnum) );

    }

    my $inc_tt = new Text::Template (
      TYPE       => 'ARRAY',
      SOURCE     => [ map "$_\n", @inc_src ],
      DELIMITERS => $delimiters{$format},
    ) or die "Can't create new Text::Template object: $Text::Template::ERROR";

    unless ( $inc_tt->compile() ) {
      my $error = "Can't compile $inc_file template: $Text::Template::ERROR\n";
      warn $error. "Template:\n". join('', map "$_\n", @inc_src);
      die $error;
    }

    $invoice_data{$include} = $inc_tt->fill_in( HASH => \%invoice_data );

    $invoice_data{$include} =~ s/\n+$//
      if ($format eq 'latex');
  }

  $invoice_lines = 0;
  my $wasfunc = 0;
  foreach ( grep /invoice_lines\(\d*\)/, @invoice_template ) { #kludgy
    /invoice_lines\((\d*)\)/;
    $invoice_lines += $1 || scalar(@buf);
    $wasfunc=1;
  }
  die "no invoice_lines() functions in template?"
    if ( $format eq 'template' && !$wasfunc );

  if ($format eq 'template') {

    if ( $invoice_lines ) {
      $invoice_data{'total_pages'} = int( scalar(@buf) / $invoice_lines );
      $invoice_data{'total_pages'}++
        if scalar(@buf) % $invoice_lines;
    }

    #setup subroutine for the template
    $invoice_data{invoice_lines} = sub {
      my $lines = shift || scalar(@buf);
      map { 
        scalar(@buf)
          ? shift @buf
          : [ '', '' ];
      }
      ( 1 .. $lines );
    };

    my $lines;
    my @collect;
    while (@buf) {
      push @collect, split("\n",
        $text_template->fill_in( HASH => \%invoice_data )
      );
      $invoice_data{'page'}++;
    }
    map "$_\n", @collect;

  } else { # this is where we actually create the invoice

    warn "filling in template for invoice ". $self->invnum. "\n"
      if $DEBUG;
    warn join("\n", map " $_ => ". $invoice_data{$_}, keys %invoice_data). "\n"
      if $DEBUG > 1;

    $text_template->fill_in(HASH => \%invoice_data);
  }
}

sub notice_name { '('.shift->table.')'; }

sub template_conf { 'invoice_'; }

# helper routine for generating date ranges
sub _prior_month30s {
  my $self = shift;
  my @ranges = (
   [ 1,       2592000 ], # 0-30 days ago
   [ 2592000, 5184000 ], # 30-60 days ago
   [ 5184000, 7776000 ], # 60-90 days ago
   [ 7776000, 0       ], # 90+   days ago
  );

  map { [ $_->[0] ? $self->_date - $_->[0] - 1 : '',
          $_->[1] ? $self->_date - $_->[1] - 1 : '',
      ] }
  @ranges;
}

=item print_ps HASHREF | [ TIME [ , TEMPLATE ] ]

Returns an postscript invoice, as a scalar.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time> an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_ps {
  my $self = shift;

  my ($file, $logofile, $barcodefile) = $self->print_latex(@_);
  my $ps = generate_ps($file);
  unlink($logofile);
  unlink($barcodefile) if $barcodefile;

  $ps;
}

=item print_pdf HASHREF | [ TIME [ , TEMPLATE ] ]

Returns an PDF invoice, as a scalar.

Options can be passed as a hashref (recommended) or as a list of time, template
and then any key/value pairs for any other options.

I<time> an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_pdf {
  my $self = shift;

  my ($file, $logofile, $barcodefile) = $self->print_latex(@_);
  my $pdf = generate_pdf($file);
  unlink($logofile);
  unlink($barcodefile) if $barcodefile;

  $pdf;
}

=item print_html HASHREF | [ TIME [ , TEMPLATE [ , CID ] ] ]

Returns an HTML invoice, as a scalar.

I<time> an optional value used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

I<cid> is a MIME Content-ID used to create a "cid:" URL for the logo image, used
when emailing the invoice as part of a multipart/related MIME email.

=cut

sub print_html {
  my $self = shift;
  my %params;
  if ( ref($_[0]) ) {
    %params = %{ shift() }; 
  }else{
    $params{'time'} = shift;
    $params{'template'} = shift;
    $params{'cid'} = shift;
  }

  $params{'format'} = 'html';
  
  $self->print_generic( %params );
}

# quick subroutine for print_latex
#
# There are ten characters that LaTeX treats as special characters, which
# means that they do not simply typeset themselves: 
#      # $ % & ~ _ ^ \ { }
#
# TeX ignores blanks following an escaped character; if you want a blank (as
# in "10% of ..."), you have to "escape" the blank as well ("10\%\ of ..."). 

sub _latex_escape {
  my $value = shift;
  $value =~ s/([#\$%&~_\^{}])( )?/"\\$1". ( ( defined($2) && length($2) ) ? "\\$2" : '' )/ge;
  $value =~ s/([<>])/\$$1\$/g;
  $value;
}

sub _html_escape {
  my $value = shift;
  encode_entities($value);
  $value;
}

sub _html_escape_nbsp {
  my $value = _html_escape(shift);
  $value =~ s/ +/&nbsp;/g;
  $value;
}

#utility methods for print_*

sub _translate_old_latex_format {
  warn "_translate_old_latex_format called\n"
    if $DEBUG; 

  my @template = ();
  while ( @_ ) {
    my $line = shift;
  
    if ( $line =~ /^%%Detail\s*$/ ) {
  
      push @template, q![@--!,
                      q!  foreach my $_tr_line (@detail_items) {!,
                      q!    if ( scalar ($_tr_item->{'ext_description'} ) ) {!,
                      q!      $_tr_line->{'description'} .= !, 
                      q!        "\\tabularnewline\n~~".!,
                      q!        join( "\\tabularnewline\n~~",!,
                      q!          @{$_tr_line->{'ext_description'}}!,
                      q!        );!,
                      q!    }!;

      while ( ( my $line_item_line = shift )
              !~ /^%%EndDetail\s*$/                            ) {
        $line_item_line =~ s/'/\\'/g;    # nice LTS
        $line_item_line =~ s/\\/\\\\/g;  # escape quotes and backslashes
        $line_item_line =~ s/\$(\w+)/'. \$_tr_line->{$1}. '/g;
        push @template, "    \$OUT .= '$line_item_line';";
      }

      push @template, '}',
                      '--@]';
      #' doh, gvim
    } elsif ( $line =~ /^%%TotalDetails\s*$/ ) {

      push @template, '[@--',
                      '  foreach my $_tr_line (@total_items) {';

      while ( ( my $total_item_line = shift )
              !~ /^%%EndTotalDetails\s*$/                      ) {
        $total_item_line =~ s/'/\\'/g;    # nice LTS
        $total_item_line =~ s/\\/\\\\/g;  # escape quotes and backslashes
        $total_item_line =~ s/\$(\w+)/'. \$_tr_line->{$1}. '/g;
        push @template, "    \$OUT .= '$total_item_line';";
      }

      push @template, '}',
                      '--@]';

    } else {
      $line =~ s/\$(\w+)/[\@-- \$$1 --\@]/g;
      push @template, $line;  
    }
  
  }

  if ($DEBUG) {
    warn "$_\n" foreach @template;
  }

  (@template);
}

sub terms {
  my $self = shift;
  my $conf = $self->conf;

  #check for an invoice-specific override
  return $self->invoice_terms if $self->invoice_terms;
  
  #check for a customer- specific override
  my $cust_main = $self->cust_main;
  return $cust_main->invoice_terms if $cust_main && $cust_main->invoice_terms;

  #use configured default
  $conf->config('invoice_default_terms') || '';
}

sub due_date {
  my $self = shift;
  my $duedate = '';
  if ( $self->terms =~ /^\s*Net\s*(\d+)\s*$/ ) {
    $duedate = $self->_date() + ( $1 * 86400 );
  }
  $duedate;
}

sub due_date2str {
  my $self = shift;
  $self->due_date ? time2str(shift, $self->due_date) : '';
}

sub balance_due_msg {
  my $self = shift;
  my $msg = $self->mt('Balance Due');
  return $msg unless $self->terms;
  if ( $self->due_date ) {
    $msg .= ' - ' . $self->mt('Please pay by'). ' '.
      $self->due_date2str($date_format);
  } elsif ( $self->terms ) {
    $msg .= ' - '. $self->terms;
  }
  $msg;
}

sub balance_due_date {
  my $self = shift;
  my $conf = $self->conf;
  my $duedate = '';
  if (    $conf->exists('invoice_default_terms') 
       && $conf->config('invoice_default_terms')=~ /^\s*Net\s*(\d+)\s*$/ ) {
    $duedate = time2str($rdate_format, $self->_date + ($1*86400) );
  }
  $duedate;
}

sub credit_balance_msg { 
  my $self = shift;
  $self->mt('Credit Balance Remaining')
}

=item _date_pretty

Returns a string with the date, for example: "3/20/2008"

=cut

sub _date_pretty {
  my $self = shift;
  time2str($date_format, $self->_date);
}

=item _items_sections LATE SUMMARYPAGE ESCAPE EXTRA_SECTIONS FORMAT

Generate section information for all items appearing on this invoice.
This will only be called for multi-section invoices.

For each line item (L<FS::cust_bill_pkg> record), this will fetch all 
related display records (L<FS::cust_bill_pkg_display>) and organize 
them into two groups ("early" and "late" according to whether they come 
before or after the total), then into sections.  A subtotal is calculated 
for each section.

Section descriptions are returned in sort weight order.  Each consists 
of a hash containing:

description: the package category name, escaped
subtotal: the total charges in that section
tax_section: a flag indicating that the section contains only tax charges
summarized: same as tax_section, for some reason
sort_weight: the package category's sort weight

If 'condense' is set on the display record, it also contains everything 
returned from C<_condense_section()>, i.e. C<_condensed_foo_generator>
coderefs to generate parts of the invoice.  This is not advised.

Arguments:

LATE: an arrayref to push the "late" section hashes onto.  The "early"
group is simply returned from the method.

SUMMARYPAGE: a flag indicating whether this is a summary-format invoice.
Turning this on has the following effects:
- Ignores display items with the 'summary' flag.
- Combines all items into the "early" group.
- Creates sections for all non-disabled package categories, even if they 
have no charges on this invoice, as well as a section with no name.

ESCAPE: an escape function to use for section titles.

EXTRA_SECTIONS: an arrayref of additional sections to return after the 
sorted list.  If there are any of these, section subtotals exclude 
usage charges.

FORMAT: 'latex', 'html', or 'template' (i.e. text).  Not used, but 
passed through to C<_condense_section()>.

=cut

use vars qw(%pkg_category_cache);
sub _items_sections {
  my $self = shift;
  my $late = shift;
  my $summarypage = shift;
  my $escape = shift;
  my $extra_sections = shift;
  my $format = shift;

  my %subtotal = ();
  my %late_subtotal = ();
  my %not_tax = ();

  foreach my $cust_bill_pkg ( $self->cust_bill_pkg )
  {

      my $usage = $cust_bill_pkg->usage;

      foreach my $display ($cust_bill_pkg->cust_bill_pkg_display) {
        next if ( $display->summary && $summarypage );

        my $section = $display->section;
        my $type    = $display->type;

        $not_tax{$section} = 1
          unless $cust_bill_pkg->pkgnum == 0;

        if ( $display->post_total && !$summarypage ) {
          if (! $type || $type eq 'S') {
            $late_subtotal{$section} += $cust_bill_pkg->setup
              if $cust_bill_pkg->setup != 0
              || $cust_bill_pkg->setup_show_zero;
          }

          if (! $type) {
            $late_subtotal{$section} += $cust_bill_pkg->recur
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }

          if ($type && $type eq 'R') {
            $late_subtotal{$section} += $cust_bill_pkg->recur - $usage
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }
          
          if ($type && $type eq 'U') {
            $late_subtotal{$section} += $usage
              unless scalar(@$extra_sections);
          }

        } else {

          next if $cust_bill_pkg->pkgnum == 0 && ! $section;

          if (! $type || $type eq 'S') {
            $subtotal{$section} += $cust_bill_pkg->setup
              if $cust_bill_pkg->setup != 0
              || $cust_bill_pkg->setup_show_zero;
          }

          if (! $type) {
            $subtotal{$section} += $cust_bill_pkg->recur
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }

          if ($type && $type eq 'R') {
            $subtotal{$section} += $cust_bill_pkg->recur - $usage
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }
          
          if ($type && $type eq 'U') {
            $subtotal{$section} += $usage
              unless scalar(@$extra_sections);
          }

        }

      }

  }

  %pkg_category_cache = ();

  push @$late, map { { 'description' => &{$escape}($_),
                       'subtotal'    => $late_subtotal{$_},
                       'post_total'  => 1,
                       'sort_weight' => ( _pkg_category($_)
                                            ? _pkg_category($_)->weight
                                            : 0
                                       ),
                       ((_pkg_category($_) && _pkg_category($_)->condense)
                                           ? $self->_condense_section($format)
                                           : ()
                       ),
                   } }
                 sort _sectionsort keys %late_subtotal;

  my @sections;
  if ( $summarypage ) {
    @sections = grep { exists($subtotal{$_}) || ! _pkg_category($_)->disabled }
                map { $_->categoryname } qsearch('pkg_category', {});
    push @sections, '' if exists($subtotal{''});
  } else {
    @sections = keys %subtotal;
  }

  my @early = map { { 'description' => &{$escape}($_),
                      'subtotal'    => $subtotal{$_},
                      'summarized'  => $not_tax{$_} ? '' : 'Y',
                      'tax_section' => $not_tax{$_} ? '' : 'Y',
                      'sort_weight' => ( _pkg_category($_)
                                           ? _pkg_category($_)->weight
                                           : 0
                                       ),
                       ((_pkg_category($_) && _pkg_category($_)->condense)
                                           ? $self->_condense_section($format)
                                           : ()
                       ),
                    }
                  } @sections;
  push @early, @$extra_sections if $extra_sections;

  sort { $a->{sort_weight} <=> $b->{sort_weight} } @early;

}

#helper subs for above

sub _sectionsort {
  _pkg_category($a)->weight <=> _pkg_category($b)->weight;
}

sub _pkg_category {
  my $categoryname = shift;
  $pkg_category_cache{$categoryname} ||=
    qsearchs( 'pkg_category', { 'categoryname' => $categoryname } );
}

my %condensed_format = (
  'label' => [ qw( Description Qty Amount ) ],
  'fields' => [
                sub { shift->{description} },
                sub { shift->{quantity} },
                sub { my($href, %opt) = @_;
                      ($opt{dollar} || ''). $href->{amount};
                    },
              ],
  'align'  => [ qw( l r r ) ],
  'span'   => [ qw( 5 1 1 ) ],            # unitprices?
  'width'  => [ qw( 10.7cm 1.4cm 1.6cm ) ],   # don't like this
);

sub _condense_section {
  my ( $self, $format ) = ( shift, shift );
  ( 'condensed' => 1,
    map { my $method = "_condensed_$_"; $_ => $self->$method($format) }
      qw( description_generator
          header_generator
          total_generator
          total_line_generator
        )
  );
}

sub _condensed_generator_defaults {
  my ( $self, $format ) = ( shift, shift );
  return ( \%condensed_format, ' ', ' ', ' ', sub { shift } );
}

my %html_align = (
  'c' => 'center',
  'l' => 'left',
  'r' => 'right',
);

sub _condensed_header_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);

  if ($format eq 'latex') {
    $prefix = "\\hline\n\\rule{0pt}{2.5ex}\n\\makebox[1.4cm]{}&\n";
    $suffix = "\\\\\n\\hline";
    $separator = "&\n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{\\textbf{$d}}}";
          };
  } elsif ( $format eq 'html' ) {
    $prefix = '<th></th>';
    $suffix = '';
    $separator = '';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<th align="$html_align{$a}">$d</th>!;
      };
  }

  sub {
    my @args = @_;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( map { $f->{$_}->[$i] } qw(label align span width) );
    }

    $prefix. join($separator, @result). $suffix;
  };

}

sub _condensed_description_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);

  my $money_char = '$';
  if ($format eq 'latex') {
    $prefix = "\\hline\n\\multicolumn{1}{c}{\\rule{0pt}{2.5ex}~} &\n";
    $suffix = '\\\\';
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{\\textbf{$d}}}";
          };
    $money_char = '\\dollar';
  }elsif ( $format eq 'html' ) {
    $prefix = '"><td align="center"></td>';
    $suffix = '';
    $separator = '';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}">$d</td>!;
      };
    #$money_char = $conf->config('money_char') || '$';
    $money_char = '';  # this is madness
  }

  sub {
    #my @args = @_;
    my $href = shift;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      my $dollar = '';
      $dollar = $money_char if $i == scalar(@{$f->{label}})-1;
      push @result,
        &{$column}( &{$f->{fields}->[$i]}($href, 'dollar' => $dollar),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}

sub _condensed_total_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);
  my $style = '';

  if ($format eq 'latex') {
    $prefix = "& ";
    $suffix = "\\\\\n";
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{$d}}";
          };
  }elsif ( $format eq 'html' ) {
    $prefix = '';
    $suffix = '';
    $separator = '';
    $style = 'border-top: 3px solid #000000;border-bottom: 3px solid #000000;';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}" style="$style">$d</td>!;
      };
  }


  sub {
    my @args = @_;
    my @result = ();

    #  my $r = &{$f->{fields}->[$i]}(@args);
    #  $r .= ' Total' unless $i;

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( &{$f->{fields}->[$i]}(@args). ($i ? '' : ' Total'),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}

=item total_line_generator FORMAT

Returns a coderef used for generation of invoice total line items for this
usage_class.  FORMAT is either html or latex

=cut

# should not be used: will have issues with hash element names (description vs
# total_item and amount vs total_amount -- another array of functions?

sub _condensed_total_line_generator {
  my ( $self, $format ) = ( shift, shift );

  my ( $f, $prefix, $suffix, $separator, $column ) =
    _condensed_generator_defaults($format);
  my $style = '';

  if ($format eq 'latex') {
    $prefix = "& ";
    $suffix = "\\\\\n";
    $separator = " & \n";
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return "\\multicolumn{$s}{$a}{\\makebox[$w][$a]{$d}}";
          };
  }elsif ( $format eq 'html' ) {
    $prefix = '';
    $suffix = '';
    $separator = '';
    $style = 'border-top: 3px solid #000000;border-bottom: 3px solid #000000;';
    $column =
      sub { my ($d,$a,$s,$w) = @_;
            return qq!<td align="$html_align{$a}" style="$style">$d</td>!;
      };
  }


  sub {
    my @args = @_;
    my @result = ();

    foreach  (my $i = 0; $f->{label}->[$i]; $i++) {
      push @result,
        &{$column}( &{$f->{fields}->[$i]}(@args),
                    map { $f->{$_}->[$i] } qw(align span width)
                  );
    }

    $prefix. join( $separator, @result ). $suffix;
  };

}

#  sub _items { # seems to be unused
#    my $self = shift;
#  
#    #my @display = scalar(@_)
#    #              ? @_
#    #              : qw( _items_previous _items_pkg );
#    #              #: qw( _items_pkg );
#    #              #: qw( _items_previous _items_pkg _items_tax _items_credits _items_payments );
#    my @display = qw( _items_previous _items_pkg );
#  
#    my @b = ();
#    foreach my $display ( @display ) {
#      push @b, $self->$display(@_);
#    }
#    @b;
#  }

=item _items_pkg [ OPTIONS ]

Return line item hashes for each package item on this invoice. Nearly 
equivalent to 

$self->_items_cust_bill_pkg([ $self->cust_bill_pkg ])

The only OPTIONS accepted is 'section', which may point to a hashref 
with a key named 'condensed', which may have a true value.  If it 
does, this method tries to merge identical items into items with 
'quantity' equal to the number of items (not the sum of their 
separate quantities, for some reason).

=cut

sub _items_pkg {
  my $self = shift;
  my %options = @_;

  warn "$me _items_pkg searching for all package line items\n"
    if $DEBUG > 1;

  my @cust_bill_pkg = grep { $_->pkgnum } $self->cust_bill_pkg;

  warn "$me _items_pkg filtering line items\n"
    if $DEBUG > 1;
  my @items = $self->_items_cust_bill_pkg(\@cust_bill_pkg, @_);

  if ($options{section} && $options{section}->{condensed}) {

    warn "$me _items_pkg condensing section\n"
      if $DEBUG > 1;

    my %itemshash = ();
    local $Storable::canonical = 1;
    foreach ( @items ) {
      my $item = { %$_ };
      delete $item->{ref};
      delete $item->{ext_description};
      my $key = freeze($item);
      $itemshash{$key} ||= 0;
      $itemshash{$key} ++; # += $item->{quantity};
    }
    @items = sort { $a->{description} cmp $b->{description} }
             map { my $i = thaw($_);
                   $i->{quantity} = $itemshash{$_};
                   $i->{amount} =
                     sprintf( "%.2f", $i->{quantity} * $i->{amount} );#unit_amount
                   $i;
                 }
             keys %itemshash;
  }

  warn "$me _items_pkg returning ". scalar(@items). " items\n"
    if $DEBUG > 1;

  @items;
}

sub _taxsort {
  return 0 unless $a->itemdesc cmp $b->itemdesc;
  return -1 if $b->itemdesc eq 'Tax';
  return 1 if $a->itemdesc eq 'Tax';
  return -1 if $b->itemdesc eq 'Other surcharges';
  return 1 if $a->itemdesc eq 'Other surcharges';
  $a->itemdesc cmp $b->itemdesc;
}

sub _items_tax {
  my $self = shift;
  my @cust_bill_pkg = sort _taxsort grep { ! $_->pkgnum } $self->cust_bill_pkg;
  $self->_items_cust_bill_pkg(\@cust_bill_pkg, @_);
}

=item _items_cust_bill_pkg CUST_BILL_PKGS OPTIONS

Takes an arrayref of L<FS::cust_bill_pkg> objects, and returns a
list of hashrefs describing the line items they generate on the invoice.

OPTIONS may include:

format: the invoice format.

escape_function: the function used to escape strings.

DEPRECATED? (expensive, mostly unused?)
format_function: the function used to format CDRs.

section: a hashref containing 'description'; if this is present, 
cust_bill_pkg_display records not belonging to this section are 
ignored.

multisection: a flag indicating that this is a multisection invoice,
which does something complicated.

multilocation: a flag to display the location label for the package.

Returns a list of hashrefs, each of which may contain:

pkgnum, description, amount, unit_amount, quantity, _is_setup, and 
ext_description, which is an arrayref of detail lines to show below 
the package line.

=cut

sub _items_cust_bill_pkg {
  my $self = shift;
  my $conf = $self->conf;
  my $cust_bill_pkgs = shift;
  my %opt = @_;

  my $format = $opt{format} || '';
  my $escape_function = $opt{escape_function} || sub { shift };
  my $format_function = $opt{format_function} || '';
  my $no_usage = $opt{no_usage} || '';
  my $unsquelched = $opt{unsquelched} || ''; #unused
  my $section = $opt{section}->{description} if $opt{section};
  my $summary_page = $opt{summary_page} || ''; #unused
  my $multilocation = $opt{multilocation} || '';
  my $multisection = $opt{multisection} || '';
  my $discount_show_always = 0;

  my $maxlength = $conf->config('cust_bill-latex_lineitem_maxlength') || 50;

  my $cust_main = $self->cust_main;#for per-agent cust_bill-line_item-ate_style

  my @b = ();
  my ($s, $r, $u) = ( undef, undef, undef );
  foreach my $cust_bill_pkg ( @$cust_bill_pkgs )
  {

    foreach ( $s, $r, ($opt{skip_usage} ? () : $u ) ) {
      if ( $_ && !$cust_bill_pkg->hidden ) {
        $_->{amount}      = sprintf( "%.2f", $_->{amount} ),
        $_->{amount}      =~ s/^\-0\.00$/0.00/;
        $_->{unit_amount} = sprintf( "%.2f", $_->{unit_amount} ),
        push @b, { %$_ }
          if $_->{amount} != 0
          || $discount_show_always
          || ( ! $_->{_is_setup} && $_->{recur_show_zero} )
          || (   $_->{_is_setup} && $_->{setup_show_zero} )
        ;
        $_ = undef;
      }
    }

    my @cust_bill_pkg_display = $cust_bill_pkg->cust_bill_pkg_display;

    warn "$me _items_cust_bill_pkg considering cust_bill_pkg ".
         $cust_bill_pkg->billpkgnum. ", pkgnum ". $cust_bill_pkg->pkgnum. "\n"
      if $DEBUG > 1;

    foreach my $display ( grep { defined($section)
                                 ? $_->section eq $section
                                 : 1
                               }
                          #grep { !$_->summary || !$summary_page } # bunk!
                          grep { !$_->summary || $multisection }
                          @cust_bill_pkg_display
                        )
    {

      warn "$me _items_cust_bill_pkg considering cust_bill_pkg_display ".
           $display->billpkgdisplaynum. "\n"
        if $DEBUG > 1;

      my $type = $display->type;

      my $desc = $cust_bill_pkg->desc;
      $desc = substr($desc, 0, $maxlength). '...'
        if $format eq 'latex' && length($desc) > $maxlength;

      my %details_opt = ( 'format'          => $format,
                          'escape_function' => $escape_function,
                          'format_function' => $format_function,
                          'no_usage'        => $opt{'no_usage'},
                        );

      if ( $cust_bill_pkg->pkgnum > 0 ) {

        warn "$me _items_cust_bill_pkg cust_bill_pkg is non-tax\n"
          if $DEBUG > 1;
 
        my $cust_pkg = $cust_bill_pkg->cust_pkg;

        # start/end dates for invoice formats that do nonstandard 
        # things with them
        my %item_dates = map { $_ => $cust_bill_pkg->$_ } ('sdate', 'edate');

        if (    (!$type || $type eq 'S')
             && (    $cust_bill_pkg->setup != 0
                  || $cust_bill_pkg->setup_show_zero
                )
           )
         {

          warn "$me _items_cust_bill_pkg adding setup\n"
            if $DEBUG > 1;

          my $description = $desc;
          $description .= ' Setup'
            if $cust_bill_pkg->recur != 0
            || $discount_show_always
            || $cust_bill_pkg->recur_show_zero;

          my @d = ();
          unless ( $cust_pkg->part_pkg->hide_svc_detail
                || $cust_bill_pkg->hidden )
          {

            push @d, map &{$escape_function}($_),
                         $cust_pkg->h_labels_short($self->_date, undef, 'I')
              unless $cust_bill_pkg->pkgpart_override; #don't redisplay services

            if ( $multilocation ) {
              my $loc = $cust_pkg->location_label;
              $loc = substr($loc, 0, $maxlength). '...'
                if $format eq 'latex' && length($loc) > $maxlength;
              push @d, &{$escape_function}($loc);
            }

          } #unless hiding service details

          push @d, $cust_bill_pkg->details(%details_opt)
            if $cust_bill_pkg->recur == 0;

          if ( $cust_bill_pkg->hidden ) {
            $s->{amount}      += $cust_bill_pkg->setup;
            $s->{unit_amount} += $cust_bill_pkg->unitsetup;
            push @{ $s->{ext_description} }, @d;
          } else {
            $s = {
              _is_setup       => 1,
              description     => $description,
              #pkgpart         => $part_pkg->pkgpart,
              pkgnum          => $cust_bill_pkg->pkgnum,
              amount          => $cust_bill_pkg->setup,
              setup_show_zero => $cust_bill_pkg->setup_show_zero,
              unit_amount     => $cust_bill_pkg->unitsetup,
              quantity        => $cust_bill_pkg->quantity,
              ext_description => \@d,
            };
          };

        }

        if (    ( !$type || $type eq 'R' || $type eq 'U' )
             && (
                     $cust_bill_pkg->recur != 0
                  || $cust_bill_pkg->setup == 0
                  || $discount_show_always
                  || $cust_bill_pkg->recur_show_zero
                )
           )
        {

          warn "$me _items_cust_bill_pkg adding recur/usage\n"
            if $DEBUG > 1;

          my $is_summary = $display->summary;
          my $description = ($is_summary && $type && $type eq 'U')
                            ? "Usage charges" : $desc;

          #pry be a bit more efficient to look some of this conf stuff up
          # outside the loop
          unless (
            $conf->exists('disable_line_item_date_ranges')
              || $cust_pkg->part_pkg->option('disable_line_item_date_ranges',1)
          ) {
            my $time_period;
            my $date_style = $conf->config( 'cust_bill-line_item-date_style',
                                            $cust_main->agentnum
                                          );
            if ( defined($date_style) && $date_style eq 'month_of' ) {
              $time_period = time2str('The month of %B', $cust_bill_pkg->sdate);
            } elsif ( defined($date_style) && $date_style eq 'X_month' ) {
              my $desc = $conf->config( 'cust_bill-line_item-date_description',
                                         $cust_main->agentnum
                                      );
              $desc .= ' ' unless $desc =~ /\s$/;
              $time_period = $desc. time2str('%B', $cust_bill_pkg->sdate);
            } else {
              $time_period =      time2str($date_format, $cust_bill_pkg->sdate).
                           " - ". time2str($date_format, $cust_bill_pkg->edate);
            }
            $description .= " ($time_period)";
          }

          my @d = ();
          my @seconds = (); # for display of usage info

          #at least until cust_bill_pkg has "past" ranges in addition to
          #the "future" sdate/edate ones... see #3032
          my @dates = ( $self->_date );
          my $prev = $cust_bill_pkg->previous_cust_bill_pkg;
          push @dates, $prev->sdate if $prev;
          push @dates, undef if !$prev;

          unless ( $cust_pkg->part_pkg->hide_svc_detail
                || $cust_bill_pkg->itemdesc
                || $cust_bill_pkg->hidden
                || $is_summary && $type && $type eq 'U' )
          {

            warn "$me _items_cust_bill_pkg adding service details\n"
              if $DEBUG > 1;

            push @d, map &{$escape_function}($_),
                         $cust_pkg->h_labels_short(@dates, 'I')
                                                   #$cust_bill_pkg->edate,
                                                   #$cust_bill_pkg->sdate)
              unless $cust_bill_pkg->pkgpart_override; #don't redisplay services

            warn "$me _items_cust_bill_pkg done adding service details\n"
              if $DEBUG > 1;

            if ( $multilocation ) {
              my $loc = $cust_pkg->location_label;
              $loc = substr($loc, 0, $maxlength). '...'
                if $format eq 'latex' && length($loc) > $maxlength;
              push @d, &{$escape_function}($loc);
            }

            # Display of seconds_since_sqlradacct:
            # On the invoice, when processing @detail_items, look for a field
            # named 'seconds'.  This will contain total seconds for each 
            # service, in the same order as @ext_description.  For services 
            # that don't support this it will show undef.
            if ( $conf->exists('svc_acct-usage_seconds') 
                 and ! $cust_bill_pkg->pkgpart_override ) {
              foreach my $cust_svc ( 
                  $cust_pkg->h_cust_svc(@dates, 'I') 
                ) {

                # eval because not having any part_export_usage exports 
                # is a fatal error, last_bill/_date because that's how 
                # sqlradius_hour billing does it
                my $sec = eval {
                  $cust_svc->seconds_since_sqlradacct($dates[1] || 0, $dates[0]);
                };
                push @seconds, $sec;
              }
            } #if svc_acct-usage_seconds

          }

          unless ( $is_summary ) {
            warn "$me _items_cust_bill_pkg adding details\n"
              if $DEBUG > 1;

            #instead of omitting details entirely in this case (unwanted side
            # effects), just omit CDRs
            $details_opt{'no_usage'} = 1
              if $type && $type eq 'R';

            push @d, $cust_bill_pkg->details(%details_opt);
          }

          warn "$me _items_cust_bill_pkg calculating amount\n"
            if $DEBUG > 1;
  
          my $amount = 0;
          if (!$type) {
            $amount = $cust_bill_pkg->recur;
          } elsif ($type eq 'R') {
            $amount = $cust_bill_pkg->recur - $cust_bill_pkg->usage;
          } elsif ($type eq 'U') {
            $amount = $cust_bill_pkg->usage;
          }
  
          if ( !$type || $type eq 'R' ) {

            warn "$me _items_cust_bill_pkg adding recur\n"
              if $DEBUG > 1;

            if ( $cust_bill_pkg->hidden ) {
              $r->{amount}      += $amount;
              $r->{unit_amount} += $cust_bill_pkg->unitrecur;
              push @{ $r->{ext_description} }, @d;
            } else {
              $r = {
                description     => $description,
                #pkgpart         => $part_pkg->pkgpart,
                pkgnum          => $cust_bill_pkg->pkgnum,
                amount          => $amount,
                recur_show_zero => $cust_bill_pkg->recur_show_zero,
                unit_amount     => $cust_bill_pkg->unitrecur,
                quantity        => $cust_bill_pkg->quantity,
                %item_dates,
                ext_description => \@d,
              };
              $r->{'seconds'} = \@seconds if grep {defined $_} @seconds;
            }

          } else {  # $type eq 'U'

            warn "$me _items_cust_bill_pkg adding usage\n"
              if $DEBUG > 1;

            if ( $cust_bill_pkg->hidden ) {
              $u->{amount}      += $amount;
              $u->{unit_amount} += $cust_bill_pkg->unitrecur;
              push @{ $u->{ext_description} }, @d;
            } else {
              $u = {
                description     => $description,
                #pkgpart         => $part_pkg->pkgpart,
                pkgnum          => $cust_bill_pkg->pkgnum,
                amount          => $amount,
                recur_show_zero => $cust_bill_pkg->recur_show_zero,
                unit_amount     => $cust_bill_pkg->unitrecur,
                quantity        => $cust_bill_pkg->quantity,
                %item_dates,
                ext_description => \@d,
              };
            }
          }

        } # recurring or usage with recurring charge

      } else { #pkgnum tax or one-shot line item (??)

        warn "$me _items_cust_bill_pkg cust_bill_pkg is tax\n"
          if $DEBUG > 1;

        if ( $cust_bill_pkg->setup != 0 ) {
          push @b, {
            'description' => $desc,
            'amount'      => sprintf("%.2f", $cust_bill_pkg->setup),
          };
        }
        if ( $cust_bill_pkg->recur != 0 ) {
          push @b, {
            'description' => "$desc (".
                             time2str($date_format, $cust_bill_pkg->sdate). ' - '.
                             time2str($date_format, $cust_bill_pkg->edate). ')',
            'amount'      => sprintf("%.2f", $cust_bill_pkg->recur),
          };
        }

      }

    }

    $discount_show_always = ($cust_bill_pkg->cust_bill_pkg_discount
                                && $conf->exists('discount-show-always'));

  }

  foreach ( $s, $r, ($opt{skip_usage} ? () : $u ) ) {
    if ( $_  ) {
      $_->{amount}      = sprintf( "%.2f", $_->{amount} ),
      $_->{amount}      =~ s/^\-0\.00$/0.00/;
      $_->{unit_amount} = sprintf( "%.2f", $_->{unit_amount} ),
      push @b, { %$_ }
        if $_->{amount} != 0
        || $discount_show_always
        || ( ! $_->{_is_setup} && $_->{recur_show_zero} )
        || (   $_->{_is_setup} && $_->{setup_show_zero} )
    }
  }

  warn "$me _items_cust_bill_pkg done considering cust_bill_pkgs\n"
    if $DEBUG > 1;

  @b;

}

=item _items_discounts_avail

Returns an array of line item hashrefs representing available term discounts
for this invoice.  This makes the same assumptions that apply to term 
discounts in general: that the package is billed monthly, at a flat rate, 
with no usage charges.  A prorated first month will be handled, as will 
a setup fee if the discount is allowed to apply to setup fees.

=cut

sub _items_discounts_avail {
  my $self = shift;

  #maybe move this method from cust_bill when quotations support discount_plans 
  return () unless $self->can('discount_plans');
  my %plans = $self->discount_plans;

  my $list_pkgnums = 0; # if any packages are not eligible for all discounts
  $list_pkgnums = grep { $_->list_pkgnums } values %plans;

  map {
    my $months = $_;
    my $plan = $plans{$months};

    my $term_total = sprintf('%.2f', $plan->discounted_total);
    my $percent = sprintf('%.0f', 
                          100 * (1 - $term_total / $plan->base_total) );
    my $permonth = sprintf('%.2f', $term_total / $months);
    my $detail = $self->mt('discount on item'). ' '.
                 join(', ', map { "#$_" } $plan->pkgnums)
      if $list_pkgnums;

    # discounts for non-integer months don't work anyway
    $months = sprintf("%d", $months);

    +{
      description => $self->mt('Save [_1]% by paying for [_2] months',
                                $percent, $months),
      amount      => $self->mt('[_1] ([_2] per month)', 
                                $term_total, $money_char.$permonth),
      ext_description => ($detail || ''),
    }
  } #map
  sort { $b <=> $a } keys %plans;

}

1;
