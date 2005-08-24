package FS::cust_main_county;

use strict;
use vars qw( @ISA @EXPORT_OK $conf
             @cust_main_county %cust_main_county $countyflag );
use Exporter;
use FS::Record qw( qsearch );

@ISA = qw( FS::Record );
@EXPORT_OK = qw( regionselector );

@cust_main_county = ();
$countyflag = '';

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_main_county'} = sub { 
  $conf = new FS::Conf;
};

=head1 NAME

FS::cust_main_county - Object methods for cust_main_county objects

=head1 SYNOPSIS

  use FS::cust_main_county;

  $record = new FS::cust_main_county \%hash;
  $record = new FS::cust_main_county { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  ($county_html, $state_html, $country_html) =
    FS::cust_main_county::regionselector( $county, $state, $country );

=head1 DESCRIPTION

An FS::cust_main_county object represents a tax rate, defined by locale.
FS::cust_main_county inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item taxnum - primary key (assigned automatically for new tax rates)

=item state

=item county

=item country

=item tax - percentage

=item taxclass

=item exempt_amount

=item taxname - if defined, printed on invoices instead of "Tax"

=item setuptax - if 'Y', this tax does not apply to setup fees

=item recurtax - if 'Y', this tax does not apply to recurring fees

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax rate.  To add the tax rate to the database, see L<"insert">.

=cut

sub table { 'cust_main_county'; }

=item insert

Adds this tax rate to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this tax rate from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid tax rate.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  $self->exempt_amount(0) unless $self->exempt_amount;

  $self->ut_numbern('taxnum')
    || $self->ut_anything('state')
    || $self->ut_textn('county')
    || $self->ut_text('country')
    || $self->ut_float('tax')
    || $self->ut_textn('taxclass') # ...
    || $self->ut_money('exempt_amount')
    || $self->ut_textn('taxname')
    || $self->ut_enum('setuptax', [ '', 'Y' ] )
    || $self->ut_enum('recurtax', [ '', 'Y' ] )
    || $self->SUPER::check
    ;

}

sub taxname {
  my $self = shift;
  if ( $self->dbdef_table->column('taxname') ) {
    return $self->setfield('taxname', $_[0]) if @_;
    return $self->getfield('taxname');
  }  
  return '';
}

sub setuptax {
  my $self = shift;
  if ( $self->dbdef_table->column('setuptax') ) {
    return $self->setfield('setuptax', $_[0]) if @_;
    return $self->getfield('setuptax');
  }  
  return '';
}

sub recurtax {
  my $self = shift;
  if ( $self->dbdef_table->column('recurtax') ) {
    return $self->setfield('recurtax', $_[0]) if @_;
    return $self->getfield('recurtax');
  }  
  return '';
}

=back

=head1 SUBROUTINES

=over 4

=item regionselector [ COUNTY STATE COUNTRY [ PREFIX [ ONCHANGE [ DISABLED ] ] ] ]

=cut

sub regionselector {
  my ( $selected_county, $selected_state, $selected_country,
       $prefix, $onchange, $disabled ) = @_;

  $prefix = '' unless defined $prefix;

  $countyflag = 0;

#  unless ( @cust_main_county ) { #cache 
    @cust_main_county = qsearch('cust_main_county', {} );
    foreach my $c ( @cust_main_county ) {
      $countyflag=1 if $c->county;
      #push @{$cust_main_county{$c->country}{$c->state}}, $c->county;
      $cust_main_county{$c->country}{$c->state}{$c->county} = 1;
    }
#  }
  $countyflag=1 if $selected_county;

  my $script_html = <<END;
    <SCRIPT>
    function opt(what,value,text) {
      var optionName = new Option(text, value, false, false);
      var length = what.length;
      what.options[length] = optionName;
    }
    function ${prefix}country_changed(what) {
      country = what.options[what.selectedIndex].text;
      for ( var i = what.form.${prefix}state.length; i >= 0; i-- )
          what.form.${prefix}state.options[i] = null;
END
      #what.form.${prefix}state.options[0] = new Option('', '', false, true);

  foreach my $country ( sort keys %cust_main_county ) {
    $script_html .= "\nif ( country == \"$country\" ) {\n";
    foreach my $state ( sort keys %{$cust_main_county{$country}} ) {
      ( my $dstate = $state ) =~ s/[\n\r]//g;
      my $text = $dstate || '(n/a)';
      $script_html .= qq!opt(what.form.${prefix}state, "$dstate", "$text");\n!;
    }
    $script_html .= "}\n";
  }

  $script_html .= <<END;
    }
    function ${prefix}state_changed(what) {
END

  if ( $countyflag ) {
    $script_html .= <<END;
      state = what.options[what.selectedIndex].text;
      country = what.form.${prefix}country.options[what.form.${prefix}country.selectedIndex].text;
      for ( var i = what.form.${prefix}county.length; i >= 0; i-- )
          what.form.${prefix}county.options[i] = null;
END

    foreach my $country ( sort keys %cust_main_county ) {
      $script_html .= "\nif ( country == \"$country\" ) {\n";
      foreach my $state ( sort keys %{$cust_main_county{$country}} ) {
        $script_html .= "\nif ( state == \"$state\" ) {\n";
          #foreach my $county ( sort @{$cust_main_county{$country}{$state}} ) {
          foreach my $county ( sort keys %{$cust_main_county{$country}{$state}} ) {
            my $text = $county || '(n/a)';
            $script_html .=
              qq!opt(what.form.${prefix}county, "$county", "$text");\n!;
          }
        $script_html .= "}\n";
      }
      $script_html .= "}\n";
    }
  }

  $script_html .= <<END;
    }
    </SCRIPT>
END

  my $county_html = $script_html;
  if ( $countyflag ) {
    $county_html .= qq!<SELECT NAME="${prefix}county" onChange="$onchange" $disabled>!;
    $county_html .= '</SELECT>';
  } else {
    $county_html .=
      qq!<INPUT TYPE="hidden" NAME="${prefix}county" VALUE="$selected_county">!;
  }

  my $state_html = qq!<SELECT NAME="${prefix}state" !.
                   qq!onChange="${prefix}state_changed(this); $onchange" $disabled>!;
  foreach my $state ( sort keys %{ $cust_main_county{$selected_country} } ) {
    my $text = $state || '(n/a)';
    my $selected = $state eq $selected_state ? 'SELECTED' : '';
    $state_html .= qq(\n<OPTION $selected VALUE="$state">$text</OPTION>);
  }
  $state_html .= '</SELECT>';

  $state_html .= '</SELECT>';

  my $country_html = qq!<SELECT NAME="${prefix}country" !.
                     qq!onChange="${prefix}country_changed(this); $onchange" $disabled>!;
  my $countrydefault = $conf->config('countrydefault') || 'US';
  foreach my $country (
    sort { ($b eq $countrydefault) <=> ($a eq $countrydefault) or $a cmp $b }
      keys %cust_main_county
  ) {
    my $selected = $country eq $selected_country ? ' SELECTED' : '';
    $country_html .= qq(\n<OPTION$selected VALUE="$country">$country</OPTION>");
  }
  $country_html .= '</SELECT>';

  ($county_html, $state_html, $country_html);

}

=back

=head1 BUGS

regionselector?  putting web ui components in here?  they should probably live
somewhere else...

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

