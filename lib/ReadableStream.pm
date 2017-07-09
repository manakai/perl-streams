package ReadableStream;
use strict;
use warnings;
our $VERSION = '1.0';
use ArrayBuffer;
use TypedArray;
use DataView;
use Promise;
use Streams::_Common;

sub new ($;$$) {
  die _type_error "Source is not a HASH"
      if defined $_[1] and not ref $_[1] eq 'HASH'; # Not in JS
  die _type_error "Options is not a HASH"
      if defined $_[2] and not ref $_[2] eq 'HASH'; # Not in JS
  my $self = bless {
    created_location => Carp::shortmess,
  }, $_[0];
  my $underlying_source = $_[1] || {};
  my $opts = $_[2] || {};
  $self->{state} = 'readable';
  $self->{reader} = undef;
  $self->{stored_error} = undef;
  $self->{disturbed} = undef;
  $self->{readable_stream_controller} = undef;
  my $hwm = $opts->{high_water_mark};
  if (not defined $underlying_source->{type}) {
    $self->{readable_stream_controller} = ReadableStreamDefaultController->new
        ($self, $underlying_source, $opts->{size}, defined $hwm ? $hwm : 1);
  } else {
    my $type = ''.$underlying_source->{type}; # ToString
    if ($type eq 'bytes') {
      $self->{readable_stream_controller} = ReadableByteStreamController->new
          ($self, $underlying_source, defined $hwm ? $hwm : 0);
    } else {
      die _range_error "Unknown type |$type|";
    }
  }
  return $self;
} # new

sub locked ($) {
  return defined $_[0]->{reader}; # IsReadableStreamLocked
} # locked

sub ReadableStream::_close ($) {
  my $stream = $_[0];
  $stream->{state} = 'closed';
  my $reader = $stream->{reader};
  return if not defined $reader;
  if (defined $reader->{read_requests}) { # IsReadableStreamDefaultReader
    for my $read_request (@{$reader->{read_requests}}) {
      $read_request->{resolve}->({done => 1});
    }
    $reader->{read_requests} = [];
  }
  $reader->{closed_promise}->{resolve}->(undef);
} # ReadableStreamClose

sub ReadableStream::_cancel ($$) {
  my $stream = $_[0];
  $stream->{disturbed} = 1;
  if ($stream->{state} eq 'closed') {
    return Promise->resolve (undef);
  } elsif ($stream->{state} eq 'errored') {
    return Promise->reject ($stream->{stored_error});
  }
  ReadableStream::_close $stream;
  my $source_cancel_promise = $stream->{readable_stream_controller}->_cancel_steps ($_[1]);
  return $source_cancel_promise->then (sub { return undef });
} # ReadableStreamCancel

sub cancel ($;$) {
  return Promise->reject (_type_error "ReadableStream is locked")
      if defined $_[0]->{reader}; # IsReadableStreamLocked
  return ReadableStream::_cancel $_[0], $_[1];
} # cancel

sub get_reader ($;$) {
  if (defined $_[1]) {
    my $mode = ''.$_[1]; # ToString
    if ($mode eq 'byob') {
      ## AcquireReadableStreamBYOBReader
      return ReadableStreamBYOBReader->new ($_[0]);
    } else {
      die _range_error "Unknown mode |$mode|";
    }
  } else {
    ## AcquireReadableStreamDefaultReader
    return ReadableStreamDefaultReader->new ($_[0]);
  }
} # getReader(mode)

# XXX Not implemented yet:
# $rs->pipe_to pipe_through tee

## XXX IsReadableStreamDisturbed hook

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    my $location = $_[0]->{created_location};
    $location =~ s/\.?\s+\z//;
    warn "$$: Reference to @{[ref $_[0]]} created${location} is not discarded before global destruction\n";
  }
} # DESTROY

package ReadableStreamDefaultController;
use Streams::_Common;
push our @CARP_NOT, qw(ReadableStream);

sub ReadableStreamDefaultController::_get_desired_size ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};
  my $state = $stream->{state};
  return undef if $state eq 'errored';
  return 0 if $state eq 'closed';
  return $controller->{strategy_hwm} - $controller->{queue_total_size};
} # ReadableStreamDefaultControllerGetDesiredSize

sub ReadableStream::_error ($$) {
  my $stream = $_[0];
  $stream->{state} = 'errored';
  $stream->{stored_error} = $_[1];
  my $reader = $stream->{reader};
  return if not defined $reader;
  if (defined $reader->{read_requests}) { # IsReadableStreamDefaultReader
    for my $read_request (@{$reader->{read_requests}}) {
      $read_request->{promise}->{reject}->($_[1]);
    }
    $reader->{read_requests} = [];
  } else {
    for my $read_into_request (@{$reader->{read_into_requests}}) {
      $read_into_request->{promise}->{reject}->($_[1]);
    }
    $reader->{read_into_requests} = [];
  }
  $reader->{closed_promise}->{reject}->($_[1]);
  # $reader->{closed_promise}->{promise_is_handled} = 1;
} # ReadableStreamError

sub ReadableStreamDefaultController::_error ($$) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};

  ## ResetQueue
  $controller->{queue} = [];
  $controller->{queue_total_size} = 0;

  ReadableStream::_error $stream, $_[1];
} # ReadableByteStreamControllerError

