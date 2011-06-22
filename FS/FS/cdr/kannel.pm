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
                            $row =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) ([A-Za-z ]+) (\[SMSC:\w+\] \[SVC:\w*\] \[ACT:\w*\] \[BINF:\w*\] \[FID:\w*\]) \[from:(\s|)(|\+)(\d+)\] \[to:(|\+)(\d+)\] (\[flags:.*?\]) \[msg:(\d+):(.*?)\] (\[udh:.*?\])$/;
                        $row = "$1,$2,$3,$6,$8,$9,$10,$12";
                        $row;
                     },
  'import_fields' => [
        _cdr_date_parser_maker('startdate'),
        'disposition',
        'userfield', # [SMSC: ... FID...], five fields
        'src',
        'dst',

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
