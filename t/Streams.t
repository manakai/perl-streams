use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use Streams;

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  isa_ok $rs, 'ReadableStream';
  done $c;
} n => 1, name => 'ReadableStream loaded';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  isa_ok $ws, 'WritableStream';
  done $c;
} n => 1, name => 'WritableStream loaded';

{
  package test::HasBL;
  sub byte_length { 42 }
}

test {
  my $c = shift;
  my $s = Streams::ByteLengthQueuingStrategy {
    high_water_mark => 53,
  };
  is ref $s, 'HASH';
  is $s->{high_water_mark}, 53;
  is ref $s->{size}, 'CODE';
  is $s->{size}->(bless {}, 'test::HasBL'), 42;
  done $c;
} n => 4, name => 'ByteLengthQueuingStrategy';

for my $value (
  undef, 0, 52532, "", "abae", [], {}, (bless {}, 'test::Foo'),
) {
  test {
    my $c = shift;
    my $s = Streams::ByteLengthQueuingStrategy {
      high_water_mark => 53,
    };
    is ref $s, 'HASH';
    is $s->{high_water_mark}, 53;
    is ref $s->{size}, 'CODE';
    eval {
      $s->{size}->($value);
    };
    like $@, qr{^TypeError: The chunk does not have byte_length method at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 4, name => 'ByteLengthQueuingStrategy bad arg';
}

test {
  my $c = shift;
  my $s = Streams::CountQueuingStrategy {
    high_water_mark => 53,
  };
  is ref $s, 'HASH';
  is $s->{high_water_mark}, 53;
  is ref $s->{size}, 'CODE';
  is $s->{size}->(bless {}, 'test::HasBL'), 1;
  done $c;
} n => 4, name => 'CountQueuingStrategy';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
