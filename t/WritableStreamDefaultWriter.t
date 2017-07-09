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
  my $w = WritableStreamDefaultWriter->new ($ws);
  isa_ok $w, 'WritableStreamDefaultWriter';
  ok $ws->locked;
  done $c;
} n => 2, name => 'new';

for my $value (undef, '', 0, 123, "abc", {}, bless {}, 'test::foo') {
  test {
    my $c = shift;
    eval {
      WritableStreamDefaultWriter->new ($value);
    };
    like $@, qr{^TypeError: The argument is not a WritableStream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new bad arg';
}

test {
  my $c = shift;
  eval {
    WritableStreamDefaultWriter->new;
  };
  like $@, qr{^TypeError: The argument is not a WritableStream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1;

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  eval {
    WritableStreamDefaultWriter->new ($ws);
  };
  like $@, qr{^TypeError: WritableStream is locked at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1;

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->ready->then (sub {
    test {
      ok 1;
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'ready';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->release_lock;
  $w->write ("abc")->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'write detached';

test {
  my $c = shift;
  my $w;
  my $ws = WritableStream->new (undef, {
    size => sub {
      $w->release_lock;
    },
  });
  $w = $ws->get_writer;
  $w->write ("abc")->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'write detached';

test {
  my $c = shift;
  my $w;
  my $w2;
  my $ws; $ws = WritableStream->new (undef, {
    size => sub {
      $w->release_lock;
      $w2 = $ws->get_writer;
    },
  });
  $w = $ws->get_writer;
  $w->write ("abc")->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+5]}\E};
    } $c;
    done $c;
    undef $c;
    undef $ws;
  });
} n => 1, name => 'write detached';

test {
  my $c = shift;
  my $ws = WritableStream->new (undef, {});
  my $w = $ws->get_writer;
  $w->close;
  $w->write ("abc")->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: WritableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'write after closed';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  is $w->desired_size, 1;
  done $c;
} n => 1, name => 'desired_size';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->release_lock;
  eval {
    $w->desired_size;
  };
  test {
    like $@, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__-3]}\E};
  } $c;
  done $c;
} n => 1, name => 'desired_size';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->close->then (sub {
    test {
      is $w->desired_size, 0;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'desired_size after close';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->abort->then (sub {
    test {
      is $w->desired_size, undef;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'desired_size after error';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  is $w->release_lock, undef;
  is $w->release_lock, undef;
  done $c;
} n => 2, name => 'release_lock';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  is $w->release_lock, undef;
  $w->closed->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
    } $c;
    return $w->ready;
  })->then (sub {
    test {
      ok 1;
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'release_lock';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {high_water_mark => 0});
  my $w = $ws->get_writer;
  is $w->release_lock, undef;
  $w->closed->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
    } $c;
    return $w->ready;
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__-10]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'release_lock';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->release_lock;
  $w->close->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'close after release';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->close;
  $w->close->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: WritableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'close after close';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->close->then (sub {
    return $w->close;
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: WritableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'close after close';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  $w->release_lock;
  $w->abort->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: Writer's lock is released at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'abort after release';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  my $reason = [];
  $w->abort ($reason)->then (sub {
    return $w->abort;
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: WritableStream is aborted at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'abort after abort';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  my $close_fulfilled;
  my $close_rejected;
  $w->closed->then (sub {
    $close_fulfilled = 1;
  }, sub {
    $close_rejected = $_[0];
  });
  is $close_fulfilled, undef;
  is $close_rejected, undef;
  $w->close->then (sub { })->then (sub {
    test {
      is $close_fulfilled, 1;
      is $close_rejected, undef;
    } $c;
    done $c;
    undef $c;
  });
} n => 4, name => 'closed';

test {
  my $c = shift;
  my $ws = WritableStream->new;
  my $w = $ws->get_writer;
  my $close_fulfilled;
  my $close_rejected;
  $w->closed->then (sub {
    $close_fulfilled = 1;
  }, sub {
    $close_rejected = $_[0];
  });
  is $close_fulfilled, undef;
  is $close_rejected, undef;
  my $reason = $_[0];
  $w->abort ($reason)->then (sub { })->then (sub {
    test {
      is $close_fulfilled, undef;
      like $close_rejected, qr{^TypeError: WritableStream is aborted at \Q@{[__FILE__]}\E line \Q@{[__LINE__+4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 4, name => 'closed';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
