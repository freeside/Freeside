package FS::template_image;
use base qw( FS::Agent_Mixin FS::Record );

use strict;
use FS::Record qw( qsearchs );
use File::Slurp qw( slurp );
use MIME::Base64 qw( encode_base64 );

my %ext_to_type = (
  'jpeg' => 'image/jpeg',
  'jpg'  => 'image/jpeg',
  'png'  => 'image/png',
  'gif'  => 'image/gif',
);

=head1 NAME

FS::template_image - Object methods for template_image records

=head1 SYNOPSIS

  use FS::template_image;

  $record = new FS::template_image {
              'name'      => 'logo',
              'agentnum'  => $agentnum,
              'base64'    => encode_base64($rawdata),
              'mime_type' => 'image/jpg',
  };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::template_image object represents an uploaded image for insertion into templates.
FS::template_image inherits from FS::Record.  The following fields are currently supported:

=over 4

=item imgnum - primary key

=item name - unique name, for selecting/editing images

=item agentnum - image agent

=item mime-type - image mime-type

=item base64 - base64-encoded raw contents of image file

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new object.  To add the object to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'template_image'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('imgnum','agentnum')
    || $self->ut_text('name','mime-type')
    || $self->ut_anything('base64')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item src

Returns a data url for this image, incorporating mime_type & base64

=cut

sub src {
  my $self = shift;
  'data:'
  . $self->mime_type
  . ';base64,'
  . $self->base64;
}

=item html

Returns html for a basic img tag for this image (no attributes)

=cut

sub html {
  my $self = shift;
  '<IMG SRC="'
  . $self->src
  . '">';
}

=item process_image_delete

Process for deleting an image.  Run as a job using L<FS::queue>.

=cut

sub process_image_delete {
  my $job = shift;
  my $param = shift;
  my $template_image = qsearchs('template_image',{ 'imgnum' => $param->{'imgnum'} })
    or die "Could not load template_image";
  my $error = $template_image->delete;
  die $error if $error;
  '';
}

=item process_image_upload

Process for uploading an image.  Run as a job using L<FS::queue>.

=cut

sub process_image_upload {
  my $job = shift;
  my $param = shift;

  my $files = $param->{'uploaded_files'}
    or die "No files provided.\n";

  my (%files) = map { /^(\w+):([\.\w]+)$/ ? ($1,$2):() } split /,/, $files;

  my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/';
  my $file = $dir. $files{'file'};

  my $type;
  if ( $file =~ /\.(\w+)$/i ) {
    my $ext = lc($1);
    die "Unrecognized file extension $ext"
      unless $ext_to_type{$ext};
    $type = $ext_to_type{$ext};
  } else {
    die "Cannot upload image file without extension"
  }

  my $template_image = new FS::template_image {
    'name'   => $param->{'name'},
    'mime_type' => $type,
    'agentnum'  => $param->{'agentnum'},
    'base64'    => encode_base64( slurp($file, binmode => ':raw'), '' ),
  };
  my $error = $template_image->insert();
  die $error if $error;
  unlink $file;
  '';

}

=back

=head1 BUGS

Will be described here once found.

=head1 SEE ALSO

L<FS::Record>

=cut

1;

