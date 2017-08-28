use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use Streams::IOError;

test {
  my $c = shift;
  ok $Web::DOM::Error::L1ObjectClass->{'Streams::IOError'};
  done $c;
} n => 1, name => 'error classes';

test {
  my $c = shift;
  my $e = Streams::IOError->new_from_errno_and_message (13, "ab x");
  is $e->name, 'Perl I/O error';
  is $e->errno, 13;
  is $e->message, 'ab x';
  is $e->file_name, __FILE__;
  is $e->line_number, __LINE__-5;
  like $e->stringify, qr{^Perl I/O error: ab x at \Q@{[__FILE__]}\E line @{[__LINE__-6]}};
  done $c;
} n => 6, name => 'new_from_errno_and_message';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
