package DataView;
use strict;
use warnings;
our $VERSION = '1.0';

use ArrayBuffer;
BEGIN {
  *_type_error = \&ArrayBuffer::_type_error;
  *_range_error = \&ArrayBuffer::_range_error;
  *_not_supported_error = \&ArrayBuffer::_not_supported_error;
}
push our @CARP_NOT, qw(ArrayBuffer);

sub new ($$;$$) {
  my $self = bless {}, $_[0];

  my $buffer = $_[1];
  die _type_error "The argument is not an ArrayBuffer"
      unless defined $buffer and UNIVERSAL::isa ($buffer, 'ArrayBuffer'); ## has [[ArrayBufferData]]

  ## ToIndex for Perl
  my $offset = int ($_[2] || 0);
  die _range_error "Offset $offset is negative" if $offset < 0;

  die _type_error "ArrayBuffer is detached"
      if not defined $buffer->{array_buffer_data}; ## IsDetachedBuffer
  my $buffer_byte_length = $buffer->{array_buffer_byte_length};
  die _range_error "Offset $offset > buffer length $buffer_byte_length"
      if $offset > $buffer_byte_length;
  my $view_byte_length;
  if (defined $_[3]) {
    ## ToIndex for Perl
    $view_byte_length = int $_[3];
    die _range_error "Byte length $view_byte_length is negative"
        if $view_byte_length < 0;

    die _range_error
        "Offset $offset + length $view_byte_length > buffer length $buffer_byte_length"
            if $offset + $view_byte_length > $buffer_byte_length;
  } else {
    $view_byte_length = $buffer_byte_length - $offset;
  }
  #$self->{data_view} = undef;
  $self->{viewed_array_buffer} = $buffer;
  $self->{byte_length} = $view_byte_length;
  $self->{byte_offset} = $offset;
  return $self;
} # new

sub buffer ($) {
  return $_[0]->{viewed_array_buffer};
} # buffer

sub byte_length ($) {
  my $self = $_[0];
  die _type_error "ArrayBuffer is detached"
      if not defined $self->{viewed_array_buffer}
          ->{array_buffer_data}; ## IsDetachedBuffer
  return $self->{byte_length};
} # byte_length

sub byte_offset ($) {
  my $self = $_[0];
  die _type_error "ArrayBuffer is detached"
      if not defined $self->{viewed_array_buffer}
          ->{array_buffer_data}; ## IsDetachedBuffer
  return $self->{byte_offset};
} # byte_offset

## Not implemented yet:
##   $object->get_* set_*

1;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
