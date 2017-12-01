use utf8;

# Any configuration directives you include  here will override
# RT's default configuration file, RT_Config.pm
#
# To include a directive here, just copy the equivalent statement
# from RT_Config.pm and change the value. We've included a single
# sample value below.
#
# If this file includes non-ASCII characters, it must be encoded in
# UTF-8.
#
# This file is actually a perl module, so you can include valid
# perl code, as well.
#
# The converse is also true, if this file isn't valid perl, you're
# going to run into trouble. To check your SiteConfig file, use
# this command:
#
#   perl -c /path/to/your/etc/RT_SiteConfig.pm

#Set( $rtname, 'example.com');

# These settings should have been inserted by the initial Freeside install.
# Sometimes you may want to change domain, timezone, or freeside::URL later,
# everything else should probably stay untouched.

Set($rtname, '%%%RT_DOMAIN%%%');
Set($Organization, '%%%RT_DOMAIN%%%');

Set($Timezone, '%%%RT_TIMEZONE%%%');

Set($WebRemoteUserAuth, 1);
Set($WebFallbackToInternal, 1); #no
Set($WebRemoteUserAutocreate, 1);

$RT::URI::freeside::IntegrationType = 'Internal';
$RT::URI::freeside::URL = '%%%FREESIDE_URL%%%';

