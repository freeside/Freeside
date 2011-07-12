<% include( 'elements/edit.html',
              'post_url'              => popurl(1).'process/part_pkg.cgi',
              'name'                  => "Package definition",
              'table'                 => 'part_pkg',

              'agent_virt'            => 1,
              'agent_null_right'      => $edit_global,
              'agent_clone_extra_sql' => $agent_clone_extra_sql,
              #'viewall_dir'           => 'browse',
              'viewall_url'           => $p.'browse/part_pkg.cgi',
              'html_init'             => include('/elements/init_overlib.html').
                                         $javascript,
              'html_bottom'           => $html_bottom,
              'body_etc'              =>
                'onLoad="agent_changed(document.edit_topform.agentnum)"',

              'begin_callback'        => $begin_callback,
              'end_callback'          => $end_callback,
              'new_hashref_callback'  => $new_hashref_callback,
              'new_object_callback'   => $new_object_callback,
              'new_callback'          => $new_callback,
              'clone_callback'        => $clone_callback,
              'edit_callback'         => $edit_callback,
              'error_callback'        => $error_callback,
              'field_callback'        => $field_callback,

              'labels' => { 
                            'pkgpart'          => 'Package Definition',
                            'pkg'              => 'Package (customer-visible)',
                            'comment'          => 'Comment (customer-hidden)',
                            'classnum'         => 'Package class',
                            'addon_classnum'   => 'Restrict additional orders to package class',
                            'promo_code'       => 'Promotional code',
                            'freq'             => 'Recurring fee frequency',
                            'setuptax'         => 'Setup fee tax exempt',
                            'recurtax'         => 'Recurring fee tax exempt',
                            'taxclass'         => 'Tax class',
                            'taxproduct_select'=> 'Tax products',
                            'plan'             => 'Price plan',
                            'disabled'         => 'Disable new orders',
                            'disable_line_item_date_ranges' => 'Disable line item date ranges',
                            'setup_cost'       => 'Setup cost',
                            'recur_cost'       => 'Recur cost',
                            'pay_weight'       => 'Payment weight',
                            'credit_weight'    => 'Credit weight',
                            'agentnum'         => 'Agent',
                            'setup_fee'        => 'Setup fee',
                            'setup_show_zero'  => 'Show zero setup',
                            'recur_fee'        => 'Recurring fee',
                            'recur_show_zero'  => 'Show zero recurring',
                            'discountnum'      => 'Offer discounts for longer terms',
                            'bill_dst_pkgpart' => 'Include line item(s) from package',
                            'svc_dst_pkgpart'  => 'Include services of package',
                            'report_option'    => 'Report classes',
                            'fcc_ds0s'         => 'Voice-grade equivalents',
                          },

              'fields' => [
                            { field=>'clone',  type=>'hidden',
                              curr_value_callback =>
                                sub { shift->param('clone') },
                            },
                            { field=>'pkgnum', type=>'hidden',
                              curr_value_callback =>
                                sub { shift->param('pkgnum') },
                            },

                            { field=>'custom',  type=>'hidden' },

                            { type => 'columnstart' },
                            
                              { field     => 'pkg',
                                type      => 'text',
                                size      => 40, #32
                                maxlength => 50,
                              },
                              {field=>'comment',  type=>'text', size=>40 }, #32
                              { field         => 'agentnum',
                                type          => 'select-agent',
                                disable_empty => ! $acl_edit_global,
                                empty_label   => '(global)',
                                onchange      => 'agent_changed',
                              },
                              {field=>'classnum', type=>'select-pkg_class' },
                              ( $conf->exists('pkg-addon_classnum')
                                  ? ( { field=>'addon_classnum',
                                        type =>'select-pkg_class',
                                      }
                                    )
                                   : ()
                              ),
                              {field=>'disabled', type=>$disabled_type, value=>'Y'},
                              {field=>'disable_line_item_date_ranges', type=>$disabled_type, value=>'Y'},

                              { type     => 'tablebreak-tr-title',
                                value    => 'Pricing', #better name?
                              },
                              { field    => 'plan',
                                type     => 'selectlayers-select',
                                options  => [ keys %plan_labels ],
                                labels   => \%plan_labels,
                                onchange => 'aux_planchanged(what);',
                              },
                              { field    => 'setup_fee',
                                type     => 'money',
                                onchange => 'setup_changed',
                              },
                              { field    => 'setup_show_zero',
                                type     => 'checkbox',
                                value    => 'Y',
                                disabled => sub { $setup_show_zero_disabled },
                              },
                              { field    => 'freq',
                                type     => 'part_pkg_freq',
                                onchange => 'freq_changed',
                              },
                              { field    => 'recur_fee',
                                type     => 'money',
                                disabled => sub { $recur_disabled },
                                onchange => 'recur_changed',
                              },

                              { field    => 'recur_show_zero',
                                type     => 'checkbox',
                                value    => 'Y',
                                disabled => sub { $recur_show_zero_disabled },
                              },

                              #price plan
                              #setup fee
                              #recurring frequency
                              #recurring fee (auto-disable)

                            { type => 'columnnext' },

                              {type=>'justtitle', value=>'Taxation' },
                              {field=>'setuptax', type=>'checkbox', value=>'Y'},
                              {field=>'recurtax', type=>'checkbox', value=>'Y'},
                              {field=>'taxclass', type=>'select-taxclass' },
                              { field => 'taxproductnums',
                                type  => 'hidden',
                                value => join(',', @taxproductnums),
                              },
                              { field => 'taxproduct_select',
                                type  => 'selectlayers',
                                options => [ '(default)', @taxproductnums ],
                                curr_value => '(default)',
                                labels  => { ( '(default)' => '(default)' ),
                                             map {($_=>$usage_class{$_})}
                                             @taxproductnums
                                           },
                                layer_fields => \%taxproduct_fields,
                                layer_values_callback => $taxproduct_values,
                                layers_only  =>   !$taxproducts,
                                cell_style   => ( !$taxproducts
                                                  ? 'display:none'
                                                  : ''
                                                ),
                              },

                              { type  => 'tablebreak-tr-title',
                                value => 'Promotions', #better name?
                              },
                              { field=>'promo_code', type=>'text', size=>15 },

                              { type  => 'tablebreak-tr-title',
                                value => 'Cost tracking', #better name?
                              },
                              { field=>'setup_cost', type=>'money', },
                              { field=>'recur_cost', type=>'money', },

                            { type => 'columnnext' },

                              { field    => 'agent_type',
                                type     => 'select-agent_types',
                                disabled => ! $acl_edit_global,
                                curr_value_callback => sub {
                                  my($cgi, $object, $field) = @_;
                                  #in the other callbacks..?  hmm.
                                  \@agent_type;
                                },
                              },

                              { type  => 'tablebreak-tr-title',
                                value => 'Line-item revenue recogition', #better name?
                              },
                              { field=>'pay_weight',    type=>'text', size=>6 },
                              { field=>'credit_weight', type=>'text', size=>6 },

                              ( $conf->exists('cust_pkg-show_fcc_voice_grade_equivalent')
                                ? ( 
                                    { type  => 'tablebreak-tr-title',
                                      value => 'FCC Form 477 information',
                                    },
                                    { field=>'fcc_ds0s', type=>'text', size=>6 },
                                  )
                                 : ()
                              ),


                            { type => 'columnend' },

                            { 'type'  => $report_option ? 'tablebreak-tr-title'
                                                        : 'hidden',
                              'value' => 'Optional report classes',
                              'field' => 'census_title',
                            },
                            { 'field'    => 'report_option',
                              'type'     => $report_option ? 'select-table'
                                                           : 'hidden',
                              'table'    => 'part_pkg_report_option',
                              'name_col' => 'name',
                              'hashref'  => { 'disabled' => '' },
                              'multiple' => 1,
                            },

                            { 'type'    => 'tablebreak-tr-title',
                              'value'   => 'Term discounts',
                            },
                            { 'field'      => 'discountnum',
                              'type'       => 'select-table',
                              'table'      => 'discount',
                              'name_col'   => 'name',
                              'hashref'    => { %$discountnum_hashref },
                              #'extra_sql'  => 'AND (months IS NOT NULL OR months != 0)',
                              'empty_label'=> 'Select discount',
                              'm2_label'   => 'Offer discounts for longer terms',
                              'm2m_method' => 'part_pkg_discount',
                              'm2m_dstcol' => 'discountnum',
                              'm2_error_callback' => $discount_error_callback,
                            },

                            { 'type'    => 'tablebreak-tr-title',
                              'value'   => 'Pricing add-ons',
                              'colspan' => 4,
                            },
                            { 'field'      => 'bill_dst_pkgpart',
                              'type'       => 'select-part_pkg',
                              'extra_sql'  => sub { $pkgpart
                                                     ? "AND pkgpart != $pkgpart"
                                                     : ''
                                                  },
                              'm2_label'   => 'Include line item(s) from package',
                              'm2m_method' => 'bill_part_pkg_link',
                              'm2m_dstcol' => 'dst_pkgpart',
                              'm2_error_callback' =>
                                &{$m2_error_callback_maker}('bill'),
                              'm2_fields' => [ { 'field' => 'hidden',
                                                 'type'  => 'checkbox',
                                                 'value' => 'Y',
                                                 'curr_value' => '',
                                                 'label' => 'Bundle',
                                               },
                                             ],
                            },

                            { type  => 'tablebreak-tr-title',
                              value => 'Services',
                            },
                            { type => 'pkg_svc', },

                            { 'field'      => 'svc_dst_pkgpart',
                              'label'      => 'Also include services from package: ',
                              'type'       => 'select-part_pkg',
                              'extra_sql'  => sub { $pkgpart
                                                     ? "AND pkgpart != $pkgpart"
                                                     : ''
                                                  },
                              'm2_label'   => 'Include services of package: ',
                              'm2m_method' => 'svc_part_pkg_link',
                              'm2m_dstcol' => 'dst_pkgpart',
                              'm2_error_callback' =>
                                &{$m2_error_callback_maker}('svc'),
                            },

                            { type  => 'tablebreak-tr-title',
                              value => 'Price plan options',
                            },

                          ],

           )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