sub ReadableStreamDefaultController::_call_pull_if_needed ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};

  {
    ## return unless ReadableStreamDefaultControllerShouldCallPull
    return if $stream->{state} eq 'closed' or $stream->{state} eq 'errored';
    last if $controller->{close_requested};
    return unless $controller->{started};
    if (defined $controller->{reader} and # IsReadableStreamLocked
        (
          ## ReadableStreamGetNumReadRequests
          @{$controller->{reader}->{read_requests}}
        ) > 0) {
      last;
    }
    my $desired_size = ReadableStreamDefaultController::_get_desired_size $controller;
    return unless $desired_size > 0;
  }

  if ($controller->{pulling}) {
    $controller->{pull_again} = 1;
    return undef;
  }
  $controller->{pulling} = 1;
  _hashref_method ($controller->{underlying_source}, 'pull', [$controller])->then (sub {
    $controller->{pulling} = 0;
    if ($controller->{pull_again}) {
      $controller->{pull_again} = 0;
      ReadableStreamDefaultController::_call_pull_if_needed ($controller);
    }
    return undef;
  }, sub {
    ## ReadableStreamDefaultControllerErrorIfNeeded
    if ($stream->{state} eq 'readable') {
      ReadableStreamDefaultController::_error ($controller, $_[0]);
    }
  });
  return undef;
} # ReadableStreamDefaultControllerCallPullIfNeeded

sub new ($$$$$) {
  my ($class, $stream, $underlying_source, $size, $high_water_mark) = @_;
  die _type_error "ReadableStream is closed"
      unless UNIVERSAL::isa ($stream, 'ReadableStream'); # IsReadableStream
  die _type_error "ReadableStream has a controller"
      if defined $stream->{readable_stream_controller};
  my $self = bless {}, $class;
  $self->{controlled_readable_stream} = $stream;
  $self->{underlying_source} = $underlying_source;

  ## ResetQueue
  $self->{queue} = [];
  $self->{queue_total_size} = 0;

  $self->{started} = 0;
  $self->{close_requested} = 0;
  $self->{pull_again} = 0;
  $self->{pulling} = 0;

  ## ValidateAndNormalizeQueuingStrategy
  {
    die _type_error "Size is not a CODE"
        if defined $size and not ref $size eq 'CODE';
    $self->{strategy_size} = $size;

    ## ValidateAndNormalizeHighWaterMark
    $self->{strategy_hwm} = 0+$high_water_mark; ## ToNumber
    $self->{strategy_hwm} = 0 if $high_water_mark eq 'NaN' or $high_water_mark eq 'nan'; # Not in JS
    die _range_error "High water mark $high_water_mark is negative"
        if $high_water_mark < 0;
  }

  _hashref_method_throws ($underlying_source, 'start', [$self])->then (sub { # requires Promise
    $self->{started} = 1;
    ReadableStreamDefaultController::_call_pull_if_needed $self;
  }, sub {
    ## ReadableStreamDefaultControllerErrorIfNeeded
    if ($self->{controlled_readable_stream}->{state} eq 'readable') {
      ReadableStreamDefaultController::_error ($self, $_[0]);
    }
  });
  return $self;
} # new

sub desired_size ($) {
  return ReadableStreamDefaultController::_get_desired_size $_[0];
} # desired_size

sub close ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};
  die _type_error "ReadableStream is closed" if $controller->{close_requested};
  die _type_error "ReadableStream is closed"
      unless $stream->{state} eq 'readable';

  ## ReadableStreamDefaultControllerClose
  $controller->{close_requested} = 1;
  unless (@{$controller->{queue}}) {
    ReadableStream::_close $stream;
  }
} # close

sub enqueue ($$) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};
  die _type_error "ReadableStream is closed" if $controller->{close_requested};
  die _type_error "ReadableStream is closed"
      unless $stream->{state} eq 'readable';

  ## ReadableStreamDefaultControllerEnqueue
  if (defined $stream->{reader} and # IsReadableStreamLocked
      (
        ## ReadableStreamGetNumReadRequests
        @{$stream->{reader}->{read_requests}}
      ) > 0) {
    ## ReadableStreamFulfillReadRequest
    my $read_request = shift @{$stream->{reader}->{read_requests}};
    $read_request->{promise}->{resolve}->({value => $_[1]}); # CreateIterResultObject
  } else {
    my $chunk_size = 1;
    if (defined $controller->{strategy_size}) {
      $chunk_size = eval { $controller->{strategy_size}->($_[1]) };
      if ($@) {
        ## ReadableStreamDefaultControllerErrorIfNeeded
        if ($controller->{controlled_readable_stream}->{state} eq 'readable') {
          ReadableStreamDefaultController::_error ($controller, $@);
        }

        die $@;
      }
    }

    ## EnqueueValueWithSize
    my $size = eval { _to_size $chunk_size, 'Size' };
    if ($@) {
      ## ReadableStreamDefaultControllerErrorIfNeeded
      if ($controller->{controlled_readable_stream}->{state} eq 'readable') {
        ReadableStreamDefaultController::_error ($controller, $@);
      }

      die $@;
    }
    push @{$controller->{queue}}, {value => $_[1], size => $size};
    $controller->{queue_total_size} += $size;
  }
  ReadableStreamDefaultController::_call_pull_if_needed $controller;
  return undef;
} # enqueue(chunk)

sub error ($$) {
  my $stream = $_[0]->{controlled_readable_stream};
  die _type_error "ReadableStream is closed"
      unless $stream->{state} eq 'readable';
  ReadableStreamDefaultController::_error $_[0], $_[1];
  return undef;
} # error(e)

sub _cancel_steps ($$) {
  ## ResetQueue
  $_[0]->{queue} = [];
  $_[0]->{queue_total_size} = 0;

  return _hashref_method ($_[0]->{underlying_source}, 'cancel', [$_[1]]);
} # [[CancelSteps]]

