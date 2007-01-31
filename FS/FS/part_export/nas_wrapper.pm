package FS::part_export::nas_wrapper;

=head1 FS::part_export::nas_wrapper

This is a meta-export that triggers other exports for FS::svc_broadband objects
based on a set of configurable conditions.  These conditions are defined by the
following FS::router virtual fields:

=over 4

=item nas_conf - Per-router meta-export configuration.  See L</"nas_conf Syntax">.

=back

=head2 nas_conf Syntax

export_name|routernum[,routernum]|[field,condition[,field,condition]][||...]

=over 4

=item export_name - Name or exportnum of the export to be executed.  In order to specify export options you must use the exportnum form.  (ex. 'router' for FS::part_export::router).

=item routernum - FS::router routernum corresponding to the desired FS::router for which this export will be run.

=item field - FS::svc_broadband field (real or virtual).  The following condition (regex) will be matched against the value of this field.

=item condition - A regular expression to be match against the value of the previously listed FS::svc_broadband field.

=back

If multiple routernum's are specified, then the export will be triggered for each router listed.  If multiple field/condition pairs are present, then the results of the matches will be and'd.  Note that if a false match is found, the rest of the matches may not be checked.

You can specify multiple export/router/condition sets by concatenating them with '||'.

=cut

use strict;
use vars qw(@ISA %info $me $DEBUG);

use FS::Record qw(qsearchs);
use FS::part_export;

use Tie::IxHash;
use Data::Dumper qw(Dumper);

@ISA = qw(FS::part_export);
$me = '[' . __PACKAGE__ . ']';
$DEBUG = 1;

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'A meta-export that triggers other svc_broadband exports.',
  'options' => {},
  'notes'   => '',
);


sub rebless { shift; }

sub _export_insert {
  my($self) = shift;
  $self->_export_command('insert', @_);
}

sub _export_delete {
  my($self) = shift;
  $self->_export_command('delete', @_);
}

sub _export_suspend {
  my($self) = shift;
  $self->_export_command('suspend', @_);
}

sub _export_unsuspend {
  my($self) = shift;
  $self->_export_command('unsuspend', @_);
}

sub _export_replace {
  my($self) = shift;
  $self->_export_command('replace', @_);
}

sub _export_command {
  my ( $self, $action, $svc_broadband) = (shift, shift, shift);

  my ($new, $old);
  if ($action eq 'replace') {
    $new = $svc_broadband;
    $old = shift;
  }

  my $router = $svc_broadband->addr_block->router;

  return '' unless grep(/^nas_conf$/, $router->fields);
  my $nas_conf = $router->nas_conf;

  my $child_exports = &_parse_nas_conf($nas_conf);

  my $error = '';

  my $queue_child_exports = {};

  # Similar to FS::svc_Common::replace, calling insert, delete, and replace
  # exports where necessary depending on which conditions match.
  if ($action eq 'replace') {

    my @new_child_exports = ();
    my @old_child_exports = ();

    # Find all the matching "new" child exports.
    foreach my $child_export (@$child_exports) {
      my $match = &_test_child_export_conditions(
        $child_export->{'conditions'},
        $new,
      );

      if ($match) {
	push @new_child_exports, $child_export;
      }
    }

    # Find all the matching "old" child exports.
    foreach my $child_export (@$child_exports) {
      my $match = &_test_child_export_conditions(
        $child_export->{'conditions'},
        $old,
      );

      if ($match) {
	push @old_child_exports, $child_export;
      }
    }

    # Insert exports for new.
    push @{$queue_child_exports->{'insert'}}, (
      map { 
	my $new_child_export = $_;
	if (! grep { $new_child_export eq $_ } @old_child_exports) {
	  $new_child_export->{'args'} = [ $new ];
	  $new_child_export;
	} else {
	  ();
	}
      } @new_child_exports
    );

    # Replace exports for new and old.
    push @{$queue_child_exports->{'replace'}}, (
      map { 
	my $new_child_export = $_;
	if (grep { $new_child_export eq $_ } @old_child_exports) {
	  $new_child_export->{'args'} = [ $new, $old ];
	  $new_child_export;
	} else {
	  ();
	}
      } @new_child_exports
    );

    # Delete exports for old.
    push @{$queue_child_exports->{'delete'}}, (
      grep { 
	my $old_child_export = $_;
	if (! grep { $old_child_export eq $_ } @new_child_exports) {
	  $old_child_export->{'args'} = [ $old ];
	  $old_child_export;
	} else {
	  ();
	}
      } @old_child_exports
    );

  } else {

    foreach my $child_export (@$child_exports) {
      my $match = &_test_child_export_conditions(
        $child_export->{'conditions'},
        $svc_broadband,
      );

      if ($match) {
	$child_export->{'args'} = [ $svc_broadband ];
        push @{$queue_child_exports->{$action}}, $child_export;
      }
    }

  }

  warn "[debug]$me Dispatching child exports... "
    . &Dumper($queue_child_exports);

  # Actually call the child exports now, with their preset action and arguments.
  foreach my $_action (keys(%$queue_child_exports)) {

    foreach my $_child_export (@{$queue_child_exports->{$_action}}) {
      $error = &_dispatch_child_export(
        $_child_export,
        $_action,
        @{$_child_export->{'args'}},
      );

      # Bail if there's an error queueing one of the exports.
      # This will all get rolled-back.
      return $error if $error;
    }

  }

  return '';

}


