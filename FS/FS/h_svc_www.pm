package FS::h_svc_www;

use strict;
use vars qw( @ISA $DEBUG );
use Carp qw(carp);
use FS::Record qw(qsearchs);
use FS::h_Common;
use FS::svc_www;
use FS::h_domain_record;

@ISA = qw( FS::h_Common FS::svc_www );

$DEBUG = 0;

sub table { 'h_svc_www' };

=head1 NAME

FS::h_svc_www - Historical web virtual host objects

=head1 SYNOPSIS

=head1 METHODS

=over 4

=item domain_record

=cut

sub domain_record {
  my $self = shift;

  carp 'Called FS::h_svc_www->domain_record on svcnum ' . $self->svcnum if $DEBUG;

  local($FS::Record::qsearch_qualify_columns) = 0;
  my $domain_record = qsearchs(
    'h_domain_record',
    { 'recnum' => $self->recnum },
    FS::h_domain_record->sql_h_searchs(@_),
  ) || $self->SUPER::domain_record
    or die "no history domain_record.recnum for svc_www.recnum ". $self->domsvc;

  carp 'Using domain_record in place of missing h_domain_record record.'
    if ($domain_record->isa('FS::domain_record') and $DEBUG);

  return $domain_record;
  
}

=back

=head1 DESCRIPTION

An FS::h_svc_www object represents a historical web virtual host.
FS::h_svc_www inherits from FS::h_Common and FS::svc_www.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_www>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

