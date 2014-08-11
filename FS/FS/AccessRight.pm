package FS::AccessRight;

use strict;
use vars qw(@rights); # %rights);
use Tie::IxHash;

=head1 NAME

FS::AccessRight - Access control rights.

=head1 SYNOPSIS

  use FS::AccessRight;

  my @rights = FS::AccessRight->rights;

  #my %rights = FS::AccessRight->rights_categorized;
  tie my %rights, 'Tie::IxHash', FS::AccessRight->rights_categorized;
  foreach my $category ( keys %rights ) {
    my @category_rights = @{ $rights{$category} };
  }

=head1 DESCRIPTION

Access control rights - Permission to perform specific actions that can be
assigned to users and/or groups.

=cut

#@rights = (
#  'Reports' => [
#    '_desc' => 'Access to high-level reporting',
#  ],
#  'Configuration' => [
#    '_desc' => 'Access to configuration',
#
#    'Settings' => {},
#
#    'agent' => [
#      '_desc' => 'Master access to reseller configuration',
#      'agent_type'  => {},
#      'agent'       => {},
#    ],
#
#    'export_svc_pkg' => [
#      '_desc' => 'Access to export, service and package configuration',
#      'part_export' => {},
#      'part_svc'    => {},
#      'part_pkg'    => {},
#      'pkg_class'   => {},
#    ],
#
#    'billing' => [
#      '_desc' => 'Access to billing configuration',
#      'payment_gateway'  => {},
#      'part_bill_event'  => {},
#      'prepay_credit'    => {},
#      'rate'             => {},
#      'cust_main_county' => {},
#    ],
#
#    'dialup' => [
#      '_desc' => 'Access to dialup configuraiton',
#      'svc_acct_pop' => {},
#    ],
#
#    'broadband' => [
#      '_desc' => 'Access to broadband configuration',
#      'router'     => {},
#      'addr_block' => {},
#    ],
#
#    'misc' => [
#      'part_referral'      => {},
#      'part_virtual_field' => {},
#      'msgcat'             => {},
#      'inventory_class'    => {},
#    ],
#
#  },
#
#);
#
##turn it into a more hash-like structure, but ordered via IxHash