sub _pull_steps ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};
  if (@{$controller->{queue}}) {
    ## DequeueValue
    my $pair = shift @{$controller->{queue}};
    $controller->{queue_total_size} -= $pair->{size};
    $controller->{queue_total_size} = 0 if $controller->{queue_total_size} < 0;

    if ($controller->{close_requested} and not @{$controller->{queue}}) {
      ReadableStream::_close $stream;
    } else {
      ReadableStreamDefaultController::_call_pull_if_needed $controller;
    }
    return Promise->resolve ({value => $pair->{value}}); # CreateIterResultObject
  }

  ## ReadableStreamAddReadRequest
  my $p = _promise_capability;
  push @{$stream->{reader}->{read_requests}}, {promise => $p};

  ReadableStreamDefaultController::_call_pull_if_needed $controller;
  return $p->{promise};
} # [[PullSteps]]

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to @{[ref $_[0]]} is not discarded before global destruction\n";
  }
} # DESTROY

package ReadableByteStreamController;
use Streams::_Common;
push our @CARP_NOT, qw(ReadableStream);

sub ReadableByteStreamController::_invalidate_byob_request ($) {
  return if not defined $_[0]->{byob_request};
  $_[0]->{byob_request}->{associated_readable_byte_stream_controller} = undef;
  $_[0]->{byob_request}->{view} = undef;
  $_[0]->{byob_request} = undef;
} # ReadableByteStreamControllerInvalidateBYOBRequest

sub ReadableByteStreamController::_error ($$) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};

  ## ReadableByteStreamControllerClearPendingPullIntos
  ReadableByteStreamController::_invalidate_byob_request $controller;
  $controller->{pending_pull_intos} = [];

  ## ResetQueue
  $controller->{queue} = [];
  $controller->{queue_total_size} = 0;

  ReadableStream::_error $stream, $_[1];
} # ReadableByteStreamControllerError

sub ReadableByteStreamController::_get_desired_size ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};
  return undef if $stream->{state} eq 'errored';
  return 0 if $stream->{state} eq 'closed';
  return $controller->{strategy_hwm} - $controller->{queue_total_size};
} ## ReadableByteStreamControllerGetDesiredSize

sub ReadableByteStreamController::_call_pull_if_needed ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};

  {
    ## return unless ReadableByteStreamControllerShouldCallPull
    return unless $stream->{state} eq 'readable';
    return if $controller->{close_requested};
    return unless $controller->{started};
    if (
      ## ReadableStreamHasDefaultReader
      (defined $stream->{reader} and defined $stream->{reader}->{read_requests}) # IsReadableStreamDefaultReader
      and
      (
        ## ReadableStreamGetNumReadRequests
        @{$stream->{reader}->{read_requests}}
      ) > 0
    ) {
      last;
    }
    if (
      ## ReadableStreamHasBYOBReader
      (defined $stream->{reader} and defined $stream->{reader}->{read_into_requests}) # IsReadableStreamBYOBReader
      and
        (
          ## ReadableStreamGetNumReadIntoRequests
          @{$stream->{reader}->{read_into_requests}}
        ) > 0
    ) {
      last;
    }
    if (ReadableByteStreamController::_get_desired_size ($controller) > 0) {
      last;
    }
    return;
  }

  if ($controller->{pulling}) {
    $controller->{pull_again} = 1;
    return;
  }
  $controller->{pulling} = 1;
  _hashref_method ($controller->{underlying_byte_source}, 'pull', [$controller])->then (sub {
    $controller->{pulling} = 0;
    if ($controller->{pull_again}) {
      $controller->{pull_again} = 0;
      ReadableByteStreamController::_call_pull_if_needed ($controller);
    }
  }, sub {
    if ($stream->{state} eq 'readable') {
      ReadableByteStreamController::_error $controller, $_[0];
    }
  });
  return undef;
} ## ReadableByteStreamControllerCallPullIfNeeded

sub new ($$$$) {
  my ($class, $stream, $underlying_byte_source, $high_water_mark) = @_;
  die _type_error "ReadableStream has a controller"
      if defined $stream->{readable_stream_controller};
  my $self = bless {}, $class;
  $self->{controlled_readable_stream} = $stream;
  $self->{underlying_byte_source} = $underlying_byte_source;
  $self->{pull_again} = 0;
  $self->{pulling} = 0;

  ## ReadableByteStreamControllerClearPendingPullIntos
  ReadableByteStreamController::_invalidate_byob_request $self;
  $self->{pending_pull_intos} = [];

  ## ResetQueue
  $self->{queue} = [];
  $self->{queue_total_size} = 0;

  $self->{started} = 0;
  $self->{close_requested} = 0;

  ## ValidateAndNormalizeHighWaterMark
  $self->{strategy_hwm} = 0+$high_water_mark; ## ToNumber
  $self->{strategy_hwm} = 0
      if $high_water_mark eq 'NaN' or $high_water_mark eq 'nan'; # Not in JS
  die _range_error "High water mark $high_water_mark is negative"
      if $high_water_mark < 0;

  my $auto_allocate_chunk_size = $underlying_byte_source->{auto_allocate_chunk_size};
  if (defined $auto_allocate_chunk_size) {
    ## In the spec, RangeError if not IsInteger(size) or size <= 0.
    ## NaN handling is different here to be Perlish.
    my $size = int _to_size $auto_allocate_chunk_size, 'Chunk size';
    die _range_error "Chunk size $auto_allocate_chunk_size is not a positive integer"
        unless $size == $auto_allocate_chunk_size and $size > 0;
    $self->{auto_allocate_chunk_size} = $size;
  }
  $self->{pending_pull_intos} = [];
  my $controller = $self;
  _hashref_method_throws ($underlying_byte_source, 'start', [$self])->then (sub {
    $controller->{started} = 1;
    ReadableByteStreamController::_call_pull_if_needed $controller;
  }, sub {
    if ($stream->{state} eq 'readable') {
      ReadableByteStreamController::_error $controller, $_[0];
    }
  });
  return $self;
} # new