my $edit_global = 'Edit global package definitions';
my $acl_edit        = $curuser->access_right('Edit package definitions');
my $acl_edit_global = $curuser->access_right($edit_global);

my $acl_edit_either = $acl_edit || $acl_edit_global;

my $begin_callback = sub {
  my( $cgi, $fields, $opt ) = @_;
  die "access denied"
    unless $acl_edit_either
        || ( $cgi->param('pkgnum')
             && $curuser->access_right('Customize customer package')
           );
};

my $disabled_type = $acl_edit_either ? 'checkbox' : 'hidden';

#arg.  access rights for cloning are Hard.
# on the one hand we don't really want cloning (customizing a package) to fail 
#  for want of finding the source package in normal usage
# on the other hand, we don't want people using the clone link to be able to
#  see 
my $agent_clone_extra_sql = 
  ' ( '. FS::part_pkg->curuser_pkgs_sql.
  "   OR ( part_pkg.custom = 'Y' ) ".
  ' ) ';

my $conf = new FS::Conf;
my $taxproducts = $conf->exists('enable_taxproducts');

my $sth = dbh->prepare("SELECT COUNT(*) FROM part_pkg_report_option".
                       "  WHERE disabled IS NULL OR disabled = ''  ")
  or die dbh->errstr;
$sth->execute or die $sth->errstr;
my $report_option = $sth->fetchrow_arrayref->[0];

