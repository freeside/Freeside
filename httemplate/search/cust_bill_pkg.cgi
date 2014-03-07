<& elements/search.html,
                 'title'       => emt('Line items'),
                 'name'        => emt('line items'),
                 'query'       => $query,
                 'count_query' => $count_query,
                 'count_addl'  => \@total_desc,
                 'header'      => [
                   @pkgnum_header,
                   emt('Pkg Def'),
                   emt('Description'),
                   @post_desc_header,
                   @peritem_desc,
                   emt('Invoice'),
                   emt('Date'),
                   emt('Paid'),
                   emt('Credited'),
                   FS::UI::Web::cust_header(),
                 ],
                 'fields'      => [
                   @pkgnum,
                   sub { $_[0]->pkgnum > 0
                           ? $_[0]->get('pkgpart')
                           : ''
                       },
                   'itemdesc', # is part_pkg.pkg if applicable
                   @post_desc,
                   #strikethrough or "N/A ($amount)" or something these when
                   # they're not applicable to pkg_tax search
                   @peritem_sub,
                   'invnum',
                   sub { time2str('%b %d %Y', shift->_date ) },
                   sub { sprintf($money_char.'%.2f', shift->get('pay_amount')) },
                   sub { sprintf($money_char.'%.2f', shift->get('credit_amount')) },
                   \&FS::UI::Web::cust_fields,
                 ],
                 'sort_fields' => [
                   @pkgnum_null,
                   '',
                   '',
                   @post_desc_null,
                   @peritem,
                   'invnum',
                   '_date',
                   '', #'pay_amount',
                   '', #'credit_amount',
                   FS::UI::Web::cust_sort_fields(),
                 ],
                 'links'       => [
                   @pkgnum_null,
                   '',
                   '',
                   @post_desc_null,
                   @peritem_null,
                   $ilink,
                   $ilink,
                   $pay_link,
                   $credit_link,
                   ( map { $_ ne 'Cust. Status' ? $clink : '' }
                         FS::UI::Web::cust_header()
                   ),
                 ],
                 #'align' => 'rlrrrc'.FS::UI::Web::cust_aligns(),
                 'align' => $pkgnum_align.
                            'rl'.
                            $post_desc_align.
                            $peritem_align.
                            'rcrr'.
                            FS::UI::Web::cust_aligns(),
                 'color' => [ 
                              @pkgnum_null,
                              '',
                              '',
                              @post_desc_null,
                              @peritem_null,
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              @pkgnum_null,
                              '',
                              '',
                              @post_desc_null,
                              @peritem_null,
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_styles(),
                            ],
&>
<%doc>

Output control parameters:
- distribute: Boolean.  If true, recurring fees will be "prorated" for the 
  portion of the package date range (sdate-edate) that falls within the date
  range of the report.  Line items will be limited to those for which this 
  portion is > 0.  This disables filtering on invoice date.

- usage: Separate usage (cust_bill_pkg_detail records) from
  recurring charges.  If set to "usage", will show usage instead of 
  recurring charges.  If set to "recurring", will deduct usage and only
  show the flat rate charge.  If not passed, the "recurring charge" column
  will include usage charges also.

Filtering parameters:
- begin, end: Date range.  Applies to invoice date, not necessarily package
  date range.  But see "distribute".

- status: Customer status (active, suspended, etc.).  This will filter on 
  _current_ customer status, not status at the time the invoice was generated.

- agentnum: Filter on customer agent.

- refnum: Filter on customer reference source.

- cust_classnum: Filter on customer class.

- classnum: Filter on package class.

- report_optionnum: Filter on package report class.  Can be a single report
  class number or a comma-separated list (where 0 is "no report class"), or the
  word "multiple".

- use_override: Apply "classnum" and "taxclass" filtering based on the 
  override (bundle) pkgpart, rather than always using the true pkgpart.

- nottax: Limit to items that are not taxes (pkgnum > 0 or feepart > 0).