sub byob_request ($) {
  if (not defined $_[0]->{byob_request} and @{$_[0]->{pending_pull_intos}}) {
    my $first_descriptor = $_[0]->{pending_pull_intos}->[0];
    my $view = TypedArray::Uint8Array->new
        ($first_descriptor->{buffer},
         $first_descriptor->{byte_offset} + $first_descriptor->{bytes_filled},
         $first_descriptor->{byte_length} - $first_descriptor->{bytes_filled});
    $_[0]->{byob_request} = ReadableStreamBYOBRequest->new ($_[0], $view);
  }
  return $_[0]->{byob_request};
} # byob_request

sub desired_size ($) {
  return ReadableByteStreamController::_get_desired_size $_[0];
} # desired_size

sub close ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_readable_stream};
  die _type_error "ReadableStream is closed" if $controller->{close_requested};
  die _type_error "ReadableStream is closed"
      unless $stream->{state} eq 'readable';

  ## ReadableByteStreamControllerClose
  if ($controller->{queue_total_size} > 0) {
    $controller->{close_requested} = 1;
    return;
  }
  if (@{$controller->{pending_pull_intos}}) {
    my $first_pending_pull_into = $controller->{pending_pull_intos}->[0];
    if ($first_pending_pull_into->{bytes_filled} > 0) {
      my $e = _type_error "There is a pending read request";
      ReadableByteStreamController::_error $controller, $e;
      die $e;
    }
  }
  ReadableStream::_close $stream;
  return undef;
} # close

sub min ($$) {
  return $_[0] > $_[1] ? $_[1] : $_[0];
}

sub ReadableByteStreamController::_fill_pull_into_descriptor_from_queue ($$) {
  my ($controller, $pull_into_descriptor) = @_;
  my $element_size = $pull_into_descriptor->{element_size};
  my $current_aligned_bytes = $pull_into_descriptor->{bytes_filled} - ($pull_into_descriptor->{bytes_filled} % $element_size);
  my $max_bytes_to_copy = min ($controller->{queue_total_size}, $pull_into_descriptor->{byte_length} - $pull_into_descriptor->{bytes_filled});
  my $max_bytes_filled = $pull_into_descriptor->{bytes_filled} + $max_bytes_to_copy;
  my $max_aligned_bytes = $max_bytes_filled - ($max_bytes_filled % $element_size);
  my $total_bytes_to_copy_remaining = $max_bytes_to_copy;
  my $ready = 0;
  if ($max_aligned_bytes > $current_aligned_bytes) {
    $total_bytes_to_copy_remaining = $max_aligned_bytes - $pull_into_descriptor->{bytes_filled};
    $ready = 1;
  }
  my $queue = $controller->{queue};
  while ($total_bytes_to_copy_remaining) {
    my $head_of_queue = $queue->[0];
    my $bytes_to_copy = min ($total_bytes_to_copy_remaining, $head_of_queue->{byte_length});
    my $dest_start = $pull_into_descriptor->{byte_offset} + $pull_into_descriptor->{bytes_filled};

    ArrayBuffer::_copy_data_block_bytes
        $pull_into_descriptor->{buffer}, $dest_start,
        $head_of_queue->{buffer}, $head_of_queue->{byte_offset},
        $bytes_to_copy;
    # XXX debug info for buffer copying

    if ($head_of_queue->{byte_length} == $bytes_to_copy) {
      shift @{$queue};
    } else {
      $head_of_queue->{byte_offset} += $bytes_to_copy;
      $head_of_queue->{byte_length} -= $bytes_to_copy;
    }
    $controller->{queue_total_size} -= $bytes_to_copy;

    ## ReadableByteStreamControllerFillHeadPullIntoDescriptor
    ReadableByteStreamController::_invalidate_byob_request $controller;
    $pull_into_descriptor->{bytes_filled} += $bytes_to_copy;

    $total_bytes_to_copy_remaining -= $bytes_to_copy;
  }
  return $ready;
} # ReadableByteStreamControllerFillPullIntoDescriptorFromQueue

sub ReadableByteStreamController::_commit_pull_into_descriptor ($$) {
  my $pull_into_descriptor = $_[1];
  my $done = $_[0]->{state} eq 'closed';

  ## ReadableByteStreamControllerConvertPullIntoDescriptor
  my $filled_view = $pull_into_descriptor->{ctor}->new
      ($pull_into_descriptor->{buffer},
       $pull_into_descriptor->{byte_offset},
       $pull_into_descriptor->{bytes_filled} / $pull_into_descriptor->{element_size});

  if ($pull_into_descriptor->{reader_type} eq 'default') {
    ## ReadableStreamFulfillReadRequest
    my $read_request = shift @{$_[0]->{reader}->{read_requests}};
    $read_request->{promise}->{resolve}->({value => $filled_view, done => $done}); # CreateIterResultObject
  } else {
    ## ReadableStreamFulfillReadIntoRequest
    my $read_into_request = shift @{$_[0]->{reader}->{read_into_requests}};
    $read_into_request->{promise}->{resolve}->({value => $filled_view, done => $done}); # CreateIterResultObject
  }
} # ReadableByteStreamControllerCommitPullIntoDescriptor

sub ReadableByteStreamController::_process_pull_into_descriptors_using_queue ($) {
  my $controller = $_[0];
  while (@{$controller->{pending_pull_intos}}) {
    return if $controller->{queue_total_size} == 0;
    my $pull_into_descriptor = $controller->{pending_pull_intos}->[0];
    if (ReadableByteStreamController::_fill_pull_into_descriptor_from_queue
            $controller, $pull_into_descriptor) {
      ## ReadableByteStreamControllerShiftPendingPullInto
      shift @{$controller->{pending_pull_intos}};
      ReadableByteStreamController::_invalidate_byob_request $controller;

      ReadableByteStreamController::_commit_pull_into_descriptor
          $controller->{controlled_readable_stream}, $pull_into_descriptor;
    }
  }
} # ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue

