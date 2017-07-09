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
      ReadableStreamDefaultReader->new ($value);
    };
    like $@, qr{^TypeError: The argument is not a ReadableStream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new bad arg';
}

test {
  my $c = shift;
  my $rs = ReadableStream->new ({});
  my $r = ReadableStreamDefaultReader->new ($rs);
  isa_ok $r, 'ReadableStreamDefaultReader';
  done $c;
} n => 1, name => 'new default';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({type => 'bytes'});
  my $r = ReadableStreamDefaultReader->new ($rs);
  isa_ok $r, 'ReadableStreamDefaultReader';
  done $c;
} n => 1, name => 'new bytes';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({type => 'bytes'});
  my $r = $rs->get_reader;
  eval {
    ReadableStreamDefaultReader->new ($rs);
  };
  like $@, qr{^TypeError: ReadableStream is locked at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new locked';

test {
  my $c = shift;
  my $x = 3;
  my $rs = ReadableStream->new ({
    pull => sub { $_[1]->enqueue ($x++); $_[1]->close if $x == 5 },
  });
  my $r = $rs->get_reader;
  $r->read->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, 3;
      ok ! $v->{done};
    } $c;
    return $r->read;
  })->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, 4;
      ok ! $v->{done};
    } $c;
    return $r->read;
  })->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, undef;
      ok $v->{done};
    } $c;
    done $c;
    undef $c;
  });
} n => 6, name => 'read';

test {
  my $c = shift;
  my $x = 3;
  my $rs = ReadableStream->new ({
    pull => sub { $_[1]->enqueue ($x++); $_[1]->close if $x == 5 },
  });
  my $r = $rs->get_reader;
  $r->release_lock;
  $r->read->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Reader's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'read released';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({});
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  is $r->release_lock, undef;
  my $r2 = $rs->get_reader;
  isa_ok $r2, 'ReadableStreamDefaultReader';
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
  my $rs = ReadableStream->new ({});
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  $r->read;
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
    start => sub { $rc = $_[1] },
  });
  my $r = $rs->get_reader;
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
    start => sub { $rc = $_[1] },
  });
  my $r = $rs->get_reader;
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
} n => 1, name => 'cancel after release';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({});
  my $r = $rs->get_reader;
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