#well, this is what we have for now.  getting better.
tie my %rights, 'Tie::IxHash',

  ###
  # contact rights
  ###
  'Contact and Prospect rights' => [
    'New prospect',
    'View prospect',
    'Edit prospect',
    'List prospects',
    'Edit contact', #!
    #'New contact',
    #'View customer contacts',
    #'List contacts',
    'Generate quotation',
  ],
  
  ###
  # basic customer rights
  ###
  'Customer rights' => [
    'New customer',
    'View customer',
    #'View Customer | View tickets',
    'Edit customer',
    'Edit customer tags',
    'Edit referring customer',
    'View customer history',
    'Suspend customer',
    'Unsuspend customer',
    'Cancel customer',
    'Complimentary customer', #aka users-allow_comp 
    'Merge customer',
    'Merge customer across agents',
    'Bill customer now', #NEW
    'Bulk send customer notices', #NEW
    { rightname=>'View customers of all agents', global=>1 },
  ],
  
  ###
  # customer package rights
  ###
  'Customer package rights' => [
    'View customer packages', #NEW
    'Order customer package',
    'One-time charge',
    'Modify one-time charge',
    'Change customer package',
    'Detach customer package',
    'Bulk change customer packages',
    'Edit customer package dates',
    'Discount customer package', #NEW
    'Custom discount customer package', #NEW
    'Customize customer package',
    'Suspend customer package',
    'Suspend customer package later',
    'Unsuspend customer package',
    'Cancel customer package immediately',
    'Cancel customer package later',
    'Un-cancel customer package',
    'Delay suspension events',
    'Add on-the-fly cancel reason', #NEW
    'Add on-the-fly suspend reason', #NEW
    'Edit customer package invoice details', #NEW
    'Edit customer package comments', #NEW
    'Qualify service', #NEW
    'Waive setup fee', #NEW
    'View appointments', #NEWNEW
    'Make appointment',
    'View package definition costs', #NEWNEW
  ],
  
  ###
  # customer service rights
  ###
  'Customer service rights' => [
    'View customer services', #NEW
    'Provision customer service',
    'Bulk provision customer service',
    'Bulk move customer services', #NEWNEW
    'Recharge customer service', #NEW
    'Unprovision customer service',
    'Change customer service', #NEWNEW
    'Edit password',
    'Edit usage', #NEW
    'Edit home dir', #NEW
    'Edit www config', #NEW
    'Edit domain catchall', #NEW
    'Edit domain nameservice', #NEW
    'Manage domain registration',
  
    { rightname=>'View/link unlinked services', global=>1 }, #not agent-virtualizable without more work
  ],
  
  ###
  # customer invoice/financial info rights
  ###
  'Customer invoice / financial info rights' => [
    'View invoices',
    'Resend invoices', #NEWNEW
    'Void invoices',
    'Unvoid invoices',
    'Delete invoices',
    'View customer tax exemptions', #yow
    'Edit customer tax exemptions', #NEWNEW
    'Add customer tax adjustment', #new, but no need to phase in
    'View customer batched payments', #NEW
    'View customer pending payments', #NEW
    'Edit customer pending payments', #NEW
    'View customer billing events', #NEW
  ],
  
  ###
  # customer payment rights
  ###
  'Customer payment rights' => [
    'View payments',
    { rightname=>'Post payment', desc=>'Make check or cash payments.' },
    { rightname=>'Backdate payment', desc=>'Enable payments to be posted for days other than today.' },
    'Post check payment',
    'Post cash payment',
    'Post payment batch',
    'Apply payment', #NEWNEW
    { rightname=>'Unapply payment', desc=>'Enable "unapplication" of unclosed payments from specific invoices.' }, #aka. unapplypayments
    { rightname=>'Process payment', desc=>'Process credit card or e-check payments' },
    'Process credit card payment',
    'Process Echeck payment',
    { rightname=>'Delete payment', desc=>'Enable deletion of unclosed payments. Be very careful!  Only delete payments that were data-entry errors, not adjustments.' }, #aka. deletepayments Optionally specify one or more comma-separated email addresses to be notified when a payment is deleted.
  ],
  
  ###
  # customer credit rights
  ###
  'Customer credit and refund rights' => [
    'Post credit',
    'Credit line items', #NEWNEWNEW
    'Apply credit', #NEWNEW
    { rightname=>'Unapply credit', desc=>'Enable "unapplication" of unclosed credits.' }, #aka unapplycredits
    { rightname=>'Delete credit', desc=>'Enable deletion of unclosed credits. Be very careful!  Only delete credits that were data-entry errors, not adjustments.' }, #aka. deletecredits Optionally specify one or more comma-separated email addresses to be notified when a credit is deleted.
    'View refunds',
    { rightname=>'Post refund', desc=>'Enable posting of check and cash refunds.' },
    'Post check refund',
    'Post cash refund',
#    { rightname=>'Process refund', desc=>'Enable processing of generic credit card/ACH refunds (i.e. not associated with a specific prior payment).' },
    { rightname=>'Refund payment', desc=>'Enable refund of existing customer credit card or e-check payments.' },
    'Refund credit card payment',
    'Refund Echeck payment',
    'Delete refund', #NEW
    'Add on-the-fly credit reason', #NEW
    'Add on-the-fly refund reason', #NEW
  ],
  
  ###
  # customer voiding rights..
  ###
  'Customer payment void rights' => [
    { rightname=>'Credit card void', desc=>'Enable local-only voiding of credit card payments in addition to refunds against the payment gateway.' }, #aka. cc-void 
    { rightname=>'Echeck void', desc=>'Enable local-only voiding of echeck payments in addition to refunds against the payment gateway.' }, #aka. echeck-void
    'Void payments',
    { rightname=>'Unvoid payments', desc=>'Enable unvoiding of voided payments' }, #aka. unvoid 
    
  
  ],
 
  ###
  # note/attachment rights...
  ###
  'Customer note and attachment rights' => [
    'Add customer note', #NEW
    'Edit customer note', #NEW
    'View attachments', #NEW
    'Browse attachments', #NEW
    'Download attachment', #NEW
    'Add attachment', #NEW
    'Edit attachment', #NEW
    'Delete attachment', #NEW
    'View deleted attachments', #NEW
    'Undelete attachment', #NEW
    'Purge attachment', #NEW
  ],
  
  ###
  # report/listing rights...
  ###
  'Reporting/listing rights' => [
    'List customers',
    'List all customers',
    'Advanced customer search',
    'List zip codes', #NEW
    'List quotations',
    'List invoices',
    'List packages',
    'Summarize packages',
    'List services',
    'List service passwords',
  
    { rightname=> 'List rating data', desc=>'Usage reports', global=>1 },
    'Billing event reports',
    'Receivables report',
    'Financial reports',
    { rightname=> 'List inventory', global=>1 },
    { rightname=>'View email logs', global=>1 },
    { rightname=>'View system logs' },

    'Download report data',
    'Services: Accounts',
    'Services: Accounts: Advanced search',
    'Services: Domains',
    'Services: Certificates',
    'Services: Mail forwards',
    'Services: Virtual hosting services',
    'Services: Wireless broadband services',
    'Services: Wireless broadband services: Advanced search',
    'Services: DSLs',
    'Services: Cable subscribers',
    'Services: Conferencing',
    'Services: Dish services',
    'Services: Hardware',
    'Services: Hardware: Advanced search',
    'Services: Phone numbers',
    'Services: Phone numbers: Advanced search',
    'Services: PBXs',
    'Services: Ports',
    'Services: Mailing lists',
    'Services: Alarm services',
    'Services: Video',
    'Services: External services',
    'Usage: RADIUS sessions',
    'Usage: Call Detail Records (CDRs)',
    'Usage: Unrateable CDRs',
    'Usage: Time worked',
    #gone in 4.x as a distinct ACL (for now?) { rightname=>'Employees: Commission Report', global=>1 },
    { rightname=>'Employees: Audit Report', global=>1 },

    #{ rightname => 'List customers of all agents', global=>1 },
  ],
  
  ###
  # misc rights
  ###
  'Miscellaneous rights' => [
    { rightname=>'Job queue', global=>1 },
    { rightname=>'Time queue', global=>1 },
    { rightname=>'Process batches', }, #Process payment batches
    { rightname=>'Process global batches', global=>1 }, #Process global payment batches
    { rightname=>'Reprocess batches', global=>1 }, #Reprocess payment batches
    { rightname=>'Redownload resolved batches', global=>1 }, #Redownload resolved payment batches
    { rightname=>'Process invoice batches', },
    { rightname=>'Process global invoice batches', global=>1 },
    { rightname=>'Import', global=>1 }, #some of these are ag-virt'ed now?  give em their own ACLs
    { rightname=>'Export', global=>1 },
    { rightname=> 'Edit rating data', desc=>'Delete CDRs', global=>1 },
  #],
  #
  ###
  # misc misc rights
  ###
  #'Database access rights' => [
    { rightname=>'Raw SQL', global=>1 }, #NEW
  ],
  
  ###
  # setup/config rights
  ###
  'Configuration rights' => [
    'Edit advertising sources',
    { rightname=>'Edit global advertising sources', global=>1 },

    'Edit sales people',

    'Edit package definitions',
    { rightname=>'Edit global package definitions', global=>1 },
    'Edit package definition costs',

    'Bulk edit package definitions',

    'Edit FCC report configuration',
    { rightname => 'Edit FCC report configuration for all agents', global=>1 },

    'Edit CDR rates',
    #{ rightname=>'Edit global CDR rates', global=>1, },

    'Edit fee definitions',
    { rightname=>'Edit global fee definitions', global=>1 },

    'Edit billing events',
    { rightname=>'Edit global billing events', global=>1 },

    'View templates',
    { rightname=>'View global templates', global=>1 },
    'Edit templates',
    { rightname=>'Edit global templates', global=>1 },

    'Edit inventory',
    { rightname=>'Edit global inventory', global=>1 },
  
    { rightname=>'Dialup configuration' },
    { rightname=>'Dialup global configuration', global=>1 },

    { rightname=>'Broadband configuration' },
    { rightname=>'Broadband global configuration', global=>1 },

    { rightname=>'Alarm configuration' },
    { rightname=>'Alarm global configuration', global=>1 },

    { rightname=> 'Configure network monitoring', global=>1 },

    #{ rightname=>'Edit employees', global=>1, },
    #{ rightname=>'Edit employee groupss', global=>1, },

    { rightname=>'Configuration', global=>1 }, #most of the rest of the configuraiton is not agent-virtualized

    { rightname=>'Configuration download', }, #description of how it affects
                                              #search/elements/search.html

  ],
  
