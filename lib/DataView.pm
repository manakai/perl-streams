package DataView;
use strict;
use warnings;
our $VERSION = '1.0';
use Streams::_Common;
push our @ISA, qw(ArrayBufferView);

sub new ($$;$$) {
  my $self = bless {}, $_[0];

  my $buffer = $_[1];
  die _type_error "The argument is not an ArrayBuffer"
      unless defined $buffer and UNIVERSAL::isa ($buffer, 'ArrayBuffer'); ## has [[ArrayBufferData]]
  my $offset = _to_index $_[2] || 0, 'Offset';
  die _type_error "ArrayBuffer is detached"
      if not defined $buffer->{array_buffer_data}; ## IsDetachedBuffer
  my $buffer_byte_length = $buffer->{array_buffer_byte_length};
  die _range_error "Offset $offset > buffer length $buffer_byte_length"
      if $offset > $buffer_byte_length;
  my $view_byte_length;
  if (defined $_[3]) {
    $view_byte_length = _to_index $_[3], 'Byte length';
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

sub manakai_to_string ($) {
  my $self = $_[0];
  die _type_error "ArrayBuffer is detached"
      if not defined $self->{viewed_array_buffer}
          ->{array_buffer_data}; ## IsDetachedBuffer

  my $buffer = $self->{viewed_array_buffer};
  _note_buffer_copy $self->{byte_length}, $buffer->debug_info, "string";
  if ($buffer->{allocation_delayed}) {
    return "\x00" x $self->{byte_length};
  } else {
    return substr ${$buffer->{array_buffer_data}},
        $self->{byte_offset}, $self->{byte_length};
  }
} # manakai_to_string

## Not implemented yet:
##   $object->get_* set_*

1;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
