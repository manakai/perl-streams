use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use ReadableStream;

test {
  my $c = shift;
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3));
  my $req = ReadableStreamBYOBRequest->new (undef, $view);
  is $req->view, $view;
  done $c;
} n => 1, name => 'view';

test {
  my $c = shift;
  my $view = DataView->new (ArrayBuffer->new (3));
  my $req = ReadableStreamBYOBRequest->new (undef, $view);
  is $req->view, $view;
  done $c;
} n => 1, name => 'view';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $rc = $_[1];
      test {
        my $req1 = $rc->byob_request;
        my $view1 = $req1->view;
        isa_ok $view1, 'TypedArray::Uint8Array';
        my $req2 = $rc->byob_request;
        my $view2 = $req2->view;
        isa_ok $view2, 'TypedArray::Uint8Array';
        is $view2, $view1;
      } $c;
    },
  });
  my $view = DataView->new (ArrayBuffer->new (2));
  $rs->get_reader ('byob')->read ($view);
  Promise->resolve->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'byob_request same view objects';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $rc = $_[1];
      test {
        my $req1 = $rc->byob_request;
        my $view1 = $req1->view;
        isa_ok $view1, 'TypedArray::Uint8Array';
        undef $req1;
        my $req2 = $rc->byob_request;
        my $view2 = $req2->view;
        isa_ok $view2, 'TypedArray::Uint8Array';
        is $view2, $view1;
      } $c;
    },
  });
  my $view = DataView->new (ArrayBuffer->new (2));
  $rs->get_reader ('byob')->read ($view);
  Promise->resolve->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'byob_request same view objects 2';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      test {
        is $req->respond (3), undef;
      } $c;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
  $r->read ($view)->then (sub {
    my $v = $_[0]->{value};
    test {
      isnt $v, $view;
      eval { $view->buffer->byte_length }; ok $@;
      is $v->byte_offset, 0;
      is $v->byte_length, 3;
      is ${$v->buffer->manakai_transfer_to_scalarref}, "\x00\x00\x00\x00\x00";
    } $c;
    done $c;
    undef $c;
  });
} n => 6, name => 'respond';

test {
  my $c = shift;
  my $req;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      $req = $_[1]->byob_request;
      $req->respond (2);
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
  $r->read ($view)->then (sub {
    return $req->respond (4);
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: There is no controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'respond after invalidate';

test {
  my $c = shift;
  my $after_throw;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      $req->respond (6);
      $after_throw = 1;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
  $r->read ($view)->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^RangeError: Byte length 6 is greater than requested length 5 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-9]}\E};
      ok ! $after_throw;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'respond large';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      $rc = $_[1];
    },
  });
  my $r = $rs->get_reader ('byob');
  $rc->close;
  $r->closed->then (sub {
    my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
    my $req = ReadableStreamBYOBRequest->new ($rc, $view);
    return $req->respond (4);
  })->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^TypeError: ReadableStream is closed at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'respond close respond';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      open my $fh, '<', __FILE__;
      test {
        is $req->manakai_respond_by_sysread ($fh), 5;
      } $c;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
  $r->read ($view)->then (sub {
    my $v = $_[0]->{value};
    test {
      isnt $v, $view;
      eval { $view->buffer->byte_length }; ok $@;
      is $v->byte_offset, 0;
      is $v->byte_length, 5;
      is ${$v->buffer->manakai_transfer_to_scalarref}, "use s";
    } $c;
    done $c;
    undef $c;
  });
} n => 6, name => 'manakai_respond_by_sysread';

test {
  my $c = shift;
  my $req = ReadableStreamBYOBRequest->new (undef, undef);
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3));
  eval {
    $req->respond (4);
  };
  like $@, qr{^TypeError: There is no controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'respond no controller';

test {
  my $c = shift;
  my $req = ReadableStreamBYOBRequest->new (undef, undef);
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3));
  open my $fh, '<', __FILE__;
  eval {
    $req->manakai_respond_by_sysread (4, $fh);
  };
  like $@, qr{^TypeError: There is no controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'manakai_respond_by_sysread no controller';

test {
  my $c = shift;
  my $req = ReadableStreamBYOBRequest->new (undef, undef);
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3));
  eval {
    $req->respond_with_new_view ($view);
  };
  like $@, qr{^TypeError: There is no controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'respond_with_new_view no controller';

test {
  my $c = shift;
  my $req = ReadableStreamBYOBRequest->new (undef, undef);
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3));
  eval {
    $req->manakai_respond_with_new_view ($view);
  };
  like $@, qr{^TypeError: There is no controller at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
  done $c;
} n => 1, name => 'manakai_respond_with_new_view no controller';

