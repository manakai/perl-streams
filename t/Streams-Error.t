use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Streams::Error;

test {
  my $c = shift;
  ok $Web::DOM::Error::L1ObjectClass->{'Streams::Error'};
  done $c;
} n => 1, name => 'Perl Error Object Interface Level 1';

test {
  my $c = shift;
  my $e = Streams::Error->new;
  my $f = Streams::Error->wrap ($e);
  is $f, $e;
  isa_ok $f, 'Streams::Error';
  done $c;
} n => 2, name => 'is_error true';

test {
  my $c = shift;
  my $e = bless {}, 'test::customexception1';
  local $Web::DOM::Error::L1ObjectClass->{'test::customexception1'} = 1;
  my $f = Streams::Error->wrap ($e);
  is $f, $e;
  isa_ok $f, 'test::customexception1';
  done $c;
} n => 2, name => 'is_error true custom class';

for my $value (
  undef, '',
) {
  test {
    my $c = shift;
    my $e = Streams::Error->wrap ($value);
    isa_ok $e, 'Streams::Error';
    is $e->name, 'Error';
    is $e->message, "Something's wrong";
    is $e->file_name, __FILE__;
    is $e->line_number, __LINE__-5;
    is $e . '', "Error: ".$e->message." at ".$e->file_name." line ".$e->line_number.".\n";
    done $c;
  } n => 6, name => 'is_error false';
}

for my $value (
  'aava', 0, 532, -3141, 44.4, 0+'nan',
  [], {}, \"abc", (bless {}, 'test::foo'),
) {
  test {
    my $c = shift;
    my $e = Streams::Error->wrap ($value);
    isa_ok $e, 'Streams::Error';
    is $e->name, 'Error';
    is $e->message, $value . '';
    ok ! ref $e->message;
    is $e->file_name, __FILE__;
    is $e->line_number, __LINE__-6;
    is $e . '', "Error: ".$e->message." at ".$e->file_name." line ".$e->line_number.".\n";
    done $c;
  } n => 7, name => 'is_error false';
}

sub create_error (;%) {
  return bless {@_}, 'Streams::Error';
} # create_error

test {
  my $c = shift;
  my $error = Streams::Error->new ('Error message');
  $error->{file_name} = 'path/to file';
  $error->{line_number} = 120;
  is $error->name, 'Error';
  is $error->message, 'Error message';
  is $error->file_name, 'path/to file';
  is $error->line_number, 120;
  is $error . '', "Error: Error message at path/to file line 120.\n";
  is $error->stringify, $error . '';
  done $c;
} name => 'with message', n => 6;

test {
  my $c = shift;
  my $error = Streams::Error->new ('Error message');
  isa_ok $error, 'Streams::Error';
  is $error->name, 'Error';
  is $error->message, 'Error message';
  is $error->file_name, __FILE__;
  is $error->line_number, __LINE__-5;
  is $error . '', "Error: Error message at ".$error->file_name." line ".$error->line_number.".\n";
  is $error->stringify, $error . '';
  done $c;
} name => 'new with message', n => 7;

test {
  my $c = shift;
  my $error = Streams::Error->new ('');
  isa_ok $error, 'Streams::Error';
  is $error->name, 'Error';
  is $error->message, '';
  is $error->file_name, __FILE__;
  is $error->line_number, __LINE__-5;
  is $error . '', "Error at ".$error->file_name." line ".$error->line_number.".\n";
  done $c;
} name => 'new with empty message', n => 6;

test {
  my $c = shift;
  my $error = Streams::Error->new;
  isa_ok $error, 'Streams::Error';
  is $error->name, 'Error';
  is $error->message, '';
  is $error->file_name, __FILE__;
  is $error->line_number, __LINE__-5;
  is $error . '', "Error at ".$error->file_name." line ".$error->line_number.".\n";
  done $c;
} name => 'new without message', n => 6;

test {
  my $c = shift;
  my $error1 = Streams::Error->new;
  my $error2 = Streams::Error->new;

  ok $error1 eq $error1;
  ok not $error1 ne $error1;
  ok not $error2 eq $error1;
  ok $error2 ne $error1;
  ok $error1 ne undef;
  ok not $error1 eq undef;
  is $error1 cmp $error1, 0;
  isnt $error1 cmp $error2, 0;
  isnt $error1 . '', $error1;

  # XXX test unitinialized warning by eq/ne/cmp-ing with undef
  
  done $c;
} name => 'eq', n => 9;

run_tests;

=head1 LICENSE

Copyright 2012-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
