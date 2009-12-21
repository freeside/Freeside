%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect(popurl(2). "view/cust_main.cgi?$custnum") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bill customer now');

#untaint custnum
my($query) = $cgi->keywords;
$query =~ /^(\d*)$/;
my $custnum = $1;
my $cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
die "Can't find customer!\n" unless $cust_main;

my $conf = new FS::Conf;

my $error = $cust_main->bill_and_collect( 'fatal' => 'return',
                                          'retry' => 'yes',
                                        );

                                  #'invoice-time'=>$time,
                                  #'batch_card'=> 'yes',
                                  #'batch_card'=> 'no',
                                  #'report_badcard'=> 'yes',
                                  #'retry_card' => 'yes',

                                  #this is used only by cust_main::batch_card
                                  #need to pick & create an actual config
                                  #value if we're going to turn this on
                                  #("realtime-backend" doesn't exist,
                                  # "backend-realtime" is for something
                                  #  entirely different)
                                  #'realtime' => $conf->exists('realtime-backend'),

</%init>
