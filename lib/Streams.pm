package Streams;
use strict;
use warnings;
our $VERSION = '1.0';
use Streams::_Common;
use ReadableStream;
use WritableStream;

sub ByteLengthQueuingStrategy ($) {
  return {high_water_mark => $_[0]->{high_water_mark}, size => sub {
     die _type_error "The chunk does not have byte_length method"
         unless UNIVERSAL::can ($_[0], 'byte_length'); # not in JS
     return $_[0]->byte_length; # or throw
  }};
} # ByteLengthQueuingStrategy

sub CountQueuingStrategy ($) {
  return {high_water_mark => $_[0]->{high_water_mark}, size => sub { 1 }};
} # CountQueuingStrategy

1;