sub enqueue ($$) {
  my $controller = $_[0];
  die _type_error "ReadableStream is closed" if $controller->{close_requested};
  die _type_error "ReadableStream is closed"
      unless $controller->{controlled_readable_stream}->{state} eq 'readable';
  die _type_error "The argument is not an ArrayBufferView"
      unless UNIVERSAL::isa ($_[1], 'TypedArray') or
             UNIVERSAL::isa ($_[1], 'DataView'); # has [[ViewedArrayBuffer]]

  ## ReadableByteStreamControllerEnqueue
  my $stream = $controller->{controlled_readable_stream};
  my $buffer = $_[1]->{viewed_array_buffer};
  my $byte_offset = $_[1]->{byte_offset};
  my $byte_length = $_[1]->{byte_length};
  my $transferred_buffer = $buffer->_transfer;
  if (
    ## ReadableStreamHasDefaultReader
    (defined $stream->{reader} and $stream->{reader}->{read_requests}) # IsReadableStreamDefaultReader
  ) {
    if (
      ## ReadableStreamGetNumReadRequests
      @{$stream->{reader}->{read_requests}}
    == 0) {
      ## ReadableByteStreamControllerEnqueueChunkToQueue
      push @{$controller->{queue}}, {
        buffer => $transferred_buffer,
        byte_offset => $byte_offset,
        byte_length => $byte_length,
      };
      $controller->{queue_total_size} += $byte_length;
    } else {
      my $transferred_view = TypedArray::Uint8Array->new
          ($transferred_buffer, $byte_offset, $byte_length);

      ## ReadableStreamFulfillReadRequest
      my $read_request = shift @{$stream->{reader}->{read_requests}};
      $read_request->{promise}->{resolve}->({value => $transferred_view}); # CreateIterResultObject
    }
  } elsif (
    ## ReadableStreamHasBYOBReader
    (defined $stream->{reader} and defined $stream->{reader}->{read_into_requests}) # IsReadableStreamBYOBReader
  ) {
    ## ReadableByteStreamControllerEnqueueChunkToQueue
    push @{$controller->{queue}}, {
      buffer => $transferred_buffer,
      byte_offset => $byte_offset,
      byte_length => $byte_length,
    };
    $controller->{queue_total_size} += $byte_length;

    ReadableByteStreamController::_process_pull_into_descriptors_using_queue $controller;
  } else {
    ## ReadableByteStreamControllerEnqueueChunkToQueue
    push @{$controller->{queue}}, {
      buffer => $transferred_buffer,
      byte_offset => $byte_offset,
      byte_length => $byte_length,
    };
    $controller->{queue_total_size} += $byte_length;
  }
  return undef;
} # enqueue(chunk)

sub error ($$) {
  die _type_error "ReadableStream is closed"
      unless $_[0]->{controlled_readable_stream}->{state} eq 'readable';
  ReadableByteStreamController::_error $_[0], $_[1];
  return undef;
} # error(e)

sub _cancel_steps ($$) {
  if (@{$_[0]->{pending_pull_intos}}) {
    my $first_descriptor = $_[0]->{pending_pull_intos};
    $first_descriptor->{bytes_filled} = 0;
  }

  ## ResetQueue
  $_[0]->{queue} = [];
  $_[0]->{queue_total_size} = 0;

  return _hashref_method ($_[0]->{underlying_byte_source}, 'cancel', [$_[1]]);
} # [[CancelSteps]]

sub _pull_steps ($) {
  my $stream = $_[0]->{controlled_readable_stream};
  if ($_[0]->{queue_total_size}) {
    my $entry = shift @{$_[0]->{queue}};
    $_[0]->{queue_total_size} -= $entry->{byte_length};

    ## ReadableByteStreamControllerHandleQueueDrain
    if ($_[0]->{queue_total_size} == 0 and
        $_[0]->{close_requested}) {
      ReadableStream::_close $_[0]->{controlled_readable_stream};
    } else {
      ReadableByteStreamController::_call_pull_if_needed $_[0];
    }

    my $view = TypedArray::Uint8Array->new
        ($entry->{buffer}, $entry->{byte_offset}, $entry->{byte_length});
    return Promise->resolve ({value => $view}); # CreateIterResultObject
  }
  my $auto_allocate_chunk_size = $_[0]->{auto_allocate_chunk_size};
  if (defined $auto_allocate_chunk_size) {
    my $buffer = eval { ArrayBuffer->new ($auto_allocate_chunk_size) };
    return Promise->reject ($@) if $@;
    push @{$_[0]->{pending_pull_intos}}, {
      buffer => $buffer,
      byte_offset => 0, byte_length => $auto_allocate_chunk_size,
      bytes_filled => 0, element_size => 1, ctor => 'TypedArray::Uint8Array',
      reader_type => 'default',
    };
  }

  ## ReadableStreamAddReadRequest
  my $p = _promise_capability;
  push @{$stream->{reader}->{read_requests}}, {promise => $p};

  ReadableByteStreamController::_call_pull_if_needed $_[0];
  return $p->{promise};
} # [[PullSteps]

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to @{[ref $_[0]]} is not discarded before global destruction\n";
  }
} # DESTROY

package ReadableStreamBYOBRequest;
use Streams::_Common;
push our @CARP_NOT, qw(ReadableStream);

