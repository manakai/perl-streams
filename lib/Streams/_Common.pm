package Streams::_Common;
use strict;
use warnings;
use Carp;

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
sub _type_error ($) { $Streams::CreateTypeError->(undef, $_[0]) }
sub _range_error ($) { $Streams::CreateRangeError->(undef, $_[0]) }
push @EXPORT, qw(_type_error _range_error);

## ToIndex for Perl
sub _to_index ($$) {
  my $index = int $_[0];
  die _range_error "$_[1] $index is negative" if $index < 0;
  return $index;
} # to_index
push @EXPORT, qw(_to_index);

1;
