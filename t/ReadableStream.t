use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use Promised::Flow;
use ReadableStream;

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  isa_ok $rs, 'ReadableStream';
  done $c;
} n => 1, name => 'new no args';

for my $value (0, "", "abc", (bless {}, "test::foo"), [], \"ab") {
  test {
    my $c = shift;
    eval {
      ReadableStream->new ($value);
    };
    like $@, qr{^TypeError: Source is not a HASH at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new source not hashref';

  test {
    my $c = shift;
    eval {
      ReadableStream->new (undef, $value);
    };
    like $@, qr{^TypeError: Options is not a HASH at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new options not hashref';
}

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => '',
    });
  };
  like $@, qr{^\QRangeError: Unknown type ||\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'new bad type';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'byte',
    });
  };
  like $@, qr{^\QRangeError: Unknown type |byte|\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'new bad type';

test {
  my $c = shift;
  my $r1;
  my $r2;
  my $i = 0;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub {
      $rc = $_[1];
      $r1 = rand;
      $r2 = rand;
    },
    pull => sub {
      $i++;
      return $rc->enqueue ($r1) if $i == 1;
      return Promise->resolve->then (sub { $rc->enqueue ($r2) }) if $i == 2;
      die "Bad pull ($i)";
    },
  });
  my $reader = $rs->get_reader;
  isa_ok $reader, 'ReadableStreamDefaultReader';
  my @read;
  $reader->read->then (sub { push @read, $_[0]->{value} });
  $reader->read->then (sub { push @read, $_[0]->{value} });
  $reader->read->catch (sub {
    my $err = $_[0];
    test {
      is 0+@read, 2;
      is $read[0], $r1;
      is $read[1], $r2;
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-14]}\E};
    } $c;
  });
  $reader->closed->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-24]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 6;

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      start => sub {
        die "Bad start";
      },
    });
  };
  like $@, qr{^Bad start at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'start throw';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    start => sub {
      return Promise->resolve->then (sub {
        die "Bad start";
      });
    },
  });
  isa_ok $rs, 'ReadableStream';
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  $r->read->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^Bad start at \Q@{[__FILE__]}\E line \Q@{[__LINE__-10]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'start rejects';

test {
  my $c = shift;
  my $resolved = 0;
  my $read;
  my $rs = ReadableStream->new ({
    start => sub {
      return Promise->resolve->then (sub {
        $resolved = 1;
      });
    },
    pull => sub {
      $read = $resolved;
      $_[1]->enqueue ("x");
    },
  });
  isa_ok $rs, 'ReadableStream';
  is $resolved, 0, 'Not resolved yet';
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  $r->read->then (sub {
    test {
      is $resolved, 1;
      is $read, 1, '$resolved is 1 when write is invoked';
    } $c;
    done $c;
    undef $c;
  });
} n => 5, name => 'start resolves';

test {
  my $c = shift;
  my $resolved = 0;
  my $read;
  my $start_args;
  my $source = {
    start => sub {
      $start_args = [@_];
      $resolved = 1;
      test {
        ok defined wantarray;
        ok ! wantarray;
      } $c;
    },
    pull => sub {
      $read = $resolved;
      $_[1]->enqueue ("x");
    },
  };
  my $rs = ReadableStream->new ($source);
  isa_ok $rs, 'ReadableStream';
  is $resolved, 1;
  is $start_args->[0], $source;
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  $r->read->then (sub {
    test {
      is $resolved, 1;
      is $read, 1, '$resolved is 1 when write is invoked';
    } $c;
    undef $start_args; # [0] - $source->{start} - $start_args / [1] $rc
    done $c;
    undef $c;
  });
} n => 8, name => 'start returns';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      start => "hoe",
    });
  };
  like $@, qr{^\QTypeError: The |start| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'start is not CODE';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      start => "",
    });
  };
  like $@, qr{^\QTypeError: The |start| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'start is not CODE';

test {
  my $c = shift;
  my $closed;
  my $rs = ReadableStream->new ({
    cancel => sub {
      $closed = $_[1];
    },
  });
  ok ! $closed;
  my $r = $rs->get_reader;
  my $reason = {};
  $r->cancel ($reason)->then (sub {
    test {
      is $closed, $reason;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'close';

test {
  my $c = shift;
  my $closed;
  my $rs = ReadableStream->new ({
    cancel => sub {
      my $reason = $_[1];
      return Promise->resolve->then (sub {
        $closed = $reason;
      });
    },
  });
  ok ! $closed;
  my $r = $rs->get_reader;
  my $reason = {};
  $r->cancel ($reason)->then (sub {
    test {
      is $closed, $reason;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'close resolves';

test {
  my $c = shift;
  my $closed;
  my $rs = ReadableStream->new ({
    cancel => sub {
      $closed = $_[1];
      die "Close failed";
    },
  });
  ok ! $closed;
  my $r = $rs->get_reader;
  my $reason = {};
  $r->cancel ($reason)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      is $closed, $reason;
      like $e, qr{^\QClose failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-12]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'close dies';

test {
  my $c = shift;
  my $closed;
  my $rs = ReadableStream->new ({
    cancel => sub {
      my $reason = $_[1];
      return Promise->resolve->then (sub {
        $closed = $reason;
        die "Close failed";
      });
    },
  });
  ok ! $closed;
  my $r = $rs->get_reader;
  my $reason = {};
  $r->cancel ($reason)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      is $closed, $reason;
      like $e, qr{^\QClose failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-13]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'close rejects';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    cancel => "foobar",
  });
  my $r = $rs->get_reader;
  my $reason = {};
  $r->cancel ($reason)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      like $e, qr{^\QTypeError: The |cancel| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'cancel bad code';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    cancel => "foobar",
  });
  my $r = $rs->get_reader ('byob');
  my $reason = {};
  $r->cancel ($reason)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      like $e, qr{^\QTypeError: The |cancel| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'cancel bad code';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    start => sub { $rc = $_[1] },
  });
  $rs->cancel->then (sub {
    return $rc->close;
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^\QTypeError: ReadableStream is closed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
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
  $rs->cancel->catch (sub {
    my $e = $_[0];
    undef $rc; # referencing $rs referencing start referencing $rc
    test {
      like $e, qr{^\QTypeError: ReadableStream is locked\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'cancel after reader';

test {
  my $c = shift;
  my $pulled;
  my $rs = ReadableStream->new ({
    pull => sub {
      $pulled = 1;
      $_[1]->enqueue ([]);
    },
  });
  is $pulled, undef;
  my $r = $rs->get_reader;
  $r->read->then (sub {
    test {
      is $pulled, 1;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'pull 1';

test {
  my $c = shift;
  my $pulled;
  my $rs = ReadableStream->new ({
    pull => sub {
      my $rc = $_[1];
      return Promise->resolve->then (sub {
        $pulled = 1;
        $rc->enqueue ([]);
      });
    },
  });
  is $pulled, undef;
  my $r = $rs->get_reader;
  $r->read->then (sub {
    test {
      is $pulled, 1;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'pull 2';

test {
  my $c = shift;
  my $pulled;
  my $rs = ReadableStream->new ({
    pull => sub {
      $pulled = 1;
      $_[1]->enqueue ([]);
      die "pull failed";
    },
  });
  is $pulled, undef;
  my $r = $rs->get_reader;
  $r->read->then (sub {
    test {
      ok 1;
    } $c;
    return $r->read;
  })->catch (sub {
    my $e = $_[0];
    test {
      is $pulled, 1;
      like $e, qr{^\Qpull failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-14]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4, name => 'pull 3';

test {
  my $c = shift;
  my $pulled;
  my $rs = ReadableStream->new ({
    pull => sub {
      my $rc = $_[1];
      return Promise->resolve->then (sub {
        $pulled = 1;
        $rc->enqueue ([]);
        die "pull failed";
      });
    },
  });
  is $pulled, undef;
  my $r = $rs->get_reader;
  $r->read->then (sub {
    test {
      ok 1;
    } $c;
    return $r->read;
  })->catch (sub {
    my $e = $_[0];
    test {
      is $pulled, 1;
      like $e, qr{^\Qpull failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-15]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4, name => 'pull 4';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    pull => \"foo",
  });
  my $r = $rs->get_reader;
  $r->read->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^\QTypeError: The |pull| member is not a CODE\E}; # XXX at Promise.pm :-<
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'pull 5';

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  ok ! $rs->locked;
  my $r = $rs->get_reader;
  ok $rs->locked;
  $r->release_lock;
  ok ! $rs->locked;
  my $r2 = $rs->get_reader;
  ok $rs->locked;
  done $c;
} n => 4, name => 'locked';

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  done $c;
} n => 1, name => 'get_reader';

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  my $r = $rs->get_reader (undef);
  isa_ok $r, 'ReadableStreamDefaultReader';
  done $c;
} n => 1, name => 'get_reader';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({type => 'bytes'});
  my $r = $rs->get_reader ('byob');
  isa_ok $r, 'ReadableStreamBYOBReader';
  done $c;
} n => 1, name => 'get_reader';

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  eval {
    $rs->get_reader ('byob');
  };
  like $@, qr{^TypeError: ReadableStream is not a byte stream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  ok $rs->get_reader;
  done $c;
} n => 2, name => 'get_reader';

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  eval {
    $rs->get_reader ('');
  };
  like $@, qr{^\QRangeError: Unknown mode ||\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  ok $rs->get_reader;
  done $c;
} n => 2, name => 'get_reader';

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  eval {
    $rs->get_reader ('hoge');
  };
  like $@, qr{^\QRangeError: Unknown mode |hoge|\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  ok $rs->get_reader;
  done $c;
} n => 2, name => 'get_reader';

test {
  my $c = shift;
  my $rs = ReadableStream->new;
  eval {
    $rs->get_reader ('BYOB');
  };
  like $@, qr{^\QRangeError: Unknown mode |BYOB|\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  ok $rs->get_reader;
  done $c;
} n => 2, name => 'get_reader';

{
  package test::DestroyCallback1;
  sub DESTROY {
    $_[0]->();
  }
}

test {
  my $c = shift;
  my $destroyed;
  {
    my $rs = ReadableStream->new;
    $rs->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
  }
  Promise->resolve->then (sub {
    return promised_wait_until { $destroyed } timeout => 10;
  })->then (sub {
    test {
      ok $destroyed;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'destroy';

test {
  my $c = shift;
  my $p;
  my $destroyed;
  {
    my $rc;
    my @read = ("abc", "def");
    my $rs = ReadableStream->new ({
      start => sub { $rc = $_[1] },
      pull => sub { $_[1]->enqueue (shift @read || (return $_[1]->close)) },
    });
    $rs->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
    my $r = $rs->get_reader;
    $p = $r->read;
    Promise->resolve->then (sub {
      undef $rc; # need explicit freeing!
    });
  }
  Promise->resolve ($p)->then (sub {
    return promised_wait_until { $destroyed } timeout => 10;
  })->then (sub {
    test {
      ok $destroyed;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'destroy';

test {
  my $c = shift;
  my $p;
  my $destroyed;
  {
    my $rc;
    my @read = ("abc", "def");
    my $rs = ReadableStream->new ({
      start => sub { $rc = $_[1] },
      pull => sub { $_[1]->enqueue (shift @read || (return $_[1]->close)) },
    });
    $rs->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
    my $r = $rs->get_reader;
    $r->read;
    $rc->close;
    $p = $r->closed;
  }
  Promise->resolve ($p)->then (sub {
    test {
      ok $destroyed;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'destroy';

test {
  my $c = shift;
  my @read = ("abc", "def");
  my $rs = ReadableStream->new ({
    pull => sub { $_[1]->enqueue (shift @read || (return $_[1]->close)) },
  });
  my $r = $rs->get_reader;
  undef $rs;
  my $result = '';
  $r->read->then (sub { $result .= $_[0]->{value} });
  $r->read->then (sub { $result .= $_[0]->{value} });
  $r->closed->then (sub {
    test {
      is $result, "abcdef";
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'ReadableStream reference discarded before read';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
