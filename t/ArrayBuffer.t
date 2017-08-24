use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use ArrayBuffer;
use File::Temp qw(tempfile);

test {
  my $c = shift;
  my $ab = ArrayBuffer->new (0);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 0;
  ok not $ab->isa ('ArrayBufferView');
  is $ab->debug_info, "{ArrayBuffer l=0 file @{[__FILE__]} line @{[__LINE__-4]}}";
  done $c;
} n => 4, name => 'new 0';

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
  my $ab = ArrayBuffer->new (2**32-1);
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, -1 + 2**31 + 2**31;
  done $c;
} n => 2, name => 'new 2^32-1';

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
  my $ab = ArrayBuffer->new (0+"nan");
  isa_ok $ab, 'ArrayBuffer';
  is $ab->byte_length, 0;
  done $c;
} n => 2, name => 'new NaN';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new (-32);
  };
  like $@, qr{^RangeError: Byte length -32 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  isa_ok $@, 'Streams::RangeError';
  is $@->name, 'RangeError';
  is $@->message, 'Byte length -32 is negative';
  is $@->file_name, __FILE__;
  is $@->line_number, __LINE__-7;
  done $c;
} n => 6, name => 'new negative';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new (-"inf");
  };
  like $@, qr{^RangeError: Byte length -.+ is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new negative';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new (2**64);
  };
  like $@, qr{^RangeError: Byte length .+ is too large at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new outside of range';

test {
  my $c = shift;
  eval {
    ArrayBuffer->new (0+"inf");
  };
  like $@, qr{^RangeError: Byte length .+ is too large at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new outside of range';

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
  is $ab->debug_info, "{ArrayBuffer l=1042 file @{[__FILE__]} line @{[__LINE__-3]}}";
  done $c;
} n => 3, name => 'new_from_scalarref 1042';

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

test {
  my $c = shift;
  my $ref1 = \"abcdefghijklmn";
  my $ab1 = ArrayBuffer->new_from_scalarref ($ref1);
  my $ab2 = ArrayBuffer->_clone ($ab1, 6, 4);
  is $ab2->byte_length, 4;
  my $ref2 = $ab2->manakai_transfer_to_scalarref;
  is $$ref2, "ghij";
  is $ab2->debug_info, "{ArrayBuffer clone of {ArrayBuffer l=14 file @{[__FILE__]} line @{[__LINE__-5]}} detached file @{[__FILE__]} line @{[__LINE__-4]}}";
  done $c;
} n => 3, name => '_clone allocated';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (30);
  my $ab2 = ArrayBuffer->_clone ($ab1, 6, 4);
  is $ab2->byte_length, 4;
  my $ref2 = $ab2->manakai_transfer_to_scalarref;
  is $$ref2, "\x00\x00\x00\x00";
  done $c;
} n => 2, name => '_clone not allocated';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (50);
  my $ab2 = ArrayBuffer->new (30);
  ArrayBuffer::_copy_data_block_bytes ($ab2, 6, $ab1, 3, 12);
  is $ab1->byte_length, 50;
  is $ab2->byte_length, 30;
  is ${$ab1->manakai_transfer_to_scalarref}, "\x00" x 50;
  is ${$ab2->manakai_transfer_to_scalarref}, "\x00" x 30;
  done $c;
} n => 4, name => '_copy_data_block_bytes not allocated -> not allocated';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new (50);
  my $ab2 = ArrayBuffer->new_from_scalarref (\(my $v = "abetaEyewyaewewraeaetee"));
  ArrayBuffer::_copy_data_block_bytes ($ab2, 6, $ab1, 3, 12);
  is $ab1->byte_length, 50;
  is $ab2->byte_length, 23;
  is ${$ab1->manakai_transfer_to_scalarref}, "\x00" x 50;
  is ${$ab2->manakai_transfer_to_scalarref}, "abetaE".("\x00" x 12)."aetee";
  done $c;
} n => 4, name => '_copy_data_block_bytes not allocated -> allocated';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new_from_scalarref (\(my $v = "abetaEyewyaewewraeaetee"));
  my $ab2 = ArrayBuffer->new (50);
  ArrayBuffer::_copy_data_block_bytes ($ab2, 3, $ab1, 6, 12);
  is $ab1->byte_length, 23;
  is $ab2->byte_length, 50;
  is ${$ab1->manakai_transfer_to_scalarref}, "abetaEyewyaewewraeaetee";
  is ${$ab2->manakai_transfer_to_scalarref}, "\x00\x00\x00"."yewyaewewrae".("\x00" x (50-15));
  done $c;
} n => 4, name => '_copy_data_block_bytes allocated -> not allocated';