- istax: Limit to items that are taxes (pkgnum == 0 and feepart = null).

- taxnum: Limit to items whose tax definition matches this taxnum.
  With "nottax" that means items that are subject to that tax;
  with "istax" it's the tax charges themselves.  Can be specified 
  more than once to include multiple taxes.

- country, state, county, city: Limit to items whose tax location 
  matches these fields.  If "nottax" it's the tax location of the package;
  if "istax" the location of the tax.

- taxname, taxnameNULL: With "nottax", limit to items whose tax location
  matches a tax with this name.  With "istax", limit to items that have
  this tax name.  taxnameNULL is equivalent to "taxname = '' OR taxname 
  = 'Tax'".

- out: With "nottax", limit to items that don't match any tax definition.
  With "istax", find tax items that are unlinked to their tax definitions.
  Current Freeside (> July 2012) always creates tax links, but unlinked
  items may result from an incomplete upgrade of legacy data.

- locationtaxid: With "nottax", limit to packages matching this 
  tax_rate_location ID; with "tax", limit to taxes generated from that 
  location.

- taxclass: Filter on package taxclass.

- taxclassNULL: With "nottax", limit to items that would be subject to the
  tax with taxclass = NULL.  This doesn't necessarily mean part_pkg.taxclass
  is NULL; it also includes taxclasses that don't have a tax in this region.

- itemdesc: Limit to line items with this description.  Note that non-tax
  packages usually have a description of NULL.  (Deprecated.)

- report_group: Can contain '=' or '!=' followed by a string to limit to 
  line items where itemdesc starts with, or doesn't start with, the string.

- cust_tax: Limit to customers who are tax-exempt.  If "taxname" is also
  specified, limit to customers who are also specifically exempt from that 
  tax.

- pkg_tax: Limit to packages that are tax-exempt, and only include the 
  exempt portion (setup, recurring, or both) when calculating totals.

- taxable: Limit to packages that are subject to tax, i.e. where a
  cust_bill_pkg_tax_location record exists.

- credit: Limit to line items that received a credit application.  The
  amount of the credit will also be shown.

</%doc>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied" unless $curuser->access_right('Financial reports');

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my @select = ( 'cust_bill_pkg.*', 'cust_bill._date' );
my @total = ( 'COUNT(*)', 'SUM(cust_bill_pkg.setup + cust_bill_pkg.recur)');
my @total_desc = ( $money_char.'%.2f total' ); # sprintf strings

my @peritem = ( 'setup', 'recur' );
my @peritem_desc = ( 'Setup charge', 'Recurring charge' );

my @pkgnum_header = ();
my @pkgnum = ();
my @pkgnum_null;
my $pkgnum_align = '';
if ( $curuser->option('show_pkgnum') ) {
  push @select, 'cust_bill_pkg.pkgnum';
  push @pkgnum_header, 'Pkg Num';
  push @pkgnum, sub { $_[0]->pkgnum > 0 ? $_[0]->pkgnum : '' };
  push @pkgnum_null, '';
  $pkgnum_align .= 'r';
}

my @post_desc_header = ();
my @post_desc = ();
my @post_desc_null = ();
my $post_desc_align = '';
if ( $conf->exists('enable_taxclasses') ) {
  push @post_desc_header, 'Tax class';
  push @post_desc, 'taxclass';
  push @post_desc_null, '';
  $post_desc_align .= 'l';
}

# used in several places
my $itemdesc = 'COALESCE(part_fee.itemdesc, part_pkg.pkg, cust_bill_pkg.itemdesc)';

# valid in both the tax and non-tax cases
my $join_cust = 
  " LEFT JOIN cust_bill ON (cust_bill_pkg.invnum = cust_bill.invnum)".
  # use cust_pkg.locationnum if it exists
  FS::UI::Web::join_cust_main('cust_bill', 'cust_pkg');

#agent virtualization
my $agentnums_sql =
  $FS::CurrentUser::CurrentUser->agentnums_sql( 'table' => 'cust_main' );

