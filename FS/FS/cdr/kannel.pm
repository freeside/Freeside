package FS::cdr::kannel;

use strict;
use vars qw( @ISA %info );
use FS::cdr qw( _cdr_date_parser_maker );

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Kannel',
  'weight'        => 25,
  'header'        => 1,
  'type'          => 'csv',
  'row_callback'  => sub { my $row = shift;
                        return ' ' if $row =~ /.*Log (begins|ends)$/;
                        die "invalid row format for '$row'" unless
                            $row =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) ([A-Za-z ]+) (\[SMSC:\w+\] \[SVC:\w*\] \[ACT:\w*\] \[BINF:\w*\] \[FID:\w*\]) \[from:(.*?)\] \[to:(.*?)\] (\[flags:.*?\]) \[msg:(\d+):.*?\] (\[udh:.*?\])$/;
                        $row = "$1,$2,$3,$4,$5,$6,$7,$8";
                        $row;
                     },
  'import_fields' => [
        _cdr_date_parser_maker('startdate'),
        'disposition',
        'userfield', # [SMSC: ... FID...], five fields

        sub {
            my($cdr, $src) = @_;
            $src =~ s/[^\+\d]//g; 
            $src =~ /^(\+|)(\d+)$/ 
                or die "unparsable number: $src"; #maybe we shouldn't die...
            $cdr->src("$1$2");
        },
        
        sub {
            my($cdr, $dst) = @_;
            $dst =~ s/[^\+\d]//g; 
            $dst =~ /^(\+|)(\d+)$/ 
                or die "unparsable number: $dst"; #maybe we shouldn't die...
            $cdr->dst("$1$2");
        },

        sub { my($cdr, $flags) = @_;
            $cdr->userfield($cdr->userfield." $flags");
        },

        # setting billsec to the msg length as we need billsec set non-zero
        'billsec', 

        sub { my($cdr, $udh) = @_;
            $cdr->userfield($cdr->userfield." $udh");
        },
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
