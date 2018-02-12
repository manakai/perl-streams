use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use File::Temp;
use Test::More;
use Test::X1;
use Promised::Flow;
use Streams::Filehandle;
use DataView;

test {
  my $c = shift;
  my $path = path (__FILE__)->parent->parent->child ('.gitignore');
  my $expected = $path->slurp;

  my $fh = $path->openr;

  my ($rs, $ws, $closed) = Streams::Filehandle::fh_to_streams ($fh, 1, 0);
  isa_ok $rs, 'ReadableStream';
  is $ws, undef;
  isa_ok $closed, 'Promise';

  my $r = $rs->get_reader ('byob');

  my @result;
  my $try; $try = sub {
    return $r->read (DataView->new (ArrayBuffer->new_from_scalarref (\("x" x 10))))->then (sub {
      my $v = $_[0];
      return if $v->{done};
      push @result, $v->{value};
      return $try->();
    });
  };

  return promised_cleanup {
    undef $try;
    done $c;
    undef $c;
  } $try->()->then (sub {
    return $closed;
  })->then (sub {
    my $got = join '', map {
      $_->manakai_to_string;
    } @result;
    test {
      is $got, $expected;
    } $c;
  });
} n => 4, name => 'read internal';

test {
  my $c = shift;
  my $path = path (__FILE__)->parent->parent->child ('Makefile');
  my $expected = $path->slurp;

  my $fh = $path->openr;

  my $rs = Streams::Filehandle->create_readable ($fh);
  isa_ok $rs, 'ReadableStream';

  my $r = $rs->get_reader ('byob');

  my @result;
  my $try; $try = sub {
    return $r->read (DataView->new (ArrayBuffer->new_from_scalarref (\("x" x 10))))->then (sub {
      my $v = $_[0];
      return if $v->{done};
      push @result, $v->{value};
      return $try->();
    });
  };

  return promised_cleanup {
    undef $try;
    done $c;
    undef $c;
  } $try->()->then (sub {
    my $got = join '', map {
      $_->manakai_to_string;
    } @result;
    test {
      is $got, $expected;
    } $c;
  });
} n => 2, name => 'create_readable';

test {
  my $c = shift;
  my $temp = File::Temp->newdir;
  my $path = path ($temp->dirname)->child ('file');

  my $expected = [];
  push @$expected, rand for 1..100;

  my $fh = $path->openw;

  my ($rs, $ws, $closed) = Streams::Filehandle::fh_to_streams ($fh, 0, 1);
  is $rs, undef;
  isa_ok $ws, 'WritableStream';
  isa_ok $closed, 'Promise';

  my $w = $ws->get_writer;
  $w->write (DataView->new (ArrayBuffer->new_from_scalarref (\$_)))
      for @$expected;
  $w->close;

  return $closed->then (sub {
    my $written = $path->slurp;
    test {
      is $written, join '', @$expected;
    } $c;
    done $c;
    undef $c;
    undef $temp;
  });
} n => 4, name => 'write internal';

test {
  my $c = shift;
  my $temp = File::Temp->newdir;
  my $path = path ($temp->dirname)->child ('file');

  my $expected = [];
  push @$expected, rand for 1..100;

  my $fh = $path->openw;

  my $ws = Streams::Filehandle->create_writable ($fh);
  isa_ok $ws, 'WritableStream';

  my $w = $ws->get_writer;
  $w->write (DataView->new (ArrayBuffer->new_from_scalarref (\$_)))
      for @$expected;
  $w->close;

  return $w->closed->then (sub {
    my $written = $path->slurp;
    test {
      is $written, join '', @$expected;
    } $c;
    done $c;
    undef $c;
    undef $temp;
  });
} n => 2, name => 'create_writable';

run_tests;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
