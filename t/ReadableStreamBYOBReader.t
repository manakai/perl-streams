use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use ReadableStream;

for my $value (
  undef, 0, '', "abc", 135, [], {}, (bless {}, 'test::foo'),
) {
  test {
    my $c = shift;
    eval {
      ReadableStreamBYOBReader->new ($value);
    };
    like $@, qr{^TypeError: The argument is not a ReadableStream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new bad arg';
}

test {
  my $c = shift;
  my $rs = ReadableStream->new ({});
  eval {
    $rs->get_reader ('byob');
  };
  like $@, qr{^TypeError: ReadableStream is not a byte stream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new not bytes';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({});
  eval {
    ReadableStreamBYOBReader->new ($rs);
  };
  like $@, qr{^TypeError: ReadableStream is not a byte stream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new not bytes';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({type => 'bytes'});
  my $r = $rs->get_reader;
  eval {
    ReadableStreamBYOBReader->new ($rs);
  };
  like $@, qr{^TypeError: ReadableStream is locked at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new locked';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      $_[1]->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"abc")));
    },
  });
  my $r = $rs->get_reader ('byob');
  $r->read (TypedArray::Uint8Array->new (ArrayBuffer->new (10)))->then (sub {
    my $v = $_[0]->{value};
    test {
      isa_ok $v, 'TypedArray::Uint8Array';
      is $v->byte_length, 3;
      is $v->buffer->byte_length, 10;
      is ${$v->buffer->manakai_transfer_to_scalarref}, "abc".("\x00" x 7);
    } $c;
    done $c;
    undef $c;
  });
} n => 4, name => 'read TypedArray';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      $_[1]->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"abc")));
    },
  });
  my $r = $rs->get_reader ('byob');
  $r->read (DataView->new (ArrayBuffer->new (10)))->then (sub {
    my $v = $_[0]->{value};
    test {
      isa_ok $v, 'DataView';
      is $v->byte_length, 3;
      is $v->buffer->byte_length, 10;
      is ${$v->buffer->manakai_transfer_to_scalarref}, "abc".("\x00" x 7);
    } $c;
    done $c;
    undef $c;
  });
} n => 4, name => 'read DataView';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
  });
  my $r = $rs->get_reader ('byob');
  $r->release_lock;
  $r->read (TypedArray::Uint8Array->new (ArrayBuffer->new (10)))->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Reader's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'read after release';

for my $value (
  undef, '', 0, 215, "abc", [], {}, (bless {}, "test::hoge"),
  ArrayBuffer->new (120),
) {
  test {
    my $c = shift;
    my $rs = ReadableStream->new ({
      type => 'bytes',
    });
    my $r = $rs->get_reader ('byob');
    $r->read ($value)->catch (sub {
      my $e = $_[0];
      test {
        like $e, qr{^TypeError: The argument is not an ArrayBufferView at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
      } $c;
      done $c;
      undef $c;
    });
  } n => 1, name => 'read bad';
}

for my $value (
  TypedArray::Uint8Array->new (ArrayBuffer->new (0)),
  DataView->new (ArrayBuffer->new (0)),
  TypedArray::Uint8Array->new (ArrayBuffer->new (1000), 1000),
  DataView->new (ArrayBuffer->new (200), 200, 0),
) {
  test {
    my $c = shift;
    my $rs = ReadableStream->new ({
      type => 'bytes',
    });
    my $r = $rs->get_reader ('byob');
    $r->read ($value)->catch (sub {
      my $e = $_[0];
      test {
        like $e, qr{^TypeError: The ArrayBufferView is empty at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
      } $c;
      done $c;
      undef $c;
    });
  } n => 1, name => 'read empty view';
}

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  $rc->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"a")));
  my $r = $rs->get_reader ('byob');
  $rc->close;
  $r->read (TypedArray::Uint16Array->new (ArrayBuffer->new (2)))->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'read after close' if 0; # XXX Uint16Array not implemented yet

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
  });
  my $r = $rs->get_reader ('byob');
  isa_ok $r, 'ReadableStreamBYOBReader';
  is $r->release_lock, undef;
  my $r2 = $rs->get_reader ('byob');
  isa_ok $r2, 'ReadableStreamBYOBReader';
  is $r->release_lock, undef;
  $r->closed->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Reader's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__-7]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 5, name => 'release_lock';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
  });
  my $r = $rs->get_reader ('byob');
  isa_ok $r, 'ReadableStreamBYOBReader';
  $r->read (TypedArray::Uint8Array->new (ArrayBuffer->new (10)));
  eval {
    $r->release_lock;
  };
  like $@, qr{^TypeError: There is a pending read request at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  eval {
    $rs->get_reader;
  };
  like $@, qr{^TypeError: ReadableStream is locked at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 3, name => 'release_lock';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  my $r = $rs->get_reader ('byob');
  $r->cancel->then (sub {
    return $rc->close;
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'cancel';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  my $r = $rs->get_reader ('byob');
  isa_ok $r, 'ReadableStreamBYOBReader';
  $r->release_lock;
  $r->cancel->catch (sub {
    my $e = $_[0];
    undef $rc; # referencing $rs referencing start referencing $rc
    test {
      like $e, qr{^TypeError: Reader's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'cancel after release';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
  });
  my $r = $rs->get_reader ('byob');
  my $closed;
  $r->closed->then (sub {
    $closed = 1;
  });
  Promise->resolve->then (sub {
    test {
      ok ! $closed;
    } $c;
    return $r->cancel;
  })->then (sub {
    test {
      ok $closed;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'closed';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