my @where = ( $agentnums_sql );

# date range
my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

if ( $cgi->param('distribute') == 1 ) {
  push @where, "sdate <= $ending",
               "edate >  $beginning",
  ;
}
else {
  push @where, "cust_bill._date >= $beginning",
               "cust_bill._date <= $ending";
}

# status
if ( $cgi->param('status') =~ /^([a-z]+)$/ ) {
  push @where, FS::cust_main->cust_status_sql . " = '$1'";
}

# agentnum
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  push @where, "cust_main.agentnum = $1";
}

# salesnum--see below
# refnum
if ( $cgi->param('refnum') =~ /^(\d+)$/ ) {
  push @where, "cust_main.refnum = $1";
}

# cust_classnum (false laziness w/ elements/cust_main_dayranges.html, elements/cust_pay_or_refund.html, prepaid_income.html, cust_bill_pay.html, cust_bill_pkg_referral.html, unearned_detail.html, cust_credit.html, cust_credit_refund.html, cust_main::Search::search_sql)
if ( grep { $_ eq 'cust_classnum' } $cgi->param ) {
  my @classnums = grep /^\d*$/, $cgi->param('cust_classnum');
  push @where, 'COALESCE( cust_main.classnum, 0) IN ( '.
                   join(',', map { $_ || '0' } @classnums ).
               ' )'
    if @classnums;
}


# custnum
if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  push @where, "cust_main.custnum = $1";
}

# we want the package and its definition if available
my $join_pkg = 
' LEFT JOIN cust_pkg      USING (pkgnum) 
  LEFT JOIN part_pkg      USING (pkgpart)
  LEFT JOIN part_fee      USING (feepart)';

my $part_pkg = 'part_pkg';
# "Separate sub-packages from parents"
my $use_override = $cgi->param('use_override') ? 1 : 0;
if ( $use_override ) {
  # still need the real part_pkg for tax applicability, 
  # so alias this one
  $join_pkg .= " LEFT JOIN part_pkg AS override ON (
  COALESCE(cust_bill_pkg.pkgpart_override, cust_pkg.pkgpart, 0) = override.pkgpart
  )";
  $part_pkg = 'override';
}
push @select, "$part_pkg.pkgpart", "$part_pkg.pkg";
push @select, "COALESCE($part_pkg.taxclass, part_fee.taxclass) AS taxclass"
  if $conf->exists('enable_taxclasses');

