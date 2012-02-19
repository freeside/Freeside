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
#
use strict;
no warnings qw(redefine);

#use vars qw($conf);

use FS;
use FS::UID qw(dbh);
use FS::CGI qw(popurl);
use FS::UI::Web::small_custview;
use FS::Conf;
use FS::Record qw(qsearchs qsearch dbdef);
use FS::cust_main;
use FS::cust_svc;
use FS::payby;

=head1 NAME

RT::URI::freeside::Internal

=head1 DESCRIPTION

Overlay for the RT::URI::freeside URI handler implementing the Internal integration type.

See L<RT::URI::freeside> for public/private interface documentation.

=cut



sub _FreesideGetRecord {

  my $self = shift;
  my ($table, $pkey) = ($self->{'fstable'}, $self->{'fspkey'});

  $RT::Logger->debug("Called _FreesideGetRecord()");

  #eval "use FS::$table;";

  my $dbdef = dbdef;
  unless ($dbdef) {
    $RT::Logger->error("Using Internal freeside integration type, ".
                       "but it doesn't look like we're running under ".
                       "freeside's Mason handler.");
    return;
  }

  my $pkeyfield = $dbdef->table($table)->primary_key;
  unless ($pkeyfield) {
    $RT::Logger->error("No primary key for freeside table '$table'");
    return;
  }

  my $fsrec = qsearchs($table, { $pkeyfield => $pkey });
  unless ($fsrec) {
    $RT::Logger->error("Record with '$pkeyfield' == '$pkey' does " .
                       "not exist in table $table");
    return;
  }

  return { $fsrec->hash, '_object' => $fsrec };

}

sub FreesideVersion {

  return $FS::VERSION;

}

sub FreesideGetConfig {

  #$conf = new FS::Conf unless ref($conf);
  my $conf = new FS::Conf;

  return scalar($conf->config(@_));

}

sub smart_search { #Subroutine

  return map { { $_->hash } } &FS::cust_main::Search::smart_search(@_);

}

sub email_search { #Subroutine

  return map { { $_->hash } } &FS::cust_main::Search::email_search(@_);

}

sub small_custview {

  return &FS::UI::Web::small_custview::small_custview(@_);

}

sub _FreesideURILabelLong {

  my $self = shift;

  my $table = $self->{'fstable'};

  if ( $table eq 'cust_main' ) {

    my $rec = $self->_FreesideGetRecord();
    return small_custview( $rec->{'_object'},
                           scalar(FS::Conf->new->config('countrydefault')),
                           1 #nobalance
                         );

  } else {

    return $self->_FreesideURILabel();

  }

}

# no need to have a separate wrapper method for every one of these things
sub CustomerInfo {
  my $self = shift;
  my $rec = $self->_FreesideGetRecord() or return;
  my $cust_main = $rec->{'_object'};
  my $agent = $cust_main->agent;
  my $class = $cust_main->cust_class;
  my $referral = qsearchs('part_referral', { refnum => $cust_main->refnum });
  my @part_tags = $cust_main->part_tag;

  return $self->{CustomerInfo} ||= {
    $cust_main->hash,

    AgentName     => ($agent ? ($agent->agentnum.': '.$agent->agent) : ''),
    CustomerClass => ($class ? $class->classname : ''),
    CustomerTags  => [
      sort { $a->{'name'} <=> $b->{'name'} }
      map { 
        { name => $_->tagname, desc => $_->tagdesc, color => $_->tagcolor }
      } @part_tags
    ],
    Referral      => ($referral ? $referral->referral : ''),
    InvoiceEmail  => $cust_main->invoicing_list_emailonly_scalar,
    BillingType   => FS::payby->longname($cust_main->payby),
  }
}

1;
