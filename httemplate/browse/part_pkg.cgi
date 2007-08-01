<% include( 'elements/browse.html',
                 'title'              => 'Package Definitions',
                 'menubar'            => [ 'Main Menu' => $p ],
                 'html_init'          => $html_init,
                 'name'               => 'package definitions',
                 'disableable'        => 1,
                 'disabled_statuspos' => 3,
                 'query'              => { 'select'    => $select,
                                           'table'     => 'part_pkg',
                                           'hashref'   => {},
                                           'extra_sql' => "ORDER BY $orderby",
                                         },
                 'count_query'        => $count_query,
                 'header'             => \@header,
                 'fields'             => \@fields,
                 'links'              => \@links,
                 'align'              => $align,
             )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $select = '*';
my $orderby = 'pkgpart';
if ( $cgi->param('active') ) {

  $orderby = 'num_active DESC';
}
  $select = "

    *,

    ( SELECT COUNT(*) FROM cust_pkg WHERE cust_pkg.pkgpart = part_pkg.pkgpart
       AND ( cancel IS NULL OR cancel = 0 )
       AND ( susp IS NULL OR susp = 0 )
    ) AS num_active,

    ( SELECT COUNT(*) FROM cust_pkg WHERE cust_pkg.pkgpart = part_pkg.pkgpart
        AND ( cancel IS NULL OR cancel = 0 )
        AND susp IS NOT NULL AND susp != 0
    ) AS num_suspended,

    ( SELECT COUNT(*) FROM cust_pkg WHERE cust_pkg.pkgpart = part_pkg.pkgpart
        AND cancel IS NOT NULL AND cancel != 0
    ) AS num_cancelled

  ";

#}

my $conf = new FS::Conf;
my $taxclasses = $conf->exists('enable_taxclasses');

my $html_init;
#unless ( $cgi->param('active') ) {
  $html_init = qq!
    One or more service definitions are grouped together into a package 
    definition and given pricing information.  Customers purchase packages
    rather than purchase services directly.<BR><BR>
    <A HREF="${p}edit/part_pkg.cgi"><I>Add a new package definition</I></A>
    <BR><BR>
  !;
#}

# ------

my $link = [ $p.'edit/part_pkg.cgi?', 'pkgpart' ];

my @header = ( '#', 'Package', 'Comment' );
my @fields = ( 'pkgpart', 'pkg', 'comment' );
my $align = 'rll';
my @links = ( $link, $link, '' );

unless ( 0 ) { #already showing only one class or something?
  push @header, 'Class';
  push @fields, sub { shift->classname || '(none)'; };
  $align .= 'l';
}

#if ( $cgi->param('active') ) {
  push @header, 'Customer<BR>packages';
  my %col = (
    'active'          => '00CC00',
    'suspended'       => 'FF9900',
    'cancelled'       => 'FF0000',
    #'one-time charge' => '000000',
    'charge'          => '000000',
  );
  my $cust_pkg_link = $p. 'search/cust_pkg.cgi?pkgpart=';
  push @fields, sub { my $part_pkg = shift;
                      [
                        map {
                              my $magic = $_;
                              my $label = $_;
                              if ( $magic eq 'active' && $part_pkg->freq == 0 ) {
                                $magic = 'inactive';
                                #$label = 'one-time charge',
                                $label = 'charge',
                              }
                          
                              [
                                {
                                 'data'  => '<B><FONT COLOR="#'. $col{$label}. '">'.
                                            $part_pkg->get("num_$_").
                                            '</FONT></B>',
                                 'align' => 'right',
                                },
                                {
                                 'data'  => $label.
                                              ( $part_pkg->get("num_$_") != 1
                                                && $label =~ /charge$/
                                                  ? 's'
                                                  : ''
                                              ),
                                 'align' => 'left',
                                 'link'  => ( $part_pkg->get("num_$_")
                                                ? $cust_pkg_link.
                                                  $part_pkg->pkgpart.
                                                  ";magic=$magic"
                                                : ''
                                            ),
                                },
                              ],
                            } (qw( active suspended cancelled ))
                      ]; };
  $align .= 'r';
#}

push @header, 'Frequency';
push @fields, sub { shift->freq_pretty; };
$align .= 'l';

if ( $taxclasses ) {
  push @header, 'Taxclass';
  push @fields, sub { shift->taxclass() || '&nbsp;'; };
  $align .= 'l';
}

push @header, 'Plan',
              'Data',
              'Services';
              #'Service', 'Quan', 'Primary';

push @fields, sub { shift->plan || '(legacy)' }, 

              sub {
                    my $part_pkg = shift;
                    if ( $part_pkg->plan ) {

                      [ map { 
                              /^(\w+)=(.*)$/; #or something;
                              [
                                { 'data'  => $1,
                                  'align' => 'right',
                                },
                                { 'data'  => $part_pkg->format($1,$2),
                                  'align' => 'left',
                                },
                              ];
                            }
                        split(/\n/, $part_pkg->plandata)
                      ];

                    } else {

                      [ map { [
                                { 'data'  => uc($_),
                                  'align' => 'right',
                                },
                                {
                                  'data'  => $part_pkg->$_(),
                                  'align' => 'left',
                                },
                              ];
                            }
                        (qw(setup recur))
                      ];

                    }

                  },

              sub {
                    my $part_pkg = shift;

                    [ map  {
                             my $pkg_svc = $_;
                             my $part_svc = $pkg_svc->part_svc;
                             my $svc = $part_svc->svc;
                             if ( $pkg_svc->primary_svc =~ /^Y/i ) {
                               $svc = "<B>$svc (PRIMARY)</B>";
                             }
                             $svc =~ s/ +/&nbsp;/g;

                             [
                               {
                                 'data'  => '<B>'. $pkg_svc->quantity. '</B>',
                                 'align' => 'right'
                               },
                               {
                                 'data'  => $svc,
                                 'align' => 'left',
                                 'link'  => $p. 'edit/part_svc.cgi?'.
                                            $part_svc->svcpart,
                               },
                             ];
                           }
                      sort {     $b->primary_svc =~ /^Y/i
                             <=> $a->primary_svc =~ /^Y/i
                           }
                           $part_pkg->pkg_svc

                    ];

                  };

$align .= 'lrl'; #rr';

# --------

my $count_query = 'SELECT COUNT(*) FROM part_pkg';

</%init>
