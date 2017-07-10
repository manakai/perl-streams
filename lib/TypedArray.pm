package TypedArray;
use strict;
use warnings;
our $VERSION = '1.0';
use Streams::_Common;
use ArrayBuffer;

## TypedArray ()
## TypedArray (length)
## TypedArray (typedArray) - not supported
## TypedArray (object) - not supported
## TypedArray (buffer)
## TypedArray (buffer, byteOffset)
## TypedArray (buffer, byteOffset, length)
sub new ($;$$$) {
  die _type_error __PACKAGE__ . " is an abstract class"
      if $_[0] eq __PACKAGE__;
  my $self = bless {}, $_[0];

  my $length;
  if (not defined $_[1]) {
    $length = 0;
  } elsif (ref $_[1]) {
    if (UNIVERSAL::isa ($_[1], 'ArrayBuffer')) { ## has [[ArrayBufferData]]
      #
    } else {
      die _range_error 'The argument is not an ArrayBuffer or length';
    }
  } else {
    $length = _to_index $_[1], 'Length';
  }

  if (defined $length) {
    ## AllocateTypedArray
    {
      #$self->{viewed_array_buffer} = undef;
      #$self->{typed_array_name} = ref $self;

      ## AllocateTypedArrayBuffer
      {
        my $element_size = $self->BYTES_PER_ELEMENT; ## Table->{ref $_[0]}
        my $byte_length = $element_size * $length;
        $self->{viewed_array_buffer}
            = ArrayBuffer->new ($byte_length); ## AllocateArrayBuffer
        $self->{byte_length} = $byte_length;
        $self->{byte_offset} = 0;
        $self->{array_length} = $length;
      }
    }
  } else { # $_[1] is an array buffer
    ## AllocateTypedArray
    #$self->{viewed_array_buffer} = undef;
    #$self->{typed_array_name} = ref $self;
    #$self->{byte_length} = 0;
    #$self->{byte_offset} = 0;
    #$self->{array_length} = 0;

    my $element_size = $self->BYTES_PER_ELEMENT; ## Table->{ref $_[0]}

    my $offset = _to_index $_[2] || 0, 'Offset';
    die _range_error "Offset $offset % element size $element_size != 0"
        unless ($offset % $element_size) == 0;
    die _type_error "ArrayBuffer is detached"
        if not defined $_[1]->{array_buffer_data}; ## IsDetachedBuffer
    my $buffer_byte_length = $_[1]->{array_buffer_byte_length};
    my $new_byte_length;
    if (not defined $_[3]) {
      die _range_error
          "Buffer length $buffer_byte_length % element size $element_size != 0"
              unless ($buffer_byte_length % $element_size) == 0;
      $new_byte_length = $buffer_byte_length - $offset;
      die _range_error "Buffer length $buffer_byte_length < offset $offset"
          if $new_byte_length < 0;
    } else { # $length specified
      my $new_length = _to_index $_[3], 'Array length';
      $new_byte_length = $new_length * $element_size;
      die _range_error
          "Buffer length $buffer_byte_length < offset $offset + array length $new_length * element size $element_size"
              if $offset + $new_byte_length > $buffer_byte_length;
    }
    $self->{viewed_array_buffer} = $_[1];
    $self->{byte_length} = $new_byte_length;
    $self->{byte_offset} = $offset;
    $self->{array_length} = $new_byte_length / $element_size; # integer
  }
  return $self;
} # new

sub buffer ($) {
  return $_[0]->{viewed_array_buffer};
} # buffer

sub byte_length ($) {
  return 0 if not defined $_[0]->{viewed_array_buffer}
      ->{array_buffer_data}; ## IsDetachedBuffer
  return $_[0]->{byte_length};
} # byte_length

sub byte_offset ($) {
  return 0 if not defined $_[0]->{viewed_array_buffer}
      ->{array_buffer_data}; ## IsDetachedBuffer
  return $_[0]->{byte_offset};
} # byte_offset

sub length ($) {
  return 0 if not defined $_[0]->{viewed_array_buffer}
      ->{array_buffer_data}; ## IsDetachedBuffer
  return $_[0]->{array_length};
} # length

## XXX Not implemented:
## $subclass->from
## $subclass->of
## $object->copy_within
## $object->entries
## $object->every
##          fill filter find find_index for_each includes index_of
##          join keys last_index_of map reduce reduce_right
##          reverse set slice some sort subarray values
## $object->[$n] getter / setter

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to @{[ref $_[0]]}@{[
      (not defined $_[0]->{viewed_array_buffer}->{array_buffer_data})
          ? ' (detached)' : ''
    ]} is not discarded before global destruction\n";
  }
} # DESTROY

package TypedArray::Uint8Array;
push our @ISA, qw(TypedArray);
use Streams::_Common;

## Not in JS
sub new_by_sysread ($$) {
  my ($class, $fh, $byte_length) = @_;
  my $buffer = '';
  my $bytes_read = sysread $fh, $buffer, (_to_index $byte_length, 'Byte length'), 0;
  die _io_error $! unless defined $bytes_read;
  return $class->new
      (ArrayBuffer->new_from_scalarref (\$buffer), 0, $bytes_read);
} # new_by_sysread

## Table->{$_[0]}
sub BYTES_PER_ELEMENT () { 1 }

# XXX Not implemented: other subclasses

1;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
