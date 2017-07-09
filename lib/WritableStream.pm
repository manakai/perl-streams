package WritableStream;
use strict;
use warnings;
our $VERSION = '1.0';
use Promise;
use Streams::_Common;

sub new ($;$$) {
  die _type_error "Sink is not a HASH"
      if defined $_[1] and not ref $_[1] eq 'HASH'; # Not in JS
  die _type_error "Options is not a HASH"
      if defined $_[2] and not ref $_[2] eq 'HASH'; # Not in JS
  my $self = bless {}, $_[0];
  my $underlying_sink = $_[1] || {};
  my $opts = $_[2] || {high_water_mark => 1};
  die _range_error "Unknown type |$underlying_sink->{type}|"
      if defined $underlying_sink->{type};
  $self->{state} = 'writable';
  $self->{stored_error} = undef;
  $self->{writer} = undef;
  $self->{in_flight_write_request} = undef;
  $self->{close_request} = undef;
  $self->{in_flight_close_request} = undef;
  $self->{pending_abort_request} = undef;
  $self->{write_requests} = [];
  $self->{backpressure} = !!0;
  $self->{writable_stream_controller} = WritableStreamDefaultController->new
      ($self, $underlying_sink, $opts->{size}, $opts->{high_water_mark});
  ## [[StartSteps]] is invoked within WritableStreamDefaultController::new
  return $self;
} # new

sub locked ($) {
  return defined $_[0]->{writer}; # IsWritableStreamLocked
} # locked

sub abort ($$) {
  return Promise->reject (_type_error "WritableStream is locked")
      if defined $_[0]->{writer}; # IsWritableStreamLocked
  return $_[0]->_abort ($_[1]);
} # abort

sub get_writer ($) {
  ## AcquireWritableStreamDefaultWriter
  return WritableStreamDefaultWriter->new ($_[0]);
} # get_writer

sub WritableStream::_update_backpressure ($$) {
  my ($stream, $controller) = @_;

  my $backpressure = (
    ## WritableStreamDefaultControllerGetBackpressure
    (
      ## WritableStreamDefaultControllerGetDesiredSize
      (
        $controller->{strategy_hwm} - $controller->{queue_total_size}
      )
      <= 0
    )
  );

  ## WritableStreamUpdateBackpressure
  my $writer = $stream->{writer};
  if (defined $writer and
      not $backpressure eq $stream->{backpressure}) {
    if ($backpressure) {
      $writer->{ready_promise} = _promise_capability;
    } else {
      $writer->{ready_promise}->{resolve}->(undef);
    }
  }
  $stream->{backpressure} = $backpressure;
} # _update_backpressure

sub WritableStream::_reject_close_and_closed_promise_if_needed ($) {
  my $stream = $_[0];
  if (defined $stream->{close_request}) {
    $stream->{close_request}->{reject}->($stream->{stored_error});
    $stream->{close_request} = undef;
  }
  my $writer = $stream->{writer};
  if (defined $writer) {
    $writer->{closed_promise}->{reject}->($stream->{stored_error});
    $writer->{closed_promise}->{promise}->manakai_set_handled;
  }
} # WritableStreamRejectCloseAndClosedPromiseIfNeeded

sub WritableStream::_finish_erroring ($) {
  my $stream = $_[0];
  $stream->{state} = 'errored';
  $stream->{writable_stream_controller}->_error_steps;
  my $stored_error = $stream->{stored_error};
  for my $write_request (@{$stream->{write_requests}}) {
    $write_request->{reject}->($stored_error);
  }
  $stream->{write_requests} = [];
  if (not defined $stream->{pending_abort_request}) {
    WritableStream::_reject_close_and_closed_promise_if_needed $stream;
    return;
  }
  my $abort_request = $stream->{pending_abort_request};
  $stream->{pending_abort_request} = undef;
  if ($abort_request->{was_already_erroring}) {
    $abort_request->{promise}->{reject}->($stored_error);
    WritableStream::_reject_close_and_closed_promise_if_needed $stream;
    return;
  }
  $stream->{writable_stream_controller}->_abort_steps ($abort_request->{reason})->then (sub {
    $abort_request->{promise}->{resolve}->(undef);
    WritableStream::_reject_close_and_closed_promise_if_needed $stream;
  }, sub {
    $abort_request->{promise}->{reject}->($_[0]);
    WritableStream::_reject_close_and_closed_promise_if_needed $stream;
  });
} # WritableStreamFinishErroring

