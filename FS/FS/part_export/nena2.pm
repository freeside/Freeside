package FS::part_export::nena2;

use base 'FS::part_export::batch_Common';
use strict;
use FS::Record qw(qsearch qsearchs dbh);
use FS::svc_phone;
use FS::upload_target;
use Tie::IxHash;
use Date::Format qw(time2str);
use Parse::FixedLength;
use File::Temp qw(tempfile);
use vars qw(%info %options $initial_load_hack $DEBUG);

my %upload_targets;

tie %options, 'Tie::IxHash', (
  'company_name'    => {  label => 'Company name for header record',
                          type  => 'text',
                       },
  'company_id'      => {  label => 'NENA company ID',
                          type  => 'text',
                       },
  'customer_code'   => {  label => 'Customer code',
                          type  => 'text',
                       },
  'area_code'       => {  label => 'Default area code for 7 digit numbers',
                          type  => 'text',
                       },
  'prefix'          => {  label => 'File name prefix',
                          type  => 'text',
                       },
  'format'          => {  label => 'Format variant',
                          type  => 'select',
                          options => [ '', 'Intrado' ],
                       },
  'target'          => {  label => 'Upload destination',
                          type => 'select',
                          option_values => sub {
                            %upload_targets = 
                              map { $_->targetnum, $_->label } 
                              qsearch('upload_target');
                            sort keys (%upload_targets);
                          },
                          option_label => sub {
                            $upload_targets{$_[0]}
                          },
                        },
  'cycle_counter'   => { label => 'Cycle counter',
                         type => 'text',
                         default => '1'
                       },
  'debug'           => { label => 'Enable debugging',
                         type => 'checkbox' },
);

%info = (
  'svc'       => 'svc_phone',
  'desc'      => 'Export a NENA 2 E911 data file',
  'options'   => \%options,
  'nodomain'  => 'Y',
  'no_machine'=> 1,
  'notes'     => qq!
<p>Export the physical location of a telephone service to a NENA 2.1 file
for use by an ALI database provider.</p>
<p>Options:
<ul>
<li><b>Company name</b> is the company name that should appear in your header
and trailer records.<li>
<li><b>Company ID</b> is your <a href="http://www.nena.org/?CompanyID">NENA 
assigned company ID</a>.</li>
<li><b>File name prefix</b> is the prefix to use in your upload file names.
The rest of the file name will be the date (in mmddyy format) followed by 
".dat".</li>
<li><b>Format variant</b> is the modification of the NENA format required 
by your database provider.  We support the Intrado variant used by
Qwest/CenturyLink.  To produce a pure standard-compliant file, leave this
blank.</li>
<li><b>Upload destination</b> is the <a href="../browse/upload_target.html">
upload target</a> to send the file to.</li>
<li><b>Cycle counter</b> is the sequence number of the next batch to be sent.
This will be automatically incremented with each batch.</li>
</ul>
</p>
  !,
);

$initial_load_hack = 0; # set to 1 if running from a re-export script

# All field names and sizes are taken from the NENA-2-010 standard, May 1999 
# version.

my $item_format = Parse::FixedLength->new([ qw(
    function_code:1:1:1
    npa:3:2:4
    calling_number:7:5:11
    house_number:10:12:21
    house_number_suffix:4:22:25
    prefix_directional:2:26:27
    street_name:60:28:87
    street_suffix:4:88:91
    post_directional:2:92:93
    community_name:32:94:125
    state:2:126:127
    location:60:128:187
    customer_name:32:188:219
    class_of_service:1:220:220
    type_of_service:1:221:221
    exchange:4:222:225
    esn:5:226:230
    main_npa:3:231:233
    main_number:7:234:240
    order_number:10:241:250
    extract_date:6:251:256
    county_id:4:257:260
    company_id:5:261:265
    source_id:1:266:266
    zip_code:5:267:271
    zip_4:4:272:275
    general_use:11:276:286
    customer_code:3:287:289
    comments:30:290:319
    x_coordinate:9:320:328
    y_coordinate:9:329:337
    z_coordinate:5:338:342
    cell_id:6:343:348
    sector_id:1:349:349
    tar_code:6:350:355
    reserved:21:356:376
    alt:10:377:386
    expanded_extract_date:8:387:394
    nena_reserved:86:395:480
    dbms_reserved:31:481:511
    end_of_record:1:512:512
  )]
);

my $header_format = Parse::FixedLength->new([ qw(
    header_indicator:5:1:5
    extract_date:6:6:11
    company_name:50:12:61
    cycle_counter:6R:62:67
    county_id:4:68:71
    state:2:72:73
    general_use:20:74:93
    release_number:3:94:96
    format_version:1:97:97
    expanded_extract_date:8:98:105
    reserved:406:106:511
    end_of_record:1:512:512
  )]
);