#XXX
# - tr-part_pkg_freq: month_increments_only (from price plans)
# - test cloning
# - test errors cloning
# - test custom pricing
# - move the selectlayer divs away from lame layer_callback

#my ($query) = $cgi->keywords;
#
#my $part_pkg = '';

my @agent_type = ();
my %tax_override = ();

my %taxproductnums = map { ($_->classnum => 1) }
                     qsearch('usage_class', { 'disabled' => '' });
my @taxproductnums = ( qw( setup recur ), sort (keys %taxproductnums) );

my %options = ();
my $recur_disabled = 1;
my $setup_show_zero_disabled = 0;
my $recur_show_zero_disabled = 1;

my $pkgpart = '';

my $error_callback = sub {
  my($cgi, $object, $fields, $opt ) = @_;

  (@agent_type) = $cgi->param('agent_type');

  $opt->{action} = 'Custom' if $cgi->param('pkgnum');

  $setup_show_zero_disabled = ($cgi->param('setup_fee') > 0) ? 1 : 0;

  $recur_disabled = $cgi->param('freq') ? 0 : 1;
  $recur_show_zero_disabled =
    $cgi->param('freq')
      ? $cgi->param('recur_fee') > 0 ? 1 : 0
      : 1;

  foreach ($cgi->param) {
    /^usage_taxproductnum_(\d+)$/ && ($taxproductnums{$1} = 1);
  }
  $tax_override{''} = $cgi->param('tax_override');
  $tax_override{$_} = $cgi->param('tax_override_$_')
    foreach(grep { /^tax_override_(\w+)$/ } $cgi->param);

  #some false laziness w/process
  $cgi->param('plan') =~ /^(\w+)$/ or die 'unparsable plan';
  my $plan = $1;
  my $options = $cgi->param($plan."__OPTIONS");
  my @options = split(',', $options);
  %options =
    map { my $optionname = $_;
          my $param = $plan."__$optionname";
          my $value = join(', ', $cgi->param($param));
          ( $optionname => $value );
        }
        @options;

  $object->set($_ => scalar($cgi->param($_)) )
    foreach (qw( setup_fee recur_fee disable_line_item_date_ranges ));

  $pkgpart = $object->pkgpart;

};