for my $value (
  undef, 0, 13, "", "abc", [], {}, (bless {}, 'test::foo'),
) {
  test {
    my $c = shift;
    my $rc;
    my $rs = ReadableStream->new ({type => 'bytes', start => sub {$rc=$_[1]}});
    my $req = ReadableStreamBYOBRequest->new ($rc, undef);
    eval {
      $req->respond_with_new_view ($value);
    };
    like $@, qr{^TypeError: The argument is not an ArrayBufferView at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    undef $rc;
    done $c;
  } n => 1, name => 'respond_with_new_view not view';

  test {
    my $c = shift;
    my $rc;
    my $rs = ReadableStream->new ({type => 'bytes', start => sub {$rc=$_[1]}});
    my $req = ReadableStreamBYOBRequest->new ($rc, undef);
    eval {
      $req->manakai_respond_with_new_view ($value);
    };
    like $@, qr{^TypeError: The argument is not an ArrayBufferView at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    undef $rc;
    done $c;
  } n => 1, name => 'manakai_respond_with_new_view not view';
}

test {
  my $c = shift;
  my $after_throw;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3), 2);
      $req->respond_with_new_view ($view);
      $after_throw = 1;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3));
  $r->read ($view)->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^RangeError: Bad byte offset 2 != 0 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-9]}\E};
      ok ! $after_throw;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'respond_with_new_view no controller';

test {
  my $c = shift;
  my $after_throw;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      my $view = DataView->new (ArrayBuffer->new (3), 2);
      $req->manakai_respond_with_new_view ($view);
      $after_throw = 1;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = DataView->new (ArrayBuffer->new (3));
  $r->read ($view)->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^RangeError: Bad byte offset 2 != 0 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-9]}\E};
      ok ! $after_throw;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'manakai_respond_with_new_view bad offset';

test {
  my $c = shift;
  my $after_throw;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
      $req->respond_with_new_view ($view);
      $after_throw = 1;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (3));
  $r->read ($view)->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^RangeError: Bad byte length 5 != 3 at \Q@{[__FILE__]}\E line \Q@{[__LINE__-9]}\E};
      ok ! $after_throw;
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'respond_with_new_view bad length';

test {
  my $c = shift;
  my $v2;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      $v2 = TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"abcde"));
      test {
        is $req->respond_with_new_view ($v2), undef;
      } $c;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
  $r->read ($view)->then (sub {
    my $v = $_[0]->{value};
    test {
      isnt $v, $view;
      isnt $v, $v2;
      eval { $view->buffer->byte_length }; ok $@;
      eval { $v2->buffer->byte_length }; ok $@;
      is $v->byte_offset, 0;
      is $v->byte_length, 5;
      is ${$v->buffer->manakai_transfer_to_scalarref}, "abcde";
    } $c;
    done $c;
    undef $c;
  });
} n => 8, name => 'respond_with_new_view';

test {
  my $c = shift;
  my $v2;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      $v2 = TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"abcde"));
      test {
        is $req->manakai_respond_with_new_view ($v2), undef;
      } $c;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
  $r->read ($view)->then (sub {
    my $v = $_[0]->{value};
    test {
      isnt $v, $view;
      isnt $v, $v2;
      eval { $view->buffer->byte_length }; ok $@;
      eval { $v2->buffer->byte_length }; ok $@;
      is $v->byte_offset, 0;
      is $v->byte_length, 5;
      is ${$v->buffer->manakai_transfer_to_scalarref}, "abcde";
    } $c;
    done $c;
    undef $c;
  });
} n => 8, name => 'manakai_respond_with_new_view';

test {
  my $c = shift;
  my $v2;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      $v2 = TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"abcd"));
      test {
        is $req->manakai_respond_with_new_view ($v2), undef;
      } $c;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $view = TypedArray::Uint8Array->new (ArrayBuffer->new (5));
  $r->read ($view)->then (sub {
    my $v = $_[0]->{value};
    test {
      isnt $v, $view;
      isnt $v, $v2;
      eval { $view->buffer->byte_length }; ok $@;
      eval { $v2->buffer->byte_length }; ok $@;
      is $v->byte_offset, 0;
      is $v->byte_length, 4;
      is ${$v->buffer->manakai_transfer_to_scalarref}, "abcd";
    } $c;
    done $c;
    undef $c;
  });
} n => 8, name => 'manakai_respond_with_new_view short';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