# the non-tax case
if ( $cgi->param('nottax') ) {

  push @select, $itemdesc;

  push @where,
    '(cust_bill_pkg.pkgnum > 0 OR cust_bill_pkg.feepart IS NOT NULL)';

  my @tax_where; # will go into a subquery
  my @exempt_where; # will also go into a subquery

  # classnum (of override pkgpart if applicable)
  # not specified: all classes
  # 0: empty class
  # N: classnum
  if ( grep { $_ eq 'classnum' } $cgi->param ) {
    my @classnums = grep /^\d+$/, $cgi->param('classnum');
    push @where, "COALESCE(part_fee.classnum, $part_pkg.classnum, 0) IN ( ".
                     join(',', @classnums ).
                 ' )'
      if @classnums;
  }

  if ( grep { $_ eq 'report_optionnum' } $cgi->param ) {
    my $num = join(',', grep /^[\d,]+$/, $cgi->param('report_optionnum'));
    my $not_num = join(',', grep /^[\d,]+$/, $cgi->param('not_report_optionnum'));
    my $all = $cgi->param('all_report_options') ? 1 : 0;
    push @where, # code reuse FTW
      FS::Report::Table->with_report_option(
        report_optionnum      => $num,
        not_report_optionnum  => $not_num,
        use_override          => $use_override,
        all_report_options    => $all,
      );
  }

  # taxclass
  if ( $cgi->param('taxclassNULL') ) {
    # a little different from 'taxclass' in that it applies to the
    # effective taxclass, not the real one
    push @tax_where, 'cust_main_county.taxclass IS NULL'
  } elsif ( $cgi->param('taxclass') ) {
    push @tax_where, "COALESCE(part_fee.taxclass, $part_pkg.taxclass) IN (" .
                 join(', ', map {dbh->quote($_)} $cgi->param('taxclass') ).
                 ')';
  }

  if ( $cgi->param('exempt_cust') eq 'Y' ) {
    # tax-exempt customers
    push @exempt_where, "(exempt_cust = 'Y' OR exempt_cust_taxname = 'Y')";

  } elsif ( $cgi->param('exempt_pkg') eq 'Y' ) { # non-taxable package
    # non-taxable package charges
    push @exempt_where, "(exempt_setup = 'Y' OR exempt_recur = 'Y')";
  }
  # we don't handle exempt_monthly here
  
  if ( $cgi->param('taxname') ) { # specific taxname
      push @tax_where, 'cust_main_county.taxname = '.
                        dbh->quote($cgi->param('taxname'));
  } elsif ( $cgi->param('taxnameNULL') ) {
      push @tax_where, 'cust_main_county.taxname IS NULL OR '.
                       'cust_main_county.taxname = \'Tax\'';
  }

  # country:state:county:city:district (may be repeated)
  # You can also pass a big list of taxnums but that leads to huge URLs.
  # Note that this means "packages whose tax is in this region", not 
  # "packages in this region".  It's meant for links from the tax report.
  if ( $cgi->param('region') ) {
    my @orwhere;
    foreach ( $cgi->param('region') ) {
      my %loc;
      @loc{qw(country state county city district)} = 
        split(':', $cgi->param('region'));
      my $string = join(' AND ',
            map { 
              if ( $loc{$_} ) {
                "$_ = ".dbh->quote($loc{$_});
              } else {
                "$_ IS NULL";
              }
            } keys(%loc)
      );
      push @orwhere, "($string)";
    }
    push @tax_where, '(' . join(' OR ', @orwhere) . ')' if @orwhere;
  }

  # specific taxnums
  if ( $cgi->param('taxnum') ) {
    my $taxnum_in = join(',', 
      grep /^\d+$/, $cgi->param('taxnum')
    );
    push @tax_where, "cust_main_county.taxnum IN ($taxnum_in)"
      if $taxnum_in;
  }

  # If we're showing exempt items, we need to find those with 
  # cust_tax_exempt_pkg records matching the selected taxes.
  # If we're showing taxable items, we need to find those with 
  # cust_bill_pkg_tax_location records.  We also need to find the 
  # exemption records so that we can show the taxable amount.
  # If we're showing all items, we need the union of those.
  # If we're showing 'out' (items that aren't region/class taxable),
  # then we need the set of all items minus the union of those.

  my $exempt_sub;

  if ( @exempt_where or @tax_where 
    or $cgi->param('taxable') or $cgi->param('out') )
  {
    # process exemption restrictions, including @tax_where
    my $exempt_sub = 'SELECT SUM(amount) as exempt_amount, billpkgnum 
    FROM cust_tax_exempt_pkg JOIN cust_main_county USING (taxnum)';

    $exempt_sub .= ' WHERE '.join(' AND ', @tax_where, @exempt_where)
      if (@tax_where or @exempt_where);

    $exempt_sub .= ' GROUP BY billpkgnum';

    $join_pkg .= " LEFT JOIN ($exempt_sub) AS item_exempt
    USING (billpkgnum)";
  }
 
  if ( @tax_where or $cgi->param('taxable') or $cgi->param('out') ) { 
    # process tax restrictions
    unshift @tax_where,
      'cust_main_county.tax > 0';

    my $tax_sub = "SELECT invnum, cust_bill_pkg_tax_location.pkgnum
    FROM cust_bill_pkg_tax_location
    JOIN cust_bill_pkg AS tax_item USING (billpkgnum)
    JOIN cust_main_county USING (taxnum)
    WHERE ". join(' AND ', @tax_where).
    " GROUP BY invnum, cust_bill_pkg_tax_location.pkgnum";

    $join_pkg .= " LEFT JOIN ($tax_sub) AS item_tax
    ON (item_tax.invnum = cust_bill_pkg.invnum AND
        item_tax.pkgnum = cust_bill_pkg.pkgnum)";
  }

  # now do something with that
  if ( @exempt_where ) {

    push @where,    'item_exempt.billpkgnum IS NOT NULL';
    push @select,   'item_exempt.exempt_amount';
    push @peritem,  'exempt_amount';
    push @peritem_desc, 'Exempt';
    push @total,    'SUM(exempt_amount)';
    push @total_desc, "$money_char%.2f tax-exempt";

  } elsif ( $cgi->param('taxable') ) {

    my $taxable = 'cust_bill_pkg.setup + cust_bill_pkg.recur '.
                  '- COALESCE(item_exempt.exempt_amount, 0)';

    push @where,    'item_tax.invnum IS NOT NULL';
    push @select,   "($taxable) AS taxable_amount";
    push @peritem,  'taxable_amount';
    push @peritem_desc, 'Taxable';
    push @total,    "SUM($taxable)";
    push @total_desc, "$money_char%.2f taxable";

  } elsif ( $cgi->param('out') ) {
  
    push @where,    'item_tax.invnum IS NULL',
                    'item_exempt.billpkgnum IS NULL';

  } elsif ( @tax_where ) {

    # union of taxable + all exempt_ cases
    push @where,
      '(item_tax.invnum IS NOT NULL OR item_exempt.billpkgnum IS NOT NULL)';

  }

  # recur/usage separation
  if ( $cgi->param('usage') eq 'recurring' ) {

    my $recur_no_usage = FS::cust_bill_pkg->charged_sql('', '', no_usage => 1);
    push @select, "($recur_no_usage) AS recur_no_usage";
    $peritem[1] = 'recur_no_usage';
    $total[1] = "SUM(cust_bill_pkg.setup + $recur_no_usage)";
    $total_desc[0] .= ' (excluding usage)';

  } elsif ( $cgi->param('usage') eq 'usage' ) {

    my $usage = FS::cust_bill_pkg->usage_sql();
    push @select, "($usage) AS _usage";
    # there's already a method named 'usage'
    $peritem[1] = '_usage';
    $peritem_desc[1] = 'Usage charge';
    $total[1] = "SUM($usage)";
    $total_desc[0] .= ' usage charges';
  }

} elsif ( $cgi->param('istax') ) {

  @peritem = ( 'setup' ); # taxes only have setup
  @peritem_desc = ( 'Tax charge' );

  push @where, 'cust_bill_pkg.pkgnum = 0';

  # tax location when using tax_rate_location
  if ( $cgi->param('vendortax') ) {

    $join_pkg .= ' LEFT JOIN cust_bill_pkg_tax_rate_location USING ( billpkgnum ) '.
                 ' LEFT JOIN tax_rate_location USING ( taxratelocationnum )';
    foreach (qw( state county city locationtaxid)) {
      if ( scalar($cgi->param($_)) ) {
        my $place = dbh->quote( $cgi->param($_) );
        push @where, "tax_rate_location.$_ = $place";
      }
    }

    $total[1] = 'SUM(
      COALESCE(cust_bill_pkg_tax_rate_location.amount, 
               cust_bill_pkg.setup + cust_bill_pkg.recur)
    )';

  } elsif ( $cgi->param('out') ) {

    $join_pkg .= '
      LEFT JOIN cust_bill_pkg_tax_location USING (billpkgnum)
    ';
    push @where, 'cust_bill_pkg_tax_location.billpkgnum IS NULL';

    # each billpkgnum should appear only once
    $total[0] = 'COUNT(*)';
    $total[1] = 'SUM(cust_bill_pkg.setup)';

  } else { # not locationtaxid or 'out'--the normal case

    $join_pkg .= '
      LEFT JOIN cust_bill_pkg_tax_location USING (billpkgnum)
      JOIN cust_main_county           USING (taxnum)
    ';

    # don't double-count the components of consolidated taxes
    $total[0] = 'COUNT(DISTINCT cust_bill_pkg.billpkgnum)';
    $total[1] = 'SUM(cust_bill_pkg_tax_location.amount)';
  }

  # taxclass
  if ( $cgi->param('taxclassNULL') ) {
    push @where, 'cust_main_county.taxclass IS NULL';
  }

  # taxname
  if ( $cgi->param('taxnameNULL') ) {
    push @where, 'cust_main_county.taxname IS NULL OR '.
                 'cust_main_county.taxname = \'Tax\'';
  } elsif ( $cgi->param('taxname') ) {
    push @where, 'cust_main_county.taxname = '.
                  dbh->quote($cgi->param('taxname'));
  }

  # specific taxnums
  if ( $cgi->param('taxnum') ) {
    my $taxnum_in = join(',', 
      grep /^\d+$/, $cgi->param('taxnum')
    );
    push @where, "cust_main_county.taxnum IN ($taxnum_in)"
      if $taxnum_in;
  }

  # report group (itemdesc)
  if ( $cgi->param('report_group') =~ /^(=|!=) (.*)$/ ) {
    my ( $group_op, $group_value ) = ( $1, $2 );
    if ( $group_op eq '=' ) {
      #push @where, 'itemdesc LIKE '. dbh->quote($group_value.'%');
      push @where, 'itemdesc = '. dbh->quote($group_value);
    } elsif ( $group_op eq '!=' ) {
      push @where, '( itemdesc != '. dbh->quote($group_value) .' OR itemdesc IS NULL )';
    } else {
      die "guru meditation #00de: group_op $group_op\n";
    }
  }

  # itemdesc, for breakdown from the vendor tax report
  if ( $cgi->param('itemdesc') ) {
    if ( $cgi->param('itemdesc') eq 'Tax' ) {
      push @where, "($itemdesc = 'Tax' OR $itemdesc is null)";
    } else {
      push @where, "$itemdesc = ". dbh->quote($cgi->param('itemdesc'));
    }
  }

} # nottax / istax


