package FS::part_bill_event;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_bill_event - Object methods for part_bill_event records

=head1 SYNOPSIS

  use FS::part_bill_event;

  $record = new FS::part_bill_event \%hash;
  $record = new FS::part_bill_event { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_bill_event object represents an invoice event definition -
a callback which is triggered when an invoice is a certain amount of time
overdue.  FS::part_bill_event inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item eventpart - primary key

=item payby - CARD, DCRD, CHEK, DCHK, LECB, BILL, or COMP

=item event - event name

=item eventcode - event action

=item seconds - how long after the invoice date events of this type are triggered

=item weight - ordering for events with identical seconds

=item plan - eventcode plan

=item plandata - additional plan data

=item disabled - Disabled flag, empty or `Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice event definition.  To add the example to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_bill_event'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid invoice event definition.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->weight(0) unless $self->weight;

  my $conf = new FS::Conf;
  if ( $conf->exists('safe-part_bill_event') ) {
    my $error = $self->ut_anything('eventcode');
    return $error if $error;

    my $c = $self->eventcode;

    $c =~ /^\s*\$cust_main\->(suspend|cancel|invoicing_list_addpost|bill|collect)\(\);\s*("";)?\s*$/

      or $c =~ /^\s*\$cust_bill\->(comp|realtime_(card|ach|lec)|batch_card|send)\(\);\s*$/

      or $c =~ /^\s*\$cust_bill\->send(_if_newest)?\(\'[\w\-\s]+\'\s*(,\s*(\d+|\[\s*\d+(,\s*\d+)*\s*\])\s*,\s*'[\w\@\.\-\+]*'\s*)?\);\s*$/

      or $c =~ /^\s*\$cust_main\->apply_payments; \$cust_main->apply_credits; "";\s*$/

      or $c =~ /^\s*\$cust_main\->charge\( \s*\d*\.?\d*\s*,\s*\'[\w \!\@\#\$\%\&\(\)\-\+\;\:\"\,\.\?\/]*\'\s*\);\s*$/

      or $c =~ /^\s*\$cust_main\->suspend_(if|unless)_pkgpart\([\d\,\s]*\);\s*$/

      or do {
        #log
        return "illegal eventcode: $c";
      };

  }

  my $error = $self->ut_numbern('eventpart')
    || $self->ut_enum('payby', [qw( CARD DCRD CHEK DCHK LECB BILL COMP )] )
    || $self->ut_text('event')
    || $self->ut_anything('eventcode')
    || $self->ut_number('seconds')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_number('weight')
    || $self->ut_textn('plan')
    || $self->ut_anything('plandata')
  ;
    #|| $self->ut_snumber('seconds')
  return $error if $error;

  #quelle kludge
  if ( $self->plandata =~ /^(agent_)?templatename\s+(.*)$/m ) {
    my $name= $2;

    foreach my $file (qw( template
                          latex latexnotes latexreturnaddress latexfooter
                            latexsmallfooter
                          html htmlnotes htmlreturnaddress htmlfooter
                     ))
    {
      unless ( $conf->exists("invoice_${file}_$name") ) {
        $conf->set(
          "invoice_${file}_$name" =>
            join("\n", $conf->config("invoice_$file") )
        );
      }
    }
  }

  $self->SUPER::check;
}

=item templatename

Returns the alternate invoice template name, if any, or false if there is
no alternate template for this invoice event.

=cut

sub templatename {
  my $self = shift;
  if (    $self->plan     =~ /^send_(alternate|agent)$/
       && $self->plandata =~ /^(agent_)?templatename (.*)$/m
     )
  {
    $2;
  } else {
    '';
  }
}


=back

=head1 BUGS

The whole "eventcode" idea is bunk.  This should be refactored with subclasses
like part_pkg/ and part_export/

=head1 SEE ALSO

L<FS::cust_bill>, L<FS::cust_bill_event>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

