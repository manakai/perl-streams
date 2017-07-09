use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use WritableStream;

for my $value (undef, '', 0, 123, "abc", {}, bless {}, 'test::foo') {
  test {
    my $c = shift;
    eval {
      WritableStreamDefaultController->new ($value);
    };
    like $@, qr{^TypeError: The argument is not a WritableStream at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => 'new bad arg';
}

test {
  my $c = shift;
  my $ws = WritableStream->new;
  eval {
    WritableStreamDefaultController->new ($ws);
  };
  like $@, qr{^TypeError: WritableStream has a controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'new with WritableStream';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 314,
  });
  my $w = $ws->get_writer;
  is $w->desired_size, 314;
  done $c;
} n => 1, name => 'high_water_mark integer';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 314.42,
  });
  my $w = $ws->get_writer;
  is $w->desired_size, 314.42;
  done $c;
} n => 1, name => 'high_water_mark float';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => "42abc",
  });
  my $w = $ws->get_writer;
  is $w->desired_size, 42;
  done $c;
} n => 1, name => 'high_water_mark number string';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 0,
  });
  my $w = $ws->get_writer;
  is $w->desired_size, 0;
  done $c;
} n => 1, name => 'high_water_mark zero';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => "abcd",
  });
  my $w = $ws->get_writer;
  is $w->desired_size, 0;
  done $c;
} n => 1, name => 'high_water_mark string';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 0+"Inf",
  });
  my $w = $ws->get_writer;
  is $w->desired_size, 0+"Inf";
  done $c;
} n => 1, name => 'high_water_mark Inf';

test {
  my $c = shift;
  my $ws = WritableStream->new ({}, {
    high_water_mark => 0+"NaN",
  });
  my $w = $ws->get_writer;
  is $w->desired_size, 0;
  done $c;
} n => 1, name => 'high_water_mark NaN';

test {
  my $c = shift;
  eval {
    WritableStream->new ({}, {
      high_water_mark => -54,
    });
  };
  like $@, qr{^RangeError: High water mark -54 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'high_water_mark negative';

test {
  my $c = shift;
  my $wc;
  my $ws = WritableStream->new ({
    start => sub {
      $wc = $_[1];
    },
  });
  isa_ok $wc, 'WritableStreamDefaultController';
  my $reason = {};
  my $result = $wc->error ($reason);
  is $result, undef;
  my $reason2 = {};
  my $result2 = $wc->error ($reason2);
  is $result2, undef;
  $ws->get_writer->closed->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $e = $_[0];
    test {
      is $e, $reason;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4, name => 'error';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
