package FS::Template_Mixin;

use strict;
use vars qw( $DEBUG $me
             $money_char
             $date_format
           );
             # but NOT $conf
use vars qw( $invoice_lines @buf ); #yuck
use List::Util qw(sum); #can't import first, it conflicts with cust_main.first
use Date::Format;
use Date::Language;
use Text::Template 1.20;
use File::Temp 0.14;
use HTML::Entities;
use Locale::Country;
use Cwd;
use FS::UID;
use FS::Misc qw( send_email );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::Misc qw( generate_ps generate_pdf );
use FS::pkg_category;
use FS::pkg_class;
use FS::invoice_mode;
use FS::L10N;

$DEBUG = 0;
$me = '[FS::Template_Mixin]';
FS::UID->install_callback( sub { 
  my $conf = new FS::Conf; #global
  $money_char  = $conf->config('money_char')  || '$';  
  $date_format = $conf->config('date_format') || '%x'; #/YY
} );

=item conf [ MODE ]

Returns a configuration handle (L<FS::Conf>) set to the customer's locale.

If the "mode" pseudo-field is set on the object, the configuration handle
will be an L<FS::invoice_conf> for that invoice mode (and the customer's
locale).

=cut

sub conf {
  my $self = shift;
  my $mode = $self->get('mode');
  if ($self->{_conf} and !defined($mode)) {
    return $self->{_conf};
  }

  my $cust_main = $self->cust_main;
  my $locale = $cust_main ? $cust_main->locale : '';
  my $conf;
  if ( $mode ) {
    if ( ref $mode and $mode->isa('FS::invoice_mode') ) {
      $mode = $mode->modenum;
    } elsif ( $mode =~ /\D/ ) {
      die "invalid invoice mode $mode";
    }
    $conf = qsearchs('invoice_conf', { modenum => $mode, locale => $locale });
    if (!$conf) {
      $conf = qsearchs('invoice_conf', { modenum => $mode, locale => '' });
      # it doesn't have a locale, but system conf still might
      $conf->set('locale' => $locale) if $conf;
    }
  }
  # if $mode is unspecified, or if there is no invoice_conf matching this mode
  # and locale, then use the system config only (but with the locale)
  $conf ||= FS::Conf->new({ 'locale' => $locale });
  # cache it
  return $self->{_conf} = $conf;
}

=item print_text OPTIONS

Returns an text invoice, as a list of lines.

Options can be passed as a hash.

I<time>, if specified, is used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_text {
  my $self = shift;
  my %params;
  if ( ref($_[0]) ) {
    %params = %{ shift() };
  } else {
    %params = @_;
  }

  $params{'format'} = 'template'; # for some reason

  $self->print_generic( %params );
}

=item print_latex HASHREF

Internal method - returns a filename of a filled-in LaTeX template for this
invoice (Note: add ".tex" to get the actual filename), and a filename of
an associated logo (with the .eps extension included).

See print_ps and print_pdf for methods that return PostScript and PDF output.

Options can be passed as a hash.

I<time>, if specified, is used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

I<template>, if specified, is the name of a suffix for alternate invoices.  
This is strongly deprecated; see L<FS::invoice_conf> for the right way to
customize invoice templates for different purposes.

I<notice_name>, if specified, overrides "Invoice" as the name of the sent document (templates from 10/2009 or newer required)

=cut