sub WritableStream::_start_erroring ($$) {
  my $stream = $_[0];
  my $controller = $stream->{writable_stream_controller};
  $stream->{state} = 'erroring';
  $stream->{stored_error} = $_[1];
  my $writer = $stream->{writer};
  if (defined $writer) {
    ## WritableStreamDefaultWriterEnsureReadyPromiseRejected
    $writer->{ready_promise} ||= _promise_capability;
    $writer->{ready_promise}->{reject}->($_[1]);
    $writer->{ready_promise}->{promise}->manakai_set_handled;
  }

  if (not (
    ## WritableStreamHasOperationMarkedInFlight
    not (
      not defined $stream->{in_flight_writer_request} and
      not defined $controller->{in_flight_close_request}
    )
  ) and $controller->{started}) {
    WritableStream::_finish_erroring $stream;
  }
} # WritableStreamStartErroring

sub WritableStream::_deal_with_rejection ($$) {
  my $stream = $_[0];
  if ($stream->{state} eq 'writable') {
    WritableStream::_start_erroring $stream, $_[1];
    return;
  }
  WritableStream::_finish_erroring $stream;
} # WritableStreamDealWithRejection

## This is not a public method but can be used to implement
## specification operations invoking WritableStreamAbort.
sub WritableStream::_abort ($$) {
  ## WritableStreamAbort
  my $stream = $_[0];
  if ($stream->{state} eq 'closed') {
    return Promise->resolve (undef);
  } elsif ($stream->{state} eq 'errored') {
    return Promise->reject ($stream->{stored_error});
  }
  my $error = _type_error "WritableStream is aborted";
  if (defined $stream->{pending_abort_request}) {
    return Promise->reject ($error);
  }
  my $reason = $stream->{state} eq 'erroring' ? undef : $_[1];
  my $was_already_erroring = $stream->{state} eq 'erroring';
  my $p = _promise_capability;
  $stream->{pending_abort_request} = {
    promise => $p,
    reason => $reason,
    was_already_erroring => $was_already_erroring,
  };
  WritableStream::_start_erroring $stream, $error
      unless $was_already_erroring;
  return $p->{promise};
} # _abort

sub WritableStreamDefaultController::_process_close ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_writable_stream};

  ## WritableStreamMarkCloseRequestInFlight
  $stream->{in_flight_close_request} = $stream->{close_request};
  $stream->{close_request} = undef;

  ## DequeueValue
  {
    my $pair = shift @{$controller->{queue}};
    $controller->{queue_total_size} -= $pair->{size};
    $controller->{queue_total_size} = 0 if $controller->{queue_total_size} < 0;
    #$pair->{value};
  }

  _hashref_method ($controller->{underlying_sink}, 'close', [])->then (sub {
    ## WritableStreamFinishInFlightClose
    $stream->{in_flight_close_request}->{resolve}->(undef);
    $stream->{in_flight_close_request} = undef;
    if ($stream->{state} eq 'erroring') {
      $stream->{stored_error} = undef;
      if (defined $stream->{pending_abort_request}) {
        $stream->{pending_abort_request}->{promise}->{resolve}->(undef);
        $stream->{pending_abort_request} = undef;
      }
    }
    $stream->{state} = 'closed';
    if (defined $stream->{writer}) {
      $stream->{writer}->{closed_promise}->{resolve}->(undef);
    }
  }, sub {
    ## WritableStreamFinishInFlightCloseWithError
    $stream->{in_flight_close_request}->{reject}->($_[0]);
    $stream->{in_flight_close_request} = undef;
    if (defined $stream->{pending_abort_request}) {
      $stream->{pending_abort_request}->{promise}->{reject}->($_[0]);
      $stream->{pending_abort_request} = undef;
    }
    WritableStream::_deal_with_rejection $stream, $_[1];
  });
} # WritableStreamDefaultControllerProcessClose