my $trailer_format = Parse::FixedLength->new([ qw(
    trailer_indicator:5:1:5
    extract_date:6:6:11
    company_name:50:12:61
    record_count:9R:62:70
    expanded_extract_date:8:71:78
    reserved:433:79:511
    end_of_record:1:512:512
  )]
);

my %function_code = (
  'insert'    => 'I',
  'delete'    => 'D',
  'replace'   => 'C',
  'relocate'  => 'C',
);

sub immediate {

  # validate some things
  my ($self, $action, $svc) = @_;
  if ( $svc->phonenum =~ /\D/ ) {
    return "Can't export E911 information for a non-numeric phone number";
  } elsif ( $svc->phonenum =~ /^011/ ) {
    return "Can't export E911 information for a non-North American phone number";
  }
  '';
}

sub create_item {
  my $self = shift;
  my $action = shift;
  my $svc = shift;
  # pkg_change, suspend, unsuspend actions don't trigger anything here
  return '' if !exists( $function_code{$action} ); 
  if ( $action eq 'replace' ) {
    my $old = shift;
    # the one case where the old service is relevant: phone number change
    # in that case, insert a batch item to delete the old number, then 
    # continue as if this were an insert.
    if ($old->phonenum ne $svc->phonenum) {
      return $self->create_item('delete', $old)
          || $self->create_item('insert', $svc);
    }
  }
  $self->SUPER::create_item($action, $svc, @_);
}

sub data {
  local $@;
  eval "use Geo::StreetAddress::US";
  if ($@) {
    if ($@ =~ /^Can't locate/) {
      return "Geo::StreetAddress::US must be installed to use the NENA2 export.";
    } else {
      die $@;
    }
  }
  # generate the entire record here.  reconciliation of multiple updates to 
  # the same service can be done at process time.
  my $self = shift;
  my $action = shift;

  my $svc = shift;

  my $locationnum =    $svc->locationnum
                    || $svc->cust_svc->cust_pkg->locationnum;
  my $cust_location = FS::cust_location->by_key($locationnum);

  # initialize with empty strings
  my %hash = map { $_ => '' } @{ $item_format->names };

  $hash{function_code} = $function_code{$action};
  
  # Add default area code if phonenum is 7 digits
  my $phonenum = $svc->phonenum;
  if ($self->option('area_code') =~ /^\d{3}$/ && $phonenum =~ /^\d{7}$/ ){
  $phonenum = $self->option('area_code'). $svc->phonenum;
  }
 
  # phone number
  $phonenum =~ /^(\d{3})(\d*)$/;
  $hash{npa} = $1;
  $hash{calling_number} = $2;

  # street address
  # some cleanup:
  my $full_address = $cust_location->address1;
  my $address2 = $cust_location->address2;
  if (length($address2)) {
    # correct 'Sp', 'Sp.', 'sp ', etc. to the word SPACE for convenience
    $address2 =~ s/^sp\b\.? ?/SPACE /i;
    # and join it to $full_address with a space, not a comma
    $full_address .= ' ' . $address2;
  }

  my $location_hash = Geo::StreetAddress::US->parse_address(
    uc( join(', ',  $full_address,
                    $cust_location->city,
                    $cust_location->state,
                    $cust_location->zip
    ) )
  );
  if ( !$location_hash and length($address2) ) {
    # then parsing failed. Try again without the address2.
    $location_hash = Geo::StreetAddress::US->parse_address(
      uc( join(', ',
                    $cust_location->address1,
                    $cust_location->city,
                    $cust_location->state,
                    $cust_location->zip
      ) )
    );
    # this should not produce an address with sec_unit_type,
    # so 'location' will be set to address2
  }
  if ( $location_hash ) {
    # then store it
    $hash{house_number}         = $location_hash->{number};
    $hash{house_number_suffix}  = ''; # we don't support this, do we?
    $hash{prefix_directional}   = $location_hash->{prefix};
    $hash{street_name}          = $location_hash->{street};
    $hash{street_suffix}        = $location_hash->{type};
    $hash{post_directional}     = $location_hash->{suffix};
    $hash{community_name}       = $location_hash->{city};
    $hash{state}                = $location_hash->{state};
    if ($location_hash->{sec_unit_type}) {
      $hash{location} = $location_hash->{sec_unit_type} . ' ' .
                        $location_hash->{sec_unit_num};
    } else {
      $hash{location} = $address2;
    }
  } else {
    # then it still wouldn't parse; happens when the address has no house
    # number (which is allowed in NENA 2 format). so just put all the 
    # information we have into the record. (Parse::FixedLength will trim
    # it to fit if necessary.)
    $hash{street_name}    = uc($cust_location->address1);
    $hash{location}       = uc($address2);
    $hash{community_name} = uc($cust_location->city);
    $hash{state}          = uc($cust_location->state);
  }

  # customer name and class
  $hash{customer_name} = $svc->phone_name_or_cust;
  $hash{class_of_service} = $svc->e911_class;
  if (!$hash{class_of_service}) {
    # then guess
    my $cust_main = $svc->cust_main;
    if ($cust_main->company) {
      $hash{class_of_service} = '2';
    } else {
      $hash{class_of_service} = '1';
    }
  }
  $hash{type_of_service}  = $svc->e911_type || '0';

  $hash{exchange} = '';
  # the routing number for the local emergency service call center; 
  # will be filled in by the service provider
  $hash{esn} = '';

  # Main Number (I guess for callbacks?)
  # XXX this is probably not right, but we don't have a concept of "main 
  # number for the site".
  $hash{main_npa} = $hash{npa};
  $hash{main_number} = $hash{calling_number};

  # Order Number...is a foreign concept to us.  It's supposed to be the 
  # transaction number that ordered this service change.  (Maybe the 
  # number of the batch item?  That's really hard for a user to do anything
  # with.)
  $hash{order_number} = $svc->svcnum;
  $hash{extract_date} = time2str('%m%d%y', time);

  # $hash{county_id} is supposed to be the FIPS code for the county,
  # but it's a four-digit field.  INCITS 31 county codes are 5 digits,
  # so we can't comply.  NENA 3 fixed this...

  $hash{company_id} = $self->option('company_id');
  $hash{customer_code} = $self->option('customer_code') || '';
  $hash{source_id} = $initial_load_hack ? 'C' : ' ';

  @hash{'zip_code', 'zip_4'} = split('-', $cust_location->zip);
 
  $hash{x_coordinate} = $cust_location->longitude;
  $hash{y_coordinate} = $cust_location->latitude;
  # $hash{z_coordinate} = $cust_location->altitude; # not implemented, sadly

  $hash{expanded_extract_date} = time2str('%Y%m%d', time);

  # quirks mode
  if ( $self->option('format') eq 'Intrado' ) { 
    my $century = substr($hash{expanded_extract_date}, 0, 2);
    $hash{expanded_extract_date} = '';
    $hash{nena_reserved} = '   '.$century;
    $hash{x_coordinate} = '';
    $hash{y_coordinate} = '';
  }
  $hash{end_of_record} = '*';
  return $item_format->pack(\%hash);
}

