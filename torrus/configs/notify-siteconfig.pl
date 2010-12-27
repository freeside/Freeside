
%Torrus::Notify::programs =
    (
     'mailto' => '$TORRUS_BIN/action_printemail | /usr/bin/mail $ARG1',
     'page' => '/usr/bin/echo $TORRUS_NODEPATH:$TORRUS_MONITOR ' .
     '>> /tmp/monitor.$ARG1.log'
     );

%Torrus::Notify::policies =
    (
     'CUST_A' => {
         'match' => sub { $ENV{'TORRUS_P_notify_policy'} eq 'A' },
         'severity' => {
             '3' => [ 'mailto:aaa@domain.com',
                      'mailto:bbb@domain.com' ],
             '5' => [ 'page:1234', 'mailto:boss@domain.com' ] } } );
     
                 
             
         
# Torrus::Log::setLevel('debug');    
    


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