sub WritableStreamDefaultController::_process_write ($$) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_writable_stream};

  ## WritableStreamMarkFirstWriteRequestInFlight
  $stream->{in_flight_write_request} = shift @{$stream->{write_requests}};

  _hashref_method ($controller->{underlying_sink}, 'write', [$_[1], $controller])->then (sub {
    ## WritableStreamFinishInFlightWrite
    $stream->{in_flight_write_request}->{resolve}->(undef);
    $stream->{in_flight_write_request} = undef;

    ## DequeueValue
    my $pair = shift @{$controller->{queue}};
    $controller->{queue_total_size} -= $pair->{size};
    $controller->{queue_total_size} = 0 if $controller->{queue_total_size} < 0;
    #$pair->{value};

    if (
      not
      ## WritableStreamCloseQueuedOrInFlight
      (defined $stream->{close_request} or
       defined $stream->{in_flight_close_request}) and
      $stream->{state} eq 'writable'
    ) {
      $stream->_update_backpressure ($controller);
    }
    WritableStreamDefaultController::_advance_queue_if_needed ($controller);
  }, sub {
    ## WritableStreamFinishInFlightWriteWithError
    $stream->{in_flight_write_request}->{reject}->($_[0]);
    $stream->{in_flight_write_request} = undef;
    WritableStream::_deal_with_rejection $stream, $_[0];
  });
} # WritableStreamDefaultControllerProcessWrite

sub WritableStreamDefaultController::_advance_queue_if_needed ($) {
  my $controller = $_[0];
  my $stream = $controller->{controlled_writable_stream};
  return if not $controller->{started};
  return if defined $stream->{in_flight_write_request};
  return if $stream->{state} eq 'closed' or $stream->{state} eq 'errored';
  if ($stream->{state} eq 'erroring') {
    WritableStream::_finish_erroring $stream;
    return;
  }
  return unless @{$controller->{queue}};

  my $write_record = $controller->{queue}->[0]->{value}; # PeekQueueValue
  if ($write_record eq 'close') {
    WritableStreamDefaultController::_process_close $controller;
  } else {
    WritableStreamDefaultController::_process_write
        $controller, $write_record->{chunk};
  }
} # WritableStreamDefaultControllerAdvanceQueueIfNeeded

package WritableStreamDefaultWriter;
use Streams::_Common;
push our @CARP_NOT, qw(WritableStream);

sub new ($$) {
  my $self = bless {}, $_[0];
  my $stream = $_[1];
  die _type_error "The argument is not a WritableStream"
      unless UNIVERSAL::isa ($stream, 'WritableStream'); # IsWritableStream
  die _type_error "WritableStream is locked"
      if defined $stream->{writer}; # IsWritableStreamLocked
  $self->{owner_writable_stream} = $stream;
  $stream->{writer} = $self;
  $self->{ready_promise} = _promise_capability;
  $self->{closed_promise} = _promise_capability;
  if ($stream->{state} eq 'writable') {
    if (
      not
      ## WritableStreamCloseQueuedOrInFlight
      (defined $stream->{close_request} or
       defined $stream->{in_flight_close_request}) and
      $stream->{backpressure}
    ) {
      #
    } else {
      $self->{ready_promise}->{resolve}->(undef);
    }
  } elsif ($stream->{state} eq 'erroring') {
    $self->{ready_promise}->{reject}->($stream->{stored_error});
    $self->{ready_promise}->{promise}->manakai_set_handled;
  } elsif ($stream->{state} eq 'closed') {
    $self->{ready_promise}->{resolve}->(undef);
    $self->{closed_promise}->{resolve}->(undef);
  } else {
    my $stored_error = $stream->{stored_error};
    $self->{ready_promise}->{reject}->($stream->{stored_error});
    $self->{ready_promise}->{promise}->manakai_set_handled;
    $self->{closed_promise}->{reject}->($stream->{stored_error});
    $self->{closed_promise}->{promise}->manakai_set_handled;
  }
  return $self;
} # new