my $new_hashref_callback = sub { { 'plan' => 'flat' }; };

my $new_object_callback = sub {
  my( $cgi, $hashref, $fields, $opt ) = @_;

  my $part_pkg = FS::part_pkg->new( $hashref );
  $part_pkg->set($_ => '0')
    foreach (qw( setup_fee recur_fee disable_line_item_date_ranges ));

  $part_pkg;

};

my $edit_callback = sub {
  my( $cgi, $object, $fields, $opt ) = @_;

  $setup_show_zero_disabled = ($object->option('setup_fee') > 0) ? 1 : 0;

  $recur_disabled = $object->freq ? 0 : 1;

  $recur_show_zero_disabled =
    $object->freq
      ? $object->option('recur_fee') > 0 ? 1 : 0
      : 1;

  (@agent_type) =
    map {$_->typenum} qsearch('type_pkgs', { 'pkgpart' => $object->pkgpart } );

  my @report_option = ();
  foreach ($object->options) {
    /^usage_taxproductnum_(\d+)$/ && ($taxproductnums{$1} = 1);
    /^report_option_(\d+)$/ && (push @report_option, $1);
  }
  foreach ($object->part_pkg_taxoverride) {
    $taxproductnums{$_->usage_class} = 1
      if $_->usage_class;
  }

  $cgi->param('report_option', join(',', @report_option));
  foreach my $field ( @$fields ) {
    next unless ( 
      ref($field) eq 'HASH' &&
      $field->{field} &&
      $field->{field} eq 'report_option'
    );
    #$field->{curr_value} = join(',', @report_option);
    $field->{value} = join(',', @report_option);
  }

  %options = $object->options;

  $object->set($_ => $object->option($_, 1))
    foreach (qw( setup_fee recur_fee disable_line_item_date_ranges ));

  $pkgpart = $object->pkgpart;

};

my $new_callback = sub {
  my( $cgi, $object, $fields ) = @_;

  my $conf = new FS::Conf; 

  if ( $conf->exists('agent_defaultpkg') ) {
    #my @all_agent_types = map {$_->typenum} qsearch('agent_type',{});
    @agent_type = map {$_->typenum} qsearch('agent_type',{});
  }

  $options{'suspend_bill'}=1 if $conf->exists('part_pkg-default_suspend_bill');

};

my $clone_callback = sub {
  my( $cgi, $object, $fields, $opt ) = @_;

  if ( $cgi->param('pkgnum') ) {

    my $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $cgi->param('pkgnum') } );
    $object->agentnum( $cust_pkg->cust_main->agentnum );

    $opt->{action} = 'Custom';

    #my $part_pkg = $clone_part_pkg->clone;
    #this is all clone does anyway
    $object->custom('Y');

    $object->disabled('Y');

  } else { #not when cloning...

    (@agent_type) =
      map {$_->typenum} qsearch('type_pkgs',{ 'pkgpart' => $object->pkgpart } );

  }

  %options = $object->options;

  $object->set($_ => $options{$_})
    foreach (qw( setup_fee recur_fee disable_line_item_date_ranges ));

  $recur_disabled = $object->freq ? 0 : 1;
};