$RT::URI::freeside::URL =~ m(^(https?://[^/]+)(/.*)?$)i;
Set($WebBaseURL, $1);
Set($WebPath, "$2/rt");

Set($DatabaseHost   , '');

# These settings are user-editable.

Set($UsernameFormat, 'verbose'); #back to concise to hide email addresses

#uncomment to use
#Set($DefaultSummaryRows, 10);

Set($MessageBoxWidth, 80);
Set($MessageBoxRichTextHeight, 368);

#redirects to ticket display on quick create
#Set($DisplayTicketAfterQuickCreate, 1);

#Set(@Plugins,(qw(Extension::QuickDelete RT::FM)));


# Define default lifecycle to include resolved_quiet status workflow
Set(%Lifecycles,
  default => {
    initial         => [qw(new)], # loc_qw
    active          => [qw(open stalled)], # loc_qw
    inactive        => [qw(resolved resolved_quiet rejected deleted)], # loc_qw

    defaults => {
        on_create => 'new',
        on_merge  => 'resolved',
        approved  => 'open',
        denied    => 'rejected',
        reminder_on_open     => 'open',
        reminder_on_resolve  => 'resolved',
    },

    transitions => {
        ""       => [qw(new open resolved)],

        # from   => [ to list ],
        new       => [qw(open stalled resolved resolved_quiet rejected  deleted)],
        open      => [qw(new stalled resolved resolved_quiet rejected  deleted)],
        stalled   => [qw(new open rejected resolved resolved_quiet deleted)],
        resolved  => [qw(new open stalled rejected deleted)],
        resolved_quiet => [qw(resolved)],
        rejected  => [qw(new open stalled resolved resolved_quiet deleted)],
        deleted   => [qw(new open stalled rejected resolved resolved_quiet)],
    },

    rights => {
        '* -> deleted'  => 'DeleteTicket',
        '* -> *'        => 'ModifyTicket',
    },
    actions => [
        'new -> open'            => { label  => 'Open It',       update => 'Respond' },
        'new -> resolved'        => { label  => 'Resolve',       update => 'Comment' },
        'new -> resolved_quiet'  => { label  => 'Quiet Resolve', update => 'Comment' },
        'new -> rejected'        => { label  => 'Reject',        update => 'Respond' },
        'new -> deleted'         => { label  => 'Delete',                            },
        'open -> stalled'        => { label  => 'Stall',         update => 'Comment' },
        'open -> resolved'       => { label  => 'Resolve',       update => 'Comment' },
        'open -> resolved_quiet' => { label  => 'Quiet Resolve', update => 'Comment' },
        'open -> rejected'       => { label  => 'Reject',        update => 'Respond' },
        'stalled -> open'        => { label  => 'Open It',                           },
        'resolved -> open'       => { label  => 'Re-open',       update => 'Comment' },
        'rejected -> open'       => { label  => 'Re-open',       update => 'Comment' },
        'deleted -> open'        => { label  => 'Undelete',                          },
    ],
  },
# don't change lifecyle of the approvals, they are not capable to deal with
# custom statuses
  approvals => {
    initial         => [ 'new' ],
    active          => [ 'open', 'stalled' ],
    inactive        => [ 'resolved', 'rejected', 'deleted' ],

    defaults => {
      on_create => 'new',
      on_merge => 'resolved',
      reminder_on_open     => 'open',
      reminder_on_resolve  => 'resolved',
    },

    transitions => {
      ''       => [qw(new open resolved)],

      # from   => [ to list ],
      new      => [qw(open stalled resolved rejected deleted)],
      open     => [qw(new stalled resolved rejected deleted)],
      stalled  => [qw(new open rejected resolved deleted)],
      resolved => [qw(new open stalled rejected deleted)],
      rejected => [qw(new open stalled resolved deleted)],
      deleted  => [qw(new open stalled rejected resolved)],
    },
    rights => {
      '* -> deleted'  => 'DeleteTicket',
      '* -> rejected' => 'ModifyTicket',
      '* -> *'        => 'ModifyTicket',
    },
    actions => [
      'new -> open'      => { label  => 'Open It', update => 'Respond' },
      'new -> resolved'  => { label  => 'Resolve', update => 'Comment' },
      'new -> rejected'  => { label  => 'Reject',  update => 'Respond' },
      'new -> deleted'   => { label  => 'Delete',                      },
      'open -> stalled'  => { label  => 'Stall',   update => 'Comment' },
      'open -> resolved' => { label  => 'Resolve', update => 'Comment' },
      'open -> rejected' => { label  => 'Reject',  update => 'Respond' },
      'stalled -> open'  => { label  => 'Open It',                     },
      'resolved -> open' => { label  => 'Re-open', update => 'Comment' },
      'rejected -> open' => { label  => 'Re-open', update => 'Comment' },
      'deleted -> open'  => { label  => 'Undelete',                    },
    ],
  },
);

# Lifecycle 'default' from RT_Config.pm
# Customer may set the lifecycle on their ticket queue as 'hide_resolve_quiet'
# to suppress the 'resolve_quiet' ticket status
Set(%Lifecycles,
    hide_resolve_quiet => {
        initial         => [qw(new)], # loc_qw
        active          => [qw(open stalled)], # loc_qw
        inactive        => [qw(resolved rejected deleted)], # loc_qw

        defaults => {
            on_create => 'new',
            on_merge  => 'resolved',
            approved  => 'open',
            denied    => 'rejected',
            reminder_on_open     => 'open',
            reminder_on_resolve  => 'resolved',
        },

        transitions => {
            ""       => [qw(new open resolved)],

            # from   => [ to list ],
            new      => [qw(    open stalled resolved rejected deleted)],
            open     => [qw(new      stalled resolved rejected deleted)],
            stalled  => [qw(new open         rejected resolved deleted)],
            resolved => [qw(new open stalled          rejected deleted)],
            rejected => [qw(new open stalled resolved          deleted)],
            deleted  => [qw(new open stalled rejected resolved        )],
        },
        rights => {
            '* -> deleted'  => 'DeleteTicket',
            '* -> *'        => 'ModifyTicket',
        },
        actions => [
            'new -> open'      => { label  => 'Open It', update => 'Respond' }, # loc{label}
            'new -> resolved'  => { label  => 'Resolve', update => 'Comment' }, # loc{label}
            'new -> rejected'  => { label  => 'Reject',  update => 'Respond' }, # loc{label}
            'new -> deleted'   => { label  => 'Delete',                      }, # loc{label}
            'open -> stalled'  => { label  => 'Stall',   update => 'Comment' }, # loc{label}
            'open -> resolved' => { label  => 'Resolve', update => 'Comment' }, # loc{label}
            'open -> rejected' => { label  => 'Reject',  update => 'Respond' }, # loc{label}
            'stalled -> open'  => { label  => 'Open It',                     }, # loc{label}
            'resolved -> open' => { label  => 'Re-open', update => 'Comment' }, # loc{label}
            'rejected -> open' => { label  => 'Re-open', update => 'Comment' }, # loc{label}
            'deleted -> open'  => { label  => 'Undelete',                    }, # loc{label}
        ],
    },
# don't change lifecyle of the approvals, they are not capable to deal with
# custom statuses
    approvals => {
        initial         => [ 'new' ],
        active          => [ 'open', 'stalled' ],
        inactive        => [ 'resolved', 'rejected', 'deleted' ],

        defaults => {
            on_create => 'new',
            on_merge => 'resolved',
            reminder_on_open     => 'open',
            reminder_on_resolve  => 'resolved',
        },

        transitions => {
            ''       => [qw(new open resolved)],

            # from   => [ to list ],
            new      => [qw(open stalled resolved rejected deleted)],
            open     => [qw(new stalled resolved rejected deleted)],
            stalled  => [qw(new open rejected resolved deleted)],
            resolved => [qw(new open stalled rejected deleted)],
            rejected => [qw(new open stalled resolved deleted)],
            deleted  => [qw(new open stalled rejected resolved)],
        },
        rights => {
            '* -> deleted'  => 'DeleteTicket',
            '* -> rejected' => 'ModifyTicket',
            '* -> *'        => 'ModifyTicket',
        },
        actions => [
            'new -> open'      => { label  => 'Open It', update => 'Respond' }, # loc{label}
            'new -> resolved'  => { label  => 'Resolve', update => 'Comment' }, # loc{label}
            'new -> rejected'  => { label  => 'Reject',  update => 'Respond' }, # loc{label}
            'new -> deleted'   => { label  => 'Delete',                      }, # loc{label}
            'open -> stalled'  => { label  => 'Stall',   update => 'Comment' }, # loc{label}
            'open -> resolved' => { label  => 'Resolve', update => 'Comment' }, # loc{label}
            'open -> rejected' => { label  => 'Reject',  update => 'Respond' }, # loc{label}
            'stalled -> open'  => { label  => 'Open It',                     }, # loc{label}
            'resolved -> open' => { label  => 'Re-open', update => 'Comment' }, # loc{label}
            'rejected -> open' => { label  => 'Re-open', update => 'Comment' }, # loc{label}
            'deleted -> open'  => { label  => 'Undelete',                    }, # loc{label}
        ],
    },
);

1;
