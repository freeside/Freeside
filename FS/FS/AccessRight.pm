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
  # basic customer rights
  ###
  'Customer rights' => [
    'New customer',
    'View customer',
    #'View Customer | View tickets',
    'Edit customer',
    'Cancel customer',
    'Complimentary customer', #aka users-allow_comp 
    { rightname=>'Delete customer', desc=>"Enable customer deletions. Be very careful! Deleting a customer will remove all traces that this customer ever existed! It should probably only be used when auditing a legacy database. Normally, you cancel all of a customer's packages if they cancel service." }, #aka. deletecustomers
    'Add customer note', #NEW
    'Edit customer note', #NEW
    'Bill customer now', #NEW
    'Bulk send customer notices', #NEW
  ],
  
  ###
  # customer package rights
  ###
  'Customer package rights' => [
    'View customer packages', #NEW
    'Order customer package',
    'One-time charge',
    'Change customer package',
    'Bulk change customer packages',
    'Edit customer package dates',
    'Customize customer package',
    'Suspend customer package',
    'Suspend customer package later',
    'Unsuspend customer package',
    'Cancel customer package immediately',
    'Cancel customer package later',
    'Delay suspension events',
    'Add on-the-fly cancel reason', #NEW
    'Add on-the-fly suspend reason', #NEW
    'Edit customer package invoice details', #NEW
    'Edit customer package comments', #NEW
  ],
  
  ###
  # customer service rights
  ###
  'Customer service rights' => [
    'View customer services', #NEW
    'Provision customer service',
    'Recharge customer service', #NEW
    'Unprovision customer service',
    'Change customer service', #NEWNEW
    'Edit usage', #NEW
    'Edit home dir', #NEW
    'Edit www config', #NEW
    'Edit domain catchall', #NEW
    'Edit domain nameservice', #NEW
  
    { rightname=>'View/link unlinked services', global=>1 }, #not agent-virtualizable without more work
  ],
  
  ###
  # customer invoice/financial info rights
  ###
  'Customer invoice / financial info rights' => [
    'View invoices',
    'Resend invoices', #NEWNEW
    'View customer tax exemptions', #yow
    'View customer batched payments', #NEW
    'View customer billing events', #NEW
  ],
  
  ###
  # customer payment rights
  ###
  'Customer payment rights' => [
    'Post payment',
    'Post payment batch',
    'Apply payment', #NEWNEW
    { rightname=>'Unapply payment', desc=>'Enable "unapplication" of unclosed payments from specific invoices.' }, #aka. unapplypayments
    'Process payment',
    { rightname=>'Refund payment', desc=>'Enable refund of existing customer payments.' },

    { rightname=>'Delete payment', desc=>'Enable deletion of unclosed payments. Be very careful!  Only delete payments that were data-entry errors, not adjustments.' }, #aka. deletepayments Optionally specify one or more comma-separated email addresses to be notified when a payment is deleted.
  
  ],
  
  ###
  # customer credit rights
  ###
  'Customer credit and refund rights' => [
    'Post credit',
    'Apply credit', #NEWNEW
    { rightname=>'Unapply credit', desc=>'Enable "unapplication" of unclosed credits.' }, #aka unapplycredits
    { rightname=>'Delete credit', desc=>'Enable deletion of unclosed credits. Be very careful!  Only delete credits that were data-entry errors, not adjustments.' }, #aka. deletecredits Optionally specify one or more comma-separated email addresses to be notified when a credit is deleted.
    { rightname=>'Post refund', desc=>'Enable posting of check and cash refunds.' },
#    { rightname=>'Process refund', desc=>'Enable processing of generic credit card/ACH refunds (i.e. not associated with a specific prior payment).' },
    'Delete refund', #NEW
    'Add on-the-fly credit reason', #NEW
  ],
  
  ###
  # customer voiding rights..
  ###
  'Customer void rights' => [
    { rightname=>'Credit card void', desc=>'Enable local-only voiding of echeck payments in addition to refunds against the payment gateway.' }, #aka. cc-void 
    { rightname=>'Echeck void', desc=>'Enable local-only voiding of echeck payments in addition to refunds against the payment gateway.' }, #aka. echeck-void
    'Regular void',
    { rightname=>'Unvoid', desc=>'Enable unvoiding of voided payments' }, #aka. unvoid 
    
  
  ],
  
  ###
  # report/listing rights...
  ###
  'Reporting/listing rights' => [
    'List customers',
    'List zip codes', #NEW
    'List invoices',
    'List packages',
    'List services',
  
    { rightname=> 'List rating data', desc=>'Usage reports', global=>1 },
    'Billing event reports',
    'Financial reports',
  ],
  
  ###
  # misc rights
  ###
  'Miscellaneous rights' => [
    { rightname=>'Job queue', global=>1 },
    { rightname=>'Time queue', global=>1 },
    { rightname=>'Process batches', global=>1 },
    { rightname=>'Reprocess batches', global=>1 },
    { rightname=>'Import', global=>1 }, #some of these are ag-virt'ed now?  give em their own ACLs
    { rightname=>'Export', global=>1 },
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

    'Edit package definitions',
    { rightname=>'Edit global package definitions', global=>1 },
  
    'Edit billing events',
    { rightname=>'Edit global billing events', global=>1 },
  
    { rightname=>'Dialup configuration' },
    { rightname=>'Dialup global configuration', global=>1 },

    { rightname=>'Broadband configuration' },
    { rightname=>'Broadband global configuration', global=>1 },

    { rightname=>'Configuration', global=>1 }, #most of the rest of the configuraiton is not agent-virtualized
  ],
  
;
  
=head1 CLASS METHODS
  
=over 4
  
=item rights

Returns a list of right names.

=cut
  
  sub rights {
  #my $class = shift;
  map { ref($_) ? $_->{'rightname'} : $_ } map @{ $rights{$_} }, keys %rights;
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

