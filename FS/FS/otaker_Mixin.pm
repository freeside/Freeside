package FS::otaker_Mixin;

use strict;
use Carp qw( croak ); #confess );
use FS::Record qw( qsearch qsearchs );
use FS::access_user;

sub otaker {
  my $self = shift;
  if ( scalar(@_) ) { #set
    my $otaker = shift;
    my $access_user = qsearchs('access_user', { 'username' => $otaker } );
    if ( !$access_user && $otaker =~ /^(.+), (.+)$/ ) { #same as below..
      my($lastname, $firstname) = ($1, $2);
      $otaker = lc($firstname.$lastname);
      $access_user =  qsearchs('access_user', { 'first' => $firstname, 
                                                'last'  => $lastname  } )
                   || qsearchs('access_user', { 'username' => $otaker } );
    }
    croak "can't set otaker: $otaker not found!" unless $access_user; #confess?
    $self->usernum( $access_user->usernum );
    $otaker; #not sure return is used anywhere, but just in case
  } else { #get
    if ( $self->usernum ) {
      $self->access_user->username;
    } elsif ( length($self->get('otaker')) ) {
      $self->get('otaker');
    } else {
      '';
    }
  }
}

sub access_user {
  my $self = shift;
  qsearchs('access_user', { 'usernum' => $self->usernum } );
}

sub _upgrade_otaker {
  my $class = shift;
  my $table = $class->table;

  my $limit = ( $table eq 'cust_attachment' ? 10 : 1000 );

  while ( 1 ) {
    my @records = qsearch({
                    'table'     => $table,
                    'hashref'   => {},
                    'extra_sql' => "WHERE otaker IS NOT NULL LIMIT $limit",
                  });
    last unless @records;

    foreach my $record (@records) {
      eval { $record->otaker($record->otaker) };
      if ( $@ ) {
        my $username = $record->otaker;
        my($lastname, $firstname) = ( 'User', 'Legacy' );
        if ( $username =~ /^(.+), (.+)$/ ) {
          ($lastname, $firstname) = ($1, $2);
          $username = lc($firstname.$lastname);
        }
        my $access_user = new FS::access_user {
          'username'  => $username,
          '_password' => 'CHANGEME',
          'first'     => $firstname,
          'last'      => $lastname,
          'disabled'  => 'Y',
        };
        my $error = $access_user->insert;
        die $error if $error;
        $record->otaker($record->otaker);
      }
      $record->set('otaker', '');
      my $error = $record->replace;
      die $error if $error;
    }

  }

}

1;