my $discount_error_callback = sub {
  my( $cgi, $object ) = @_;
  map {
        if ( /^discountnum(\d+)$/ &&
             ( my $discountnum = $cgi->param("discountnum$1") ) )
        {
          new FS::part_pkg_discount {
            'pkgpart'     => $object->pkgpart,
            'discountnum' => $discountnum,
          };
        } else {
          ();
        }
      }
  $cgi->param;
};

my $m2_error_callback_maker = sub {
  my $link_type = shift; #yay closures
  return sub {
    my( $cgi, $object ) = @_;
    map {

          if ( /^${link_type}_dst_pkgpart(\d+)$/ &&
               ( my $dst = $cgi->param("${link_type}_dst_pkgpart$1") ) )
          {

            my $hidden = $cgi->param("${link_type}_dst_pkgpart__hidden$1")
                         || '';
            new FS::part_pkg_link {
              'link_type'   => $link_type,
              'src_pkgpart' => $object->pkgpart,
              'dst_pkgpart' => $dst,
              'hidden'      => $hidden,
            };
          } else {
            ();
          }
        }
    $cgi->param;
  };
};

my $javascript = <<'END';
  <SCRIPT TYPE="text/javascript">

    function freq_changed(what) {
      var freq = what.options[what.selectedIndex].value;

      if ( freq == '0' ) {
        what.form.recur_fee.disabled = true;
        what.form.recur_fee.style.backgroundColor = '#dddddd';
        what.form.recur_show_zero.disabled = true;
        //what.form.recur_show_zero.style.backgroundColor= '#dddddd';
      } else {
        what.form.recur_fee.disabled = false;
        what.form.recur_fee.style.backgroundColor = '#ffffff';
        recur_changed( what.form.recur_fee );
        //what.form.recur_show_zero.style.backgroundColor= '#ffffff';
      }

    }

    function setup_changed(what) {
      var setup = what.value;
      if ( parseFloat(setup) == 0 ) {
        what.form.setup_show_zero.disabled = false;
      } else {
        what.form.setup_show_zero.disabled = true;
      }
    }

    function recur_changed(what) {
      var recur = what.value;
      if ( parseFloat(recur) == 0 ) {
        what.form.recur_show_zero.disabled = false;
      } else {
        what.form.recur_show_zero.disabled = true;
      }
    }

    function agent_changed(what) {

      var agentnum;
      if ( what.type == 'select-one' ) {
        agentnum = what.options[what.selectedIndex].value;
      } else {
        agentnum = what.value;
      }

      if ( agentnum == 0 ) {
        what.form.agent_type.disabled = false;
        //what.form.agent_type.style.backgroundColor = '#ffffff';
        what.form.agent_type.style.visibility = '';
      } else {
        what.form.agent_type.disabled = true;
        //what.form.agent_type.style.backgroundColor = '#dddddd';
        what.form.agent_type.style.visibility = 'hidden';
      }

    }

    function aux_planchanged(what) {

      alert('called!');
      var plan = what.options[what.selectedIndex].value;
      var table = document.getElementById('TableNumber7') // XXX NOT ROBUST

      if ( plan == 'flat' || plan == 'prorate' || plan == 'subscription' ) {
        //table.disabled = false;
        table.style.visibility = '';
      } else {
        //table.disabled = true;
        table.style.visibility = 'hidden';
      }

    }

  </SCRIPT>
END

tie my %plans, 'Tie::IxHash', %{ FS::part_pkg::plan_info() };

tie my %plan_labels, 'Tie::IxHash',
  map {  $_ => ( $plans{$_}->{'shortname'} || $plans{$_}->{'name'} ) }
      keys %plans;

