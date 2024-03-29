package Streams::Filehandle;
use strict;
use warnings;
our $VERSION = '2.0';
use Errno qw(EAGAIN EWOULDBLOCK EINTR);
use Socket qw(SOL_SOCKET SO_LINGER);
use Streams::_Common;
use AnyEvent;
use AnyEvent::Util qw(WSAEWOULDBLOCK);
use Promise;
use Promised::Flow;
use Streams::Error;
use Streams::TypeError;
use DataView;
use ReadableStream;
use WritableStream;

## Semi-public API - Utility functions for building filehandle-based
## stream modules.  Used by Web::Transport::TCPStream in
## perl-web-resources and Promised::Command in perl-promised-command.
## This might be changed into a public API in future, if desired.

push our @CARP_NOT, qw(
  Streams::Error Streams::TypeError
  ArrayBuffer DataView
  ReadableStream ReadableStreamBYOBRequest WritableStream
  Promised::Flow
);

sub _writing (&$$) {
  my ($code, $fh, $cancel) = @_;
  my $cancelled = 0;
  $$cancel = sub { $cancelled = 1 };
  return promised_until {
    return 'done' if $cancelled or $code->();
    return Promise->new (sub {
      my $ok = $_[0];
      my $w; $w = AE::io $fh, 1, sub {
        undef $w;
        $$cancel = sub { $cancelled = 1 };
        $ok->(not 'done');
      };
      $$cancel = sub {
        $cancelled = 1;
        undef $w;
        $$cancel = sub { };
        $ok->(not 'done');
      };
    });
  };
} # _writing

sub write_to_fhref ($$;%) {
  my ($fhref, $view, %args) = @_;
  return Promise->resolve->then (sub {
    die Streams::TypeError->new ("The argument is not an ArrayBufferView")
        unless UNIVERSAL::isa ($view, 'ArrayBufferView');
    return _writing {
      return 1 unless defined $$fhref; # end
      my $l = eval { $view->buffer->manakai_syswrite
                         ($$fhref, $view->byte_length, $view->byte_offset) };
      if ($@) {
        my $errno = UNIVERSAL::isa ($@, 'Streams::IOError') ? $@->errno : 0;
        if ($errno != EAGAIN && $errno != EINTR &&
            $errno != EWOULDBLOCK && $errno != WSAEWOULDBLOCK) {
          die $@;
        } else { # retry later
          return 0; # repeat
        }
      } else {
        $view = DataView->new
            ($view->buffer, $view->byte_offset + $l, $view->byte_length - $l);
        return 1 if $view->byte_length == 0; # end
        return 0; # repeat
      }
    } $$fhref, $args{cancel_ref} || \my $dummy;
  });
} # write_to_fhref

