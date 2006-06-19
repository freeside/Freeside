package FS::ConfDefaults;

=head1 NAME

FS::ConfDefaults - Freeside configuration default and available values

=head1 SYNOPSIS

  use FS::ConfDefaults;

  @avail_cust_fields = FS::ConfDefaults->cust_fields_avail();

=head1 DESCRIPTION

Just a small class to keep config default and available values

=head1 METHODS

=over 4

=item cust_fields_avail

Returns a list, suitable for assigning to a hash, of available values and
labels for customer fields values.

=cut

# XXX should use msgcat for "Day phone" and "Night phone", but how?
sub cust_fields_avail { (

  'Customer' =>
    'Last, First or Company (Last, First)',
  'Cust# | Customer' =>
    'custnum | Last, First or Company (Last, First)',

  'Name | Company' =>
    'Last, First | Company',
  'Cust# | Name | Company' =>
    'custnum | Last, First | Company',

  '(bill) Customer | (service) Customer' =>
    'Last, First or Company (Last, First) | (same for service contact if present)',
  'Cust# | (bill) Customer | (service) Customer' =>
    'custnum | Last, First or Company (Last, First) | (same for service contact if present)',

  '(bill) Name | (bill) Company | (service) Name | (service) Company' =>
    'Last, First | Company | (same for service address if present)',
  'Cust# | (bill) Name | (bill) Company | (service) Name | (service) Company' =>
    'custnum | Last, First | Company | (same for service address if present)',

  'Cust# | Name | Company | Address 1 | Address 2 | City | State | Zip | Country | Day phone | Night phone | Invoicing email(s)' => 
    'custnum | Last, First | Company | (all address fields ) | Day phone | Night phone | Invoicing email(s)',

); }

=back

=head1 BUGS

Not yet.

=head1 SEE ALSO

L<FS::Conf>

=cut

1;
