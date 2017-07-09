package WritableStream;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Scalar::Util qw(weaken);
use Promise;
use Streams::_Common;

## In JS (Streams Standard specification text), stream and controller
## are referencing each other by their internal slots:
##
##   stream.[[WritableStreamController]] === controller
##   controller.[[ControlledWritableStream]] === stream
##
## In this module, a $stream is a blessed hash reference whose
## |writable_stream_controller| is a non-blessed hash reference
## containing controller's internal slots (except for
## [[ControlledWritableStream]]).  A $controller_obj is a blessed
## scalar reference to $stream.  $stream->{controller_obj} is a weak
## reference to $controller_obj.  $controller_obj is used when
## $underlying_sink methods are invoked.  If $stream->{controller_obj}
## is not defined, a new blessed scalar reference is created.
##
## Likewise, stream and reader are referencing each other in JS when
## there is a writer whose lock is not released:
##
##   stream.[[Writer]] === writer
##   writer.[[OwnerWritableStream]] === stream
##
## In this module, a $writer is a blessed scalar reference to $stream
## whose |writer| is a non-blessed hash reference containing writer's
## internal slots (except for [[OwnerWritableStream]]).  When the
## $writer's lock is released, $$writer is replaced by a hash
## reference whose |writer| is $writer's hash reference (and
## $stream->{writer} is set to |undef|).

sub new ($;$$) {
  die _type_error "Sink is not a HASH"
      if defined $_[1] and not ref $_[1] eq 'HASH'; # Not in JS
  die _type_error "Options is not a HASH"
      if defined $_[2] and not ref $_[2] eq 'HASH'; # Not in JS
  my $self = bless {
    created_location => Carp::shortmess,
  }, $_[0];
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
  #$self->{writable_stream_controller} = # (to be set within new)
  WritableStreamDefaultController->new
      ($self, $underlying_sink, $opts->{size}, $opts->{high_water_mark});
  ## [[StartSteps]] is invoked within WritableStreamDefaultController::new
  return $self;
} # new

sub locked ($) {
  return defined $_[0]->{writer}; # IsWritableStreamLocked
} # locked

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
  $stream->_terminate; # Not in JS
} # WritableStreamRejectCloseAndClosedPromiseIfNeeded

sub WritableStream::_finish_erroring ($) {
  my $stream = $_[0];
  $stream->{state} = 'errored';
  my $controller_obj = $stream->{controller_obj};
  unless (defined $controller_obj) {
    weaken ($stream->{controller_obj} = bless \$stream, 'WritableStreamDefaultController');
    $controller_obj = $stream->{controller_obj};
  }
  $controller_obj->_error_steps;
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
  $controller_obj->_abort_steps ($abort_request->{reason})->then (sub {
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

## This is not a public function but can be used to implement
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

sub abort ($$) {
  return Promise->reject (_type_error "WritableStream is locked")
      if defined $_[0]->{writer}; # IsWritableStreamLocked
  return WritableStream::_abort $_[0], $_[1];
} # abort

sub WritableStreamDefaultController::_process_close ($) {
  #my $controller = $_[0];
  #my $stream = $controller->{controlled_writable_stream};
  my $stream = $_[0];
  my $controller = $_[0]->{writable_stream_controller};

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
    $stream->_terminate; # Not in JS
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
  #my $controller = $_[0];
  #my $stream = $controller->{controlled_writable_stream};
  my $stream = $_[0];
  my $controller = $_[0]->{writable_stream_controller};

  ## WritableStreamMarkFirstWriteRequestInFlight
  $stream->{in_flight_write_request} = shift @{$stream->{write_requests}};

  my $controller_obj = $stream->{controller_obj};
  unless (defined $controller_obj) {
    weaken ($stream->{controller_obj} = bless \$stream, 'WritableStreamDefaultController');
    $controller_obj = $stream->{controller_obj};
  }
  _hashref_method ($controller->{underlying_sink}, 'write', [$_[1], $controller_obj])->then (sub {
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
    WritableStreamDefaultController::_advance_queue_if_needed
        ($stream); #($controller);
  }, sub {
    ## WritableStreamFinishInFlightWriteWithError
    $stream->{in_flight_write_request}->{reject}->($_[0]);
    $stream->{in_flight_write_request} = undef;
    WritableStream::_deal_with_rejection $stream, $_[0];
  });
} # WritableStreamDefaultControllerProcessWrite

sub WritableStreamDefaultController::_advance_queue_if_needed ($) {
  #my $controller = $_[0];
  #my $stream = $controller->{controlled_writable_stream};
  my $stream = $_[0];
  my $controller = $_[0]->{writable_stream_controller};
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
    WritableStreamDefaultController::_process_close $stream; #$controller;
  } else {
    WritableStreamDefaultController::_process_write
        $stream, $write_record->{chunk};
        #$controller, $write_record->{chunk};
  }
} # WritableStreamDefaultControllerAdvanceQueueIfNeeded

## Not in JS
sub _terminate ($) {
  my $stream = $_[0];
  delete $stream->{writable_stream_controller}->{underlying_sink};
  delete $stream->{writable_stream_controller}->{strategy_size};
} # _terminate

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    my $location = $_[0]->{created_location};
    $location =~ s/\.?\s+\z//;
    warn "$$: Reference to @{[ref $_[0]]} created${location} is not discarded before global destruction\n";
  }
} # DESTROY

