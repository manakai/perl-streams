package ArrayBuffer;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;

## {array_buffer_data}'s value is a Data Block.  In Perl, it is
## represented as a reference to a byte string.

$ArrayBuffer::CreateTypeError ||= sub ($$) {
  return "TypeError: " . $_[1] . Carp::shortmess ();
};
$ArrayBuffer::CreateRangeError ||= sub ($$) {
  return "RangeError: " . $_[1] . Carp::shortmess ();
};
$ArrayBuffer::CreateNotSupportedError ||= sub ($$) {
  return "NotSupportedError: " . $_[1] . Carp::shortmess ();
};
sub _type_error ($) { $ArrayBuffer::CreateTypeError->(undef, $_[0]) }
sub _range_error ($) { $ArrayBuffer::CreateRangeError->(undef, $_[0]) }
sub _not_supported_error ($) { $ArrayBuffer::CreateNotSupportedError->(undef, $_[0]) }

## ArrayBuffer constructor
sub new ($$) {
  my $self = bless {}, $_[0];

  ## ToIndex for Perl
  my $length = int $_[1];
  die _range_error "Byte length $length is negative" if $length < 0;

  ## AllocateArrayBuffer
  {
    # XXX throw RangeError if $length is too large?
    $self->{array_buffer_byte_length} = $length;

    #$self->{array_buffer_data} = \("\x00" x $length); # CreateByteDataBlock (can throw RangeError)
    ## Not in JS:
    $self->{array_buffer_data} = '';
    $self->{allocation_delayed} = 1;
  }

  return $self;
} # new

## Not in JS
sub new_from_scalarref ($$) {
  die _type_error "The argument is not a SCALAR"
      unless defined $_[1] and (ref $_[1] eq 'SCALAR' or ref $_[1] eq 'LVALUE');
  die _type_error "The argument is a utf8-flaged string" if utf8::is_utf8 ${$_[1]};
  my $self = bless {}, $_[0];

  $self->{array_buffer_data} = $_[1];
  $self->{array_buffer_byte_length} = length ${$_[1]};

  return $self;
} # new_from_scalarref

## TransferArrayBuffer, invoked by Streams Standard operations.  $self
## must be an ArrayBuffer that is not detached.
sub _transfer ($) {
  my $transferred = bless {
    array_buffer_byte_length => $_[0]->{array_buffer_byte_length},
    array_buffer_data => $_[0]->{array_buffer_data},
  }, (ref $_[0]);
  $transferred->{allocation_delayed} = 1
      if delete $_[0]->{allocation_delayed}; # Not in JS

  ## DetachArrayBuffer
  {
    $_[0]->{array_buffer_data} = undef;
    $_[0]->{array_buffer_byte_length} = 0;
  }

  return $transferred
} # _transfer

## Not in JS
sub manakai_transfer_to_scalarref ($) {
  die _type_error ('ArrayBuffer is detached')
      if not defined $_[0]->{array_buffer_data}; ## IsDetachedBuffer

  if ($_[0]->{allocation_delayed}) {
    $_[0]->{array_buffer_data} = \("\x00" x $_[0]->{array_buffer_byte_length});
  }
  my $ref = $_[0]->{array_buffer_data};

  ## DetachArrayBuffer
  {
    $_[0]->{array_buffer_data} = undef;
    $_[0]->{array_buffer_byte_length} = 0;
  }

  return $ref;
} # manakai_transfer_to_scalarref

## CloneArrayBuffer (where cloneConstructor is $class), invoked by
## Typed Array and Streams Standard operations.  SharedArrayBuffer
## $src_buffer is not supported by this implementation.
sub _clone ($$$$) {
  my ($class, $src_buffer, $src_byte_offset, $src_length) = @_;

  ## Assert: $src_byte_offset < $src_buffer->byte_length,
  ## $src_byte_offset + $src_length <= $src_buffer->byte_length (As
  ## this is a private method, these are not checked here.)

  ## Can throw RangeError (in AllocateArrayBuffer) here in theory, if
  ## $src_length is too large.

  die _type_error ('ArrayBuffer is detached')
      if not defined $src_buffer->{array_buffer_data}; ## IsDetachedBuffer

  ## AllocateArrayBuffer, CopyDataBlockBytes
  if ($src_buffer->{allocation_delayed}) { # Not in JS
    my $target_block_value = "\x00" x $src_length;
    return ArrayBuffer->new_from_scalarref (\$target_block_value);
  } else {
    my $target_block_value = substr (${$src_buffer->{array_buffer_data}}, $src_byte_offset, $src_length);
    return ArrayBuffer->new_from_scalarref (\$target_block_value);
  }

  # XXX string copy counter for debugging
} # _clone

sub byte_length ($) {
  my $self = $_[0];
  die _type_error ('ArrayBuffer is detached')
      if not defined $self->{array_buffer_data}; ## IsDetachedBuffer
  return $self->{array_buffer_byte_length};
} # byte_length

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to ArrayBuffer (@{[defined $_[0]->{array_buffer_data} ? 'l=' . $_[0]->{array_buffer_byte_length} : 'detached']}) is not discarded before global destruction\n";
  }
} # DESTROY

1;

## XXX Not implemented (yet):
## $class->is_view
## $self->slice

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
