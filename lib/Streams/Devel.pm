package Streams::Devel;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Streams::_Common;

our @EXPORT;

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  no warnings 'once';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
  push @{$to_class.'::CARP_NOT'}, $from_class;
} # import

push @EXPORT, qw(note_buffer_copy);
*note_buffer_copy = \&_note_buffer_copy;

1;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
