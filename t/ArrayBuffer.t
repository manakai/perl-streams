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
  my $ab = ArrayBuffer->new (2000);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 2000;
  done $c;
} n => 2, name => 'new 2000';

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
  like $@, qr{^TypeError: Not a SCALAR at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref no argument';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new_from_scalarref ([]);
  };
  like $@, qr{^TypeError: Not a SCALAR at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new_from_scalarref bad argument';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new_from_scalarref ("abcde");
  };
  like $@, qr{^TypeError: Not a SCALAR at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
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
