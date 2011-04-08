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
package RT::URI::freeside;

use base qw( RT::URI::base );
use strict;
use vars qw( $IntegrationType $URL );
use Carp qw( cluck );


=head1 NAME

RT::URI::freeside

=head1 DESCRIPTION

URI handler for Freeside URIs.  See http://www.freeside.biz/ for more
information on Freeside.


=head1 Public subroutines

=over 4

=item FreesideGetConfig CONFKEY

Subroutine that returns the freeside's configuration value(s) for CONFKEY
as a scalar or list.

=cut

sub FreesideGetConfig { return undef; }


=item FreesideURL

Returns the URL for freeside's web interface.

=cut

sub FreesideURL { return $URL; }


=item FreesideVersion

Returns a string describing the freeside version being used.

=cut

sub FreesideVersion { return undef; }


=item smart_search

A wrapper for the FS::cust_main::smart_search subroutine.

=cut

sub smart_search { return undef; }


=item email_search

A wrapper for the FS::cust_main::email_search subroutine.

=cut

sub email_search { return undef; }


=item small_custview

A wrapper for the FS::CGI::small_custview subroutine.

=cut

sub small_custview { return 'Freeside integration error!</A>'; }


=back

=head1 Private methods

=over 4

=item _FreesideGetRecord

Method returns a hashref of the freeside record referenced in the URI.
Must be called after ParseURI.

=cut

sub _FreesideGetRecord { return undef; }


=item _FreesideURIPrefix

Method that returns the URI prefix for freeside URIs.

=cut

sub _FreesideURIPrefix {

  my $self = shift;
  return($self->Scheme . '://freeside');

}

=item _FreesideURILabel

Method that returns a short string describing the customer referenced
in the URI.

=cut

sub _FreesideURILabel {

  my $self = shift;

  #$RT::Logger->debug("Called _FreesideURILabel()");

  return unless (exists($self->{'fstable'}) and
                 exists($self->{'fspkey'}));

  my $label;
  my ($table, $pkey) = ($self->{'fstable'}, $self->{'fspkey'});

  #if ($table ne 'cust_main') {
  #  warn "FS::${table} not currently supported";
  #  return;
  #}

  my $rec = $self->_FreesideGetRecord();

  if (ref($rec) eq 'HASH' && $table eq 'cust_main') {
    my $name = $rec->{'last'} . ', ' . $rec->{'first'};
    $name = $rec->{'company'} . " ($name)" if $rec->{'company'};
    $label = "$pkey: $name";
  } elsif ( $table eq 'cust_svc' && ref($rec) && $rec->{'_object'} ) {
    #Internal only
    my($l,$v) = $rec->{'_object'}->label;
    $label = "$l: $v";
  } else {
    $label = "$pkey: $table";
  }

  if ($label and !$@) {
    return($label);
  } else {
    return;
  }

}

=item _FreesideURILabelLong

Method that returns a longer string describing the customer referenced
in the URI.

=cut

sub _FreesideURILabelLong {

  my $self = shift;

  return $self->_FreesideURILabel();

}

=back

=head1 Public methods

=over 4

=cut

sub ParseURI { 
    my $self = shift;
    my $uri = shift;
    my ($table, $pkey);

    my $uriprefix = $self->_FreesideURIPrefix;
    if ($uri =~ /^$uriprefix\/(\w+)\/(\d*)$/) {

      $table = $1;
      $pkey = $2;

      unless ( $pkey ) {
        #way too noisy, using this prefix is normal usage# cluck "bad URL $uri";
        return(undef);
      }

      $self->{'scheme'} = $self->Scheme;

    } else {
      return(undef);
    }

    $self->{'uri'} = "${uriprefix}/${table}/${pkey}";
    $self->{'fstable'} = $table;
    $self->{'fspkey'} = $pkey;


    my $url = $self->FreesideURL();

    if ($url ne '') {
      $self->{'href'} = "${url}/view/${table}.cgi?${pkey}";
    } else {
      $self->{'href'} = $self->{'uri'};
    }

    $self->{'uri'};

}

sub Scheme { 
    my $self = shift;
    return('freeside');

}

sub HREF {
    my $self = shift;
    return($self->{'href'} || $self->{'uri'});
}

sub IsLocal {
    my $self = shift;
    return undef;
}

=item AsString

Return a "pretty" string representing the URI object.

This is meant to be used like this:

 % $re = $uri->Resolver;
 <A HREF="<% $re->HREF %>"><% $re->AsString %></A>

=cut

sub AsString {
    my $self = shift;
    my $prettystring;
    if ($prettystring = $self->_FreesideURILabel) {
      return $prettystring;
    } else {
      return $self->URI;
    }
}

=item AsStringLong

Return a longer (HTML) string representing the URI object.

=cut

sub AsStringLong {
    my $self = shift;
    my $prettystring;
    if ($prettystring = $self->_FreesideURILabelLong || $self->_FreesideURILabel){
      return $prettystring;
    } else {
      return $self->URI;
    }
}

$IntegrationType ||= 'Internal';
eval "require RT::URI::freeside::${RT::URI::freeside::IntegrationType}";
warn $@ if $@;
if ($@ &&
    $@ !~ qr(^Can't locate RT/URI/freeside/${RT::URI::freeside::IntegrationType}.pm)) {
  die $@;
};

=item AgentName

Return the name of the customer's agent.

=cut

sub AgentName { undef }

=item CustomerClass

Return the name of the customer's class.

=cut

sub CustomerClass { undef }

=item CustomerTags

Return the list of tags attached to the customer.  Each tag is returned
as a hashref with keys "name", "desc", and "color".

=cut

sub CustomerTags { ( ) }

=back

=cut

1;
