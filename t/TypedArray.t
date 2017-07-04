use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use TypedArray;

test {
  my $c = shift;
  eval {
    TypedArray->new;
  };
  like $@, qr{^TypeError: TypedArray is an abstract class at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'TypedArray->new';

for (
  ['TypedArray::Uint8Array', 1],
) {
  my ($class, $bpe) = @$_;

  test {
    my $c = shift;
    my $ta = $class->new;
    isa_ok $ta, $class;
    is $ta->byte_length, 0;
    is $ta->byte_offset, 0;
    is $ta->length, 0;
    isa_ok $ta->buffer, 'ArrayBuffer';
    is $ta->buffer->byte_length, $ta->byte_length;
    is $ta->BYTES_PER_ELEMENT, 1;
    is +TypedArray::Uint8Array->BYTES_PER_ELEMENT, 1;
    done $c;
  } n => 8, name => [$class, 'no argument'];

  test {
    my $c = shift;
    my $ta = $class->new (0);
    isa_ok $ta, $class;
    is $ta->byte_length, 0;
    is $ta->byte_offset, 0;
    is $ta->length, 0;
    isa_ok $ta->buffer, 'ArrayBuffer';
    is $ta->buffer->byte_length, $ta->byte_length;
    done $c;
  } n => 6, name => [$class, 'length=0 argument'];

  test {
    my $c = shift;
    my $ta = $class->new (642);
    isa_ok $ta, $class;
    is $ta->byte_length, 642 * $bpe;
    is $ta->byte_offset, 0;
    is $ta->length, 642;
    isa_ok $ta->buffer, 'ArrayBuffer';
    is $ta->buffer->byte_length, $ta->byte_length;
    done $c;
  } n => 6, name => [$class, 'length argument'];

  test {
    my $c = shift;
    my $ta = $class->new (64.4);
    isa_ok $ta, $class;
    is $ta->byte_length, 64 * $bpe;
    is $ta->byte_offset, 0;
    is $ta->length, 64;
    isa_ok $ta->buffer, 'ArrayBuffer';
    is $ta->buffer->byte_length, $ta->byte_length;
    done $c;
  } n => 6, name => [$class, 'length float argument'];

  test {
    my $c = shift;
    my $ta = $class->new ("643avbc3");
    isa_ok $ta, $class;
    is $ta->byte_length, 643 * $bpe;
    is $ta->byte_offset, 0;
    is $ta->length, 643;
    isa_ok $ta->buffer, 'ArrayBuffer';
    is $ta->buffer->byte_length, $ta->byte_length;
    done $c;
  } n => 6, name => [$class, 'length number string argument'];

  test {
    my $c = shift;
    eval {
      $class->new (-1);
    };
    like $@, qr{^RangeError: Length -1 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => [$class, 'length negative argument'];

  test {
    my $c = shift;
    eval {
      $class->new ({});
    };
    like $@, qr{^NotSupportedError: The argument is not an ArrayBuffer or length at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => [$class, 'bad argument'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    my $ta = $class->new ($ab);
    isa_ok $ta, $class;
    is $ta->byte_length, 53;
    is $ta->byte_offset, 0;
    is $ta->length, 53;
    is $ta->buffer, $ab;
    is $ta->buffer->byte_length, $ta->byte_length;
    done $c;
  } n => 6, name => [$class, 'ArrayBuffer argument'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    my $ta = $class->new ($ab, 14);
    isa_ok $ta, $class;
    is $ta->byte_length, 53 - 14;
    is $ta->byte_offset, 14;
    is $ta->length, 53 - 14;
    is $ta->buffer, $ab;
    is $ta->buffer->byte_length, 53;
    done $c;
  } n => 6, name => [$class, 'ArrayBuffer argument and offset'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    my $ta = $class->new ($ab, 14.7);
    isa_ok $ta, $class;
    is $ta->byte_length, 53 - 14;
    is $ta->byte_offset, 14;
    is $ta->length, 53 - 14;
    is $ta->buffer, $ab;
    is $ta->buffer->byte_length, 53;
    done $c;
  } n => 6, name => [$class, 'ArrayBuffer argument and offset'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    my $ta = $class->new ($ab, 53);
    isa_ok $ta, $class;
    is $ta->byte_length, 0;
    is $ta->byte_offset, 53;
    is $ta->length, 0;
    is $ta->buffer, $ab;
    is $ta->buffer->byte_length, 53;
    done $c;
  } n => 6, name => [$class, 'ArrayBuffer argument and offset'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    my $ta = $class->new ($ab, 14, 8);
    isa_ok $ta, $class;
    is $ta->byte_length, 8;
    is $ta->byte_offset, 14;
    is $ta->length, 8;
    is $ta->buffer, $ab;
    is $ta->buffer->byte_length, 53;
    done $c;
  } n => 6, name => [$class, 'ArrayBuffer argument and offset and length'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    $ab->_transfer; # detach
    eval {
      $class->new ($ab);
    };
    like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => [$class, 'ArrayBuffer is detached'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    eval {
      $class->new ($ab, 54);
    };
    like $@, qr{^RangeError: Buffer length 53 < offset 54 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => [$class, 'ArrayBuffer offset too large'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    eval {
      $class->new ($ab, -42);
    };
    like $@, qr{^RangeError: Offset -42 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => [$class, 'ArrayBuffer offset too large'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    eval {
      $class->new ($ab, 50, 10);
    };
    like $@, qr{^RangeError: Buffer length 53 < offset 50 \+ length 10 \* element size 1 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => [$class, 'ArrayBuffer length too large'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    eval {
      $class->new ($ab, 60, 10);
    };
    like $@, qr{^RangeError: Buffer length 53 < offset 60 \+ length 10 \* element size 1 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => [$class, 'ArrayBuffer length too large'];

  test {
    my $c = shift;
    my $ab = ArrayBuffer->new (53);
    my $ta = $class->new ($ab);
    $ab->_transfer; # detach
    is $ta->byte_length, 0;
    is $ta->byte_offset, 0;
    is $ta->length, 0;
    is $ta->buffer, $ab;
    is $ta->BYTES_PER_ELEMENT, $bpe;
    done $c;
  } n => 5, name => [$class, 'ArrayBuffer detached'];
}

test {
  my $c = shift;
  open my $fh, '<', path (__FILE__)->parent->child ('TypedArray.t');
  my $ta = TypedArray::Uint8Array->new_by_sysread ($fh, 13);
  isa_ok $ta, 'TypedArray::Uint8Array';
  is $ta->byte_length, 13;
  is $ta->byte_offset, 0;
  is $ta->length, $ta->byte_length;
  is $ta->buffer->byte_length, $ta->byte_length;
  my $ref = $ta->buffer->manakai_transfer_to_scalarref;
  is $$ref, "use strict;\nu";
  done $c;
} n => 6, name => 'new_by_sysread';

test {
  my $c = shift;
  my $path = path (__FILE__)->parent->child ('TypedArray.t');
  my $size = -s $path;
  open my $fh, '<', $path;
  my $ta = TypedArray::Uint8Array->new_by_sysread ($fh, $size + 13);
  isa_ok $ta, 'TypedArray::Uint8Array';
  is $ta->byte_length, $size;
  is $ta->byte_offset, 0;
  is $ta->length, $ta->byte_length;
  is $ta->buffer->byte_length, $ta->byte_length;
  done $c;
} n => 5, name => 'new_by_sysread';

test {
  my $c = shift;
  open my $fh, '<', \"";
  eval {
    TypedArray::Uint8Array->new_by_sysread ($fh, 13);
  };
  like $@, qr{^TypeError: .+ at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_by_sysread fh error';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