sub _parse_nas_conf {

  my $nas_conf = shift;
  my @child_exports = ();

  foreach my $cond_set ($nas_conf =~ m/(.*?[^\\])(?:\|\||$)/g) {

    warn "[debug]$me cond_set is '$cond_set'" if $DEBUG;

    my @args = $cond_set =~ m/(.*?[^\\])(?:\||$)/g;

    my %child_export = (
      'export' => $args[0],
      'routernum' => [ split(/,\s*/, $args[1]) ],
      'conditions' => { @args[2..$#args] },
    );

    warn "[debug]$me " . Dumper(\%child_export) if $DEBUG;

    push @child_exports, { %child_export };

  }

  return \@child_exports;

}

sub _dispatch_child_export {

  my ($child_export, $action, @args) = (shift, shift, @_);

  my $child_export_name = $child_export->{'export'};
  my @routernums = @{$child_export->{'routernum'}};

  my $error = '';

  # And the real hack begins...

  my $child_part_export;
  if ($child_export_name =~ /^(\d+)$/) {
    my $exportnum = $1;
    $child_part_export = qsearchs('part_export', { exportnum => $exportnum });
    unless ($child_part_export) {
      return "No such FS::part_export with exportnum '$exportnum'";
    }

    $child_export_name = $child_part_export->exporttype;
  } else {
    $child_part_export = new FS::part_export {
      'exporttype' => $child_export_name,
      'machine' => 'bogus',
    };
  }

  warn "[debug]$me running export '$child_export_name' for routernum(s) '"
    . join(',', @routernums) . "'" if $DEBUG;

  my $cmd_method = "_export_$action";

  foreach my $routernum (@routernums) {
    $error ||= $child_part_export->$cmd_method(
      @args,
      'routernum' => $routernum,
    );
    last if $error;
  }

  warn "[debug]$me export '$child_export_name' returned '$error'"
    if $DEBUG;

  return $error;

}

sub _test_child_export_conditions {

  my ($conditions, $svc_broadband) = (shift, shift);

  my $match = 1;
  foreach my $cond_field (keys %$conditions) {
    my $cond_regex = $conditions->{$cond_field};
    warn "[debug]$me Condition: $cond_field =~ /$cond_regex/" if $DEBUG;
    unless ($svc_broadband->get($cond_field) =~ /$cond_regex/) {
      $match = 0;
      last;
    }
  }

  return $match;

}


1;

