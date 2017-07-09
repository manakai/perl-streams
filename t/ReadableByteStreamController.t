use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use ReadableStream;

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  eval {
    ReadableByteStreamController->new ($rs, {}, 4);
  };
  like $@, qr{^TypeError: ReadableStream has a controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'bytes',
      auto_allocate_chunk_size => 52.1,
    });
  };
  like $@, qr{^RangeError: Chunk size 52.1 is not a positive integer at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'new auto_allocate_chunk_size float';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'bytes',
      auto_allocate_chunk_size => -32,
    });
  };
  like $@, qr{^RangeError: Chunk size -32 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'new auto_allocate_chunk_size negative';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'bytes',
      auto_allocate_chunk_size => 0,
    });
  };
  like $@, qr{^RangeError: Chunk size 0 is not a positive integer at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'new auto_allocate_chunk_size zero';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'bytes',
      auto_allocate_chunk_size => 0+"NaN",
    });
  };
  like $@, qr{^RangeError: Chunk size .+ is not a positive integer at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'new auto_allocate_chunk_size NaN';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'bytes',
      auto_allocate_chunk_size => 0+"Inf",
    });
  };
  like $@, qr{^RangeError: Chunk size .+ is too large at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'new auto_allocate_chunk_size Inf';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'bytes',
      auto_allocate_chunk_size => "abcdee",
    });
  };
  like $@, qr{^RangeError: Chunk size .+ is not a positive integer at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'new auto_allocate_chunk_size string';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  $rc->close;
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (4));
  eval {
    $rc->enqueue ($view);
  };
  like $@, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'enqueue after close';

for my $value (
  undef, 0, 31, "", "abc", [], {}, (bless {}, 'test::oo'),
) {
  test {
    my $c = shift;
    my $rc;
    my $rs = ReadableStream->new ({
      type => 'bytes',
      start => sub { $rc = $_[1] },
    });
    eval {
      $rc->enqueue ($value);
    };
    like $@, qr{^TypeError: The argument is not an ArrayBufferView at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'enqueue bad argument';
}

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 314,
  });
  is $rc->desired_size, 314;
  done $c;
} n => 1, name => 'high_water_mark integer';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 314.42,
  });
  is $rc->desired_size, 314.42;
  done $c;
} n => 1, name => 'high_water_mark float';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => "42abc",
  });
  is $rc->desired_size, 42;
  done $c;
} n => 1, name => 'high_water_mark number string';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 0,
  });
  is $rc->desired_size, 0;
  done $c;
} n => 1, name => 'high_water_mark zero';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => "abcd",
  });
  is $rc->desired_size, 0;
  done $c;
} n => 1, name => 'high_water_mark string';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 0+"Inf",
  });
  is $rc->desired_size, 0+"Inf";
  done $c;
} n => 1, name => 'high_water_mark Inf';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 0+"NaN",
  });
  is $rc->desired_size, 0;
  done $c;
} n => 1, name => 'high_water_mark NaN';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({}, {
      type => 'bytes',
      high_water_mark => -54,
    });
  };
  like $@, qr{^RangeError: High water mark -54 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'high_water_mark negative';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  isa_ok $rc, 'ReadableByteStreamController';
  my $closed;
  $rs->get_reader->closed->then (sub { $closed = 1 });
  Promise->resolve->then (sub {
    test {
      ok ! $closed;
      is $rc->close, undef;
    } $c;
  })->then (sub {
    test {
      ok $closed;
    } $c;
    done $c;
    undef $c;
  });
} n => 4, name => 'close';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  $rc->close;
  $rs->get_reader->closed->then (sub {
    $rc->close;
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'close after close';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  my $reason = [];
  is $rc->error ($reason), undef;
  $rs->get_reader->closed->catch (sub {
    my $e = $_[0];
    test {
      is $e, $reason;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'error';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  $rc->error;
  my $reason = [];
  eval {
    $rc->error ($reason);
  };
  like $@, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'error';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub { $rc = $_[1] },
  });
  is $rc->byob_request, undef;
  done $c;
} n => 1, name => 'byob_request no request';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