sub process {
  my $self = shift;
  my $batch = shift;
  local $DEBUG = $self->option('debug');
  local $FS::UID::AutoCommit = 0;
  my $error;

  my $cycle = $self->option('cycle_counter');
  die "invalid cycle counter value '$cycle'" if $cycle =~ /\D/;

  # mark the batch as closed
  if ($batch->status eq 'open') {
    $batch->set(status => 'closed');
    $error = $batch->replace;
    die "can't close batch: $error" if $error;
    dbh->commit;
  }

  my @items = $batch->export_batch_item;
  return unless @items;

  my ($fh, $local_file) = tempfile();
  warn "writing batch to $local_file\n" if $DEBUG;

  # intrado documentation is inconsistent on this, but NENA 2.1 says to use
  # leading spaces, not zeroes, for the cycle counter and record count

  my %hash = ('header_indicator'      => 'UHL',
              'extract_date'          => time2str('%m%d%y', $batch->_date),
              'company_name'          => $self->option('company_name'),
              'cycle_counter'         => $cycle,
              # can add these fields if they're really necessary but it's
              # a lot of work
              'county_id'             => '',
              'state'                 => '',
              'general_use'           => '',
              'release_number'        => '',
              'format_version'        => '',
              'expanded_extract_date' => time2str('%Y%m%d', $batch->_date),
              'reserved'              => '',
              'end_of_record'         => '*'
             );

  my $header = $header_format->pack(\%hash);
  warn "HEADER: $header\n" if $DEBUG;
  print $fh $header,"\r\n";

  my %phonenum_item; # phonenum => batch item
  foreach my $item (@items) {

    # ignore items that have no data to add to the batch
    next if $item->action eq 'suspend' or $item->action eq 'unsuspend';
    
    my $data = $item->data;
    %hash = %{ $item_format->parse($data) };
    my $phonenum = $hash{npa} . $hash{calling_number};

    # reconcile multiple updates that affect a single phone number
    # set 'data' to undef here to cancel the current update.
    # we will ALWAYS remove the previous item, though.
    my $prev_item = $phonenum_item{ $phonenum };
    if ($prev_item) {
      warn "$phonenum: reconciling ".
            $prev_item->action.'#'.$prev_item->itemnum . ' with '.
            $item->action.'#'.$item->itemnum . "\n"
            if $DEBUG;

      $error = $prev_item->delete;
      delete $phonenum_item{ $phonenum };

      if ($prev_item->action eq 'delete') {
        if ( $item->action eq 'delete' ) {
          warn "$phonenum was deleted, then deleted again; ignoring first delete\n";
        } elsif ( $item->action eq 'insert' ) {
          # delete + insert = replace
          $item->action('replace');
          $data =~ s/^I/C/;
        } else {
          # it's a replace action, which isn't really valid after the phonenum
          # was deleted, but assume the delete was an error
          warn "$phonenum was deleted, then replaced; ignoring delete action\n";
        }
      } elsif ($prev_item->action eq 'insert') {
        if ( $item->action eq 'delete' ) {
          # then negate both actions (this isn't an anomaly, don't warn)
          undef $data;
        } elsif ( $item->action eq 'insert' ) {
          # assume this insert is correct
          warn "$phonenum was inserted, then inserted again; ignoring first insert\n";
        } else {
          # insert + change = insert (with updated data)
          $item->action('insert');
          $data =~ s/^C/I/;
        }
      } else { # prev_item->action is replace/relocate
        if ( $item->action eq 'delete' ) {
          # then the previous replace doesn't matter
        } elsif ( $item->action eq 'insert' ) {
          # it was changed and then inserted...not sure what to do.
          # assume the actions were queued out of order?  or there are multiple
          # svcnums with this phone number? both are pretty nasty...
          warn "$phonenum was replaced, then inserted; ignoring insert\n";
          undef $data;
        } else {
          # replaced, then replaced again; perfectly normal, and the second
          # replace will prevail
        }
      }
    } # if $prev_item

    # now, if reconciliation has changed this action, replace it
    if (!defined $data) {
      $error ||= $item->delete;
    } elsif ($data ne $item->data) {
      $item->set('data' => $data);
      $error ||= $item->replace;
    }
    if ($error) {
      dbh->rollback;
      die "error reconciling NENA2 batch actions for $phonenum: $error\n";
    }

    next if !defined $data;
    # set this action as the "current" update to perform on $phonenum
    $phonenum_item{$phonenum} = $item;
  }

  # now, go through %phonenum_item and emit exactly one batch line affecting
  # each phonenum

  my $rows = 0;
  foreach my $phonenum (sort {$a cmp $b} keys(%phonenum_item)) {
    my $item = $phonenum_item{$phonenum};
    print $fh $item->data, "\r\n";
    $rows++;
  }

  # create trailer
  %hash = ( 'trailer_indicator'     => 'UTL',
            'extract_date'          => time2str('%m%d%y', $batch->_date),
            'company_name'          => $self->option('company_name'),
            'record_count'          => $rows,
            'expanded_extract_date' => time2str('%Y%m%d', $batch->_date),
            'reserved'              => '',
            'end_of_record'         => '*',
          );
  my $trailer = $trailer_format->pack(\%hash);
  print "TRAILER: $trailer\n\n" if $DEBUG;
  print $fh $trailer, "\r\n";

  close $fh;

  return unless $self->option('target');

  # appears to be correct for Intrado; maybe the config option should
  # allow specifying the whole string, as the argument to time2str?
  my $dest_file = $self->option('prefix') . time2str("%m%d%y", $batch->_date)
                 . '.dat';

  my $upload_target = FS::upload_target->by_key($self->option('target'))
    or die "can't upload batch (target does not exist)\n";
  warn "Uploading to ".$upload_target->label.".\n" if $DEBUG;
  $error = $upload_target->put($local_file, $dest_file);

  if ( $error ) {
    dbh->rollback;
    die "error uploading batch: $error" if $error;
  }
  warn "Success.\n" if $DEBUG;

  # if it was successfully uploaded, check off the batch:
  $batch->status('done');
  $error = $batch->replace;

  # and increment the cycle counter
  $cycle++;
  my $opt = qsearchs('part_export_option', {
      optionname  => 'cycle_counter',
      exportnum   => $self->exportnum,
  });
  $opt->set(optionvalue => $cycle);
  $error ||= $opt->replace;
  if ($error) {
    dbh->rollback;
    die "error recording batch status: $error\n";
  }

  dbh->commit;
}

1;
