package FS::svc_domain;

use strict;
use vars qw(@ISA @EXPORT_OK $whois_hack $conf $mydomain $smtpmachine);
use Exporter;
use Carp;
use Mail::Internet;
use Mail::Header;
use Date::Format;
use FS::Record qw(fields qsearch qsearchs);
use FS::cust_svc;
use FS::Conf;

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

$conf = new FS::Conf;

$mydomain = $conf->config('domain');
$smtpmachine = $conf->config('smtpmachine');

my($internic)="/var/spool/freeside/conf/registries/internic";
my($conf_tech)="$internic/tech_contact";
my($conf_from)="$internic/from";
my($conf_to)="$internic/to";
my($nameservers)="$internic/nameservers";
my($template)="$internic/template";

open(TECH_CONTACT,$conf_tech) or die "Can't open $conf_tech: $!";
my($tech_contact)=map {
  /^(.*)$/ or die "Illegal line in $conf_tech!"; #yes, we trust the file
  $1;
} grep $_ !~ /^(#|$)/, <TECH_CONTACT>;
close TECH_CONTACT;

open(FROM,$conf_from) or die "Can't open $conf_from: $!";
my($from)=map {
  /^(.*)$/ or die "Illegal line in $conf_from!"; #yes, we trust the file
  $1;
} grep $_ !~ /^(#|$)/, <FROM>;
close FROM;

open(TO,$conf_to) or die "Can't open $conf_to: $!";
my($to)=map {
  /^(.*)$/ or die "Illegal line in $conf_to!"; #yes, we trust the file
  $1;
} grep $_ !~ /^(#|$)/, <TO>;
close TO;

open(NAMESERVERS,$nameservers) or die "Can't open $nameservers: $!";
my(@nameservers)=map {
  /^\s*\d+\.\d+\.\d+\.\d+\s+([^\s]+)\s*$/
    or die "Illegal line in $nameservers!"; #yes, we trust the file
  $1;
} grep $_ !~ /^(#|$)/, <NAMESERVERS>;
close NAMESERVERS;
open(NAMESERVERS,$nameservers) or die "Can't open $nameservers: $!";
my(@nameserver_ips)=map {
  /^\s*(\d+\.\d+\.\d+\.\d+)\s+([^\s]+)\s*$/
    or die "Illegal line in $nameservers!"; #yes, we trust the file
  $1;
} grep $_ !~ /^(#|$)/, <NAMESERVERS>;
close NAMESERVERS;

open(TEMPLATE,$template) or die "Can't open $template: $!";
my(@template)=map {
  /^(.*)$/ or die "Illegal line in $to!"; #yes, we trust the file
  $1. "\n";
} <TEMPLATE>;
close TEMPLATE;

=head1 NAME

FS::svc_domain - Object methods for svc_domain records

=head1 SYNOPSIS

  use FS::svc_domain;

  $record = create FS::svc_domain \%hash;
  $record = create FS::svc_domain { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_domain object represents a domain.  FS::svc_domain inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatically for new accounts)

=item domain

=back

=head1 METHODS

=over 4

=item create HASHREF

Creates a new domain.  To add the domain to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('svc_domain')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('svc_domain',$hashref);

}

=item insert

Adds this domain to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields I<pkgnum> and I<svcpart> (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

The additional field I<action> should be set to I<N> for new domains or I<M>
for transfers.

A registration or transfer email will be submitted unless
$FS::svc_domain::whois_hack is true.

The additional field I<email> can be used to manually set the admin contact
email address on this email.  Otherwise, the svc_acct records for this package 
(see L<FS::cust_pkg>) are searched.  If there is exactly one svc_acct record
in the same package, it is automatically used.  Otherwise an error is returned.

=cut

sub insert {
  my($self)=@_;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error=$self->check;
  return $error if $error;

  return "Domain in use (here)"
    if qsearchs('svc_domain',{'domain'=> $self->domain } );

  my($whois)=(($self->_whois)[0]);
  return "Domain in use (see whois)"
    if ( $self->action eq "N" && $whois !~ /^No match for/ );
  return "Domain not found (see whois)"
    if ( $self->action eq "M" && $whois =~ /^No match for/ );

  my($svcnum)=$self->getfield('svcnum');
  my($cust_svc);
  unless ( $svcnum ) {
    $cust_svc=create FS::cust_svc ( {
      'svcnum'  => $svcnum,
      'pkgnum'  => $self->getfield('pkgnum'),
      'svcpart' => $self->getfield('svcpart'),
    } );
    my($error) = $cust_svc->insert;
    return $error if $error;
    $svcnum = $self->setfield('svcnum',$cust_svc->getfield('svcnum'));
  }

  $error = $self->add;
  if ($error) {
    $cust_svc->del if $cust_svc;
    return $error;
  }

  $self->submit_internic unless $whois_hack;

  ''; #no error
}

=item delete

Deletes this domain from the database.  If there is an error, returns the
error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

=cut

sub delete {
  my($self)=@_;
  my($error);

  my($svcnum)=$self->getfield('svcnum');
  
  $error = $self->del;
  return $error if $error;

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum});  
  $error = $cust_svc->del;
  return $error if $error;

  '';
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  my($error);

  return "(Old) Not a svc_domain record!" unless $old->table eq "svc_domain";
  return "Can't change svcnum!"
    unless $old->getfield('svcnum') eq $new->getfield('svcnum');

  return "Can't change domain - reorder."
    if $old->getfield('domain') ne $new->getfield('domain'); 

  $error=$new->check;
  return $error if $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error = $new->rep($old);
  return $error if $error;

  '';

}

=item suspend

Just returns false (no error) for now.

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub suspend {
  ''; #no error (stub)
}

=item unsuspend

Just returns false (no error) for now.

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub unsuspend {
  ''; #no error (stub)
}

=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub cancel {
  ''; #no error (stub)
}

=item check

Checks all fields to make sure this is a valid domain.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my($self)=@_;
  return "Not a svc_domain record!" unless $self->table eq "svc_domain";
  my($recref) = $self->hashref;

  $recref->{svcnum} =~ /^(\d*)$/ or return "Illegal svcnum";
  $recref->{svcnum} = $1;

  #get part_svc (and pkgnum)
  my($svcpart,$pkgnum);
  my($svcnum)=$self->getfield('svcnum');
  if ($svcnum) {
    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum});
    return "Unknown svcnum" unless $cust_svc; 
    $svcpart=$cust_svc->svcpart;
    $pkgnum=$cust_svc->pkgnum;
  } else {
    $svcpart=$self->svcpart;
    $pkgnum=$self->pkgnum;
  }
  my($part_svc)=qsearchs('part_svc',{'svcpart'=>$svcpart});
  return "Unkonwn svcpart" unless $part_svc;

  #set fixed fields from part_svc
  my($field);
  foreach $field ( fields('svc_acct') ) {
    if ( $part_svc->getfield('svc_domain__'. $field. '_flag') eq 'F' ) {
      $self->setfield($field,$part_svc->getfield('svc_domain__'. $field) );
    }
  }

  unless ( $whois_hack ) {
    unless ( $self->email ) { #find out an email address
      my(@svc_acct);
      foreach ( qsearch('cust_svc',{'pkgnum'=>$pkgnum}) ) {
        my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$_->svcnum});
        push @svc_acct, $svc_acct if $svc_acct;
      }

      if ( scalar(@svc_acct) == 0 ) {
        return "Must order an account in package ". $pkgnum. " first";
      } elsif ( scalar(@svc_acct) > 1 ) {
        return "More than one account in package ". $pkgnum. ": specify admin contact email";
      } else {
        $self->email($svc_acct[0]->username. '@'. $mydomain);
      }
    }
  }

  #if ( $recref->{domain} =~ /^([\w\-\.]{1,22})\.(com|net|org|edu)$/ ) {
  if ( $recref->{domain} =~ /^([\w\-]{1,22})\.(com|net|org|edu)$/ ) {
    $recref->{domain} = "$1.$2";
  # hmmmmmmmm.
  } elsif ( $whois_hack && $recref->{domain} =~ /^([\w\-\.]+)$/ ) {
    $recref->{domain} = $1;
  } else {
    return "Illegal domain ". $recref->{domain}.
           " (or unknown registry - try \$whois_hack)";
  }

  $recref->{action} =~ /^(M|N)$/ or return "Illegal action";
  $recref->{action} = $1;

  $self->ut_textn('purpose');

}

