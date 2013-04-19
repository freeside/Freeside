% if ( $sub eq 'smart_search' ) {
%
%   my $string = $cgi->param('arg');
%   my @svc_broadband = FS::svc_broadband->smart_search( $string );
%   my $return = [ map { my $cust_pkg = $_->cust_svc->cust_pkg;
%                        [ $_->svcnum,
%                          $_->label. ( $cust_pkg
%                                        ? ' ('. $cust_pkg->cust_main->name. ')'
%                                        : ''
%                                     ),
%                        ];
%                      } 
%                    @svc_broadband,
%                ];
%     
<% encode_json($return) %>\
% }
<%init>

my $sub = $cgi->param('sub');

</%init>