sub closed ($) {
  return $_[0]->{closed_promise}->{promise};
} # closed

sub desired_size ($) {
  my $stream = $_[0]->{owner_writable_stream};
  die _type_error "Writer's lock is released" unless defined $stream;

  ## WritableStreamDefaultWriterGetDesiredSize
  {
    if ($stream->{state} eq 'errored' or
        $stream->{state} eq 'erroring') {
      return undef;
    } elsif ($stream->{state} eq 'closed') {
      return 0;
    }

    ## WritableStreamDefaultControllerGetDesiredSize
    return $stream->{writable_stream_controller}->{strategy_hwm}
         - $stream->{writable_stream_controller}->{queue_total_size};
  }
} # desired_size

sub ready ($) {
  return $_[0]->{ready_promise}->{promise};
} # ready

sub abort ($$) {
  return Promise->reject (_type_error "Writer's lock is released")
      unless defined $_[0]->{owner_writable_stream};

  ## WritableStreamDefaultWriterAbort
  return $_[0]->{owner_writable_stream}->_abort ($_[1]);
} # abort

sub close ($) {
  my $writer = $_[0];
  my $stream = $writer->{owner_writable_stream};
  return Promise->reject (_type_error "Writer's lock is released")
      unless defined $stream;
  return Promise->reject (_type_error "WritableStream is closed")
      if
      ## WritableStreamCloseQueuedOrInFlight
      (defined $stream->{close_request} or
       defined $stream->{in_flight_close_request});

  ## WritableStreamDefaultWriterClose
  {
    return Promise->reject (_type_error "WritableStream is closed")
        if $stream->{state} eq 'closed' or $stream->{state} eq 'errored';
    my $p = $stream->{close_request} = _promise_capability;
    if ($stream->{backpressure} and $stream->{state} eq 'writable') {
      $writer->{ready_promise}->{resolve}->(undef);
    }

    ## WritableStreamDefaultControllerClose
    {
      ## EnqueueValueWithSize
      #my $size = _to_size 0, 'Size';
      push @{$stream->{writable_stream_controller}->{queue}},
          {value => 'close', size => 0};
      #$stream->{writable_stream_controller}->{queue_total_size} += $size;

      WritableStreamDefaultController::_advance_queue_if_needed
          $stream->{writable_stream_controller};
    }

    return $p->{promise};
  }
} # close

sub release_lock ($) {
  my $writer = $_[0];
  return undef unless defined $writer->{owner_writable_stream};

  ## WritableStreamDefaultWriterRelease
  {
    my $released_error = _type_error "Writer's lock is released";

    ## WritableStreamDefaultWriterEnsureReadyPromiseRejected
    $writer->{ready_promise} ||= _promise_capability;
    $writer->{ready_promise}->{reject}->($released_error);
    $writer->{ready_promise}->{promise}->manakai_set_handled;

    ## WritableStreamDefaultWriterEnsureClosedPromiseRejected
    $writer->{closed_promise} ||= _promise_capability;
    $writer->{closed_promise}->{reject}->($released_error);
    $writer->{closed_promise}->{promise}->manakai_set_handled;

    $writer->{owner_writable_stream}->{writer} = undef;
    $writer->{owner_writable_stream} = undef;
    return undef;
  }
} # release_lock