my $html_bottom = sub {
  my( $object ) = @_;

  #warn join("\n", map { "$_: $options{$_}" } keys %options ). "\n";

  my $layer_callback = sub {
  
    my $layer = shift;
    my $html = ntable("#cccccc",2);
  
    #$html .= '
    #  <TR>
    #    <TD ALIGN="right">Recurring fee frequency </TD>
    #    <TD><SELECT NAME="freq">
    #';
    #
    #my @freq = keys %freq;
    #@freq = grep { /^\d+$/ } @freq
  #XXX this bit#  #  if exists($plans{$layer}->{'freq'}) && $plans{$layer}->{'freq'} eq 'm';
    #foreach my $freq ( @freq ) {
    #  $html .= qq(<OPTION VALUE="$freq");
    #  $html .= ' SELECTED' if $freq eq $part_pkg->freq;
    #  $html .= ">$freq{$freq}";
    #}

   #$html .= '</SELECT></TD></TR>';
  
    my $href = $plans{$layer}->{'fields'};
    my @fields = exists($plans{$layer}->{'fieldorder'})
                   ? @{$plans{$layer}->{'fieldorder'}}
                   : keys %{ $href };
  
    foreach my $field ( grep $_ !~ /^(setup|recur)_fee$/, @fields ) {
  
       if(!exists($href->{$field})) {
        # shouldn't happen
        warn "nonexistent part_pkg option: '$field'\n";
        next;
      }

      $html .= '<TR><TD ALIGN="right">'. $href->{$field}{'name'}. '</TD><TD>';
  
      my $format = sub { shift };
      $format = $href->{$field}{'format'} if exists($href->{$field}{'format'});

      #XXX these should use elements/ fields... (or this whole thing should
      #just use layer_fields instead of layer_callback)
  
      if ( ! exists($href->{$field}{'type'}) ) {
  
        $html .= qq!<INPUT TYPE="text" NAME="${layer}__$field" VALUE="!.
                 ( exists($options{$field})
                     ? &$format($options{$field})
                     : $href->{$field}{'default'} ).
                 qq!">!;
  
      } elsif ( $href->{$field}{'type'} eq 'checkbox' ) {
  
        $html .= qq!<INPUT TYPE="checkbox" NAME="${layer}__$field" VALUE=1 !.
                 ( exists($options{$field}) && $options{$field}
                   ? ' CHECKED'
                   : ''
                 ). '>';
  
      } elsif ( $href->{$field}{'type'} =~ /^select/ ) {
  
        $html .= '<SELECT';
        $html .= ' MULTIPLE'
          if $href->{$field}{'type'} eq 'select_multiple';
        $html .= qq! NAME="${layer}__$field">!;

        $html .= '<OPTION VALUE="">'. $href->{$field}{'empty_label'}
          if exists($href->{$field}{'disable_empty'})
               && ! $href->{$field}{'disable_empty'};
  
        if ( $href->{$field}{'select_table'} ) {
          foreach my $record (
            qsearch( $href->{$field}{'select_table'},
                     $href->{$field}{'select_hash'}   )
          ) {
            my $value = $record->getfield($href->{$field}{'select_key'});
            $html .= qq!<OPTION VALUE="$value"!.
                     (  $options{$field} =~ /(^|, *)$value *(,|$)/ #?
                          ? ' SELECTED'
                          : ''
                     ).
                     '>'. $record->getfield($href->{$field}{'select_label'});
          }
        } elsif ( $href->{$field}{'select_options'} ) {
          foreach my $key ( keys %{ $href->{$field}{'select_options'} } ) {
            my $label = $href->{$field}{'select_options'}{$key};
            $html .= qq!<OPTION VALUE="$key"!.
                     ( $options{$field} =~ /(^|, *)$key *(,|$)/ #?
                         ? ' SELECTED'
                         : ''
                     ).
                     '>'. $label;
          }
  
        } else {
          $html .= '<font color="#ff0000">warning: '.
                   "don't know how to retreive options for $field select field".
                   '</font>';
        }
        $html .= '</SELECT>';
  
      } elsif ( $href->{$field}{'type'} eq 'radio' ) {
  
        my $radio =
          qq!<INPUT TYPE="radio" NAME="${layer}__$field"!;
  
        foreach my $key ( keys %{ $href->{$field}{'options'} } ) {
          my $label = $href->{$field}{'options'}{$key};
          $html .= qq!$radio VALUE="$key"!.
                   ( $options{$field} =~ /(^|, *)$key *(,|$)/ #?
                       ? ' CHECKED'
                       : ''
                   ).
                   "> $label<BR>";
        }
  
      }
  
      $html .= '</TD></TR>';
    }
    $html .= '</TABLE>';
  
    $html .= qq(<INPUT TYPE="hidden" NAME="${layer}__OPTIONS" VALUE=").
             join(',', keys %{ $href } ). '">';
  
    $html;
  
  };

  my %selectlayers = (
    field          => 'plan',
    options        => [ keys %plan_labels ],
    labels         => \%plan_labels,
    curr_value     => $object->plan,
    layer_callback => $layer_callback,
  );

  my $return =
    include('/elements/selectlayers.html', %selectlayers, 'layers_only'=>1 ).
    '<SCRIPT TYPE="text/javascript">'.
      include('/elements/selectlayers.html', %selectlayers, 'js_only'=>1 );

  $return .=
    "taxproduct_selectchanged(document.getElementById('taxproduct_select'));\n"
      if $taxproducts;

  $return .= '</SCRIPT>';

  $return;

};

my %usage_class = map { ($_->classnum => $_->classname) }
                  qsearch('usage_class', {});
$usage_class{setup} = 'Setup';
$usage_class{recur} = 'Recurring';

my %taxproduct_fields = ();
my $end_callback = sub {
  my( $cgi, $object, $fields, $opt ) = @_;

  @taxproductnums = ( qw( setup recur ), sort (keys %taxproductnums) );

  if ( $object->pkgpart ) {
    foreach my $usage_class ( '', @taxproductnums ) {
      $tax_override{$usage_class} =
        join (",", map $_->taxclassnum,
                       qsearch( 'part_pkg_taxoverride', {
                                  'pkgpart'     => $object->pkgpart,
                                  'usage_class' => $usage_class,
                              })
             );
    }
  }

  %taxproduct_fields =
    map { $_ => [ "taxproductnum_$_", 
                  { type  => 'select-taxproduct',
                    #label => "$usage_class{$_} tax product",
                  },
                  "tax_override_$_", 
                  { type  => 'select-taxoverride' }
                ]
        }
        @taxproductnums;

  $taxproduct_fields{'(default)'} =
    [ 'taxproductnum', { type => 'select-taxproduct',
                         #label => 'Default tax product',
                       },
      'tax_override',  { type => 'select-taxoverride' },
    ];
};

my $taxproduct_values = sub {
  my ($cgi, $object, $flags) = @_;
  my $routine =
    sub { my $layer = shift;
          my @fields = @{$taxproduct_fields{$layer}};
          my @values = ();
          while( @fields ) {
            my $field = shift @fields;
            shift @fields;
            $field =~ /^taxproductnum_\w+$/ &&
              push @values, ( $field => $options{"usage_$field"} );
            $field =~ /^tax_override_(\w+)$/ &&
              push @values, ( $field => $tax_override{$1} );
            $field =~ /^taxproductnum$/ &&
              push @values, ( $field => $object->taxproductnum );
            $field =~ /^tax_override$/ &&
              push @values, ( $field => $tax_override{''} );
          }
          { (@values) };
        };
  
  my @result = 
    map { ( $_ => { &{$routine}($_) } ) } ( '(default)', @taxproductnums );
  return({ @result });
  
};

my $field_callback = sub {
  my ($cgi, $object, $fieldref) = @_;

  my $field = $fieldref->{field};
  if ($field eq 'taxproductnums') {
    $fieldref->{value} = join(',', @taxproductnums);
  } elsif ($field eq 'taxproduct_select') {
    $fieldref->{options} = [ '(default)', @taxproductnums ];
    $fieldref->{labels}  = { ( '(default)' => '(default)' ),
                             map {( $_ => ($usage_class{$_} || $_) )}
                               @taxproductnums
                           };
    $fieldref->{layer_fields} = \%taxproduct_fields;
    $fieldref->{layer_values_callback} = $taxproduct_values;
  }
};

my $discountnum_hashref = {
                            'disabled' => '',
                            'months' => { 'op' => '>', 'value' => 1 },
                          };

</%init>