sub ReadableByteStreamController::_respond_internal ($$) {
  my $controller = $_[0];
  my $first_descriptor = $controller->{pending_pull_intos}->[0];
  my $stream = $controller->{controlled_readable_stream};
  if ($stream->{state} eq 'closed') {
    die _type_error "ReadableStream is closed" unless $_[1] == 0;

    ## ReadableByteStreamControllerRespondInClosedState
    $first_descriptor->{buffer} = $first_descriptor->{buffer}->_transfer;
    if (
      ## ReadableStreamHasBYOBReader
      (defined $stream->{reader} and defined $stream->{reader}->{read_into_requests}) # IsReadableStreamBYOBReader
    ) {
      while (
        ## ReadableStreamGetNumReadIntoRequests
        @{$stream->{reader}->{read_into_requests}}
      ) {
        ## ReadableByteStreamControllerShiftPendingPullInto
        shift @{$controller->{pending_pull_intos}};
        ReadableByteStreamController::_invalidate_byob_request $controller;

        ReadableByteStreamController::_commit_pull_into_descriptor
            $stream, $first_descriptor;
      }
    }
  } else { ## ReadableByteStreamControllerRespondInReadableState
    die _range_error "Byte length $_[1] is greater than requested length @{[$first_descriptor->{byte_length} - $first_descriptor->{bytes_filled}]}"
        if $first_descriptor->{bytes_filled} + $_[1] > $first_descriptor->{byte_length};

    ## ReadableByteStreamControllerFillHeadPullIntoDescriptor
    ReadableByteStreamController::_invalidate_byob_request $controller;
    $first_descriptor->{bytes_filled} += $_[1];

    return if $first_descriptor->{bytes_filled} < $first_descriptor->{element_size};

    ## ReadableByteStreamControllerShiftPendingPullInto
    shift @{$controller->{pending_pull_intos}};
    ReadableByteStreamController::_invalidate_byob_request $controller;

    my $remainder_size = $first_descriptor->{bytes_filled} % $first_descriptor->{element_size};
    if ($remainder_size > 0) {
      my $end = $first_descriptor->{byte_offset} + $first_descriptor->{bytes_filled};
      my $remainder = ArrayBuffer->_clone
          ($first_descriptor->{buffer},
           $end - $remainder_size, $remainder_size);

      ## ReadableByteStreamControllerEnqueueChunkToQueue
      push @{$controller->{queue}}, {
        buffer => $remainder,
        byte_offset => 0,
        byte_length => $remainder->{byte_length},
      };
      $controller->{queue_total_size} += $remainder->{byte_length};
    }
    $first_descriptor->{buffer} = $first_descriptor->{buffer}->_transfer;
    $first_descriptor->{bytes_filled} -= $remainder_size;
    ReadableByteStreamController::_commit_pull_into_descriptor 
        $controller->{controlled_readable_stream}, $first_descriptor;
    ReadableByteStreamController::_process_pull_into_descriptors_using_queue $controller;
  }
} # ReadableByteStreamControllerRespondInternal

sub new ($$$) {
  my $self = bless {}, $_[0];
  $self->{associated_readable_byte_stream_controller} = $_[1];
  $self->{view} = $_[2];
  return $self;
} # new

sub view ($) {
  return $_[0]->{view};
} # view

sub respond ($$) {
  die _type_error "There is no controller"
      unless UNIVERSAL::isa ($_[0]->{associated_readable_byte_stream_controller}, 'ReadableByteStreamController'); # not undefined in spec

  ## ReadableByteStreamControllerRespond
  my $bytes_written = _to_size $_[1], 'Byte length';
  ReadableByteStreamController::_respond_internal
      $_[0]->{associated_readable_byte_stream_controller}, $bytes_written;
  return undef;
} # respond(bytesWritten)

## Not in JS.  Applications should not use this method.
sub manakai_respond_by_sysread ($$) {
  die _type_error "There is no controller"
      unless UNIVERSAL::isa ($_[0]->{associated_readable_byte_stream_controller}, 'ReadableByteStreamController'); # not undefined in spec
  my $view = $_[0]->view;
  $view->buffer->{array_buffer_data} = \(my $x = ''),
      delete $view->buffer->{allocation_delayed}
      unless ref $view->buffer->{array_buffer_data};
  my $bytes_read = sysread $_[1],
      ${$view->buffer->{array_buffer_data}},
      $view->byte_length, $view->byte_offset;
  die _type_error $! unless defined $bytes_read;
  ## Note that sysread can truncate array_buffer_data and
  ## ArrayBuffer's internal status might become inconsitent.

  ## ReadableByteStreamControllerRespond
  #my $bytes_written = _to_size $bytes_read, 'Byte length';
  ReadableByteStreamController::_respond_internal
      $_[0]->{associated_readable_byte_stream_controller}, $bytes_read;

  return $bytes_read;
} # manakai_respond_by_sysread

sub respond_with_new_view ($$) {
  die _type_error "There is no controller"
      unless UNIVERSAL::isa ($_[0]->{associated_readable_byte_stream_controller}, 'ReadableByteStreamController'); # not undefined in spec
  die _type_error "The argument is not an ArrayBufferView"
      unless UNIVERSAL::isa ($_[1], 'TypedArray') or
             UNIVERSAL::isa ($_[1], 'DataView'); # has [[ViewedArrayBuffer]]

  ## ReadableByteStreamControllerRespondWithNewView
  my $controller = $_[0]->{associated_readable_byte_stream_controller};
  my $first_descriptor = $controller->{pending_pull_intos}->[0];
  die _range_error "Bad byte offset $_[1]->{byte_offset} != @{[$first_descriptor->{byte_offset} + $first_descriptor->{bytes_filled}]}"
      unless $first_descriptor->{byte_offset} + $first_descriptor->{bytes_filled} == $_[1]->{byte_offset};
  die _range_error "Bad byte length $_[1]->{byte_length} != $first_descriptor->{byte_length}"
      unless $first_descriptor->{byte_length} == $_[1]->{byte_length};
  $first_descriptor->{buffer} = $_[1]->{viewed_array_buffer};
  ReadableByteStreamController::_respond_internal
      $controller, $_[1]->{byte_length};
  return undef;
} # respondWithNewView(view)

