use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use ArrayBuffer;

$ArrayBuffer::CreateTypeError = sub {
  return bless \"((TypeError: $_[1]))", 'test::package';
};

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (45);
  $ab->_transfer;
  eval {
    $ab->byte_length;
  };
  isa_ok $@, 'test::package';
  is ${$@}, "((TypeError: ArrayBuffer is detached))";
  done $c;
} n => 2;

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