#total payments
my $pay_sub = "SELECT SUM(cust_bill_pay_pkg.amount)
                 FROM cust_bill_pay_pkg
                   WHERE cust_bill_pkg.billpkgnum = cust_bill_pay_pkg.billpkgnum
              ";
push @select, "($pay_sub) AS pay_amount";


# credit
if ( $cgi->param('credit') ) {

  my $credit_sub;

  if ( $cgi->param('istax') ) {
    # then we need to group/join by billpkgtaxlocationnum, to get only the 
    # relevant part of partial taxes
    my $credit_sub = "SELECT SUM(cust_credit_bill_pkg.amount) AS credit_amount,
      reason.reason as reason_text, access_user.username AS username_text,
      billpkgtaxlocationnum, billpkgnum
    FROM cust_credit_bill_pkg
      JOIN cust_credit_bill USING (creditbillnum)
      JOIN cust_credit USING (crednum)
      LEFT JOIN reason USING (reasonnum)
      LEFT JOIN access_user USING (usernum)
    GROUP BY billpkgnum, billpkgtaxlocationnum, reason.reason, 
      access_user.username";

    if ( $cgi->param('out') ) {

      # find credits that are applied to the line items, but not to 
      # a cust_bill_pkg_tax_location link
      $join_pkg .= " LEFT JOIN ($credit_sub) AS item_credit
        USING (billpkgnum)";
      push @where, 'item_credit.billpkgtaxlocationnum IS NULL';

    } else {

      # find credits that are applied to the CBPTL links that are 
      # considered "interesting" by the report criteria
      $join_pkg .= " LEFT JOIN ($credit_sub) AS item_credit
        USING (billpkgtaxlocationnum)";

    }

  } else {
    # then only group by billpkgnum
    my $credit_sub = "SELECT SUM(cust_credit_bill_pkg.amount) AS credit_amount,
      reason.reason as reason_text, access_user.username AS username_text,
      billpkgnum
    FROM cust_credit_bill_pkg
      JOIN cust_credit_bill USING (creditbillnum)
      JOIN cust_credit USING (crednum)
      LEFT JOIN reason USING (reasonnum)
      LEFT JOIN access_user USING (usernum)
    GROUP BY billpkgnum, reason.reason, access_user.username";
    $join_pkg .= " LEFT JOIN ($credit_sub) AS item_credit USING (billpkgnum)";
  }

  push @where,    'item_credit.billpkgnum IS NOT NULL';
  push @select,   'item_credit.credit_amount',
                  'item_credit.username_text',
                  'item_credit.reason_text';
  push @peritem,  'credit_amount', 'username_text', 'reason_text';
  push @peritem_desc, 'Credited', 'By', 'Reason';
  push @total,    'SUM(credit_amount)';
  push @total_desc, "$money_char%.2f credited";

} else {

  #still want a credit total column

  my $credit_sub = "
    SELECT SUM(cust_credit_bill_pkg.amount)
      FROM cust_credit_bill_pkg
        WHERE cust_bill_pkg.billpkgnum = cust_credit_bill_pkg.billpkgnum
  ";
  push @select, "($credit_sub) AS credit_amount";

}