## Not in JS.  Applications should not use this method.
sub manakai_respond_with_new_view ($$) {
  die _type_error "There is no controller"
      unless UNIVERSAL::isa ($_[0]->{associated_readable_byte_stream_controller}, 'ReadableByteStreamController'); # not undefined in spec
  die _type_error "The argument is not an ArrayBufferView"
      unless UNIVERSAL::isa ($_[1], 'TypedArray') or
             UNIVERSAL::isa ($_[1], 'DataView'); # has [[ViewedArrayBuffer]]

  ## A modified version of ReadableByteStreamControllerRespondWithNewView
  my $controller = $_[0]->{associated_readable_byte_stream_controller};
  my $first_descriptor = $controller->{pending_pull_intos}->[0];
  die _range_error "Bad byte offset $_[1]->{byte_offset} != @{[$first_descriptor->{byte_offset} + $first_descriptor->{bytes_filled}]}"
      unless $first_descriptor->{byte_offset} + $first_descriptor->{bytes_filled} == $_[1]->{byte_offset};
  die "RangeError: not $first_descriptor->{byte_length} >= $_[1]->{byte_length}"
      unless $first_descriptor->{byte_length} >= $_[1]->{byte_length};
  $first_descriptor->{buffer} = $_[1]->{viewed_array_buffer};
  $first_descriptor->{byte_length} = $_[1]->{byte_length};
  ReadableByteStreamController::_respond_internal
      $controller, $_[1]->{byte_length};
  return undef;
} # manakai_respond_with_new_value

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to @{[ref $_[0]]} is not discarded before global destruction\n";
  }
} # DESTROY

package ReadableStreamDefaultReader;
use Streams::_Common;
push our @CARP_NOT, qw(ReadableStream);

sub new ($$) {
  my $stream = $_[1];
  die _type_error "The argument is not a ReadableStream"
      unless UNIVERSAL::isa ($stream, 'ReadableStream'); # IsReadableStream
  die _type_error "ReadableStream is locked"
      if defined $stream->{reader}; # IsReadableStreamLocked
  my $reader = {};
  my $self = bless \$stream, $_[0];

  ## ReadableStreamReaderGenericInitialize
  #$reader->{owner_readable_stream} = $stream;
  $stream->{reader} = $reader;
  $reader->{closed_promise} = _promise_capability;
  if ($stream->{state} eq 'readable') {
    #
  } elsif ($stream->{state} eq 'closed') {
    $reader->{closed_promise}->{resolve}->(undef);
  } else {
    $reader->{closed_promise}->{reject}->($stream->{stored_error});
    $reader->{closed_promise}->{promise}->manakai_set_handled;
  }

  $reader->{read_requests} = [];
  return $self;
} # new

sub read ($) {
  my $stream = ${$_[0]};
  #my $stream = $_[0]->{owner_readable_stream};
  return Promise->reject (_type_error "Reader's lock is released")
      unless defined $stream->{state};

  ## ReadableStreamDefaultReaderRead
  $stream->{disturbed} = 1;
  if ($stream->{state} eq 'closed') {
    return Promise->resolve ({done => 1}); # CreateIterResultObject
  } elsif ($stream->{state} eq 'errored') {
    return Promise->reject ($stream->{stored_error});
  }
  return $stream->{readable_stream_controller}->_pull_steps;
} # read

sub closed ($) {
  my $reader = ${$_[0]}->{reader};
  return $reader->{closed_promise}->{promise};
} # closed

sub cancel ($$) {
  my $stream = ${$_[0]};
  return Promise->reject (_type_error "Reader's lock is released")
      unless defined $stream->{state}; #$_[0]->{owner_readable_stream};

  ## ReadableStreamReaderGenericCancel
  return ReadableStream::_cancel $stream, $_[1];
  #return ReadableStream::_cancel $_[0]->{owner_readable_stream}, $_[1];
} # cancel

sub release_lock ($) {
  my $reader = ${$_[0]}->{reader};
  return undef unless defined ${$_[0]}->{state}; #$reader->{owner_readable_stream};
  die _type_error "There is a pending read request"
      if @{$reader->{read_requests}};

  ## ReadableStreamReaderGenericRelease
  $reader->{closed_promise} ||= _promise_capability;
  #if ($reader->{owner_readable_stream}->{state} eq 'readable') {
  if (${$_[0]}->{state} eq 'readable') {
    $reader->{closed_promise}->{reject}->(_type_error "Reader's lock is released");
  }
  $reader->{closed_promise}->{promise}->manakai_set_handled;

  ${$_[0]}->{reader} = undef;
  ${$_[0]} = {reader => $reader};
  #$reader->{owner_readable_stream}->{reader} = undef;
  #$reader->{owner_readable_stream} = undef;

  return undef;
} # releaseLock

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to @{[ref $_[0]]} is not discarded before global destruction\n";
  }
} # DESTROY

package ReadableStreamBYOBReader;
use Streams::_Common;
push our @CARP_NOT, qw(ReadableStream);

sub new ($$) {
  my $stream = $_[1];
  die _type_error "The argument is not a ReadableStream"
      unless UNIVERSAL::isa ($stream, 'ReadableStream'); # IsReadableStream
  die _type_error "ReadableStream is not a byte stream"
      unless $stream->{readable_stream_controller}->isa
          ('ReadableByteStreamController'); # IsReadableByteStreamController
  die _type_error "ReadableStream is locked"
      if defined $stream->{reader}; # IsReadableStreamLocked
  my $reader = {};
  my $self = bless \$stream, $_[0];

  ## ReadableStreamReaderGenericInitialize
  #$reader->{owner_readable_stream} = $stream;
  $stream->{reader} = $reader;
  $reader->{closed_promise} = _promise_capability;
  if ($stream->{state} eq 'readable') {
    #
  } elsif ($stream->{state} eq 'closed') {
    $reader->{closed_promise}->{resolve}->(undef);
  } else {
    $reader->{closed_promise}->{reject}->($stream->{stored_error});
    $reader->{closed_promise}->{promise}->manakai_set_handled;
  }

  $reader->{read_into_requests} = [];
  return $self;
} # new