package WritableStreamDefaultController;
use Scalar::Util qw(weaken);
use Streams::_Common;
push our @CARP_NOT, qw(WritableStream);

sub new ($$$$$) {
  my (undef, $stream, $underlying_sink, $size, $hwm) = @_;
  die _type_error "The argument is not a WritableStream"
      unless UNIVERSAL::isa ($stream, 'WritableStream'); # IsWritableStream
  die _type_error "WritableStream has a controller"
      if defined $stream->{writable_stream_controller};
  my $controller = {};
  #$controller->{controlled_writable_stream} = $stream;
  my $self = bless \$stream, $_[0];
  $controller->{underlying_sink} = $underlying_sink;
  $controller->{started} = 0;

  ## ResetQueue
  $controller->{queue} = [];
  $controller->{queue_total_size} = 0;

  ## ValidateAndNormalizeQueuingStrategy
  {
    die _type_error "Size is not a CODE"
        if defined $size and not ref $size eq 'CODE';
    $controller->{strategy_size} = $size;

    ## ValidateAndNormalizeHighWaterMark
    $hwm = 0+($hwm || 0); ## ToNumber
    $controller->{strategy_hwm} = $hwm;
    $controller->{strategy_hwm} = 0
        if $hwm eq 'NaN' or $hwm eq 'nan'; # Not in JS
    die _range_error "High water mark $hwm is negative" if $hwm < 0;
  }

  $stream->_update_backpressure ($controller);

  ## [[StartSteps]].  In the spec, this is invoked from WritableStream::new.
  _hashref_method_throws ($underlying_sink, 'start', [$self])->then (sub { # requires Promise
    $controller->{started} = 1;
    WritableStreamDefaultController::_advance_queue_if_needed
        $stream; #$controller;
  }, sub {
    $controller->{started} = 1;
    WritableStream::_deal_with_rejection $stream, $_[0];
  });

  ## In spec, done within WritableStream constructor
  $stream->{writable_stream_controller} = $controller;
  weaken ($stream->{controller_obj} = $self);

  return $self;
} # new

sub error ($$) {
  my $stream = ${$_[0]}; #$_[0]->{controlled_writable_stream};
  return undef unless $stream->{state} eq 'writable';

  ## WritableStreamDefaultControllerError
  WritableStream::_start_erroring $stream, $_[1];

  return undef;
} # error(e)

sub _abort_steps ($$) {
  my $controller = ${$_[0]}->{writable_stream_controller};

  return _hashref_method ($controller->{underlying_sink}, 'abort', [$_[1]]);
} # [[AbortSteps]]

sub _error_steps ($) {
  my $controller = ${$_[0]}->{writable_stream_controller};

  ## ResetQueue
  $controller->{queue} = [];
  $controller->{queue_total_size} = 0;
} # [[ErrorSteps]]

sub DESTROY ($) {
  local $@;
  eval { die };
  if ($@ =~ /during global destruction/) {
    warn "$$: Reference to @{[ref $_[0]]} is not discarded before global destruction\n";
  }
} # DESTROY

package WritableStreamDefaultWriter;
use Streams::_Common;
push our @CARP_NOT, qw(WritableStream);

