package Streams::Filehandle;
use strict;
use warnings;
our $VERSION = '1.0';
use Errno qw(EAGAIN EWOULDBLOCK EINTR);
use AnyEvent;
use AnyEvent::Util qw(WSAEWOULDBLOCK);
use Promise;
use Promised::Flow;
use Streams::TypeError;
use DataView;

## Semi-public API - Utility functions for building filehandle-based
## stream modules.  Used by Web::Transport::TCPStream in
## perl-web-resources and Promised::Command in perl-promised-command.
## This might be changed into a public API in future, if desired.

push our @CARP_NOT, qw(Streams::TypeError DataView);

sub _writing (&$$) {
  my ($code, $fh, $cancel) = @_;
  my $cancelled = 0;
  $$cancel = sub { $cancelled = 1 };
  my $try; $try = sub {
    return Promise->resolve if $cancelled or $code->();
    return Promise->new (sub {
      my $ok = $_[0];
      my $w; $w = AE::io $fh, 1, sub {
        undef $w;
        $$cancel = sub { $cancelled = 1 };
        $ok->();
      };
      $$cancel = sub {
        $cancelled = 1;
        undef $w;
        $$cancel = sub { };
        $ok->();
      };
    })->then ($try);
  };
  return promised_cleanup { undef $try } Promise->resolve->then ($try);
} # _writing

sub write_to_fh ($$;%) {
  my ($fh, $view, %args) = @_;
  return Promise->resolve->then (sub {
    die Streams::TypeError->new ("The argument is not an ArrayBufferView")
        unless UNIVERSAL::isa ($view, 'ArrayBufferView');
    return if $view->byte_length == 0;
    return _writing {
      return 1 unless defined $fh; # end
      my $l = eval { $view->buffer->manakai_syswrite
                         ($fh, $view->byte_length, $view->byte_offset) };
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
    } $fh, $args{cancel_ref} || \my $dummy;
  });
} # write_to_fh

1;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
