use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use ArrayBuffer;

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (0);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 0;
  done $c;
} n => 2, name => 'new 0';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new ("0 but true");
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 0;
  done $c;
} n => 2, name => 'new 0 but true';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (2000);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 2000;
  done $c;
} n => 2, name => 'new 2000';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (30.2);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 30;
  done $c;
} n => 2, name => 'new float';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new ("642abac");
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 642;
  done $c;
} n => 2, name => 'new number string';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new ("abcde");
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 0;
  done $c;
} n => 2, name => 'new string';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new (-32);
  };
  like $@, qr{^RangeError: Byte length -32 is negative};
  done $c;
} n => 1, name => 'new negative';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new;
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 0;
  done $c;
} n => 2, name => 'new undef';

test {
  my $c = shift;
  my $s = "";
  my $ab = ArrayBuffer->new_from_scalarref (\$s);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 0;
  done $c;
} n => 2, name => 'new_from_scalarref 0';

test {
  my $c = shift;
  my $s = "x" x 1042;
  my $ab = ArrayBuffer->new_from_scalarref (\$s);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 1042;
  done $c;
} n => 2, name => 'new_from_scalarref 1042';

test {
  my $c = shift;
  my $s = "\x80\xFE";
  my $ab = ArrayBuffer->new_from_scalarref (\$s);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 2;
  done $c;
} n => 2, name => 'new_from_scalarref bytes';

test {
  my $c = shift;
  my $s = "\x{524}abc\x{65000}";
  eval {
    ArrayBuffer->new_from_scalarref (\$s);
  };
  like $@, qr{^TypeError: The argument is a utf8-flaged string at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref utf8';

test {
  my $c = shift;
  my $s = substr "\x{524}abc\x{65000}", 1, 3;
  eval {
    ArrayBuffer->new_from_scalarref (\$s);
  };
  like $@, qr{^TypeError: The argument is a utf8-flaged string at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref utf8';

test {
  my $c = shift;
  my $s = "\x{524}abc\x{65000}";
  eval {
    ArrayBuffer->new_from_scalarref (\substr $s, 1, 3);
  };
  like $@, qr{^TypeError: The argument is a utf8-flaged string at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref utf8';

test {
  my $c = shift;
  my $s = substr "x" x 1042, 50, 52;
  my $ab = ArrayBuffer->new_from_scalarref (\$s);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 52;
  done $c;
} n => 2, name => 'new_from_scalarref \substr';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new_from_scalarref ();
  };
  like $@, qr{^TypeError: The argument is not a SCALAR at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref no argument';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new_from_scalarref ([]);
  };
  like $@, qr{^TypeError: The argument is not a SCALAR at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref bad argument';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new_from_scalarref ("abcde");
  };
  like $@, qr{^TypeError: The argument is not a SCALAR at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref no argument';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (105);
  my $ab2 = $ab1->_transfer;
  isa_ok $ab2, 'ArrayBuffer';
  is $ab2->byte_length, 105;
  eval {
    $ab1->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 3, name => '_transfer';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (105);
  my $ab2 = $ab1->_transfer;
  my $ab3 = $ab2->_transfer;
  isa_ok $ab3, 'ArrayBuffer';
  is $ab3->byte_length, 105;
  eval {
    $ab1->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  eval {
    $ab2->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 4, name => '_transfer twice';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (105);
  my $ab2 = $ab1->_transfer;
  my $ab3 = $ab1->_transfer;
  isa_ok $ab3, 'ArrayBuffer';
  is $ab2->byte_length, 105;
  eval {
    $ab1->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  eval {
    $ab3->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 4, name => '_transfer twice';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (105);
  my $ab2 = $ab1->manakai_transfer_to_scalarref;
  isa_ok $ab2, 'SCALAR';
  is $$ab2, "\x00" x 105;
  eval {
    $ab1->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 3, name => 'manakai_transfer_to_scalarref';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (105);
  my $ab2 = $ab1->_transfer;
  my $ab3 = $ab2->manakai_transfer_to_scalarref;
  isa_ok $ab3, 'SCALAR';
  is $$ab3, "\x00" x 105;
  eval {
    $ab1->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  eval {
    $ab2->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 4, name => 'manakai_transfer_to_scalarref twice';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (105);
  my $ab2 = $ab1->manakai_transfer_to_scalarref;
  my $ab3 = $ab1->_transfer;
  isa_ok $ab2, 'SCALAR';
  is $$ab2, "\x00" x 105;
  eval {
    $ab1->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  eval {
    $ab3->byte_length;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 4, name => 'manakai_transfer_to_scalarref twice';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (105);
  my $ab2 = $ab1->manakai_transfer_to_scalarref;
  isa_ok $ab2, 'SCALAR';
  is $$ab2, "\x00" x 105;
  eval {
    $ab1->manakai_transfer_to_scalarref;
  };
  like $@, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 3, name => 'manakai_transfer_to_scalarref twice';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (42);
  my $ab2 = ArrayBuffer->_clone ($ab1, 0, 42);
  isa_ok $ab2, 'ArrayBuffer';
  is $ab2->byte_length, 42;
  my $ref2 = $ab2->manakai_transfer_to_scalarref;
  is $ab1->byte_length, 42, 'not detached';
  $$ref2 .= "abc";
  is $ab1->byte_length, 42;
  my $ref1 = $ab1->manakai_transfer_to_scalarref;
  isnt $ref2, $ref1;
  isnt $$ref2, $$ref1;
  done $c;
} n => 6, name => '_clone';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (42);
  my $ab2 = ArrayBuffer->_clone ($ab1, 20, 6);
  isa_ok $ab2, 'ArrayBuffer';
  is $ab2->byte_length, 6;
  my $ref2 = $ab2->manakai_transfer_to_scalarref;
  is $ab1->byte_length, 42, 'not detached';
  $$ref2 .= "abc";
  is $ab1->byte_length, 42;
  my $ref1 = $ab1->manakai_transfer_to_scalarref;
  isnt $ref2, $ref1;
  isnt $$ref2, $$ref1;
  done $c;
} n => 6, name => '_clone';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