sub new ($$) {
  my $stream = $_[1];
  die _type_error "The argument is not a WritableStream"
      unless UNIVERSAL::isa ($stream, 'WritableStream'); # IsWritableStream
  die _type_error "WritableStream is locked"
      if defined $stream->{writer}; # IsWritableStreamLocked
  my $writer = {};
  my $self = bless \$stream, $_[0];
  #$writer->{owner_writable_stream} = $stream;
  $stream->{writer} = $writer;
  $writer->{ready_promise} = _promise_capability;
  $writer->{closed_promise} = _promise_capability;
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
      $writer->{ready_promise}->{resolve}->(undef);
    }
  } elsif ($stream->{state} eq 'erroring') {
    $writer->{ready_promise}->{reject}->($stream->{stored_error});
    $writer->{ready_promise}->{promise}->manakai_set_handled;
  } elsif ($stream->{state} eq 'closed') {
    $writer->{ready_promise}->{resolve}->(undef);
    $writer->{closed_promise}->{resolve}->(undef);
  } else {
    my $stored_error = $stream->{stored_error};
    $writer->{ready_promise}->{reject}->($stream->{stored_error});
    $writer->{ready_promise}->{promise}->manakai_set_handled;
    $writer->{closed_promise}->{reject}->($stream->{stored_error});
    $writer->{closed_promise}->{promise}->manakai_set_handled;
  }
  return $self;
} # new

sub closed ($) {
  return ${$_[0]}->{writer}->{closed_promise}->{promise};
} # closed

sub desired_size ($) {
  my $stream = ${$_[0]}; #${$_[0]}->{writer}->{owner_writable_stream};
  die _type_error "Writer's lock is released" unless defined $stream->{state};

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
  return ${$_[0]}->{writer}->{ready_promise}->{promise};
} # ready

sub abort ($$) {
  my $writer = ${$_[0]}->{writer};
  return Promise->reject (_type_error "Writer's lock is released")
      unless defined ${$_[0]}->{state}; #$writer->{owner_writable_stream};

  ## WritableStreamDefaultWriterAbort
  return WritableStream::_abort ${$_[0]}, $_[1];
  #return WritableStream::_abort $writer->{owner_writable_stream}, $_[1];
} # abort

sub close ($) {
  my $writer = ${$_[0]}->{writer};
  my $stream = ${$_[0]}; #$writer->{owner_writable_stream};
  return Promise->reject (_type_error "Writer's lock is released")
      unless defined $stream->{state};
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
          $stream; #$stream->{writable_stream_controller};
    }

    return $p->{promise};
  }
} # close

sub release_lock ($) {
  my $writer = ${$_[0]}->{writer};
  return undef unless defined ${$_[0]}->{state}; #$writer->{owner_writable_stream};

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

    ${$_[0]}->{writer} = undef;
    ${$_[0]} = {writer => $writer};
    #$writer->{owner_writable_stream}->{writer} = undef;
    #$writer->{owner_writable_stream} = undef;
    return undef;
  }
} # release_lock

sub write ($$) {
  my $writer = ${$_[0]}->{writer};
  return Promise->reject (_type_error "Writer's lock is released")
      unless defined ${$_[0]}->{state}; #$writer->{owner_writable_stream};

  ## WritableStreamDefaultWriterWrite
  my $stream = ${$_[0]}; #$writer->{owner_writable_stream};
  my $controller = $stream->{writable_stream_controller};

  ## WritableStreamDefaultControllerGetChunkSize
  my $chunk_size = 1;
  if (defined $controller->{strategy_size}) {
    eval { $chunk_size = $controller->{strategy_size}->($_[1]) };
    if ($@) {
      ## WritableStreamDefaultControllerErrorIfNeeded
      if ($stream->{state} eq 'writable') {
        ## WritableStreamDefaultControllerError
        WritableStream::_start_erroring $stream, $@;
      }
    }
  }

  return Promise->reject (_type_error "Writer's lock is released")
      unless defined ${$_[0]}->{state} and
             ${$_[0]}->{writer} eq $writer;
  #    unless defined $writer->{owner_writable_stream} and
  #           $stream eq $writer->{owner_writable_stream};

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
      if ($stream->{state} eq 'writable') {
        ## WritableStreamDefaultControllerError
        WritableStream::_start_erroring $stream, $@;
      }
      last;
    }
    push @{$controller->{queue}}, {value => {chunk => $_[1]}, size => $size};
    $controller->{queue_total_size} += $size;

    if (
      not
        ## WritableStreamCloseQueuedOrInFlight
        (defined $stream->{close_request} or
         defined $stream->{in_flight_close_request}) and
      $stream->{state} eq 'writable'
    ) {
      $stream->_update_backpressure ($controller);
    }
    WritableStreamDefaultController::_advance_queue_if_needed
        $stream; #$controller;
  }

  return $pc->{promise};
} # write(chunk)

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