;
  
=head1 CLASS METHODS
  
=over 4
  
=item rights

Returns the full list of right names.

=cut
  
sub rights {
  #my $class = shift;
  map { ref($_) ? $_->{'rightname'} : $_ } map @{ $rights{$_} }, keys %rights;
}

=item default_superuser_rights

Most (but not all) right names.

=cut

sub default_superuser_rights {
  my $class = shift;
  my %omit = map { $_=>1 } (
    'Delete invoices',
    'Delete payment',
    'Delete credit', #?
    'Delete refund', #?
    'Edit customer package dates',
    'Time queue',
    'Usage: Time worked',
    'Redownload resolved batches',
    'Raw SQL',
    'Configuration download',
    'View customers of all agents',
    'View/link unlinked services',
    'Edit usage',
    'Credit card void',
    'Echeck void',
    'Void invoices',#people are overusing this when credits are more appropriate
  );

  no warnings 'uninitialized';
  grep { ! $omit{$_} } $class->rights;
}
  
=item rights_info

Returns a list of key-value pairs suitable for assigning to a hash.  Keys are
category names and values are list references of rights.  Each element of the
list reference scalar right name or a hashref with the following keys:

=over 4

=item rightname - Right name

=item desc - Extended right description

=item global - Global flag, indicates that this access right provides access to global data which is shared among all agents.

=back

=cut

sub rights_info {
  %rights;
}

=back

=head1 BUGS

Damn those infernal six-legged creatures!

=head1 SEE ALSO

L<FS::access_right>, L<FS::access_group>, L<FS::access_user>

=cut

1;

