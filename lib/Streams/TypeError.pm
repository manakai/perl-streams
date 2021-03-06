package Streams::TypeError;
use strict;
use warnings;
use Streams::Error;
push our @ISA, qw(Streams::Error);
our $VERSION = '2.0';

$Web::DOM::Error::L1ObjectClass->{(__PACKAGE__)} = 1;

sub new ($$) {
  my $self = bless {name => 'TypeError',
                    message => defined $_[1] ? ''.$_[1] : ''}, $_[0];
  $self->_set_stacktrace;
  return $self;
} # new

1;

=head1 LICENSE

Copyright 2012-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