test {
  my $c = shift;
  my $ab1 = ArrayBuffer->new_from_scalarref (\(my $v = "abetaEyewyaewewraeaetee"));
  my $ab2 = ArrayBuffer->new_from_scalarref (\(my $w = "3y74h5es4ytawgaeearaeeeeee"));
  ArrayBuffer::_copy_data_block_bytes ($ab2, 3, $ab1, 6, 12);
  is $ab1->byte_length, 23;
  is $ab2->byte_length, 26;
  is ${$ab1->manakai_transfer_to_scalarref}, "abetaEyewyaewewraeaetee";
  is ${$ab2->manakai_transfer_to_scalarref}, "3y7yewyaewewraeeearaeeeeee";
  done $c;
} n => 4, name => '_copy_data_block_bytes allocated -> allocated';

test {
  my $c = shift;
  my $ab = ArrayBuffer->new;
  is $ab->manakai_label, undef;
  $ab->manakai_label (0);
  is $ab->manakai_label, '0';
  $ab->manakai_label ('');
  is $ab->manakai_label, '';
  my $v1 = rand;
  $ab->manakai_label ($v1);
  like $ab->debug_info, qr{\Q$v1\E};
  done $c;
} n => 4, name => 'manakai_label';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  my $ab = ArrayBuffer->new (54);
  is $ab->manakai_syswrite ($fh), 54;
  close $fh;
  is path ($file_name)->slurp, "\x00" x 54;
  done $c;
} n => 2, name => 'manakai_syswrite allocation_delayed';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  my $data = "a4aaeeweag5ogre00e";
  my $ab = ArrayBuffer->new_from_scalarref (\$data);
  is $ab->manakai_syswrite ($fh), length $data;
  close $fh;
  is path ($file_name)->slurp, $data;
  done $c;
} n => 2, name => 'manakai_syswrite';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  my $data = "a4aaeeweag5ogre00e";
  my $ab = ArrayBuffer->new_from_scalarref (\$data);
  is $ab->manakai_syswrite ($fh, 6), 6;
  close $fh;
  is path ($file_name)->slurp, substr $data, 0, 6;
  done $c;
} n => 2, name => 'manakai_syswrite length';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  my $data = "a4aaeeweag5ogre00e";
  my $ab = ArrayBuffer->new_from_scalarref (\$data);
  is $ab->manakai_syswrite ($fh, undef, 6), -6 + length $data;
  close $fh;
  is path ($file_name)->slurp, substr $data, 6;
  done $c;
} n => 2, name => 'manakai_syswrite offset';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  my $data = "a4aaeeweag5ogre00e";
  my $ab = ArrayBuffer->new_from_scalarref (\$data);
  is $ab->manakai_syswrite ($fh, 0), 0;
  close $fh;
  is path ($file_name)->slurp, "";
  done $c;
} n => 2, name => 'manakai_syswrite empty';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  print $fh "abcde";
  close $fh;
  my $data = "a4aaeeweag5ogre00e";
  my $ab = ArrayBuffer->new_from_scalarref (\$data);
  $ab->_transfer; # detach
  eval {
    $ab->manakai_syswrite ($fh);
  };
  is $@->name, 'TypeError';
  is $@->message, 'ArrayBuffer is detached';
  is $@->file_name, __FILE__;
  is $@->line_number, __LINE__-5;
  is path ($file_name)->slurp, "abcde";
  done $c;
} n => 5, name => 'manakai_syswrite detached';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  print $fh "abcde";
  close $fh;
  my $data = "a4aaeeweag5ogre00e";
  my $ab = ArrayBuffer->new_from_scalarref (\$data);
  eval {
    $ab->manakai_syswrite ($fh, -43);
  };
  is $@->name, 'RangeError';
  is $@->message, 'Byte length -43 is negative';
  is $@->file_name, __FILE__;
  is $@->line_number, __LINE__-5;
  is path ($file_name)->slurp, "abcde";
  done $c;
} n => 5, name => 'manakai_syswrite bad length';

test {
  my $c = shift;
  my ($fh, $file_name) = tempfile;
  print $fh "abcde";
  close $fh;
  my $data = "a4aaeeweag5ogre00e";
  my $ab = ArrayBuffer->new_from_scalarref (\$data);
  eval {
    $ab->manakai_syswrite ($fh, undef, -43);
  };
  is $@->name, 'RangeError';
  is $@->message, 'Byte offset -43 is negative';
  is $@->file_name, __FILE__;
  is $@->line_number, __LINE__-5;
  is path ($file_name)->slurp, "abcde";
  done $c;
} n => 5, name => 'manakai_syswrite bad offset';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
