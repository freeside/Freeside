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

use RT::URI::base;
use strict;
use vars qw(@ISA);

@ISA = qw/RT::URI::base/;


=head1 NAME

RT::URI::base

=head1 DESCRIPTION

URI handler for freeside URIs.  See http://www.sisd.com/freeside/ for
more information on freeside.

=cut


sub FreesideURIPrefix {

  my $self = shift;
  return($self->Scheme . '://freeside');

}

sub FreesideURILabel {

  my $self = shift;

  return(undef) unless (exists($self->{'fstable'}) and
                        exists($self->{'fspkey'}));

  my $label;
  my ($table, $pkey) = ($self->{'fstable'}, $self->{'fspkey'});

  eval {
    use FS::UID qw(dbh);
    use FS::Record qw(qsearchs qsearch dbdef);
    eval "use FS::$table;";
    use FS::cust_svc;

    my $dbdef = dbdef or die "No dbdef";
    my $pkeyfield = $dbdef->table($table)->primary_key
      or die "No primary key for table $table";

    my $rec = qsearchs($table, { $pkeyfield => $pkey })
      or die "Record with $pkeyfield == $pkey does not exist in table $table";

    if ($table =~ /^svc_/) {
      if ($rec->can('cust_svc')) {
        my $cust_svc = $rec->cust_svc or die '$rec->cust_svc failed';
        my ($svc, $tag, $svcdb) = $cust_svc->label;
        $label = "Freeside service ${svc}: ${tag}";
      }
    } elsif ($table eq 'cust_main') {
      my ($last, $first, $company) = map { $rec->getfield($_) }
                                         qw(last first company);
      $label = "Freeside customer ${last}, ${first}";
      $label .= ($company ne '') ? " with ${company}" : '';
    } else {
      $label = "Freeside ${table}, ${pkeyfield} == ${pkey}";
    }

    #... other cases

  };

  if ($label and !$@) {
    return($label);
  } else {
    return(undef);
  }
      

}

sub ParseURI { 
    my $self = shift;
    my $uri = shift;
    my ($table, $pkey);

    my $uriprefix = $self->FreesideURIPrefix;
    if ($uri =~ /^$uriprefix\/(\w+)\/(\d+)$/) {
      $table = $1;
      $pkey = $2;
      $self->{'scheme'} = $self->Scheme;
    } else {
      return(undef);
    }

    $self->{'uri'} = "${uriprefix}/${table}/${pkey}";
    $self->{'fstable'} = $table;
    $self->{'fspkey'} = $pkey;

    my $p;

    eval {
      use FS::UID qw(dbh);
      use FS::CGI qw(popurl);

      if (dbh) {
	$p = popurl(3);
      }

    };

    if ($@ or (!$p)) {
      $self->{'href'} = $self->{'uri'};
    } else {
      $self->{'href'} = "${p}view/${table}.cgi?${pkey}";
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

=head2 AsString

Return a "pretty" string representing the URI object.

This is meant to be used like this:

 % $re = $uri->Resolver;
 <A HREF="<% $re->HREF %>"><% $re->AsString %></A>

=cut

sub AsString {
    my $self = shift;
    my $prettystring;
    if ($prettystring = $self->FreesideURILabel) {
      return $prettystring;
    } else {
      return $self->URI;
    }
}

eval "require RT::URI::base_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI/base_Vendor.pm});
eval "require RT::URI::base_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI/base_Local.pm});

1;
