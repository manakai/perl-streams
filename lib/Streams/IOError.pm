package Streams::IOError;
use strict;
use warnings;
use Streams::Error;
push our @ISA, qw(Streams::Error);
our $VERSION = '2.0';

$Web::DOM::Error::L1ObjectClass->{(__PACKAGE__)} = 1;

sub new ($$) {
  my $self = bless {
    name => 'Perl I/O error',
    error => 0+$_[1],
    message => ''.$_[1],
  }, $_[0];
  $self->_set_stacktrace;
  return $self;
} # new

sub new_from_errno_and_message ($$$) {
  my $self = bless {
    name => 'Perl I/O error',
    error => 0+$_[1],
    message => ''.$_[2],
  }, $_[0];
  $self->_set_stacktrace;
  return $self;
} # new_from_errno_and_message

sub errno ($) {
  return $_[0]->{error};
} # errno

1;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
