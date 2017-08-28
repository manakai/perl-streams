use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use AnyEvent;
use ArrayBuffer;
use Promised::Flow;
use DataView;
use Streams::Filehandle;

test {
  my $c = shift;
  my ($r, $w) = AnyEvent::Util::portable_pipe;
  AnyEvent::Util::fh_nonblocking $w, 1;
  (Streams::Filehandle::write_to_fhref \$w, DataView->new (ArrayBuffer->new_from_scalarref (\"abc xyz")))->then (sub {
    close $w;

    my $bytes = <$r>;
    test {
      is $bytes, "abc xyz";
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'write_to_fhref DataView';

test {
  my $c = shift;
  my ($r, $w) = AnyEvent::Util::portable_pipe;
  AnyEvent::Util::fh_nonblocking $w, 1;
  Streams::Filehandle::write_to_fhref \$w, DataView->new (ArrayBuffer->new_from_scalarref (\"abc xyz"));
  (Streams::Filehandle::write_to_fhref \$w, "abc")->catch (sub {
    my $error = $_[0];
    test {
      is $error->name, 'TypeError', $error;
      is $error->message, 'The argument is not an ArrayBufferView';
      is $error->file_name, __FILE__;
      is $error->line_number, __LINE__+11;
    } $c;

    close $w;

    my $bytes = <$r>;
    test {
      is $bytes, "abc xyz";
    } $c;
    done $c;
    undef $c;
  });
} n => 5, name => 'write_to_fhref not DataView';

test {
  my $c = shift;
  my ($r, $w) = AnyEvent::Util::portable_pipe;
  AnyEvent::Util::fh_nonblocking $w, 1;
  my $code;
  my $p = Streams::Filehandle::write_to_fhref
      \$w, DataView->new (ArrayBuffer->new_from_scalarref (\"abc xyz")),
      cancel_ref => \$code;
  (promised_wait_until { defined $code } interval => 0.001, timeout => 3)->then (sub {
    test {
      is ref $code, 'CODE';
    } $c;
    close $r;
    close $w;
    return $p;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'write_to_fhref cancel_ref';

## There are more tests for Web::Transport::TCPStream in
## perl-web-resources and Promised::Command in perl-promised-command.

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
