package FS::AccessRight;

use strict;
use vars qw(@rights); # %rights);
use Tie::IxHash;

=head1 NAME

FS::AccessRight - Access control rights.

=head1 SYNOPSIS

  use FS::AccessRight;

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

#well, this is what we have for now.  could be ordered better, could be lots of
# things better, but this ACL system does 99% of what folks need and the UI
# isn't *that* bad
# 
# okay, well it *really* needs some catgorization in the UI.  badly.
@rights = (

##
# basic customer rights
##
  'New customer',
  'View customer',
  #'View Customer | View tickets',
  'Edit customer',
  'Cancel customer',
  'Complimentary customer', #aka users-allow_comp 
  'Delete customer', #aka. deletecustomers #Enable customer deletions. Be very careful! Deleting a customer will remove all traces that this customer ever existed! It should probably only be used when auditing a legacy database. Normally, you cancel all of a customers' packages if they cancel service.
  'Add customer note', #NEW
  'Edit customer note', #NEW

###
# customer package rights
###
  'View customer packages', #NEW
  'Order customer package',
  'One-time charge',
  'Change customer package',
  'Bulk change customer packages',
  'Edit customer package dates',
  'Customize customer package',
  'Suspend customer package',
  'Unsuspend customer package',
  'Cancel customer package immediately',
  'Cancel customer package later',
  'Add on-the-fly cancel reason', #NEW
  'Add on-the-fly suspend reason', #NEW

###
# customer service rights
###
  'Edit usage', #NEW
  'View customer services', #NEW
  'Provision customer service',
  'Recharge customer service', #NEW
  'Unprovision customer service',

  'View/link unlinked services', #not agent-virtualizable without more work

###
# customer invoice/financial info rights
###
  'View invoices',
  'View customer tax exemptions', #yow
  'View customer batched payments', #NEW

###
# customer payment rights
###
  'Post payment',
  'Post payment batch',
  'Unapply payment', #aka. unapplypayments Enable "unapplication" of unclosed payments.
  'Process payment',
  'Refund payment',

  'Delete payment', #aka. deletepayments - Enable deletion of unclosed payments. Be very careful! Only delete payments that were data-entry errors, not adjustments. Optionally specify one or more comma-separated email addresses to be notified when a payment is deleted.

  'Delete refund', #NEW

###
# customer credit rights
###
  'Post credit',
  #'Apply credit',
  'Unapply credit', #aka unapplycredits Enable "unapplication" of unclosed credits.
  'Delete credit', #aka. deletecredits Enable deletion of unclosed credits. Be very careful! Only delete credits that were data-entry errors, not adjustments. Optionally specify one or more comma-separated email addresses to be notified when a credit is deleted.

###
# customer voiding rights..
###
  'Credit card void', #aka. cc-void #Enable local-only voiding of echeck payments in addition to refunds against the payment gateway
  'Echeck void', #aka. echeck-void #Enable local-only voiding of echeck payments in addition to refunds against the payment gateway
  'Regular void',
  'Unvoid', #aka. unvoid #Enable unvoiding of voided payments

###
# report/listing rights...
###
  'List customers',
  'List zip codes', #NEW
  'List invoices',
  'List packages',
  'List services',

  'List rating data',  # 'Usage reports',
  'Billing event reports',
  'Financial reports',

###
# misc rights
###
  'Job queue',         # these are not currently agent-virtualized
  'Process batches',   # NEW
  'Reprocess batches', # NEW
  'Import',            #
  'Export',            #

###
# misc misc rights
###
  'Raw SQL', #NEW

###
# setup/config rights
###
  'Edit advertising sources',
  'Edit global advertising sources',

  'Configuration', #most of the rest of the configuraiton is not
                   # agent-virtualized
);

sub rights {
  @rights;
}

