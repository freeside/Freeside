package FS::svc_acct_pop;

use strict;
use vars qw( @ISA @EXPORT_OK @svc_acct_pop %svc_acct_pop );
use FS::Record qw( qsearch qsearchs );

@ISA = qw( FS::Record Exporter );
@EXPORT_OK = qw( popselector );

=head1 NAME

FS::svc_acct_pop - Object methods for svc_acct_pop records

=head1 SYNOPSIS

  use FS::svc_acct_pop;

  $record = new FS::svc_acct_pop \%hash;
  $record = new FS::svc_acct_pop { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $html = FS::svc_acct_pop::popselector( $popnum, $state );

=head1 DESCRIPTION

An FS::svc_acct object represents an point of presence.  FS::svc_acct_pop
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item popnum - primary key (assigned automatically for new accounts)

=item city

=item state

=item ac - area code

=item exch - exchange

=item loc - rest of number

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new point of presence (if only it were that easy!).  To add the 
point of presence to the database, see L<"insert">.

=cut

sub table { 'svc_acct_pop'; }

=item insert

Adds this point of presence to the database.  If there is an error, returns the
error, otherwise returns false.

=item delete

Removes this point of presence from the database.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid point of presence.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

    $self->ut_numbern('popnum')
      or $self->ut_text('city')
      or $self->ut_text('state')
      or $self->ut_number('ac')
      or $self->ut_number('exch')
      or $self->ut_numbern('loc')
      or $self->SUPER::check
  ;

}

=item text

Returns:

"$city, $state ($ac)/$exch"

=cut

sub text {
  my $self = shift;
  $self->city. ', '. $self->state.
    ' ('. $self->ac. ')/'. $self->exch. '-'. $self->loc;
}

=back

=head1 SUBROUTINES

=over 4

=item popselector [ POPNUM [ STATE ] ]

=cut

#horrible false laziness with signup.cgi (pull special-case for 0 & 1
# pop code out from signup.cgi??)
sub popselector {
  my( $popnum, $state ) = @_;

  unless ( @svc_acct_pop ) { #cache pop list
    @svc_acct_pop = qsearch('svc_acct_pop', {} );
    %svc_acct_pop = ();
    push @{$svc_acct_pop{$_->state}}, $_ foreach @svc_acct_pop;
  }

  my $text = <<END;
    <SCRIPT>
    function opt(what,href,text) {
      var optionName = new Option(text, href, false, false)
      var length = what.length;
      what.options[length] = optionName;
    }
    
    function popstate_changed(what) {
      state = what.options[what.selectedIndex].text;
      what.form.popnum.options.length = 0
      what.form.popnum.options[0] = new Option("", "", false, true);
END

  foreach my $popstate ( sort { $a cmp $b } keys %svc_acct_pop ) {
    $text .= "\nif ( state == \"$popstate\" ) {\n";

    foreach my $pop ( @{$svc_acct_pop{$popstate}}) {
      my $o_popnum = $pop->popnum;
      my $poptext = $pop->text;
      $text .= "opt(what.form.popnum, \"$o_popnum\", \"$poptext\");\n"
    }
    $text .= "}\n";
  }

  $text .= "}\n</SCRIPT>\n";

  $text .=
    qq!<SELECT NAME="popstate" SIZE=1 onChange="popstate_changed(this)">!.
    qq!<OPTION> !;
  $text .= "<OPTION>$_" foreach sort { $a cmp $b } keys %svc_acct_pop;
  $text .= '</SELECT>'; #callback? return 3 html pieces?  #'</TD><TD>';

  $text .= qq!<SELECT NAME="popnum" SIZE=1><OPTION> !;
  my @initial_select;
  if ( scalar(@svc_acct_pop) > 100 ) {
    @initial_select = qsearchs( 'svc_acct_pop', { 'popnum' => $popnum } );
  } else {
    @initial_select = @svc_acct_pop;
  }
  foreach my $pop ( @initial_select ) {
    $text .= qq!<OPTION VALUE="!. $pop->popnum. '"'.
             ( ( $popnum && $pop->popnum == $popnum ) ? ' SELECTED' : '' ). ">".
             $pop->text;
  }
  $text .= '</SELECT>';

  $text;

}

=back

=head1 VERSION

$Id: svc_acct_pop.pm,v 1.10 2003-08-05 00:20:47 khoff Exp $

=head1 BUGS

It should be renamed to part_pop.

popselector?  putting web ui components in here?  they should probably live
somewhere else...  

popselector: pull special-case for 0 & 1 pop code out from signup.cgi

=head1 SEE ALSO

L<FS::Record>, L<FS::svc_acct>, L<FS::part_pop_local>, schema.html from the
base documentation.

=cut

1;