for my $value (
  undef, 0, 42, "", "abae", [], {}, (bless {}, "test::foo::bar"),
) {
  test {
    my $c = shift;
    my $rs = ReadableStream->new;
    eval {
      ReadableStreamDefaultController->new ($value, {}, sub { }, 4);
    };
    like $@, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new bad stream';
}

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  eval {
    ReadableStreamDefaultController->new ($rs, {}, sub { }, 4);
  };
  like $@, qr{^TypeError: ReadableStream has a controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new stream';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    pull => sub {
      my $rc = $_[1];
      $rc->enqueue (5);
    },
  });
  my $r = $rs->get_reader;
  $r->read->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, 5;
      ok ! $v->{done};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'enqueue';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    pull => sub {
      my $rc = $_[1];
      $rc->enqueue (5);
      $rc->enqueue (15);
    },
  });
  my $r = $rs->get_reader;
  $r->read->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, 5;
      ok ! $v->{done};
    } $c;
    return $r->read;
  })->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, 15;
      ok ! $v->{done};
    } $c;
    done $c;
    undef $c;
  });
} n => 4, name => 'enqueue';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    pull => sub {
      my $rc = $_[1];
      $rc->enqueue (5);
      $rc->close;
      $rc->enqueue (15);
    },
  });
  my $r = $rs->get_reader;
  $r->read->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, 5;
      ok ! $v->{done};
    } $c;
    return $r->read;
  })->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, undef;
      ok $v->{done};
    } $c;
    return $r->closed;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4, name => 'enqueue';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    pull => sub {
      my $rc = $_[1];
      $rc->enqueue (5);
      $rc->close;
      eval {
        $rc->enqueue (15);
      };
      test {
        like $@, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-3]}\E};
      } $c;
    },
  });
  my $r = $rs->get_reader;
  $r->read->then (sub {
    my $v = $_[0];
    test {
      is $v->{value}, 5;
      ok ! $v->{done};
    } $c;
    return $r->closed;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'enqueue after close';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 314,
  });
  is $rc->desired_size, 314;
  undef $rc; # referencing $rs referencing start referencing $rc
  done $c;
} n => 1, name => 'high_water_mark integer';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 314.42,
  });
  is $rc->desired_size, 314.42;
  undef $rc; # referencing $rs referencing start referencing $rc
  done $c;
} n => 1, name => 'high_water_mark float';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => "42abc",
  });
  is $rc->desired_size, 42;
  undef $rc; # referencing $rs referencing start referencing $rc
  done $c;
} n => 1, name => 'high_water_mark number string';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 0,
  });
  is $rc->desired_size, 0;
  undef $rc; # referencing $rs referencing start referencing $rc
  done $c;
} n => 1, name => 'high_water_mark zero';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => "abcd",
  });
  is $rc->desired_size, 0;
  undef $rc; # referencing $rs referencing start referencing $rc
  done $c;
} n => 1, name => 'high_water_mark string';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 0+"Inf",
  });
  is $rc->desired_size, 0+"Inf";
  undef $rc; # referencing $rs referencing start referencing $rc
  done $c;
} n => 1, name => 'high_water_mark Inf';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  }, {
    high_water_mark => 0+"NaN",
  });
  is $rc->desired_size, 0;
  undef $rc; # referencing $rs referencing start referencing $rc
  done $c;
} n => 1, name => 'high_water_mark NaN';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({}, {
      high_water_mark => -54,
    });
  };
  like $@, qr{^RangeError: High water mark -54 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'high_water_mark negative';

test {
  my $c = shift;
  my $rc;
  my $size_invoked = 0;
  my $chunk = {};
  my $got;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
    pull => sub {
      $rc->enqueue ($chunk);
    },
  }, {
    size => sub {
      $got = $_[0] unless defined $got;
      $size_invoked++;
      return 5;
    },
    high_water_mark => 314,
  });
  is $size_invoked, 0;
  is $rc->desired_size, 314;
  my $r = $rs->get_reader;
  $r->read->then (sub {
    test {
      is $size_invoked, 0;
      is $rc->desired_size, 314;
      is $got, undef;
    } $c;
    return $r->read;
  })->then (sub {
    test {
      ok $size_invoked;
      is $got, $chunk;
      ok $rc->desired_size < 314;
    } $c;
    undef $rc; # referencing $rs referencing start referencing $rc
    done $c;
    undef $c;
  });
} n => 8, name => 'size code';

test {
  my $c = shift;
  my $rc;
  my $size_invoked = 0;
  my $chunk = {};
  my $got;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
    pull => sub {
      $rc->enqueue ($chunk);
    },
  }, {
    size => sub {
      $got = $_[0] unless defined $got;
      $size_invoked++;
      die "Size fails";
    },
    high_water_mark => 314,
  });
  is $size_invoked, 0;
  is $rc->desired_size, 314;
  my $r = $rs->get_reader;
  $r->read->then (sub {
    test {
      is $size_invoked, 0;
      is $rc->desired_size, 314;
      is $got, undef;
    } $c;
    return $r->read;
  })->then (sub {
    test {
      ok $size_invoked;
      is $got, $chunk;
      is $rc->desired_size, undef;
    } $c;
    return $r->read;
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^Size fails at \Q@{[__FILE__]}\E line \Q@{[__LINE__-24]}\E};
    } $c;
    undef $rc; # referencing $rs referencing start referencing $rc
    done $c;
    undef $c;
  });
} n => 9, name => 'size dies';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({}, {
      size => "abc",
      high_water_mark => 314,
    });
  };
  like $@, qr{^TypeError: Size is not a CODE at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'size bad';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  });
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
} n => 3, name => 'close';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
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
    start => sub { $rc = $_[1] },
  });
  my $reason = [];
  is $rc->error ($reason), undef;
  $rs->get_reader->closed->catch (sub {
    my $e = $_[0];
    test {
      is $e, $reason
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'error';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  });
  $rc->close;
  my $reason = [];
  eval {
    $rc->error ($reason);
  };
  like $@, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  $rs->get_reader->closed->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'error after close';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
