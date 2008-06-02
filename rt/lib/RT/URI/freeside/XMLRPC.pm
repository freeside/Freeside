# BEGIN LICENSE BLOCK
# 
# Copyright (c) 2004 Kristian Hoffmann <khoff@fire2wire.com>
# Based on the original RT::URI::base and RT::URI::fsck_com_rt.
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK

use strict;
no warnings qw(redefine);

use vars qw($XMLRPC_URL $_FS_VERSION);

use Frontier::Client;

=head1 NAME

RT::URI::freeside::XMLRPC

=head1 DESCRIPTION

Overlay for the RT::URI::freeside URI handler implementing the XMLRPC integration type.

See L<RT::URI::freeside> for public/private interface documentation.

=cut


sub _XMLRPCRequest { #Subroutine

  my $method = shift;
  my @args = @_;

  my $result;
  eval {
    my $server = new Frontier::Client ( url => $XMLRPC_URL );
    $result = $server->call($method, @args);
  };

  if (not $@ and ref($result) eq 'ARRAY') {
    return (scalar(@$result) == 1) ? @$result[0] : @$result;
  } else {
    $RT::Logger->debug("Freeside XMLRPC: " . $result || $@);
    return ();
  }

}

sub _FreesideGetRecord {

  my $self = shift;
  my ($table, $pkey) = ($self->{'fstable'}, $self->{'fspkey'});
  my $record;

  $RT::Logger->debug("Called XMLRPC::_FreesideGetRecord()");

  #FIXME: Need a better way to get primary keys.
  # Maybe create a method for it and cache them like version?
  my %table_pkeys = (
    cust_main => 'custnum',
  );
    
  my $method = 'Record.qsearchs';
  my @args = ($table, { $table_pkeys{$table} => $pkey });
  my ($record) = &_XMLRPCRequest($method, @args);

  return $record;

}


sub FreesideGetConfig {

  return _XMLRPCRequest('Conf.config', @_);

}


sub FreesideVersion {

  return $_FS_VERSION if ($_FS_VERSION =~ /^\d+\.\d+\.\d+/);

  $RT::Logger->debug("Requesting freeside version...");
  ($_FS_VERSION) = &_XMLRPCRequest('version');
  $RT::Logger->debug("Cached freeside version: ${_FS_VERSION}");
 
  return $_FS_VERSION;

}

sub smart_search { #Subroutine

  return _XMLRPCRequest('cust_main.smart_search', @_);

}

sub small_custview {

  return _XMLRPCRequest('Web.UI.small_custview.small_custview', @_);

}

1;
