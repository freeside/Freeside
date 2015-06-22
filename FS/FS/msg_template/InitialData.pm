package FS::msg_template::InitialData;

sub _initial_data {
  [
    { msgname   => 'Password reset',
      mime_type => 'text/html', #multipart/alternative with a text part?
                                  # cranky mutt/pine users like me are rare

      _conf        => 'selfservice-password_reset_msgnum',
      _insert_args => [ subject => '{ $company_name } password reset',
                        body    => <<'END',
To complete your { $company_name } password reset, please go to
<a href="{ $selfservice_server_base_url }/selfservice.cgi?action=process_forgot_password_session_{ $session_id }">{ $selfservice_server_base_url }/selfservice.cgi?action=process_forgot_password_session_{ $session_id }</a><br />
<br />
This link will expire in 24 hours.<br />
<br />
If you did not request this password reset, you may safely ignore and delete this message.<br />
<br />
<br />
{ $company_name } Support
END
                      ],
    },
    { msgname   => 'payment_history_template',
      mime_type => 'text/html',
      _conf        => 'payment_history_msgnum',
      _insert_args => [ subject => '{ $company_name } payment history',
                        body    => <<'END',
{ $payment_history }
END
                      ],
    },
  ];
}

1;
