% die "you don't have the 'Configuration' access right"
%   unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
%
% my($query) = $cgi->keywords;
% $query  =~ /^(\d+)$/ || die "Illegal agentgatewaynum";
% my $agentgatewaynum = $1;
%
% my $agent_payment_gateway = qsearchs('agent_payment_gateway', { 
%   'agentgatewaynum' => $agentgatewaynum,
% });
%
% my $error = $agent_payment_gateway->delete;
% eidiot($error) if $error;
%
% print $cgi->redirect($p. "browse/agent.cgi");