sub write ($$) {
  return Promise->reject (_type_error "Writer's lock is released")
      unless defined $_[0]->{owner_writable_stream};

  ## WritableStreamDefaultWriterWrite
  my $writer = $_[0];
  my $stream = $writer->{owner_writable_stream};
  my $controller = $stream->{writable_stream_controller};

  ## WritableStreamDefaultControllerGetChunkSize
  my $chunk_size = 1;
  if (defined $controller->{strategy_size}) {
    eval { $chunk_size = $controller->{strategy_size}->($_[1]) };
    if ($@) {
      ## WritableStreamDefaultControllerErrorIfNeeded
      if ($controller->{controlled_writable_stream}->{state} eq 'writable') {
        ## WritableStreamDefaultControllerError
        WritableStream::_start_erroring $controller->{controlled_writable_stream}, $@;
      }
    }
  }

  return Promise->reject (_type_error "Writer's lock is released")
      unless defined $writer->{owner_writable_stream} and
             $stream eq $writer->{owner_writable_stream};

  my $state = $stream->{state};
  return Promise->reject ($stream->{stored_error}) if $state eq 'errored';
  return Promise->reject (_type_error "WritableStream is closed")
      if
      ## WritableStreamCloseQueuedOrInFlight
      (defined $stream->{close_request} or
       defined $stream->{in_flight_close_request}) or
      $state eq 'closed';
  return Promise->reject ($stream->{stored_error}) if $state eq 'erroring';

  ## WritableStreamAddWriteRequest
  my $pc = _promise_capability;
  push @{$stream->{write_requests}}, $pc;

  ## WritableStreamDefaultControllerWrite
  {
    ## EnqueueValueWithSize
    my $size = eval { _to_size $chunk_size, 'Size' };
    if ($@) {
      ## WritableStreamDefaultControllerErrorIfNeeded
      if ($controller->{controlled_writable_stream}->{state} eq 'writable') {
        ## WritableStreamDefaultControllerError
        WritableStream::_start_erroring $controller->{controlled_writable_stream}, $@;
      }
      last;
    }
    push @{$controller->{queue}}, {value => {chunk => $_[1]}, size => $size};
    $controller->{queue_total_size} += $size;

    my $stream = $controller->{controlled_writable_stream};
    if (
      not
        ## WritableStreamCloseQueuedOrInFlight
        (defined $stream->{close_request} or
         defined $stream->{in_flight_close_request}) and
      $stream->{state} eq 'writable'
    ) {
      $stream->_update_backpressure ($controller);
    }
    WritableStreamDefaultController::_advance_queue_if_needed $controller;
  }

  return $pc->{promise};
} # write(chunk)

package WritableStreamDefaultController;
use Streams::_Common;
push our @CARP_NOT, qw(WritableStream);

sub new ($$$$$) {
  my (undef, $stream, $underlying_sink, $size, $high_water_mark) = @_;
  my $self = bless {}, $_[0];
  die _type_error "The argument is not a WritableStream"
      unless UNIVERSAL::isa ($stream, 'WritableStream'); # IsWritableStream
  die _type_error "WritableStream has a controller"
      if defined $stream->{writable_stream_controller};
  $self->{controlled_writable_stream} = $stream;
  $self->{underlying_sink} = $underlying_sink;
  $self->{started} = 0;

  ## ResetQueue
  $self->{queue} = [];
  $self->{queue_total_size} = 0;

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

  $stream->_update_backpressure ($self);

  ## [[StartSteps]].  In the spec, this is invoked from WritableStream::new.
  _hashref_method_throws ($underlying_sink, 'start', [$self])->then (sub { # requires Promise
    $self->{started} = 1;
    WritableStreamDefaultController::_advance_queue_if_needed $self;
  }, sub {
    $self->{started} = 1;
    WritableStream::_deal_with_rejection $stream, $_[0];
  });

  return $self;
} # new

sub error ($$) {
  my $state = $_[0]->{controlled_writable_stream}->{state};
  return undef unless $state eq 'writable';

  ## WritableStreamDefaultControllerError
  {
    WritableStream::_start_erroring $_[0]->{controlled_writable_stream}, $_[1];
  }

  return undef;
} # error(e)

sub _abort_steps ($$) {
  return _hashref_method ($_[0]->{underlying_sink}, 'abort', [$_[1]]);
} # [[AbortSteps]]

sub _error_steps ($) {
  ## ResetQueue
  $_[0]->{queue} = [];
  $_[0]->{queue_total_size} = 0;
} # [[ErrorSteps]]

1;

# XXX documentation
# XXX DESTROY
# XXX loop

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
