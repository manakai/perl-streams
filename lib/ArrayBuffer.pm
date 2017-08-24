package ArrayBuffer;
use strict;
use warnings;
our $VERSION = '1.0';
use Streams::_Common;
use Streams::IOError;

## {array_buffer_data}'s value is a Data Block.  In Perl, it is
## represented as a reference to a byte string.

## Private
our $CallerLevel = 0;

## ArrayBuffer constructor
sub new ($$) {
  my $self = bless {caller => [caller $CallerLevel]}, $_[0];
  my $length = _to_index $_[1], 'Byte length';

  ## AllocateArrayBuffer
  {
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
  my $self = bless {caller => [caller $CallerLevel]}, $_[0];
  my $length = _to_index $_[1], 'Byte length';

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
    caller => [caller ($CallerLevel + 1)],
    label => 'transferred from ' . $_[0]->debug_info,
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

## Not in JS
sub manakai_label ($;$) {
  if (@_ > 1) {
    $_[0]->{label} = $_[1];
  }
  return $_[0]->{label}; # or undef
} # manakai_label

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

  _note_buffer_copy $src_length, $src_buffer->debug_info, 'new clone';

  ## AllocateArrayBuffer, CopyDataBlockBytes
  local $CallerLevel = $CallerLevel + 1;
  my $ab;
  if ($src_buffer->{allocation_delayed}) { # Not in JS
    my $target_block_value = "\x00" x $src_length;
    $ab = ArrayBuffer->new_from_scalarref (\$target_block_value);
  } else {
    my $target_block_value = substr (${$src_buffer->{array_buffer_data}}, $src_byte_offset, $src_length);
    $ab = ArrayBuffer->new_from_scalarref (\$target_block_value);
  }

  $ab->{label} = 'clone of ' . $src_buffer->debug_info;
  return $ab;
} # _clone

## CopyDataBlockBytes, invoked by Streams Standard operations, without
## SharedArrayBuffer support.
sub _copy_data_block_bytes ($$$$$) {
  my ($dest_buffer, $dest_offset, $src_buffer, $src_offset, $byte_count) = @_;

  _note_buffer_copy
      $byte_count, $src_buffer->debug_info, $dest_buffer->debug_info;

  if ($dest_buffer->{allocation_delayed}) {
    my $new_buffer = ("\x00" x $dest_offset) . (
     $src_buffer->{allocation_delayed}
         ? "\x00" x $byte_count
         : substr ${$src_buffer->{array_buffer_data}}, $src_offset, $byte_count
    ) . ("\x00" x ($dest_buffer->{array_buffer_byte_length} - $byte_count - $dest_offset));
    delete $dest_buffer->{allocation_delayed};
    $dest_buffer->{array_buffer_data} = \$new_buffer;
  } else { # $dest allocated
    if ($src_buffer->{allocation_delayed}) {
      substr (${$dest_buffer->{array_buffer_data}}, $dest_offset, $byte_count)
          = "\x00" x $byte_count;
    } else {
      substr (${$dest_buffer->{array_buffer_data}}, $dest_offset, $byte_count)
          = substr ${$src_buffer->{array_buffer_data}}, $src_offset, $byte_count;
    }
  }
} # _copy_data_block_bytes

sub byte_length ($) {
  my $self = $_[0];
  die _type_error ('ArrayBuffer is detached')
      if not defined $self->{array_buffer_data}; ## IsDetachedBuffer
  return $self->{array_buffer_byte_length};
} # byte_length

## Not in JS
sub manakai_syswrite ($$;$$) {
  my $self = $_[0];
  die _type_error ('ArrayBuffer is detached')
      if not defined $self->{array_buffer_data}; ## IsDetachedBuffer
  my $length = defined $_[2] ? (_to_index $_[2], 'Byte length') : $self->{array_buffer_byte_length};
  my $offset = _to_index $_[3] || 0, 'Byte offset';
  my $l = syswrite $_[1], (
    $self->{allocation_delayed}
      ? "\x00" x $length
      : ${$self->{array_buffer_data}}
  ), $length, $offset;
  die Streams::IOError->new ($!) unless defined $l;
  _note_buffer_copy $l, $self->debug_info, 'syswrite' if $l > 0;
  return $l;
} # manakai_syswrite

## Not in JS
sub debug_info ($) {
  return '{' . (
    join ' ', grep { defined }
        'ArrayBuffer',
        $_[0]->{label},
        (defined $_[0]->{array_buffer_data}
             ? 'l=' . $_[0]->{array_buffer_byte_length} : 'detached'),
        "file $_[0]->{caller}->[1]",
        "line $_[0]->{caller}->[2]",
  ) . '}';
} # debug_info

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to ".$_[0]->debug_info." is not discarded before global destruction\n";
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