sub print_latex {
  my $self = shift;
  my %params;

  if ( ref($_[0]) ) {
    %params = %{ shift() };
  } else {
    %params = @_;
  }

  $params{'format'} = 'latex';
  my $conf = $self->conf;

  # this needs to go away
  my $template = $params{'template'};
  # and this especially
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

  my $agentnum = $self->agentnum;

  if ( $template && $conf->exists("logo_${template}.eps", $agentnum) ) {
    print $lh $conf->config_binary("logo_${template}.eps", $agentnum)
      or die "can't write temp file: $!\n";
  } else {
    print $lh $conf->config_binary('logo.eps', $agentnum)
      or die "can't write temp file: $!\n";
  }
  close $lh;
  $params{'logo_file'} = $lh->filename;

  if( $conf->exists('invoice-barcode') 
        && $self->can('invoice_barcode')
        && $self->invnum ) { # don't try to barcode statements
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

sub agentnum {
  my $self = shift;
  my $cust_main = $self->cust_main;
  $cust_main ? $cust_main->agentnum : $self->prospect_main->agentnum;
}

=item print_generic OPTION => VALUE ...

Internal method - returns a filled-in template for this invoice as a scalar.

See print_ps and print_pdf for methods that return PostScript and PDF output.

Required options

=over 4

=item format

The B<format> option is required and should be set to html, latex (print and PDF) or template (plaintext).

=back

Additional options

=over 4

=item notice_name

Overrides "Invoice" as the name of the sent document.

=item today

Used to control the printing of overdue messages.  The
default is now.  It isn't the date of the invoice; that's the `_date' field.
It is specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item logo_file

Logo file (path to temporary EPS file on the local filesystem)

=item cid

CID for inline (emailed) images (logo)

=item locale

Override customer's locale

=item unsquelch_cdr

Overrides any per customer cdr squelching when true

=item no_number

Supress the (invoice, quotation, statement, etc.) number

=item no_date

Supress the date

=item no_coupon

Supress the payment coupon

=item barcode_file

Barcode file (path to temporary EPS file on the local filesystem)

=item barcode_img

Flag indicating the barcode image should be a link (normal HTML dipaly)

=item barcode_cid

Barcode CID for inline (emailed) images

=item preref_callback

Coderef run for each line item, code should return HTML to be displayed
before that line item (quotations only)

=item template

Dprecated.  Used as a suffix for a configuration template.  Please 
don't use this, it deprecated in favor of more flexible alternatives.

=back

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

  my $locale = $params{'locale'} || $cust_main->locale;

  my %delimiters = ( 'latex'    => [ '[@--', '--@]' ],
                     'html'     => [ '<%=', '%>' ],
                     'template' => [ '{', '}' ],
                   );

  warn "$me print_generic creating template\n"
    if $DEBUG > 1;

  # set the notice name here, and nowhere else.
  my $notice_name =  $params{notice_name}
                  || $conf->config('notice_name')
                  || $self->notice_name;

  #create the template
  my $template = $params{template} ? $params{template} : $self->_agent_template;
  my $templatefile = $self->template_conf. $format;
  $templatefile .= "_$template"
    if length($template) && $conf->exists($templatefile."_$template");

  # the base template
  my @invoice_template = map "$_\n", $conf->config($templatefile)
    or die "cannot load config data $templatefile";

  if ( $format eq 'latex' && grep { /^%%Detail/ } @invoice_template ) {
    #change this to a die when the old code is removed
    # it's been almost ten years, changing it to a die
    die "old-style invoice template $templatefile; ".
         "patch with conf/invoice_latex.diff or use new conf/invoice_latex*\n";
         #$old_latex = 'true';
         #@invoice_template = _translate_old_latex_format(@invoice_template);
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
    'no_number'       => $params{'no_number'},
    'invnum'          => ( $params{'no_number'} ? '' : $self->invnum ),
    'quotationnum'    => $self->quotationnum,
    'no_date'         => $params{'no_date'},
    '_date'           => ( $params{'no_date'} ? '' : $self->_date ),
      # workaround for inconsistent behavior in the early plain text 
      # templates; see RT#28271
    'date'            => ( $params{'no_date'}
                             ? ''
                             : ($format eq 'template'
                               ? $self->_date
                               : $self->time2str_local('long', $self->_date, $format)
                               )
                         ),
    'today'           => $self->time2str_local('long', $today, $format),
    'terms'           => $self->terms,
    'template'        => $template, #params{'template'},
    'notice_name'     => $notice_name, # escape?
    'current_charges' => sprintf("%.2f", $self->charged),
    'duedate'         => $self->due_date2str('rdate'), #date_format?

    #customer info
    'custnum'         => $cust_main->display_custnum,
    'prospectnum'     => $cust_main->prospectnum,
    'agent_custid'    => &$escape_function($cust_main->agent_custid),
    ( map { $_ => &$escape_function($cust_main->$_()) }
        qw( company address1 address2 city state zip fax )
    ),
    'payname'         => &$escape_function( $cust_main->invoice_attn
                                             || $cust_main->contact_firstlast ),

    #global config
    'ship_enable'     => $cust_main->invoice_ship_address || $conf->exists('invoice-ship_address'),
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
  $invoice_data{'emt'} = sub { &$escape_function($self->mt(@_)) };
  # prototype here to silence warnings
  $invoice_data{'time2str'} = sub ($;$$) { $self->time2str_local(@_, $format) };

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
  $invoice_data{'bill_period'} =
      $self->time2str_local('%e %h', $min_sdate, $format) 
      . " to " .
      $self->time2str_local('%e %h', $max_edate, $format)
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
    $invoice_data{"ship_$_"} = $escape_function->($cust_main->$method);
  }
  if ( length($cust_main->ship_company) ) {
    $invoice_data{'ship_company'} = $escape_function->($cust_main->ship_company);
  } else {
    $invoice_data{'ship_company'} = $escape_function->($cust_main->company);
  }
  $invoice_data{'ship_contact'} = $escape_function->($cust_main->contact);
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
    $invoice_data{'payname'}.
      ( $cust_main->po_number
          ? " (P.O. #". $cust_main->po_number. ")"
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

  # the sum of amount owed on all invoices
  # (this is used in the summary & on the payment coupon)
  $invoice_data{'balance'} = sprintf("%.2f", $balance_due);

  # flag telling this invoice to have a first-page summary
  my $summarypage = '';

  if ( $self->custnum && $self->invnum ) {
    # XXX should be an FS::cust_bill method to set the defaults, instead
    # of checking the type here

    # info from customer's last invoice before this one, for some 
    # summary formats
    $invoice_data{'last_bill'} = {};
 
    my $last_bill = $self->previous_bill;
    if ( $last_bill ) {

      # "balance_date_range" unfortunately is unsuitable for this, since it
      # cares about application dates.  We want to know the sum of all 
      # _top-level transactions_ dated before the last invoice.
      my @sql =
        map "$_ WHERE _date <= ? AND custnum = ?", (
          "SELECT      COALESCE( SUM(charged), 0 ) FROM cust_bill",
          "SELECT -1 * COALESCE( SUM(amount),  0 ) FROM cust_credit",
          "SELECT -1 * COALESCE( SUM(paid),    0 ) FROM cust_pay",
          "SELECT      COALESCE( SUM(refund),  0 ) FROM cust_refund",
        );

      # the customer's current balance immediately after generating the last 
      # bill

      my $last_bill_balance = $last_bill->charged;
      foreach (@sql) {
        my $delta = FS::Record->scalar_sql(
          $_,
          $last_bill->_date - 1,
          $self->custnum,
        );
        $last_bill_balance += $delta;
      }

      $last_bill_balance = sprintf("%.2f", $last_bill_balance);

      warn sprintf("LAST BILL: INVNUM %d, DATE %s, BALANCE %.2f\n\n",
        $last_bill->invnum,
        $self->time2str_local('%D', $last_bill->_date),
        $last_bill_balance
      ) if $DEBUG > 0;
      # ("true_previous_balance" is a terrible name, but at least it's no
      # longer stored in the database)
      $invoice_data{'true_previous_balance'} = $last_bill_balance;

      # the change in balance from immediately after that invoice
      # to immediately before this one
      my $before_this_bill_balance = 0;
      foreach (@sql) {
        my $delta = FS::Record->scalar_sql(
          $_,
          $self->_date - 1,
          $self->custnum,
        );
        $before_this_bill_balance += $delta;
      }
      $invoice_data{'balance_adjustments'} =
        sprintf("%.2f", $last_bill_balance - $before_this_bill_balance);

      warn sprintf("BALANCE ADJUSTMENTS: %.2f\n\n",
                   $invoice_data{'balance_adjustments'}
      ) if $DEBUG > 0;

      # the sum of amount owed on all previous invoices
      # ($pr_total is used elsewhere but not as $previous_balance)
      $invoice_data{'previous_balance'} = sprintf("%.2f", $pr_total);

      $invoice_data{'last_bill'}{'_date'} = $last_bill->_date; #unformatted
      my (@payments, @credits);
      # for formats that itemize previous payments
      foreach my $cust_pay ( qsearch('cust_pay', {
                              'custnum' => $self->custnum,
                              '_date'   => { op => '>=',
                                             value => $last_bill->_date }
                             } ) )
      {
        next if $cust_pay->_date > $self->_date;
        push @payments, {
            '_date'       => $cust_pay->_date,
            'date'        => $self->time2str_local('long', $cust_pay->_date, $format),
            'payinfo'     => $cust_pay->payby_payinfo_pretty,
            'amount'      => sprintf('%.2f', $cust_pay->paid),
        };
        # not concerned about applications
      }
      foreach my $cust_credit ( qsearch('cust_credit', {
                              'custnum' => $self->custnum,
                              '_date'   => { op => '>=',
                                             value => $last_bill->_date }
                             } ) )
      {
        next if $cust_credit->_date > $self->_date;
        push @credits, {
            '_date'       => $cust_credit->_date,
            'date'        => $self->time2str_local('long', $cust_credit->_date, $format),
            'creditreason'=> $cust_credit->reason,
            'amount'      => sprintf('%.2f', $cust_credit->amount),
        };
      }
      $invoice_data{'previous_payments'} = \@payments;
      $invoice_data{'previous_credits'}  = \@credits;
    } else {
      # there is no $last_bill
      $invoice_data{'true_previous_balance'} =
      $invoice_data{'balance_adjustments'}   =
      $invoice_data{'previous_balance'}      = '0.00';
      $invoice_data{'previous_payments'} = [];
      $invoice_data{'previous_credits'} = [];
    }
 
    if ( $conf->exists('invoice_usesummary', $agentnum) ) {
      $invoice_data{'summarypage'} = $summarypage = 1;
    }

  } # if this is an invoice

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

  # extremely dubious
  my %other_money_chars = ( 'latex'    => '\dollar ',#XXX should be a config too
                            'html'     => $conf->config('money_char') || '$',
                            'template' => '',
                          );
  my $other_money_char = $other_money_chars{$format};
  $invoice_data{'dollar'} = $other_money_char;

  my %minus_signs = ( 'latex'    => '$-$',
                      'html'     => '&minus;',
                      'template' => '- ' );
  my $minus = $minus_signs{$format};

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

  my $unsquelched = $params{unsquelch_cdr} || $cust_main->squelch_cdr ne 'Y';
  my $multisection = $self->has_sections;
  $conf->exists($tc.'sections', $cust_main->agentnum) ||
                     $conf->exists($tc.'sections_by_location', $cust_main->agentnum);
  $invoice_data{'multisection'} = $multisection;
  my $late_sections;
  my $extra_sections = [];
  my $extra_lines = ();

  # default section ('Charges')
  my $default_section = { 'description' => '',
                          'subtotal'    => '', 
                          'no_subtotal' => 1,
                        };

  # Previous Charges section
  # subtotal is the first return value from $self->previous
  my $previous_section;
  # if the invoice has major sections, or if we're summarizing previous 
  # charges with a single line, or if we've been specifically told to put them
  # in a section, create a section for previous charges:
  if ( $multisection or
       $conf->exists('previous_balance-summary_only') or
       $conf->exists('previous_balance-section') ) {
    
    $previous_section =  { 'description' => $self->mt('Previous Charges'),
                           'subtotal'    => $other_money_char.
                                            sprintf('%.2f', $pr_total),
                           'summarized'  => '', #why? $summarypage ? 'Y' : '',
                         };
    $previous_section->{posttotal} = '0 / 30 / 60 / 90 days overdue '. 
      join(' / ', map { $cust_main->balance_date_range(@$_) }
                  $self->_prior_month30s
          )
      if $conf->exists('invoice_include_aging');

  } else {
    # otherwise put them in the main section
    $previous_section = $default_section;
  }

  my $adjust_section = {
    'description'    => $self->mt('Credits, Payments, and Adjustments'),
    'adjust_section' => 1,
    'subtotal'       => 0,   # adjusted below
  };
  my $adjust_weight = _pkg_category($adjust_section->{description})
                        ? _pkg_category($adjust_section->{description})->weight
                        : 0;
  $adjust_section->{'summarized'} = ''; #why? $summarypage && !$adjust_weight ? 'Y' : '';
  # Note: 'sort_weight' here is actually a flag telling whether there is an
  # explicit package category for the adjust section. If so, certain behavior
  # happens.
  $adjust_section->{'sort_weight'} = $adjust_weight;


  if ( $multisection ) {
    ($extra_sections, $extra_lines) =
      $self->_items_extra_usage_sections($escape_function_nonbsp, $format)
      if $conf->exists('usage_class_as_a_section', $cust_main->agentnum)
      && $self->can('_items_extra_usage_sections');

    push @$extra_sections, $adjust_section if $adjust_section->{sort_weight};

    push @detail_items, @$extra_lines if $extra_lines;

    # the code is written so that both methods can be used together, but
    # we haven't yet changed the template to take advantage of that, so for 
    # now, treat them as mutually exclusive.
    my %section_method = ( by_category => 1 );
    if ( $conf->config($tc.'sections_method') eq 'location' ) {
      %section_method = ( by_location => 1 );
    }
    my ($early, $late) =
      $self->_items_sections( 'summary' => $summarypage,
                              'escape'  => $escape_function_nonbsp,
                              'extra_sections' => $extra_sections,
                              'format'  => $format,
                              %section_method
                            );
    push @sections, @$early;
    $late_sections = $late;

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
    # and the default section total
    # XXX possibly finance_pkgclass should not be used in this manner?
    my @finance_charges;
    my @charges;
    foreach my $cust_bill_pkg ( $self->cust_bill_pkg ) {
      if ( $invoice_data{finance_section} and 
        grep { $_->section eq $invoice_data{finance_section} }
           $cust_bill_pkg->cust_bill_pkg_display ) {
        # I think these are always setup fees, but just to be sure...
        push @finance_charges, $cust_bill_pkg->recur + $cust_bill_pkg->setup;
      } else {
        push @charges, $cust_bill_pkg->recur + $cust_bill_pkg->setup;
      }
    }
    $invoice_data{finance_amount} = 
      sprintf('%.2f', sum( @finance_charges ) || 0);
    $default_section->{subtotal} = $other_money_char.
                                    sprintf('%.2f', sum( @charges ) || 0);
  }

  # start setting up summary subtotals
  my @summary_subtotals;
  my $method = $conf->config('summary_subtotals_method');
  if ( $method and $method ne $conf->config($tc.'sections_method') ) {
    # then re-section them by the correct method
    my %section_method = ( by_category => 1 );
    if ( $conf->config('summary_subtotals_method') eq 'location' ) {
      %section_method = ( by_location => 1 );
    }
    my ($early, $late) =
      $self->_items_sections( 'summary' => $summarypage,
                              'escape'  => $escape_function_nonbsp,
                              'extra_sections' => $extra_sections,
                              'format'  => $format,
                              %section_method
                            );
    foreach ( @$early ) {
      next if $_->{subtotal} == 0;
      $_->{subtotal} = $other_money_char.sprintf('%.2f', $_->{subtotal});
      push @summary_subtotals, $_;
    }
  } else {
    # subtotal sectioning is the same as for the actual invoice sections
    @summary_subtotals = @sections;
  }

  # Hereafter, push sections to both @sections and @summary_subtotals
  # if they belong in both places (e.g. tax section).  Late sections are
  # never in @summary_subtotals.

  # previous invoice balances in the Previous Charges section if there
  # is one, otherwise in the main detail section
  # (except if summary_only is enabled, don't show them at all)
  if ( $self->can('_items_previous') &&
       $self->enable_previous &&
       ! $conf->exists('previous_balance-summary_only') ) {

    warn "$me adding previous balances\n"
      if $DEBUG > 1;

    foreach my $line_item ( $self->_items_previous ) {

      my $detail = {
        ref             => $line_item->{'pkgnum'},
        pkgpart         => $line_item->{'pkgpart'},
        #quantity        => 1, # not really correct
        section         => $previous_section, # which might be $default_section
        description     => &$escape_function($line_item->{'description'}),
        ext_description => [ map { &$escape_function($_) } 
                             @{ $line_item->{'ext_description'} || [] }
                           ],
        amount          => $money_char . $line_item->{'amount'},
        product_code    => $line_item->{'pkgpart'} || 'N/A',
      };

      push @detail_items, $detail;
      push @buf, [ $detail->{'description'},
                   $money_char. sprintf("%10.2f", $line_item->{'amount'}),
                 ];
    }

  }

  if ( @pr_cust_bill && $self->enable_previous ) {
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

    my %options = ();
    $options{'section'} = $section if $multisection;
    $options{'format'} = $format;
    $options{'escape_function'} = $escape_function;
    $options{'no_usage'} = 1 unless $unsquelched;
    $options{'unsquelched'} = $unsquelched;
    $options{'summary_page'} = $summarypage;
    $options{'skip_usage'} =
      scalar(@$extra_sections) && !grep{$section == $_} @$extra_sections;
    $options{'preref_callback'} = $params{'preref_callback'};

    warn "$me   searching for line items\n"
      if $DEBUG > 1;

    foreach my $line_item ( $self->_items_pkg(%options),
                            $self->_items_fee(%options) ) {

      warn "$me     adding line item ".
           join(', ', map "$_=>".$line_item->{$_}, keys %$line_item). "\n"
        if $DEBUG > 1;

      push @buf, ( [ $line_item->{'description'},
                     $money_char. sprintf("%10.2f", $line_item->{'amount'}),
                   ],
                   map { [ " ". $_, '' ] } @{$line_item->{'ext_description'}},
                 );

      $line_item->{'ref'} = $line_item->{'pkgnum'};
      $line_item->{'product_code'} = $line_item->{'pkgpart'} || 'N/A'; # mt()?
      $line_item->{'section'} = $section;
      $line_item->{'description'} = &$escape_function($line_item->{'description'});
      $line_item->{'amount'} = $money_char.$line_item->{'amount'};

      if ( length($line_item->{'unit_amount'}) ) {
        $line_item->{'unit_amount'} = $money_char.$line_item->{'unit_amount'};
      }
      $line_item->{'ext_description'} ||= [];
 
      push @detail_items, $line_item;
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

  # if there's anything in the Previous Charges section, prepend it to the list
  if ( $pr_total and $previous_section ne $default_section ) {
    unshift @sections, $previous_section;
    # but not @summary_subtotals
  }

  warn "$me adding taxes\n"
    if $DEBUG > 1;

  # create a tax section if we don't yet have one
  my $tax_description = 'Taxes, Surcharges, and Fees';
  my $tax_section =
    List::Util::first { $_->{description} eq $tax_description } @sections;
  if (!$tax_section) {
    $tax_section = { 'description' => $tax_description };
  }
  $tax_section->{tax_section} = 1; # mark this section as containing taxes
  # if this is an existing tax section, we're merging the tax items into it.
  # grab the taxtotal that's already there, strip the money symbol if any
  my $taxtotal = $tax_section->{'subtotal'} || 0;
  $taxtotal =~ s/^\Q$other_money_char\E//;

  # this does nothing
  #my $tax_weight = _pkg_category($tax_section->{description})
  #                      ? _pkg_category($tax_section->{description})->weight
  #                      : 0;
  #$tax_section->{'summarized'} = ''; #why? $summarypage && !$tax_weight ? 'Y' : '';
  #$tax_section->{'sort_weight'} = $tax_weight;

  my @items_tax = $self->_items_tax;
  push @sections, $tax_section if $multisection and @items_tax > 0;

  foreach my $tax ( @items_tax ) {

    $taxtotal += $tax->{'amount'};

    my $description = &$escape_function( $tax->{'description'} );
    my $amount      = sprintf( '%.2f', $tax->{'amount'} );

    if ( $multisection ) {

      push @detail_items, {
        ext_description => [],
        ref          => '',
        quantity     => '',
        description  => $description,
        amount       => $money_char. $amount,
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
 
  if ( @items_tax ) {
    my $total = {};
    $total->{'total_item'} = $self->mt('Sub-total');
    $total->{'total_amount'} =
      $other_money_char. sprintf('%.2f', $self->charged - $taxtotal );

    if ( $multisection ) {
      if ( $taxtotal > 0 ) {
        $tax_section->{'subtotal'} = $other_money_char.
                                     sprintf('%.2f', $taxtotal);
        $tax_section->{'pretotal'} = 'New charges sub-total '.
                                     $total->{'total_amount'};
        $tax_section->{'description'} = $self->mt($tax_description);

        # append it if it's not already there
        if ( !grep $tax_section, @sections ) {
          push @sections, $tax_section;
          push @summary_subtotals, $tax_section;
        }
      }

    } else {
      unshift @total_items, $total;
    }
  }
  $invoice_data{'taxtotal'} = sprintf('%.2f', $taxtotal);

  ###
  # Totals
  ###

  my %embolden_functions = (
    'latex'    => sub { return '\textbf{'. shift(). '}' },
    'html'     => sub { return '<b>'. shift(). '</b>' },
    'template' => sub { shift },
  );
  my $embolden_function = $embolden_functions{$format};

  if ( $multisection ) {

    if ( $adjust_section->{'sort_weight'} ) {
      $adjust_section->{'posttotal'} = $self->mt('Balance Forward').' '.
        $other_money_char.  sprintf("%.2f", ($self->billing_balance || 0) );
    } else{
      $adjust_section->{'pretotal'} = $self->mt('New charges total').' '.
        $other_money_char.  sprintf('%.2f', $self->charged );
    }

  }
  
  if ( $self->can('_items_total') ) { # should always be true now

    # even for multisection, need plain text version

    my @new_total_items = $self->_items_total;

    push @buf,['','-----------'];

    foreach ( @new_total_items ) {
      my ($item, $amount) = ($_->{'total_item'}, $_->{'total_amount'});
      $_->{'total_item'}   = &$embolden_function( $item );
      $_->{'total_amount'} = &$embolden_function( $other_money_char.$amount );
      # but if it's multisection, don't append to @total_items. the adjust
      # section has all this stuff
      push @total_items, $_ if !$multisection;
      push @buf, [ $item, $money_char.sprintf('%10.2f',$amount) ];
    }

    push @buf, [ '', '' ];

    # if we're showing previous invoices, also show previous
    # credits and payments 
    if ( $self->enable_previous 
          and $self->can('_items_credits')
          and $self->can('_items_payments') )
      {
    
      # credits
      my $credittotal = 0;
      foreach my $credit (
        $self->_items_credits( 'template' => $template, 'trim_len' => 40 )
      ) {

        my $total;
        $total->{'total_item'} = &$escape_function($credit->{'description'});
        $credittotal += $credit->{'amount'};
        $total->{'total_amount'} = $minus.$other_money_char.$credit->{'amount'};
        if ( $multisection ) {
          push @detail_items, {
            ext_description => [],
            ref          => '',
            quantity     => '',
            description  => &$escape_function($credit->{'description'}),
            amount       => $money_char . $credit->{'amount'},
            product_code => '',
            section      => $adjust_section,
          };
        } else {
          push @total_items, $total;
        }

      }
      $invoice_data{'credittotal'} = sprintf('%.2f', $credittotal);

      #credits (again)
      foreach my $credit (
        $self->_items_credits( 'template' => $template, 'trim_len'=>32 )
      ) {
        push @buf, [ $credit->{'description'}, $money_char.$credit->{'amount'} ];
      }

      # payments
      my $paymenttotal = 0;
      foreach my $payment (
        $self->_items_payments( 'template' => $template )
      ) {
        my $total = {};
        $total->{'total_item'} = &$escape_function($payment->{'description'});
        $paymenttotal += $payment->{'amount'};
        $total->{'total_amount'} = $minus.$other_money_char.$payment->{'amount'};
        if ( $multisection ) {
          push @detail_items, {
            ext_description => [],
            ref          => '',
            quantity     => '',
            description  => &$escape_function($payment->{'description'}),
            amount       => $money_char . $payment->{'amount'},
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
                                        sprintf('%.2f', $credittotal + $paymenttotal);

        #why this? because {sort_weight} forces the adjust_section to appear
        #in @extra_sections instead of @sections. obviously.
        push @sections, $adjust_section
          unless $adjust_section->{sort_weight};
        # do not summarize; adjustments there are shown according to 
        # different rules
      }

      # create Balance Due message
      { 
        my $total;
        $total->{'total_item'} = &$embolden_function($self->balance_due_msg);
        $total->{'total_amount'} =
          &$embolden_function(
            $other_money_char. sprintf('%.2f', #why? $summarypage 
                                               #  ? $self->charged +
                                               #    $self->billing_balance
                                               #  :
                                                   $self->owed + $pr_total
                                      )
          );
        if ( $multisection && !$adjust_section->{sort_weight} ) {
          $adjust_section->{'posttotal'} = $total->{'total_item'}. ' '.
                                           $total->{'total_amount'};
        } else {
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

  } #end of default total adding ! can('_items_total')

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

    push @sections, $discount_section; # do not summarize
    push @detail_items, map { +{
        'ref'         => '', #should this be something else?
        'section'     => $discount_section,
        'description' => &$escape_function( $_->{description} ),
        'amount'      => $money_char . &$escape_function( $_->{amount} ),
        'ext_description' => [ &$escape_function($_->{ext_description}) || () ],
    } } @discounts_avail;
  }

  # not adding any more sections after this
  $invoice_data{summary_subtotals} = \@summary_subtotals;

  # usage subtotals
  if ( $conf->exists('usage_class_summary')
       and $self->can('_items_usage_class_summary') ) {
    my @usage_subtotals = $self->_items_usage_class_summary(escape => $escape_function);
    if ( @usage_subtotals ) {
      unshift @sections, $usage_subtotals[0]->{section}; # do not summarize
      unshift @detail_items, @usage_subtotals;
    }
  }

  # invoice history "section" (not really a section)
  # not to be included in any subtotals, completely independent of 
  # everything...
  if ( $conf->exists('previous_invoice_history') and $cust_main->isa('FS::cust_main') ) {
    my %history;
    my %monthorder;
    foreach my $cust_bill ( $cust_main->cust_bill ) {
      # XXX hardcoded format, and currently only 'charged'; add other fields
      # if they become necessary
      my $date = $self->time2str_local('%b %Y', $cust_bill->_date);
      $history{$date} ||= 0;
      $history{$date} += $cust_bill->charged;
      # just so we have a numeric sort key
      $monthorder{$date} ||= $cust_bill->_date;
    }
    my @sorted_months = sort { $monthorder{$a} <=> $monthorder{$b} }
                        keys %history;
    my @sorted_amounts = map { sprintf('%.2f', $history{$_}) } @sorted_months;
    $invoice_data{monthly_history} = [ \@sorted_months, \@sorted_amounts ];
  }

  # service locations: another option for template customization
  my %location_info;
  foreach my $item (@detail_items) {
    if ( $item->{locationnum} ) {
      $location_info{ $item->{locationnum} } ||= {
        FS::cust_location->by_key( $item->{locationnum} )->location_hash
      };
    }
  }
  $invoice_data{location_info} = \%location_info;

  # debugging hook: call this with 'diag' => 1 to just get a hash of 
  # the invoice variables
  return \%invoice_data if ( $params{'diag'} );

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

# this is not supposed to happen
sub template_conf { warn "bare FS::Template_Mixin::template_conf";
  'invoice_';
}

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
  } else {
    %params = @_;
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

=item terms

=cut

sub terms {
  my $self = shift;
  my $conf = $self->conf;

  #check for an invoice-specific override
  return $self->invoice_terms if $self->invoice_terms;
  
  #check for a customer- specific override
  my $cust_main = $self->cust_main;
  return $cust_main->invoice_terms if $cust_main && $cust_main->invoice_terms;

  my $agentnum = '';
  if ( $cust_main ) {
    $agentnum = $cust_main->agentnum;
  } elsif ( my $prospect_main = $self->prospect_main ) {
    $agentnum = $prospect_main->agentnum;
  }

  #use configured default
  $conf->config('invoice_default_terms', $agentnum) || '';
}

=item due_date

=cut

sub due_date {
  my $self = shift;
  my $duedate = '';
  if ( $self->terms =~ /^\s*Net\s*(\d+)\s*$/ ) {
    $duedate = $self->_date() + ( $1 * 86400 );
  }
  $duedate;
}

=item due_date2str

=cut

sub due_date2str {
  my $self = shift;
  $self->due_date ? $self->time2str_local(shift, $self->due_date) : '';
}

=item balance_due_msg

=cut

sub balance_due_msg {
  my $self = shift;
  my $msg = $self->mt('Balance Due');
  return $msg unless $self->terms; # huh?
  if ( !$self->conf->exists('invoice_show_prior_due_date')
       or $self->conf->exists('invoice_sections') ) {
    # if enabled, the due date is shown with Total New Charges (see 
    # _items_total) and not here
    # (yes, or if invoice_sections is enabled; this is just for compatibility)
    if ( $self->due_date ) {
      $msg .= ' - ' . $self->mt('Please pay by'). ' '.
        $self->due_date2str('short');
    } elsif ( $self->terms ) {
      $msg .= ' - '. $self->mt($self->terms);
    }
  }
  $msg;
}

=item balance_due_date

=cut

sub balance_due_date {
  my $self = shift;
  my $conf = $self->conf;
  my $duedate = '';
  my $terms = $self->terms;
  if ( $terms =~ /^\s*Net\s*(\d+)\s*$/ ) {
    $duedate = $self->time2str_local('rdate', $self->_date + ($1*86400) );
  }
  $duedate;
}

sub credit_balance_msg { 
  my $self = shift;
  $self->mt('Credit Balance Remaining')
}

=item _date_pretty

Returns a string with the date, for example: "3/20/2008", localized for the
customer.  Use _date_pretty_unlocalized for non-end-customer display use.

=cut

sub _date_pretty {
  my $self = shift;
  $self->time2str_local('short', $self->_date);
}

=item _date_pretty_unlocalized

Returns a string with the date, for example: "3/20/2008", in the format
configured for the back-office.  Use _date_pretty for end-customer display use.

=cut

sub _date_pretty_unlocalized {
  my $self = shift;
  time2str($date_format, $self->_date);
}

=item email HASHREF

Emails this template.

Options are passed as a hashref.  Available options:

=over 4

=item from

If specified, overrides the default From: address.

=item notice_name

If specified, overrides the name of the sent document ("Invoice" or "Quotation")

=item template

(Deprecated) If specified, is the name of a suffix for alternate template files.

=back

Options accepted by generate_email can also be used.

=cut

sub email {
  my $self = shift;
  my $opt = shift || {};
  if ($opt and !ref($opt)) {
    die ref($self). '->email called with positional parameters';
  }

  return if $self->hide;

  my $error = send_email(
    $self->generate_email(
      'subject'     => $self->email_subject($opt->{template}),
      %$opt, # template, etc.
    )
  );

  die "can't email: $error\n" if $error;
}

=item generate_email OPTION => VALUE ...

Options:

=over 4

=item from

sender address, required

=item template

alternate template name, optional

=item subject

email subject, optional

=item notice_name

notice name instead of "Invoice", optional

=back

Returns an argument list to be passed to L<FS::Misc::send_email>.

=cut

use MIME::Entity;

sub generate_email {

  my $self = shift;
  my %args = @_;
  my $conf = $self->conf;

  my $me = '[FS::Template_Mixin::generate_email]';

  my %return = (
    'from'      => $args{'from'},
    'subject'   => ($args{'subject'} || $self->email_subject),
    'custnum'   => $self->custnum,
    'msgtype'   => 'invoice',
  );

  $args{'unsquelch_cdr'} = $conf->exists('voip-cdr_email');

  my $cust_main = $self->cust_main;

  if (ref($args{'to'}) eq 'ARRAY') {
    $return{'to'} = $args{'to'};
  } elsif ( $cust_main ) {
    $return{'to'} = [ $cust_main->invoicing_list_emailonly ];
  }

  my $tc = $self->template_conf;

  my @text; # array of lines
  my $html; # a big string
  my @related_parts; # will contain the text/HTML alternative, and images
  my $related; # will contain the multipart/related object

  if ( $conf->exists($tc. 'email_pdf') ) {
    if ( my $msgnum = $conf->config($tc.'email_pdf_msgnum') ) {

      warn "$me using '${tc}email_pdf_msgnum' in multipart message"
        if $DEBUG;

      my $msg_template = FS::msg_template->by_key($msgnum)
        or die "${tc}email_pdf_msgnum $msgnum not found\n";
      my %prepared = $msg_template->prepare(
        cust_main => $self->cust_main,
        object    => $self
      );

      @text = split(/(?=\n)/, $prepared{'text_body'});
      $html = $prepared{'html_body'};

    } elsif ( my @note = $conf->config($tc.'email_pdf_note') ) {

      warn "$me using '${tc}email_pdf_note' in multipart message"
        if $DEBUG;
      @text = $conf->config($tc.'email_pdf_note');
      $html = join('<BR>', @text);
  
    } # else use the plain text invoice
  }

  if (!@text) {

    if ( $conf->config($tc.'template') ) {

      warn "$me generating plain text invoice"
        if $DEBUG;

      # 'print_text' argument is no longer used
      @text = $self->print_text(\%args);

    } else {

      warn "$me no plain text version exists; sending empty message body"
        if $DEBUG;

    }

  }

  my $text_part = build MIME::Entity (
    'Type'        => 'text/plain',
    'Encoding'    => 'quoted-printable',
    'Charset'     => 'UTF-8',
    #'Encoding'    => '7bit',
    'Data'        => \@text,
    'Disposition' => 'inline',
  );

  if (!$html) {

    if ( $conf->exists($tc.'html') ) {
      warn "$me generating HTML invoice"
        if $DEBUG;

      $args{'from'} =~ /\@([\w\.\-]+)/;
      my $from = $1 || 'example.com';
      my $content_id = join('.', rand()*(2**32), $$, time). "\@$from";

      my $logo;
      my $agentnum = $cust_main ? $cust_main->agentnum
                                : $self->prospect_main->agentnum;
      if ( defined($args{'template'}) && length($args{'template'})
           && $conf->exists( 'logo_'. $args{'template'}. '.png', $agentnum )
         )
      {
        $logo = 'logo_'. $args{'template'}. '.png';
      } else {
        $logo = "logo.png";
      }
      my $image_data = $conf->config_binary( $logo, $agentnum);

      push @related_parts, build MIME::Entity
        'Type'       => 'image/png',
        'Encoding'   => 'base64',
        'Data'       => $image_data,
        'Filename'   => 'logo.png',
        'Content-ID' => "<$content_id>",
      ;
   
      if ( ref($self) eq 'FS::cust_bill' && $conf->exists('invoice-barcode') ) {
        my $barcode_content_id = join('.', rand()*(2**32), $$, time). "\@$from";
        push @related_parts, build MIME::Entity
          'Type'       => 'image/png',
          'Encoding'   => 'base64',
          'Data'       => $self->invoice_barcode(0),
          'Filename'   => 'barcode.png',
          'Content-ID' => "<$barcode_content_id>",
        ;
        $args{'barcode_cid'} = $barcode_content_id;
      }

      $html = $self->print_html({ 'cid'=>$content_id, %args });
    }

  }

  if ( $html ) {

    warn "$me creating HTML/text multipart message"
      if $DEBUG;

    $return{'nobody'} = 1;

    my $alternative = build MIME::Entity
      'Type'        => 'multipart/alternative',
      #'Encoding'    => '7bit',
      'Disposition' => 'inline'
    ;

    if ( @text ) {
      $alternative->add_part($text_part);
    }

    $alternative->attach(
      'Type'        => 'text/html',
      'Encoding'    => 'quoted-printable',
      'Data'        => [ '<html>',
                         '  <head>',
                         '    <title>',
                         '      '. encode_entities($return{'subject'}), 
                         '    </title>',
                         '  </head>',
                         '  <body bgcolor="#e8e8e8">',
                         $html,
                         '  </body>',
                         '</html>',
                       ],
      'Disposition' => 'inline',
      #'Filename'    => 'invoice.pdf',
    );

    unshift @related_parts, $alternative;

    $related = build MIME::Entity 'Type'     => 'multipart/related',
                                  'Encoding' => '7bit';

    #false laziness w/Misc::send_email
    $related->head->replace('Content-type',
      $related->mime_type.
      '; boundary="'. $related->head->multipart_boundary. '"'.
      '; type=multipart/alternative'
    );

    $related->add_part($_) foreach @related_parts;

  }

  my @otherparts = ();
  if ( ref($self) eq 'FS::cust_bill' && $cust_main->email_csv_cdr ) {

    push @otherparts, build MIME::Entity
      'Type'        => 'text/csv',
      'Encoding'    => '7bit',
      'Data'        => [ map { "$_\n" }
                           $self->call_details('prepend_billed_number' => 1)
                       ],
      'Disposition' => 'attachment',
      'Filename'    => 'usage-'. $self->invnum. '.csv',
    ;

  }

  if ( $conf->exists($tc.'email_pdf') ) {

    #attaching pdf too:
    # multipart/mixed
    #   multipart/related
    #     multipart/alternative
    #       text/plain
    #       text/html
    #     image/png
    #   application/pdf

    my $pdf = build MIME::Entity $self->mimebuild_pdf(\%args);
    push @otherparts, $pdf;
  }

  if (@otherparts) {
    $return{'content-type'} = 'multipart/mixed'; # of the outer container
    if ( $html ) {
      $return{'mimeparts'} = [ $related, @otherparts ];
      $return{'type'} = 'multipart/related'; # of the first part
    } else {
      $return{'mimeparts'} = [ $text_part, @otherparts ];
      $return{'type'} = 'text/plain';
    }
  } elsif ( $html ) { # no PDF or CSV, strip the outer container
    $return{'mimeparts'} = \@related_parts;
    $return{'content-type'} = 'multipart/related';
    $return{'type'} = 'multipart/alternative';
  } else { # no HTML either
    $return{'body'} = \@text;
    $return{'content-type'} = 'text/plain';
  }

  %return;

}

=item mimebuild_pdf

Returns a list suitable for passing to MIME::Entity->build(), representing
this invoice as PDF attachment.

=cut

sub mimebuild_pdf {
  my $self = shift;
  (
    'Type'        => 'application/pdf',
    'Encoding'    => 'base64',
    'Data'        => [ $self->print_pdf(@_) ],
    'Disposition' => 'attachment',
    'Filename'    => 'invoice-'. $self->invnum. '.pdf',
  );
}

=item _items_sections OPTIONS

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

The method returns two arrayrefs, one of "early" sections and one of "late"
sections.

OPTIONS may include:

by_location: a flag to divide the invoice into sections by location.  
Each section hash will have a 'location' element containing a hashref of 
the location fields (see L<FS::cust_location>).  The section description
will be the location label, but the template can use any of the location 
fields to create a suitable label.

by_category: a flag to divide the invoice into sections using display 
records (see L<FS::cust_bill_pkg_display>).  This is the "traditional" 
behavior.  Each section hash will have a 'category' element containing
the section name from the display record (which probably equals the 
category name of the package, but may not in some cases).

summary: a flag indicating that this is a summary-format invoice.
Turning this on has the following effects:
- Ignores display items with the 'summary' flag.
- Places all sections in the "early" group even if they have post_total.
- Creates sections for all non-disabled package categories, even if they 
have no charges on this invoice, as well as a section with no name.

escape: an escape function to use for section titles.

extra_sections: an arrayref of additional sections to return after the 
sorted list.  If there are any of these, section subtotals exclude 
usage charges.

format: 'latex', 'html', or 'template' (i.e. text).  Not used, but 
passed through to C<_condense_section()>.

=cut

use vars qw(%pkg_category_cache);
sub _items_sections {
  my $self = shift;
  my %opt = @_;
  
  my $escape = $opt{escape};
  my @extra_sections = @{ $opt{extra_sections} || [] };

  # $subtotal{$locationnum}{$categoryname} = amount.
  # if we're not using by_location, $locationnum is undef.
  # if we're not using by_category, you guessed it, $categoryname is undef.
  # if we're not using either one, we shouldn't be here in the first place...
  my %subtotal = ();
  my %late_subtotal = ();
  my %not_tax = ();

  # About tax items + multisection invoices:
  # If either invoice_*summary option is enabled, AND there is a 
  # package category with the name of the tax, then there will be 
  # a display record assigning the tax item to that category.
  #
  # However, the taxes are always placed in the "Taxes, Surcharges,
  # and Fees" section regardless of that.  The only effect of the 
  # display record is to create a subtotal for the summary page.

  # cache these
  my $pkg_hash = $self->cust_pkg_hash;

  foreach my $cust_bill_pkg ( $self->cust_bill_pkg )
  {

      my $usage = $cust_bill_pkg->usage;

      my $locationnum;
      if ( $opt{by_location} ) {
        if ( $cust_bill_pkg->pkgnum ) {
          $locationnum = $pkg_hash->{ $cust_bill_pkg->pkgnum }->locationnum;
        } else {
          $locationnum = '';
        }
      } else {
        $locationnum = undef;
      }

      # as in _items_cust_pkg, if a line item has no display records,
      # cust_bill_pkg_display() returns a default record for it

      foreach my $display ($cust_bill_pkg->cust_bill_pkg_display) {
        next if ( $display->summary && $opt{summary} );

        my $section = $display->section;
        my $type    = $display->type;
        # Set $section = undef if we're sectioning by location and this
        # line item _has_ a location (i.e. isn't a fee).
        $section = undef if $locationnum;

        # set this flag if the section is not tax-only
        $not_tax{$locationnum}{$section} = 1
          if $cust_bill_pkg->pkgnum  or $cust_bill_pkg->feepart;

        # there's actually a very important piece of logic buried in here:
        # incrementing $late_subtotal{$section} CREATES 
        # $late_subtotal{$section}.  keys(%late_subtotal) is later used 
        # to define the list of late sections, and likewise keys(%subtotal).
        # When _items_cust_bill_pkg is called to generate line items for 
        # real, it will be called with 'section' => $section for each 
        # of these.
        if ( $display->post_total && !$opt{summary} ) {
          if (! $type || $type eq 'S') {
            $late_subtotal{$locationnum}{$section} += $cust_bill_pkg->setup
              if $cust_bill_pkg->setup != 0
              || $cust_bill_pkg->setup_show_zero;
          }

          if (! $type) {
            $late_subtotal{$locationnum}{$section} += $cust_bill_pkg->recur
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }

          if ($type && $type eq 'R') {
            $late_subtotal{$locationnum}{$section} += $cust_bill_pkg->recur - $usage
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          }
          
          if ($type && $type eq 'U') {
            $late_subtotal{$locationnum}{$section} += $usage
              unless scalar(@extra_sections);
          }

        } else { # it's a pre-total (normal) section

          # skip tax items unless they're explicitly included in a section
          next if $cust_bill_pkg->pkgnum == 0 and
                  ! $cust_bill_pkg->feepart   and
                  ! $section;

          if ( $type eq 'S' ) {
            $subtotal{$locationnum}{$section} += $cust_bill_pkg->setup
              if $cust_bill_pkg->setup != 0
              || $cust_bill_pkg->setup_show_zero;
          } elsif ( $type eq 'R' ) {
            $subtotal{$locationnum}{$section} += $cust_bill_pkg->recur - $usage
              if $cust_bill_pkg->recur != 0
              || $cust_bill_pkg->recur_show_zero;
          } elsif ( $type eq 'U' ) {
            $subtotal{$locationnum}{$section} += $usage
              unless scalar(@extra_sections);
          } elsif ( !$type ) {
            $subtotal{$locationnum}{$section} += $cust_bill_pkg->setup
                                               + $cust_bill_pkg->recur;
          }

        }

      }

  }

  %pkg_category_cache = ();

  # summary invoices need subtotals for all non-disabled package categories,
  # even if they're zero
  # but currently assume that there are no location sections, or at least
  # that the summary page doesn't care about them
  if ( $opt{summary} ) {
    foreach my $category (qsearch('pkg_category', {disabled => ''})) {
      $subtotal{''}{$category->categoryname} ||= 0;
    }
    $subtotal{''}{''} ||= 0;
  }

  my @sections;
  foreach my $post_total (0,1) {
    my @these;
    my $s = $post_total ? \%late_subtotal : \%subtotal;
    foreach my $locationnum (keys %$s) {
      foreach my $sectionname (keys %{ $s->{$locationnum} }) {
        my $section = {
                        'subtotal'    => $s->{$locationnum}{$sectionname},
                        'post_total'  => $post_total,
                        'sort_weight' => 0,
                      };
        if ( $locationnum ) {
          $section->{'locationnum'} = $locationnum;
          my $location = FS::cust_location->by_key($locationnum);
          $section->{'description'} = &{ $escape }($location->location_label);
          # Better ideas? This will roughly group them by proximity, 
          # which alpha sorting on any of the address fields won't.
          # Sorting by locationnum is meaningless.
          # We have to sort on _something_ or the order may change 
          # randomly from one invoice to the next, which will confuse
          # people.
          $section->{'sort_weight'} = sprintf('%012s',$location->zip) .
                                      $locationnum;
          $section->{'location'} = {
            label_prefix => &{ $escape }($location->label_prefix),
            map { $_ => &{ $escape }($location->get($_)) }
              $location->fields
          };
        } else {
          $section->{'category'} = $sectionname;
          $section->{'description'} = &{ $escape }($sectionname);
          if ( _pkg_category($sectionname) ) {
            $section->{'sort_weight'} = _pkg_category($sectionname)->weight;
            if ( _pkg_category($sectionname)->condense ) {
              $section = { %$section, $self->_condense_section($opt{format}) };
            }
          }
        }
        if ( !$post_total and !$not_tax{$locationnum}{$sectionname} ) {
          # then it's a tax-only section
          $section->{'summarized'} = 'Y';
          $section->{'tax_section'} = 'Y';
        }
        push @these, $section;
      } # foreach $sectionname
    } #foreach $locationnum
    push @these, @extra_sections if $post_total == 0;
    # need an alpha sort for location sections, because postal codes can 
    # be non-numeric
    $sections[ $post_total ] = [ sort {
      $opt{'by_location'} ? 
        ($a->{sort_weight} cmp $b->{sort_weight}) :
        ($a->{sort_weight} <=> $b->{sort_weight})
      } @these ];
  } #foreach $post_total

  return @sections; # early, late
}

#helper subs for above

sub cust_pkg_hash {
  my $self = shift;
  $self->{cust_pkg} ||= { map { $_->pkgnum => $_ } $self->cust_pkg };
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

=item _items_pkg [ OPTIONS ]

Return line item hashes for each package item on this invoice. Nearly 
equivalent to 

$self->_items_cust_bill_pkg([ $self->cust_bill_pkg ])

OPTIONS are passed through to _items_cust_bill_pkg, and should include
'format' and 'escape_function' at minimum.

To produce items for a specific invoice section, OPTIONS should include
'section', a hashref containing 'category' and/or 'locationnum' keys.

'section' may also contain a key named 'condensed'. If this is present
and has a true value, _items_pkg will try to merge identical items into items
with 'quantity' equal to the number of items (not the sum of their separate
quantities, for some reason).

=cut

sub _items_nontax {
  my $self = shift;
  # The order of these is important.  Bundled line items will be merged into
  # the most recent non-hidden item, so it needs to be the one with:
  # - the same pkgnum
  # - the same start date
  # - no pkgpart_override
  #
  # So: sort by pkgnum,
  # then by sdate
  # then sort the base line item before any overrides
  # then sort hidden before non-hidden add-ons
  # then sort by override pkgpart (for consistency)
  sort { $a->pkgnum <=> $b->pkgnum        or
         $a->sdate  <=> $b->sdate         or
         ($a->pkgpart_override ? 0 : -1)  or
         ($b->pkgpart_override ? 0 : 1)   or
         $b->hidden cmp $a->hidden        or
         $a->pkgpart_override <=> $b->pkgpart_override
       }
  # and of course exclude taxes and fees
  grep { $_->pkgnum > 0 } $self->cust_bill_pkg;
}

sub _items_fee {
  my $self = shift;
  my %options = @_;
  my @cust_bill_pkg = grep { $_->feepart } $self->cust_bill_pkg;
  my $escape_function = $options{escape_function};

  my @items;
  foreach my $cust_bill_pkg (@cust_bill_pkg) {
    # cache this, so we don't look it up again in every section
    my $part_fee = $cust_bill_pkg->get('part_fee')
       || $cust_bill_pkg->part_fee;
    $cust_bill_pkg->set('part_fee', $part_fee);
    if (!$part_fee) {
      #die "fee definition not found for line item #".$cust_bill_pkg->billpkgnum."\n"; # might make more sense
      warn "fee definition not found for line item #".$cust_bill_pkg->billpkgnum."\n";
      next;
    }
    if ( exists($options{section}) and exists($options{section}{category}) )
    {
      my $categoryname = $options{section}{category};
      # then filter for items that have that section
      if ( $part_fee->categoryname ne $categoryname ) {
        warn "skipping fee '".$part_fee->itemdesc."'--not in section $categoryname\n" if $DEBUG;
        next;
      }
    } # otherwise include them all in the main section
    # XXX what to do when sectioning by location?
    
    my @ext_desc;
    my %base_invnums; # invnum => invoice date
    foreach ($cust_bill_pkg->cust_bill_pkg_fee) {
      if ($_->base_invnum) {
        my $base_bill = FS::cust_bill->by_key($_->base_invnum);
        my $base_date = $self->time2str_local('short', $base_bill->_date)
          if $base_bill;
        $base_invnums{$_->base_invnum} = $base_date || '';
      }
    }
    foreach (sort keys(%base_invnums)) {
      next if $_ == $self->invnum;
      # per convention, we must escape ext_description lines
      push @ext_desc,
        &{$escape_function}(
          $self->mt('from invoice #[_1] on [_2]', $_, $base_invnums{$_})
        );
    }
    my $desc = $part_fee->itemdesc_locale($self->cust_main->locale);
    # but not escape the base description line

    push @items,
      { feepart     => $cust_bill_pkg->feepart,
        amount      => sprintf('%.2f', $cust_bill_pkg->setup + $cust_bill_pkg->recur),
        description => $desc,
        ext_description => \@ext_desc
        # sdate/edate?
      };
  }
  @items;
}

sub _items_pkg {
  my $self = shift;
  my %options = @_;

  warn "$me _items_pkg searching for all package line items\n"
    if $DEBUG > 1;

  my @cust_bill_pkg = $self->_items_nontax;

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
  my @cust_bill_pkg = sort _taxsort grep { ! $_->pkgnum and ! $_->feepart } 
    $self->cust_bill_pkg;
  my @items = $self->_items_cust_bill_pkg(\@cust_bill_pkg, @_);

  if ( $self->conf->exists('always_show_tax') ) {
    my $itemdesc = $self->conf->config('always_show_tax') || 'Tax';
    if (0 == grep { $_->{description} eq $itemdesc } @items) {
      push @items,
        { 'description' => $itemdesc,
          'amount'      => 0.00 };
    }
  }
  @items;
}

=item _items_cust_bill_pkg CUST_BILL_PKGS OPTIONS

Takes an arrayref of L<FS::cust_bill_pkg> objects, and returns a
list of hashrefs describing the line items they generate on the invoice.

OPTIONS may include:

format: the invoice format.

escape_function: the function used to escape strings.

DEPRECATED? (expensive, mostly unused?)
format_function: the function used to format CDRs.

section: a hashref containing 'category' and/or 'locationnum'; if this 
is present, only returns line items that belong to that category and/or
location (whichever is defined).

multisection: a flag indicating that this is a multisection invoice,
which does something complicated.

preref_callback: coderef run for each line item, code should return HTML to be
displayed before that line item (quotations only)

Returns a list of hashrefs, each of which may contain:

pkgnum, description, amount, unit_amount, quantity, pkgpart, _is_setup, and 
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
  my ($section, $locationnum, $category);
  if ( $opt{section} ) {
    $category = $opt{section}->{category};
    $locationnum = $opt{section}->{locationnum};
  }
  my $summary_page = $opt{summary_page} || ''; #unused
  my $multisection = defined($category) || defined($locationnum);
  my $discount_show_always = 0;

  my $maxlength = $conf->config('cust_bill-latex_lineitem_maxlength') || 40;

  my $cust_main = $self->cust_main;#for per-agent cust_bill-line_item-ate_style

  # for location labels: use default location on the invoice date
  my $default_locationnum;
  if ( $self->custnum ) {
    my $h_cust_main;
    my @h_search = FS::h_cust_main->sql_h_search($self->_date);
    $h_cust_main = qsearchs({
        'table'     => 'h_cust_main',
        'hashref'   => { custnum => $self->custnum },
        'extra_sql' => $h_search[1],
        'addl_from' => $h_search[3],
    }) || $cust_main;
    $default_locationnum = $h_cust_main->ship_locationnum;
  } elsif ( $self->prospectnum ) {
    my $cust_location = qsearchs('cust_location',
      { prospectnum => $self->prospectnum,
        disabled => '' });
    $default_locationnum = $cust_location->locationnum if $cust_location;
  }

  my @b = (); # accumulator for the line item hashes that we'll return
  my ($s, $r, $u, $d) = ( undef, undef, undef, undef );
            # the 'current' line item hashes for setup, recur, usage, discount
  foreach my $cust_bill_pkg ( @$cust_bill_pkgs )
  {
    # if the current line item is waiting to go out, and the one we're about
    # to start is not bundled, then push out the current one and start a new
    # one.
    foreach ( $s, $r, ($opt{skip_usage} ? () : $u ), $d ) {
      if ( $_ && !$cust_bill_pkg->hidden ) {
        $_->{amount}      = sprintf( "%.2f", $_->{amount} );
        $_->{amount}      =~ s/^\-0\.00$/0.00/;
        if (exists($_->{unit_amount})) {
          $_->{unit_amount} = sprintf( "%.2f", $_->{unit_amount} );
        }
        push @b, { %$_ }
          if $_->{amount} != 0
          || $discount_show_always
          || ( ! $_->{_is_setup} && $_->{recur_show_zero} )
          || (   $_->{_is_setup} && $_->{setup_show_zero} )
        ;
        $_ = undef;
      }
    }

    if ( $locationnum ) {
      # this is a location section; skip packages that aren't at this
      # service location.
      next if $cust_bill_pkg->pkgnum == 0; # skips fees...
      next if $self->cust_pkg_hash->{ $cust_bill_pkg->pkgnum }->locationnum 
              != $locationnum;
    }

    # Consider display records for this item to determine if it belongs
    # in this section.  Note that if there are no display records, there
    # will be a default pseudo-record that includes all charge types 
    # and has no section name.
    my @cust_bill_pkg_display = $cust_bill_pkg->can('cust_bill_pkg_display')
                                  ? $cust_bill_pkg->cust_bill_pkg_display
                                  : ( $cust_bill_pkg );

    warn "$me _items_cust_bill_pkg considering cust_bill_pkg ".
         $cust_bill_pkg->billpkgnum. ", pkgnum ". $cust_bill_pkg->pkgnum. "\n"
      if $DEBUG > 1;

    if ( defined($category) ) {
      # then this is a package category section; process all display records
      # that belong to this section.
      @cust_bill_pkg_display = grep { $_->section eq $category }
                                @cust_bill_pkg_display;
    } else {
      # otherwise, process all display records that aren't usage summaries
      # (I don't think there should be usage summaries if you aren't using 
      # category sections, but this is the historical behavior)
      @cust_bill_pkg_display = grep { !$_->summary }
                                @cust_bill_pkg_display;
    }

    my $classname = ''; # package class name, will fill in later

    foreach my $display (@cust_bill_pkg_display) {

      warn "$me _items_cust_bill_pkg considering cust_bill_pkg_display ".
           $display->billpkgdisplaynum. "\n"
        if $DEBUG > 1;

      my $type = $display->type;

      my $desc = $cust_bill_pkg->desc( $cust_main ? $cust_main->locale : '' );
      $desc = substr($desc, 0, $maxlength). '...'
        if $format eq 'latex' && length($desc) > $maxlength;

      my %details_opt = ( 'format'          => $format,
                          'escape_function' => $escape_function,
                          'format_function' => $format_function,
                          'no_usage'        => $opt{'no_usage'},
                        );

      if ( ref($cust_bill_pkg) eq 'FS::quotation_pkg' ) {
        # XXX this should be pulled out into quotation_pkg

        warn "$me _items_cust_bill_pkg cust_bill_pkg is quotation_pkg\n"
          if $DEBUG > 1;
        # quotation_pkgs are never fees, so don't worry about the case where
        # part_pkg is undefined

        # and I guess they're never bundled either?
        if ( $cust_bill_pkg->setup != 0 ) {
          my $description = $desc;
          $description .= ' Setup'
            if $cust_bill_pkg->recur != 0
            || $discount_show_always
            || $cust_bill_pkg->recur_show_zero;
          #push @b, {
          # keep it consistent, please
          $s = {
            'pkgnum'      => $cust_bill_pkg->pkgpart, #so it displays in Ref
            'description' => $description,
            'amount'      => sprintf("%.2f", $cust_bill_pkg->setup),
            'unit_amount' => sprintf("%.2f", $cust_bill_pkg->unitsetup),
            'quantity'    => $cust_bill_pkg->quantity,
            'preref_html' => ( $opt{preref_callback}
                                 ? &{ $opt{preref_callback} }( $cust_bill_pkg )
                                 : ''
                             ),
          };
        }
        if ( $cust_bill_pkg->recur != 0 ) {
          #push @b, {
          $r = {
            'pkgnum'      => $cust_bill_pkg->pkgpart, #so it displays in Ref
            'description' => "$desc (". $cust_bill_pkg->part_pkg->freq_pretty.")",
            'amount'      => sprintf("%.2f", $cust_bill_pkg->recur),
            'unit_amount' => sprintf("%.2f", $cust_bill_pkg->unitrecur),
            'quantity'    => $cust_bill_pkg->quantity,
           'preref_html'  => ( $opt{preref_callback}
                                 ? &{ $opt{preref_callback} }( $cust_bill_pkg )
                                 : ''
                             ),
          };
        }

      } elsif ( $cust_bill_pkg->pkgnum > 0 ) {
        # a "normal" package line item (not a quotation, not a fee, not a tax)

        warn "$me _items_cust_bill_pkg cust_bill_pkg is non-tax\n"
          if $DEBUG > 1;
 
        my $cust_pkg = $cust_bill_pkg->cust_pkg;
        my $part_pkg = $cust_pkg->part_pkg;

        # which pkgpart to show for display purposes?
        my $pkgpart = $cust_bill_pkg->pkgpart_override || $cust_pkg->pkgpart;

        # start/end dates for invoice formats that do nonstandard 
        # things with them
        my %item_dates = ();
        %item_dates = map { $_ => $cust_bill_pkg->$_ } ('sdate', 'edate')
          unless $part_pkg->option('disable_line_item_date_ranges',1);

        # not normally used, but pass this to the template anyway
        $classname = $part_pkg->classname;

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

          $description .= $cust_bill_pkg->time_period_pretty( $part_pkg,
                                                              $self->agentnum )
            if $part_pkg->is_prepaid #for prepaid, "display the validity period
                                     # triggered by the recurring charge freq
                                     # (RT#26274)
            && $cust_bill_pkg->recur == 0
            && ! $cust_bill_pkg->recur_show_zero;

          my @d = ();
          my $svc_label;

          # always pass the svc_label through to the template, even if 
          # not displaying it as an ext_description
          my @svc_labels = map &{$escape_function}($_),
                      $cust_pkg->h_labels_short($self->_date, undef, 'I');

          $svc_label = $svc_labels[0];

          unless ( $cust_pkg->part_pkg->hide_svc_detail
                || $cust_bill_pkg->hidden )
          {

            push @d, @svc_labels
              unless $cust_bill_pkg->pkgpart_override; #don't redisplay services
            # show the location label if it's not the customer's default
            # location, and we're not grouping items by location already
            if ( $cust_pkg->locationnum != $default_locationnum
                  and !defined($locationnum) ) {
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
              pkgpart         => $pkgpart,
              pkgnum          => $cust_bill_pkg->pkgnum,
              amount          => $cust_bill_pkg->setup,
              setup_show_zero => $cust_bill_pkg->setup_show_zero,
              unit_amount     => $cust_bill_pkg->unitsetup,
              quantity        => $cust_bill_pkg->quantity,
              ext_description => \@d,
              svc_label       => ($svc_label || ''),
              locationnum     => $cust_pkg->locationnum, # sure, why not?
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
          my $description = $desc;
          if ( $type eq 'U' and defined($r) ) {
            # don't just show the same description as the recur line
            $description = $self->mt('Usage charges');
          }

          my $part_pkg = $cust_pkg->part_pkg;

          $description .= $cust_bill_pkg->time_period_pretty( $part_pkg,
                                                              $self->agentnum );

          my @d = ();
          my @seconds = (); # for display of usage info
          my $svc_label = '';

          #at least until cust_bill_pkg has "past" ranges in addition to
          #the "future" sdate/edate ones... see #3032
          my @dates = ( $self->_date );
          my $prev = $cust_bill_pkg->previous_cust_bill_pkg;
          push @dates, $prev->sdate if $prev;
          push @dates, undef if !$prev;

          my @svc_labels = map &{$escape_function}($_),
                      $cust_pkg->h_labels_short(@dates, 'I');
          $svc_label = $svc_labels[0];

          # show service labels, unless...
                    # the package is set not to display them
          unless ( $part_pkg->hide_svc_detail
                    # or this is a tax-like line item
                || $cust_bill_pkg->itemdesc
                    # or this is a hidden (bundled) line item
                || $cust_bill_pkg->hidden
                    # or this is a usage summary line
                || $is_summary && $type && $type eq 'U'
                    # or this is a usage line and there's a recurring line
                    # for the package in the same section (which will 
                    # have service labels already)
                || ($type eq 'U' and defined($r))
              )
          {

            warn "$me _items_cust_bill_pkg adding service details\n"
              if $DEBUG > 1;

            push @d, @svc_labels
              unless $cust_bill_pkg->pkgpart_override; #don't redisplay services
            warn "$me _items_cust_bill_pkg done adding service details\n"
              if $DEBUG > 1;

            # show the location label if it's not the customer's default
            # location, and we're not grouping items by location already
            if ( $cust_pkg->locationnum != $default_locationnum
                  and !defined($locationnum) ) {
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

          } # if we are showing service labels

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

            my $unit_amount =
              ( $cust_bill_pkg->unitrecur > 0 ) ? $cust_bill_pkg->unitrecur
                                                : $amount;

            if ( $cust_bill_pkg->hidden ) {
              $r->{amount}      += $amount;
              $r->{unit_amount} += $unit_amount;
              push @{ $r->{ext_description} }, @d;
            } else {
              $r = {
                description     => $description,
                pkgpart         => $pkgpart,
                pkgnum          => $cust_bill_pkg->pkgnum,
                amount          => $amount,
                recur_show_zero => $cust_bill_pkg->recur_show_zero,
                unit_amount     => $unit_amount,
                quantity        => $cust_bill_pkg->quantity,
                %item_dates,
                ext_description => \@d,
                svc_label       => ($svc_label || ''),
                locationnum     => $cust_pkg->locationnum,
              };
              $r->{'seconds'} = \@seconds if grep {defined $_} @seconds;
            }

          } else {  # $type eq 'U'

            warn "$me _items_cust_bill_pkg adding usage\n"
              if $DEBUG > 1;

            if ( $cust_bill_pkg->hidden and defined($u) ) {
              # if this is a hidden package and there's already a usage
              # line for the bundle, add this package's total amount and
              # usage details to it
              $u->{amount}      += $amount;
              push @{ $u->{ext_description} }, @d;
            } elsif ( $amount ) {
              # create a new usage line
              $u = {
                description     => $description,
                pkgpart         => $pkgpart,
                pkgnum          => $cust_bill_pkg->pkgnum,
                amount          => $amount,
                usage_item      => 1,
                recur_show_zero => $cust_bill_pkg->recur_show_zero,
                %item_dates,
                ext_description => \@d,
                locationnum     => $cust_pkg->locationnum,
              };
            } # else this has no usage, so don't create a usage section
          }

        } # recurring or usage with recurring charge

      } else { # taxes and fees

        warn "$me _items_cust_bill_pkg cust_bill_pkg is tax\n"
          if $DEBUG > 1;

        # items of this kind should normally not have sdate/edate.
        push @b, {
          'description' => $desc,
          'amount'      => sprintf('%.2f', $cust_bill_pkg->setup 
                                           + $cust_bill_pkg->recur)
        };

      } # if quotation / package line item / other line item

      # decide whether to show active discounts here
      if (
          # case 1: we are showing a single line for the package
          ( !$type )
          # case 2: we are showing a setup line for a package that has
          # no base recurring fee
          or ( $type eq 'S' and $cust_bill_pkg->unitrecur == 0 )
          # case 3: we are showing a recur line for a package that has 
          # a base recurring fee
          or ( $type eq 'R' and $cust_bill_pkg->unitrecur > 0 )
      ) {

        my $item_discount = $cust_bill_pkg->_item_discount;
        if ( $item_discount ) {
          # $item_discount->{amount} is negative

          if ( $d and $cust_bill_pkg->hidden ) {
            $d->{amount}      += $item_discount->{amount};
          } else {
            $d = $item_discount;
            $_ = &{$escape_function}($_) foreach @{ $d->{ext_description} };
          }

          # update the active line (before the discount) to show the 
          # original price (whether this is a hidden line or not)
          #
          # quotation discounts keep track of setup and recur; invoice 
          # discounts currently don't
          if ( exists $item_discount->{setup_amount} ) {

            $s->{amount} -= $item_discount->{setup_amount} if $s;
            $r->{amount} -= $item_discount->{recur_amount} if $r;

          } else {

            # $active_line is the line item hashref for the line that will
            # show the original price
            # (use the recur or single line for the package, unless we're 
            # showing a setup line for a package with no recurring fee)
            my $active_line = $r;
            if ( $type eq 'S' ) {
              $active_line = $s;
            }
            $active_line->{amount} -= $item_discount->{amount};

          }

        } # if there are any discounts
      } # if this is an appropriate place to show discounts

    } # foreach $display

    $discount_show_always = ($cust_bill_pkg->cust_bill_pkg_discount
                                && $conf->exists('discount-show-always'));

  }

  foreach ( $s, $r, ($opt{skip_usage} ? () : $u ), $d ) {
    if ( $_  ) {
      $_->{amount}      = sprintf( "%.2f", $_->{amount} ),
        if exists($_->{amount});
      $_->{amount}      =~ s/^\-0\.00$/0.00/;
      if (exists($_->{unit_amount})) {
        $_->{unit_amount} = sprintf( "%.2f", $_->{unit_amount} );
      }

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