=item _whois

Executes the command:

  whois do $domain

and returns the output.

(Always returns I<No match for domian "$domain".> if
$FS::svc_domain::whois_hack is set true.)

=cut

sub _whois {
  my($self)=@_;
  my($domain)=$self->domain;
  return ( "No match for domain \"$domain\"." ) if $whois_hack;
  open(WHOIS,"whois do $domain |");
  return <WHOIS>;
}

=item submit_internic

Submits a registration email for this domain.

=cut

sub submit_internic {
  my($self)=@_;

  my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$self->pkgnum});
  return unless $cust_pkg;
  my($cust_main)=qsearchs('cust_main',{'custnum'=>$cust_pkg->custnum});
  return unless $cust_main;

  my(%subs)=(
    'action'       => $self->action,
    'purpose'      => $self->purpose,
    'domain'       => $self->domain,
    'company'      => $cust_main->company 
                        || $cust_main->getfield('first'). ' '.
                           $cust_main->getfield('last')
                      ,
    'city'         => $cust_main->city,
    'state'        => $cust_main->state,
    'zip'          => $cust_main->zip,
    'country'      => $cust_main->country,
    'last'         => $cust_main->getfield('last'),
    'first'        => $cust_main->getfield('first'),
    'daytime'      => $cust_main->daytime,
    'fax'          => $cust_main->fax,
    'email'        => $self->email,
    'tech_contact' => $tech_contact,
    'primary'      => shift @nameservers,
    'primary_ip'   => shift @nameserver_ips,
  );

  #yuck
  my(@xtemplate)=@template;
  my(@body);
  my($line);
  OLOOP: while ( defined($line = shift @xtemplate) ) {

    if ( $line =~ /^###LOOP###$/ ) {
      my(@buffer);
      LOADBUF: while ( defined($line = shift @xtemplate) ) {
        last LOADBUF if ( $line =~ /^###ENDLOOP###$/ );
        push @buffer, $line;
      }
      my(%lubs)=(
        'address'      => $cust_main->address2 
                            ? [ $cust_main->address1, $cust_main->address2 ]
                            : [ $cust_main->address1 ]
                          ,
        'secondary'    => [ @nameservers ],
        'secondary_ip' => [ @nameserver_ips ],
      );
      LOOP: while (1) {
        my(@xbuffer)=@buffer;
        SUBLOOP: while ( defined($line = shift @xbuffer) ) {
          if ( $line =~ /###(\w+)###/ ) {
            #last LOOP unless my($lub)=shift@{$lubs{$1}};
            next OLOOP unless my $lub = shift @{$lubs{$1}};
            $line =~ s/###(\w+)###/$lub/e;
            redo SUBLOOP;
          } else {
            push @body, $line;
          }
        } #SUBLOOP
      } #LOOP

    }

    if ( $line =~ /###(\w+)###/ ) {
      #$line =~ s/###(\w+)###/$subs{$1}/eg;
      $line =~ s/###(\w+)###/$subs{$1}/e;
      redo OLOOP;
    } else {
      push @body, $line;
    }

  } #OLOOP

  my($subject);
  if ( $self->action eq "M" ) {
    $subject = "MODIFY DOMAIN ". $self->domain;
  } elsif ($self->action eq "N" ) { 
    $subject = "NEW DOMAIN ". $self->domain;
  } else {
    croak "submit_internic called with action ". $self->action;
  }

  $ENV{SMTPHOSTS}=$smtpmachine;
  $ENV{MAILADDRESS}=$from;
  my($header)=Mail::Header->new( [
    "From: $from",
    "To: $to",
    "Sender: $from",
    "Reply-To: $from",
    "Date: ". time2str("%a, %d %b %Y %X %z",time),
    "Subject: $subject",
  ] );

  my($msg)=Mail::Internet->new(
    'Header' => $header,
    'Body' => \@body,
  );

  $msg->smtpsend or die "Can't send registration email"; #die? warn?

}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

All BIND/DNS fields should be included (and exported).

All registries should be supported.

Not all configuration access is through FS::Conf!

Should change action to a real field.

=head1 SEE ALSO

L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>,
L<FS::SSH>, L<ssh>, L<dot-qmail>, schema.html from the base documentation,
config.html from the base documentation.

=head1 VERSION

$Id: svc_domain.pm,v 1.2 1998-10-14 08:18:21 ivan Exp $

=head1 HISTORY

ivan@voicenet.com 97-jul-21

rewrite ivan@sisd.com 98-mar-10

add internic bits ivan@sisd.com 98-mar-14

Changed 'day' to 'daytime' because Pg6.3 reserves the day word
	bmccane@maxbaud.net	98-apr-3

/var/spool/freeside/conf/registries/internic/, Mail::Internet, etc.
ivan@sisd.com 98-jul-17-19

pod, some FS::Conf (not complete) ivan@sisd.com 98-sep-23

$Log: svc_domain.pm,v $
Revision 1.2  1998-10-14 08:18:21  ivan
More informative error messages and better doc for admin contact email stuff


=cut

1;