sub fh_to_streams ($$$) {
  my ($fh, $use_r, $use_w) = @_;

  my ($r_fh_closed, $s_fh_closed) = promised_cv;
  my $read_active = $use_r ? 1 : 0;
  my $rcancel = sub { };
  my $wc;
  my $wcancel;

  my $pull = sub {
    my ($rc, $req, $rcancelref) = @_;
    return Promise->new (sub {
      my $ready = $_[0];
      my $failed = $_[1];
      return $failed->() unless defined $fh;

      my $w;
      $$rcancelref = sub {
        eval { $rc->error ($_[0]) } if $read_active;
        my $req = $rc->byob_request;
        $req->manakai_respond_zero if defined $req;

        undef $w;
        $failed->($_[0]);
      };
      $w = AE::io $fh, 0, sub {
        $$rcancelref = sub {
          eval { $rc->error ($_[0]) } if $read_active;
          my $req = $rc->byob_request;
          $req->manakai_respond_zero if defined $req;
        };

        undef $w;
        $ready->();
      };
    })->then (sub {
      my $bytes_read = eval { $req->manakai_respond_by_sysread ($fh) };
      if ($@) {
        my $error = Streams::Error->wrap ($@);
        my $errno = $error->isa ('Streams::IOError') ? $error->errno : 0;
        if ($errno != EAGAIN && $errno != EINTR &&
            $errno != EWOULDBLOCK && $errno != WSAEWOULDBLOCK) {
          $rcancel->($error) if defined $rcancel;
          $read_active = $rcancel = undef;
          if (defined $wc) {
            $wc->error ($error);
            $wcancel->() if defined $wcancel;
            $wc = $wcancel = undef;
          }
          undef $fh;
          $s_fh_closed->();
          return 0;
        }
        return 1;
      } # $@
      if (defined $bytes_read and $bytes_read <= 0) {
        $rc->close;
        $req->manakai_respond_zero;
        $read_active = undef;
        $rcancel->(undef);
        $rcancel = undef;
        unless (defined $wc) {
          undef $fh;
          $s_fh_closed->();
        }
        return 0;
      }
      return 1;
    }, sub {
      $read_active = $rcancel = undef;
      unless (defined $wc) {
        undef $fh;
        $s_fh_closed->();
      }
      return 0;
    });
  }; # $pull

  my $read_stream = $use_r ? ReadableStream->new ({
    type => 'bytes',
    auto_allocate_chunk_size => $Streams::_Common::DefaultBufferSize,
    pull => sub {
      my $rc = $_[1];
      $rcancel = sub {
        eval { $rc->error ($_[0]) } if $read_active;
        my $req = $rc->byob_request;
        $req->manakai_respond_zero if defined $req;
      };
      return promised_until {
        my $req = $rc->byob_request;
        return 'done' unless defined $req;
        return $pull->($rc, $req, \$rcancel)->then (sub {
          return not $_[0];
        });
      };
    }, # pull
    cancel => sub {
      my $reason = defined $_[1] ? $_[1] : "Handle reader canceled";
      $rcancel->($reason) if defined $rcancel;
      $read_active = $rcancel = undef;
      if (defined $wc) {
        $wc->error ($reason);
        $wcancel->() if defined $wcancel;
        $wc = $wcancel = undef;
      }
      shutdown $fh, 2; # can result in EPIPE
      undef $fh;
      $s_fh_closed->();
    }, # cancel
  }) : undef; # $read_stream
  my $write_stream = $use_w ? WritableStream->new ({
    start => sub {
      $wc = $_[1];
    },
    write => sub {
      return Streams::Filehandle::write_to_fhref (\$fh, $_[1], cancel_ref => \$wcancel)->catch (sub {
        my $e = $_[0];
        if (defined $wc) {
          $wc->error ($e);
          $wcancel->() if defined $wcancel;
          $wc = $wcancel = undef;
        }
        if ($read_active) {
          $rcancel->($e);
          $read_active = $rcancel = undef;
        }
        undef $fh;
        $s_fh_closed->();
        die $e;
      });
    }, # write
    close => sub {
      shutdown $fh, 1; # can result in EPIPE
      $wcancel->() if defined $wcancel;
      $wc = $wcancel = undef;
      unless ($read_active) {
        undef $fh;
        $s_fh_closed->();
      }
      return undef;
    }, # close
    abort => sub {
      ## For TCP tests only
      if (UNIVERSAL::isa ($_[1], 'Web::Transport::TCPStream::Reset')) {
        setsockopt $fh, SOL_SOCKET, SO_LINGER, pack "II", 1, 0;
        $wcancel->() if defined $wcancel;
        $wc = $wcancel = undef;
        if ($read_active) {
          $rcancel->($_[1]);
          $read_active = $rcancel = undef;
        }
        undef $fh;
        $s_fh_closed->();
        return undef;
      }

      $wcancel->() if defined $wcancel;
      $wc = $wcancel = undef;
      if ($read_active) {
        my $reason = defined $_[1] ? $_[1] : "Handle writer aborted";
        $rcancel->($reason);
        $read_active = $rcancel = undef;
      }
      shutdown $fh, 2; # can result in EPIPE
      undef $fh;
      $s_fh_closed->();
    }, # abort
  }) : undef; # $write_stream

  AnyEvent::Util::fh_nonblocking $fh, 1;

  return ($read_stream, $write_stream, $r_fh_closed);
} # fh_to_streams

sub create_readable ($$) {
  my ($rs, undef, undef) = Streams::Filehandle::fh_to_streams $_[1], 1, 0;
  return $rs;
} # create_readable

sub create_writable ($$) {
  my (undef, $ws, undef) = Streams::Filehandle::fh_to_streams $_[1], 0, 1;
  return $ws;
} # create_writable

1;

=head1 LICENSE

Copyright 2016-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
