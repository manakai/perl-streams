package Streams::_Common;
use strict;
use warnings;
use Carp;
use Streams::IOError;
push our @CARP_NOT, qw(Streams::IOError);

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

$Streams::CreateTypeError ||= sub ($$) {
  return "TypeError: " . $_[1] . Carp::shortmess ();
};
$Streams::CreateRangeError ||= sub ($$) {
  return "RangeError: " . $_[1] . Carp::shortmess ();
};
$Streams::CreateIOError ||= sub ($$) {
  return Streams::IOError->new ($_[1]);
};
sub _type_error ($) { $Streams::CreateTypeError->(undef, $_[0]) }
sub _range_error ($) { $Streams::CreateRangeError->(undef, $_[0]) }
sub _io_error ($) { $Streams::CreateIOError->(undef, $_[0]) }
push @EXPORT, qw(_type_error _range_error _io_error);

## c.f. <http://search.cpan.org/~rjbs/perl-5.20.0/pod/perldelta.pod#Better_64-bit_support>
my $MaxIndex = defined [0]->[2**32] ? 2**53-1 : 2**32-1;

## ToIndex for Perl
sub _to_index ($$) {
  my $index = int $_[0];
  die _range_error "$_[1] $index is negative" if $index < 0;
  die _range_error "$_[1] $index is too large" if $index > $MaxIndex;
  return 0 if $index eq 'nan' or $index eq 'NaN';
  return $index;
} # to_index
push @EXPORT, qw(_to_index);

sub _to_size ($$) {
  ## ToNumber
  my $size = 0+$_[0];

  ## IsFiniteNonNegativeNumber
  die _range_error "$_[1] $size is negative" if $size < 0;
  die _range_error "$_[1] $size is too large" if $size eq 'Inf' or $size eq 'inf';

  ## This is different from JS's IsFiniteNonNegativeNumber, to match
  ## with Perl's convention.
  return 0 if $size eq 'NaN' or $size eq 'nan';

  return $size;
} # _to_size
push @EXPORT, qw(_to_size);

sub _promise_capability () {
  my ($resolve, $reject);
  my $promise = Promise->new (sub { ($resolve, $reject) = @_ });
  return {promise => $promise, resolve => $resolve, reject => $reject};
} # _promise_capability
push @EXPORT, qw(_promise_capability);

# requires Promise
sub _hashref_method_throws ($$$) {
  ## InvokeOrNoop whose non-abrupt result is wrapped with a Promise
  my $code = $_[0]->{$_[1]};
  return Promise->resolve (undef) unless defined $code;
  die _type_error "The |$_[1]| member is not a CODE" unless ref $code eq 'CODE';
  my $result = $code->($_[0], @{$_[2]}); # or throws
  return Promise->resolve ($result);
} # _hashref_method_throws
push @EXPORT, qw(_hashref_method_throws);

# requires Promise
sub _hashref_method ($$$) {
  ## PromiseInvokeOrNoop
  my $code = $_[0]->{$_[1]};
  return Promise->resolve (undef) unless defined $code;
  return Promise->reject (_type_error "The |$_[1]| member is not a CODE")
      unless ref $code eq 'CODE';
  my $args = [$_[0], @{$_[2]}];
  return Promise->new (sub { $_[0]->(scalar $code->(@$args)) });
} # _hashref_method
push @EXPORT, qw(_hashref_method);

1;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
