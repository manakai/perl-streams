package Streams::IOError;
use strict;
use warnings;
our $VERSION = '1.0';
use overload '""' => 'stringify', fallback => 1;
use Carp;

sub new ($$) {
  my $self = bless {
    error => 0+$_[1],
    message => ''.$_[1],
    location => Carp::shortmess,
  }, $_[0];
  return $self;
} # new

sub errno ($) {
  return $_[0]->{error};
} # errno

sub message ($) {
  return $_[0]->{message};
} # message

sub stringify ($) {
  return "Perl I/O error: " . $_[0]->{message} . $_[0]->{location};
} # stringify

1;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
