use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use WritableStream;

test {
  my $c = shift;
  my $ws = WritableStream->new;
  isa_ok $ws, 'WritableStream';
  done $c;
} n => 1, name => 'new no args';

for my $value (0, "", "abc", (bless {}, "test::foo"), [], \"ab") {
  test {
    my $c = shift;
    eval {
      WritableStream->new ($value);
    };
    like $@, qr{^TypeError: Sink is not a HASH at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new sink not hashref';

  test {
    my $c = shift;
    eval {
      WritableStream->new (undef, $value);
    };
    like $@, qr{^TypeError: Options is not a HASH at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new options not hashref';
}

test {
  my $c = shift;
  my $written = '';
  my $ws = WritableStream->new ({
    start => sub {
      $written .= '(start)';
    },
    write => sub {
      $written .= $_[1];
    },
    close => sub {
      $written .= '(close)';
    },
  });
  my $writer = $ws->get_writer;
  isa_ok $writer, 'WritableStreamDefaultWriter';
  $writer->write ("abc");
  $writer->write ('xyz');
  $writer->close;
  $writer->close->catch (sub { });
  $writer->closed->then (sub {
    test {
      is $written, '(start)abcxyz(close)';
      done $c;
      undef $c;
    } $c;
  });
} n => 2;

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  isa_ok $w, 'WritableStreamDefaultWriter';
  eval {
    $ws->get_writer;
  };
  like $@, qr{^TypeError: WritableStream is locked at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 2, name => 'get_writer';

test {
  my $c = shift;
  eval {
    WritableStream->new ({type => "abc"});
  };
  like $@, qr{^\QRangeError: Unknown type |abc|\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new type';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  is $w->desired_size, 1;
  done $c;
} n => 1, name => 'new default high_water_mark';

test {
  my $c = shift;
  my $ws = WritableStream->new (undef, {high_water_mark => 5});
  my $w = $ws->get_writer;
  is $w->desired_size, 5;
  done $c;
} n => 1, name => 'new high_water_mark';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  ok ! $ws->locked;
  my $w1 = $ws->get_writer;
  ok $ws->locked;
  $w1->release_lock;
  ok ! $ws->locked;
  my $w2 = $ws->get_writer;
  ok $ws->locked;
  done $c;
} n => 4, name => 'locked';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  $ws->abort->then (sub {
    return $ws->abort->catch (sub {
      my $e = $_[0];
      test {
        ok 1;
      } $c;
    });
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'abort';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $ws->abort->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      like $e, qr{^\QTypeError: WritableStream is locked\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'abort locked';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 100,
    size => sub {
      return 10;
    },
  });
  my $writer = $ws->get_writer;
  isa_ok $writer, 'WritableStreamDefaultWriter';
  $writer->write ("abc");
  test {
    is $writer->desired_size, 100 - 10;
  } $c;
  done $c;
  undef $c;
} n => 2, name => 'desired_size size & high_water_mark';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 100,
    size => sub {
      return 10.3;
    },
  });
  my $writer = $ws->get_writer;
  isa_ok $writer, 'WritableStreamDefaultWriter';
  $writer->write ("abc");
  test {
    is $writer->desired_size, 100 - 10.3;
  } $c;
  done $c;
  undef $c;
} n => 2, name => 'desired_size size float';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 100,
    size => sub {
      return 0+"Inf";
    },
  });
  my $writer = $ws->get_writer;
  isa_ok $writer, 'WritableStreamDefaultWriter';
  my $p = $writer->write ("abc");
  test {
    is $writer->desired_size, undef;
  } $c;
  $p->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $e = $_[0];
    test {
      like $e, qr{^RangeError: Size .+ is too large at \Q@{[__FILE__]}\E line \Q@{[__LINE__-11]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'desired_size size inf';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 100,
    size => sub {
      return 0+"nan";
    },
  });
  my $writer = $ws->get_writer;
  isa_ok $writer, 'WritableStreamDefaultWriter';
  my $p = $writer->write ("abc");
  test {
    is $writer->desired_size, 100;
  } $c;
  $p->then (sub {
    test {
      ok 1;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'desired_size size nan';

test {
  my $c = shift;
  eval {
    WritableStream->new ({
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
  my $ws = WritableStream->new ({
    start => sub {
      return Promise->resolve->then (sub {
        die "Bad start";
      });
    },
  });
  isa_ok $ws, 'WritableStream';
  my $w = $ws->get_writer;
  isa_ok $w, 'WritableStreamDefaultWriter';
  $w->write->catch (sub {
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
  my $written;
  my $ws = WritableStream->new ({
    start => sub {
      return Promise->resolve->then (sub {
        $resolved = 1;
      });
    },
    write => sub {
      $written = $resolved;
    },
  });
  isa_ok $ws, 'WritableStream';
  is $resolved, 0, 'Not resolved yet';
  my $w = $ws->get_writer;
  isa_ok $w, 'WritableStreamDefaultWriter';
  $w->write->then (sub {
    test {
      is $resolved, 1;
      is $written, 1, '$resolved is 1 when write is invoked';
    } $c;
    done $c;
    undef $c;
  });
} n => 5, name => 'start resolves';

test {
  my $c = shift;
  my $resolved = 0;
  my $written;
  my $start_args;
  my $sink = {
    start => sub {
      $start_args = [@_];
      $resolved = 1;
      test {
        ok defined wantarray;
        ok ! wantarray;
      } $c;
    },
    write => sub {
      $written = $resolved;
    },
  };
  my $ws = WritableStream->new ($sink);
  isa_ok $ws, 'WritableStream';
  is $resolved, 1;
  is $start_args->[0], $sink;
  my $w = $ws->get_writer;
  isa_ok $w, 'WritableStreamDefaultWriter';
  $w->write->then (sub {
    test {
      is $resolved, 1;
      is $written, 1, '$resolved is 1 when write is invoked';
    } $c;
    undef $start_args; # $start_args->[0] is $sink which references $start_args
    done $c;
    undef $c;
  });
} n => 8, name => 'start returns';

test {
  my $c = shift;
  eval {
    WritableStream->new ({
      start => "hoe",
    });
  };
  like $@, qr{^\QTypeError: The |start| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'start is not CODE';

test {
  my $c = shift;
  eval {
    WritableStream->new ({
      start => "",
    });
  };
  like $@, qr{^\QTypeError: The |start| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'start is not CODE';

test {
  my $c = shift;
  my $closed;
  my $ws = WritableStream->new ({
    close => sub {
      $closed = 1;
    },
  });
  ok ! $closed;
  my $w = $ws->get_writer;
  $w->close->then (sub {
    test {
      ok $closed;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'close';

test {
  my $c = shift;
  my $closed;
  my $ws = WritableStream->new ({
    close => sub {
      return Promise->resolve->then (sub {
        $closed = 1;
      });
    },
  });
  ok ! $closed;
  my $w = $ws->get_writer;
  $w->close->then (sub {
    test {
      ok $closed;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'close resolves';

test {
  my $c = shift;
  my $closed;
  my $ws = WritableStream->new ({
    close => sub {
      $closed = 1;
      die "Close failed";
    },
  });
  ok ! $closed;
  my $w = $ws->get_writer;
  $w->close->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      ok $closed;
      like $e, qr{^\QClose failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-11]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'close dies';

test {
  my $c = shift;
  my $closed;
  my $ws = WritableStream->new ({
    close => sub {
      return Promise->resolve->then (sub {
        $closed = 1;
        die "Close failed";
      });
    },
  });
  ok ! $closed;
  my $w = $ws->get_writer;
  $w->close->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      ok $closed;
      like $e, qr{^\QClose failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-12]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'close rejects';

test {
  my $c = shift;
  my $aborted;
  my $ws = WritableStream->new ({
    abort => sub {
      $aborted = $_[1];
    },
  });
  ok ! $aborted;
  my $w = $ws->get_writer;
  my $reason = [];
  $w->abort ($reason)->then (sub {
    test {
      is $aborted, $reason;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'abort';

test {
  my $c = shift;
  my $aborted;
  my $ws = WritableStream->new ({
    abort => sub {
      my $reason = $_[1];
      return Promise->resolve->then (sub {
        $aborted = $reason;
      });
    },
  });
  ok ! $aborted;
  my $w = $ws->get_writer;
  my $reason = {};
  $w->abort ($reason)->then (sub {
    test {
      is $aborted, $reason;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'abort resolves';

test {
  my $c = shift;
  my $aborted;
  my $ws = WritableStream->new ({
    abort => sub {
      $aborted = $_[1];
      die "Abort failed";
    },
  });
  ok ! $aborted;
  my $w = $ws->get_writer;
  my $reason = {};
  $w->abort ($reason)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      is $aborted, $reason;
      like $e, qr{^\QAbort failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-12]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'abort dies';

test {
  my $c = shift;
  my $aborted;
  my $ws = WritableStream->new ({
    abort => sub {
      my $reason = $_[1];
      return Promise->resolve->then (sub {
        $aborted = $reason;
        die "Abort failed";
      });
    },
  });
  ok ! $aborted;
  my $w = $ws->get_writer;
  my $reason = {};
  $w->abort ($reason)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      is $aborted, $reason;
      like $e, qr{^\QAbort failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-13]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'abort rejects';

test {
  my $c = shift;
  my $written;
  my $ws = WritableStream->new ({
    write => sub {
      $written = $_[1];
    },
  });
  my $w = $ws->get_writer;
  my $value = {};
  my $p = $w->write ($value);
  is $written, undef;
  $p->then (sub {
    test {
      is $written, $value;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'write';

test {
  my $c = shift;
  my $written;
  my $ws = WritableStream->new ({
    write => sub {
      my $chunk = $_[1];
      return Promise->resolve->then (sub {
        $written = $chunk;
      });
    },
  });
  my $w = $ws->get_writer;
  my $value = {};
  my $p = $w->write ($value);
  is $written, undef;
  $p->then (sub {
    test {
      is $written, $value;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'write';

test {
  my $c = shift;
  my $written;
  my $ws = WritableStream->new ({
    write => sub {
      $written = $_[1];
      die "Write failed";
    },
  });
  my $w = $ws->get_writer;
  my $value = {};
  my $p = $w->write ($value);
  is $written, undef;
  $p->catch (sub {
    my $e = $_[0];
    test {
      is $written, $value;
      like $e, qr{^\QWrite failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-11]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'write';

test {
  my $c = shift;
  my $written;
  my $ws = WritableStream->new ({
    write => sub {
      my $chunk = $_[1];
      return Promise->resolve->then (sub {
        $written = $chunk;
        die "Write failed";
      });
    },
  });
  my $w = $ws->get_writer;
  my $value = {};
  my $p = $w->write ($value);
  is $written, undef;
  $p->catch (sub {
    my $e = $_[0];
    test {
      is $written, $value;
      like $e, qr{^\QWrite failed\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-12]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'write';

test {
  my $c = shift;
  my @c;
  my $ws = WritableStream->new ({
    start => sub {
      push @c, $_[1];
    },
    write => sub {
      push @c, $_[2];
    },
  });
  my $writer = $ws->get_writer;
  $writer->write (1);
  $writer->write (2);
  $writer->close;
  $writer->closed->then (sub {
    test {
      is 0+@c, 3;
      is $c[0], $c[1];
      is $c[0], $c[2];
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'same controller objects';

test {
  my $c = shift;
  my $ws = WritableStream->new ({
    start => sub {
      my $wc = $_[1];
      test {
        isa_ok $wc, 'WritableStreamDefaultController';
      } $c;
    },
    write => sub {
      my $wc = $_[2];
      test {
        isa_ok $wc, 'WritableStreamDefaultController';
      } $c;
    },
  });
  my $writer = $ws->get_writer;
  $writer->write (1);
  $writer->write (2);
  $writer->close;
  $writer->closed->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'controller objects';

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
    my $ws = WritableStream->new;
    $ws->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
  }
  Promise->resolve->then (sub {
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
    my $wc;
    my $ws = WritableStream->new ({
      start => sub { $wc = $_[1] },
    });
    $ws->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
    my $w = $ws->get_writer;
    $p = $w->write (4);
    Promise->resolve->then (sub {
      undef $wc; # need explicit freeing!
    });
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
  my $p;
  my $destroyed;
  {
    my $wc;
    my $ws = WritableStream->new ({
      start => sub { $wc = $_[1] },
    });
    $ws->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
    my $w = $ws->get_writer;
    $w->write (4);
    $p = $w->close;
  }
  Promise->resolve ($p)->then (sub {
    test {
      ok $destroyed;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'destroy';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
