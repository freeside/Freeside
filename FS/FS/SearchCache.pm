package FS::SearchCache;

use strict;
use vars qw($DEBUG);
#use Carp qw(carp cluck croak confess);

$DEBUG = 0;

=head1 NAME

FS::SearchCache - cache

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item new

=cut

sub new { 
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my( $table, $key ) = @_;
  warn "table $table\n" if $DEBUG > 1;
  warn "key $key\n" if $DEBUG > 1;
  my $self = { 'table' => $table,
               'key'   => $key,
               'cache' => {},
               'subcache' => {},
             };
  bless ($self, $class);

  $self;
}

=item table

=cut

sub table { my $self = shift; $self->{table}; }

=item key

=cut

sub key { my $self = shift; $self->{key}; }

=item cache

=cut

sub cache { my $self = shift; $self->{cache}; }

=item subcache

=cut

sub subcache {
  my $self = shift;
  my $col = shift;
  my $table = shift;
  my $keyval = shift;
  if ( exists $self->{subcache}->{$col}->{$keyval} ) {
    warn "returning existing subcache for $keyval ($col)".
         "$self->{subcache}->{$col}->{$keyval}\n" if $DEBUG;
    return $self->{subcache}->{$col}->{$keyval};
  } else {
    #my $tablekey = @_ ? shift : $col;
    my $tablekey = $col;
    my $subcache = ref($self)->new( $table, $tablekey );
    $self->{subcache}->{$col}->{$keyval} = $subcache;
    warn "creating new subcache $table $tablekey: $subcache\n" if $DEBUG;
    $subcache;
  }
}

=back

=head1 BUGS

Dismal documentation.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>

=cut

1;


