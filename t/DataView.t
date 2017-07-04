use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use DataView;

test {
  my $c = shift;
  my $ab = ArrayBuffer->new;
  my $dv = DataView->new ($ab);
  isa_ok $dv, 'DataView';
  is $dv->byte_offset, 0;
  is $dv->byte_length, $ab->byte_length;
  is $dv->buffer, $ab;
  done $c;
} n => 4, name => 'new arraybuffer';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (120);
  my $dv = DataView->new ($ab);
  isa_ok $dv, 'DataView';
  is $dv->byte_offset, 0;
  is $dv->byte_length, $ab->byte_length;
  is $dv->buffer, $ab;
  done $c;
} n => 4, name => 'new arraybuffer';

for my $value (undef, '', 13, {}, [], \"x", bless {}, 'test::foo') {
  test {
    my $c = shift;
    eval {
      DataView->new ($value);
    };
    like $@, qr{^TypeError: The argument is not an ArrayBuffer at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new bad argument';
}

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (52);
  eval {
    DataView->new ($ab, -5);
  };
  like $@, qr{^RangeError: Offset -5 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new bad offset';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new_from_scalarref (\"abcderfghiaegaaea");
  my $dv = DataView->new ($ab, 9.6);
  isa_ok $dv, 'DataView';
  is $dv->byte_offset, 9;
  is $dv->byte_length, $ab->byte_length - 9;
  done $c;
} n => 3, name => 'new arraybuffer float offset';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new_from_scalarref (\"abcderfghiaegaaea");
  my $dv = DataView->new ($ab, 6.6, 3.2);
  isa_ok $dv, 'DataView';
  is $dv->byte_offset, 6;
  is $dv->byte_length, 3;
  done $c;
} n => 3, name => 'new arraybuffer float offset and length';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (42);
  $ab->_transfer; # detach
  eval {
    DataView->new ($ab);
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new arraybuffer detached';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (42);
  eval {
    DataView->new ($ab, 43);
  };
  like $@, qr{^RangeError: Offset 43 > buffer length 42 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new arraybuffer bad offset';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (42);
  eval {
    DataView->new ($ab, 42, -1);
  };
  like $@, qr{^RangeError: Byte length -1 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new arraybuffer bad length';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (42);
  eval {
    DataView->new ($ab, 41, 2);
  };
  like $@, qr{^RangeError: \QOffset 41 + length 2 > buffer length 42\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new arraybuffer bad length';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (532);
  my $dv = DataView->new ($ab);
  $ab->_transfer; # detach
  eval {
    $dv->byte_offset;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  eval {
    $dv->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 2, name => 'arraybuffer detached';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