sub closed ($) {
  my $reader = ${$_[0]}->{reader};
  return $reader->{closed_promise}->{promise};
} # closed

sub cancel ($$) {
  my $stream = ${$_[0]};
  return Promise->reject (_type_error "Reader's lock is released")
      unless defined $stream->{state}; #$_[0]->{owner_readable_stream};

  ## ReadableStreamReaderGenericCancel
  return ReadableStream::_cancel $stream, $_[1];
  #return ReadableStream::_cancel $_[0]->{owner_readable_stream}, $_[1];
} # cancel

sub read ($$) {
  my $stream = ${$_[0]}; #$_[0]->{owner_readable_stream};
  my $view = $_[1];
  return Promise->reject (_type_error "Reader's lock is released")
      unless defined $stream->{state};
  return Promise->reject (_type_error "The argument is not an ArrayBufferView")
      unless UNIVERSAL::isa ($view, 'TypedArray') or
             UNIVERSAL::isa ($view, 'DataView'); # has [[ViewedArrayBuffer]]
  return Promise->reject (_type_error "The ArrayBufferView is empty")
      if $view->{byte_length} == 0;

  ## ReadableStreamBYOBReaderRead
  {
    $stream->{disturbed} = 1;
    return Promise->reject ($stream->{stored_error})
        if $stream->{state} eq 'errored';

    ## ReadableByteStreamControllerPullInto
    my $controller = $stream->{readable_stream_controller};
    #my $stream = $controller->{controlled_readable_stream};
    my $element_size = 1;
    my $ctor = 'DataView';
    if ($view->isa ('TypedArray')) { ## has [[TypedArrayName]]
      $element_size = $view->BYTES_PER_ELEMENT; # Table
      $ctor = ref $view; ## [[TypedArrayName]]
    }
    my $pull_into_descriptor = {
      buffer => $view->{viewed_array_buffer},
      byte_offset => $view->{byte_offset},
      byte_length => $view->{byte_length},
      bytes_filled => 0,
      element_size => $element_size,
      ctor => $ctor,
      reader_type => 'byob',
    };
    if (@{$controller->{pending_pull_intos}}) {
      $pull_into_descriptor->{buffer} = $pull_into_descriptor->{buffer}->_transfer;
      push @{$controller->{pending_pull_intos}}, $pull_into_descriptor;

      ## ReadableStreamAddReadIntoRequest
      my $read_into_request = {promise => _promise_capability};
      push @{$stream->{reader}->{read_into_requests}}, $read_into_request;
      return $read_into_request->{promise}->{promise};
    }
    if ($stream->{state} eq 'closed') {
      my $empty_view = $ctor->new
          ($pull_into_descriptor->{buffer}, $pull_into_descriptor->{byte_offset}, 0);
      return Promise->resolve
          ({value => $empty_view, done => 1}); # CreateIterResultObject
    }
    if ($controller->{queue_total_size} > 0) {
      if (ReadableByteStreamController::_fill_pull_into_descriptor_from_queue
              $controller, $pull_into_descriptor) {
        ## ReadableByteStreamControllerConvertPullIntoDescriptor
        my $filled_view = $pull_into_descriptor->{ctor}->new
            ($pull_into_descriptor->{buffer},
             $pull_into_descriptor->{byte_offset},
             $pull_into_descriptor->{bytes_filled} / $pull_into_descriptor->{element_size});

        ## ReadableByteStreamControllerHandleQueueDrain
        if ($controller->{queue_total_size} == 0 and
            $controller->{close_requested}) {
          ReadableStream::_close $controller->{controlled_readable_stream};
        } else {
          ReadableByteStreamController::_call_pull_if_needed $controller;
        }

        return Promise->resolve ({value => $filled_view}); # CreateIterResultObject
      }
      if ($controller->{close_requested}) {
        my $e = _type_error "ReadableStream is closed";
        ReadableByteStreamController::_error $controller, $e;
        return Promise->reject ($e);
      }
    }
    $pull_into_descriptor->{buffer} = $pull_into_descriptor->{buffer}->_transfer;
    push @{$controller->{pending_pull_intos}}, $pull_into_descriptor;

    ## ReadableStreamAddReadIntoRequest
    my $read_into_request = {promise => _promise_capability};
    push @{$stream->{reader}->{read_into_requests}}, $read_into_request;

    ReadableByteStreamController::_call_pull_if_needed $controller;
    return $read_into_request->{promise}->{promise};
  }
} # read

sub release_lock ($) {
  my $reader = ${$_[0]}->{reader};
  return undef unless defined ${$_[0]}->{state}; #$reader->{owner_readable_stream};
  die _type_error "There is a pending read request"
      if @{$reader->{read_into_requests}};

  ## ReadableStreamReaderGenericRelease
  $reader->{closed_promise} ||= _promise_capability;
  if (${$_[0]}->{state} eq 'readable') {
  #if ($reader->{owner_readable_stream}->{state} eq 'readable') {
    $reader->{closed_promise}->{reject}->(_type_error "Reader's lock is released");
  }
  $reader->{closed_promise}->{promise}->manakai_set_handled;

  ${$_[0]}->{reader} = undef;
  ${$_[0]} = {reader => $reader};
  #$reader->{owner_readable_stream}->{reader} = undef;
  #$reader->{owner_readable_stream} = undef;

  return undef;
} # releaseLock

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to @{[ref $_[0]]} is not discarded before global destruction\n";
  }
} # DESTROY

1;

# XXX documentation

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