push @select, 'cust_main.custnum', FS::UI::Web::cust_sql_fields();

#salesnum
if ( $cgi->param('salesnum') =~ /^(\d+)$/ ) {

  my $salesnum = $1;
  my $sales = FS::sales->by_key($salesnum)
    or die "salesnum $salesnum not found";

  my $subsearch = $sales->cust_bill_pkg_search('', '',
    'cust_main_sales' => ($cgi->param('cust_main_sales') ? 1 : 0),
    'paid'            => ($cgi->param('paid') ? 1 : 0),
    'classnum'        => scalar($cgi->param('classnum'))
  );
  $join_pkg .= " JOIN sales_pkg_class ON ( COALESCE(sales_pkg_class.classnum, 0) = COALESCE( part_fee.classnum, part_pkg.classnum, 0) )";

  my $extra_sql = $subsearch->{extra_sql};
  $extra_sql =~ s/^WHERE//;
  push @where, $extra_sql;

  $cgi->param('classnum', 0) unless $cgi->param('classnum');
}


my $where = join(' AND ', @where);
$where &&= "WHERE $where";

my $query = {
  'table'     => 'cust_bill_pkg',
  'addl_from' => "$join_pkg $join_cust",
  'hashref'   => {},
  'select'    => join(",\n", @select ),
  'extra_sql' => $where,
  'order_by'  => 'ORDER BY cust_bill._date, cust_bill_pkg.billpkgnum',
};

my $count_query =
  'SELECT ' . join(',', @total) .
  " FROM cust_bill_pkg $join_pkg $join_cust
  $where";

@peritem_desc = map {emt($_)} @peritem_desc;
my @peritem_sub = map {
  my $field = $_;
  if ($field =~ /_text$/) { # kludge for credit reason/username fields
    sub {$_[0]->get($field)};
  } else {
    sub { sprintf($money_char.'%.2f', $_[0]->get($field)) }
  }
} @peritem;
my @peritem_null = map { '' } @peritem; # placeholders
my $peritem_align = 'r' x scalar(@peritem);

my $ilink = [ "${p}view/cust_bill.cgi?", 'invnum' ];
my $clink = [ "${p}view/cust_main.cgi?", 'custnum' ];

my $pay_link    = ''; #[, 'billpkgnum', ];
my $credit_link = [ "${p}search/cust_credit_bill_pkg.html?billpkgnum=", 'billpkgnum', ];

warn "\n\nQUERY:\n".Dumper($query)."\n\nCOUNT_QUERY:\n$count_query\n\n"
  if $cgi->param('debug');

</%init>
