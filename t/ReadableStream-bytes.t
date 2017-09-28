use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use ReadableStream;
use Promise;
use Promised::Flow;
use ArrayBuffer;
use TypedArray;

test {
  my $c = shift;
  my $r1;
  my $r2;
  my $i = 0;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      $rc = $_[1];
      $r1 = rand;
      $r2 = rand;
    },
    pull => sub {
      $i++;
      return $rc->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\$r1))) if $i == 1;
      return Promise->resolve->then (sub { $rc->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\$r2))) }) if $i == 2;
      die "Bad pull ($i)";
    },
  });
  my $reader = $rs->get_reader ('byob');
  isa_ok $reader, 'ReadableStreamBYOBReader';
  my @read;
  $reader->read (TypedArray::Uint8Array->new (100))->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      is 0+@read, 2;
      is ${$read[0]->buffer->manakai_transfer_to_scalarref}, $r1 . ("\x00" x (100-length$r1));
      is ${$read[1]->buffer->manakai_transfer_to_scalarref}, $r2 . ("\x00" x (100-length$r2));
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-22]}\E};
    } $c;
    return $reader->closed;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-32]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 6;

test {
  my $c = shift;
  my $i = 0;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      $rc = $_[1];
    },
    pull => sub {
      $i++;
      if ($i == 1) {
        return $rc->byob_request->respond (8);
      }
      if ($i == 2) {
        return Promise->resolve->then (sub {
          return $rc->byob_request->respond (61);
        });
      }
      die "Bad pull ($i)";
    },
  });
  my $reader = $rs->get_reader ('byob');
  isa_ok $reader, 'ReadableStreamBYOBReader';
  my @read;
  $reader->read (TypedArray::Uint8Array->new (100))->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      is 0+@read, 2;
      is $read[0]->byte_length, 8;
      is $read[1]->byte_length, 61;
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-22]}\E};
    } $c;
    return $reader->closed;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-32]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 6;

test {
  my $c = shift;
  my $i = 0;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      $rc = $_[1];
    },
    pull => sub {
      $i++;
      if ($i == 1) {
        return $rc->byob_request->respond (8);
      }
      if ($i == 2) {
        $rc->byob_request->respond (0);
        $rc->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new (3)));
        return;
      }
      die "Bad pull ($i)";
    },
  });
  my $reader = $rs->get_reader ('byob');
  isa_ok $reader, 'ReadableStreamBYOBReader';
  my @read;
  $reader->read (TypedArray::Uint8Array->new (100))->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      is 0+@read, 2;
      is $read[0]->byte_length, 8;
      is $read[1]->byte_length, 3;
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-22]}\E};
    } $c;
    return $reader->closed;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      like $err, qr{^Bad pull \(3\) at \Q@{[__FILE__]}\E line \Q@{[__LINE__-32]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 6, name => 'zero';

test {
  my $c = shift;
  my $i = 0;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      $rc = $_[1];
    },
    pull => sub {
      $i++;
      if ($i == 1) {
        return $rc->byob_request->respond (8.2);
      }
      if ($i == 2) {
        return Promise->resolve->then (sub {
          return $rc->byob_request->respond (61.9);
        });
      }
      return $rc->byob_request->respond (-2);
    },
  });
  my $reader = $rs->get_reader ('byob');
  isa_ok $reader, 'ReadableStreamBYOBReader';
  my @read;
  $reader->read (TypedArray::Uint8Array->new (100))->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    push @read, $_[0]->{value};
    return $reader->read (TypedArray::Uint8Array->new (100));
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      is 0+@read, 2;
      is $read[0]->byte_length, 8;
      is $read[1]->byte_length, 61;
      like $err, qr{^RangeError: Byte length -2 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-22]}\E};
    } $c;
    return $reader->closed;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      like $err, qr{^RangeError: Byte length -2 is negative at \Q@{[__FILE__]}\E line \Q@{[__LINE__-32]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 6, name => 'float and negative respond';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      $rc = $_[1];
    },
    pull => sub {
      $rc->byob_request->respond (0+'nan');
      $rc->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new (3)));
    },
  });
  my $reader = $rs->get_reader ('byob');
  isa_ok $reader, 'ReadableStreamBYOBReader';
  $reader->read (TypedArray::Uint8Array->new (100))->then (sub {
    test {
      ok 1;
    } $c;
  })->then (sub {
    undef $rc; # referencing $rs referencing start referencing $rc
    done $c;
    undef $c;
  });
} n => 2, name => 'respond nan';

test {
  my $c = shift;
  my $rc;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      $rc = $_[1];
    },
    pull => sub {
      return $rc->byob_request->respond (0+'Inf');
    },
  });
  my $reader = $rs->get_reader ('byob');
  isa_ok $reader, 'ReadableStreamBYOBReader';
  $reader->read (TypedArray::Uint8Array->new (100))->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      like $err, qr{^RangeError: Byte length .+ is too large at \Q@{[__FILE__]}\E line \Q@{[__LINE__-12]}\E};
    } $c;
    return $reader->closed;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $err = $_[0];
    test {
      like $err, qr{^RangeError: Byte length .+ is too large at \Q@{[__FILE__]}\E line \Q@{[__LINE__-22]}\E};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'respond Inf';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      type => 'bytes',
      start => sub {
        die "Bad start";
      },
    });
  };
  like $@, qr{^Bad start at \Q@{[__FILE__]}\E line \Q@{[__LINE__-4]}\E};
  done $c;
} n => 1, name => 'start throw';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      return Promise->resolve->then (sub {
        die "Bad start";
      });
    },
  });
  isa_ok $rs, 'ReadableStream';
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  $r->read->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^Bad start at \Q@{[__FILE__]}\E line \Q@{[__LINE__-10]}\E};
    } $c;
    done $c;
    undef $c;
  });
} n => 3, name => 'start rejects';

test {
  my $c = shift;
  my $resolved = 0;
  my $read;
  my $rs = ReadableStream->new ({
    start => sub {
      return Promise->resolve->then (sub {
        $resolved = 1;
      });
    },
    pull => sub {
      $read = $resolved;
      $_[1]->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"x")));
    },
    type => 'bytes',
  });
  isa_ok $rs, 'ReadableStream';
  is $resolved, 0, 'Not resolved yet';
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  $r->read->then (sub {
    test {
      is $resolved, 1;
      is $read, 1, '$resolved is 1 when write is invoked';
    } $c;
    done $c;
    undef $c;
  });
} n => 5, name => 'start resolves';

test {
  my $c = shift;
  my $resolved = 0;
  my $read;
  my $start_args;
  my $source = {
    start => sub {
      $start_args = [@_];
      $resolved = 1;
      test {
        ok defined wantarray;
        ok ! wantarray;
      } $c;
    },
    pull => sub {
      $read = $resolved;
      $_[1]->enqueue (TypedArray::Uint8Array->new (ArrayBuffer->new_from_scalarref (\"x")));
    },
    type => 'bytes',
  };
  my $rs = ReadableStream->new ($source);
  isa_ok $rs, 'ReadableStream';
  is $resolved, 1;
  is $start_args->[0], $source;
  my $r = $rs->get_reader;
  isa_ok $r, 'ReadableStreamDefaultReader';
  $r->read->then (sub {
    test {
      is $resolved, 1;
      is $read, 1, '$resolved is 1 when write is invoked';
    } $c;
    undef $start_args; # [0] - $source->{start} - $start_args / [1] $rc
    done $c;
    undef $c;
  });
} n => 8, name => 'start returns';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      start => "hoe",
      type => 'bytes',
    });
  };
  like $@, qr{^\QTypeError: The |start| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'start is not CODE';

test {
  my $c = shift;
  eval {
    ReadableStream->new ({
      start => "",
      type => 'bytes',
    });
  };
  like $@, qr{^\QTypeError: The |start| member is not a CODE\E at \Q@{[__FILE__]}\E line \Q@{[__LINE__-5]}\E};
  done $c;
} n => 1, name => 'start is not CODE';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $rc = $_[1];
      test {
        my $req1 = $rc->byob_request;
        isa_ok $req1, 'ReadableStreamBYOBRequest';
        my $req2 = $rc->byob_request;
        isa_ok $req2, 'ReadableStreamBYOBRequest';
        is $req2, $req1;
      } $c;
    },
  });
  my $view = DataView->new (ArrayBuffer->new (2));
  $rs->get_reader ('byob')->read ($view);
  Promise->resolve->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'byob_request same objects';

test {
  my $c = shift;
  my @req;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $rc = $_[1];
      push @req, $rc->byob_request;
      $req[-1]->respond (2);
    },
  });
  my $r = $rs->get_reader ('byob');
  $r->read (DataView->new (ArrayBuffer->new (2)))->then (sub {
    return $r->read (DataView->new (ArrayBuffer->new (2)));
  })->then (sub {
    test {
      is 0+@req, 2;
      isnt $req[0], $req[1];
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'byob_request different objects';

{
  package test::DestroyCallback1;
  sub DESTROY {
    $_[0]->();
  }
}

test {
  my $c = shift;
  my $destroyed;
  {
    my $rs = ReadableStream->new ({
      type => 'bytes',
    });
    $rs->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
  }
  Promise->resolve->then (sub {
    return promised_wait_until { $destroyed } timeout => 10;
  })->then (sub {
    test {
      ok $destroyed;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'destroy';

test {
  my $c = shift;
  my $p;
  my $destroyed;
  {
    my $rc;
    my @read = map { DataView->new (ArrayBuffer->new_from_scalarref (\$_)) } ("abc", "def");
    my $rs = ReadableStream->new ({
      type => 'bytes',
      start => sub { $rc = $_[1] },
      pull => sub { $_[1]->enqueue (shift @read || (return $_[1]->close)) },
    });
    $rs->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
    my $r = $rs->get_reader ('byob');
    $p = $r->read (DataView->new (ArrayBuffer->new (3)));
    Promise->resolve->then (sub {
      undef $rc; # need explicit freeing!
    });
  }
  Promise->resolve ($p)->then (sub {
    return promised_wait_until { $destroyed } timeout => 10;
  })->then (sub {
    test {
      ok $destroyed;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'destroy';

test {
  my $c = shift;
  my $p;
  my $destroyed;
  {
    my $rc;
    my @read = map { DataView->new (ArrayBuffer->new_from_scalarref (\$_)) } ("abc", "def");
    my $rs = ReadableStream->new ({
      type => 'bytes',
      start => sub { $rc = $_[1] },
      pull => sub { $_[1]->enqueue (shift @read || (return $_[1]->close)) },
    });
    $rs->{_destroy} = bless sub { $destroyed = 1 }, 'test::DestroyCallback1';
    my $r = $rs->get_reader ('byob');
    $r->read (DataView->new (ArrayBuffer->new (3)));
    $rc->close;
    $p = $r->closed;
  }
  Promise->resolve ($p)->then (sub {
    test {
      ok $destroyed;
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'destroy';

test {
  my $c = shift;
  my @read = map { DataView->new (ArrayBuffer->new_from_scalarref (\$_)) } ("abc", "def");
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub { $_[1]->enqueue (shift @read || (return $_[1]->close)) },
  });
  my $r = $rs->get_reader ('byob');
  undef $rs;
  my $result = '';
  $r->read (DataView->new (ArrayBuffer->new (3)))->then (sub {
    $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref};
  })->then (sub {
    return $r->read (DataView->new (ArrayBuffer->new (3)));
  })->then (sub {
    $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref};
  })->then (sub {
    return $r->read (DataView->new (ArrayBuffer->new (3)));
  });
  $r->closed->then (sub {
    test {
      is $result, "abcdef";
    } $c;
  }, sub {
    test { ok 0 } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'ReadableStream reference discarded before read 1';

test {
  my $c = shift;
  my @read = map { DataView->new (ArrayBuffer->new_from_scalarref (\$_)) } ("abc", "def");
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      $_[1]->enqueue ($_) for @read;
      return $_[1]->close;
    },
  });
  my $r = $rs->get_reader ('byob');
  undef $rs;
  my $result = '';
  $r->read (DataView->new (ArrayBuffer->new (3)))->then (sub {
    $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref};
  })->then (sub {
    return $r->read (DataView->new (ArrayBuffer->new (3)));
  })->then (sub {
    $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref};
  })->then (sub {
    return $r->read (DataView->new (ArrayBuffer->new (3)));
  })->then (sub {
    $result .= $_[0]->{done} ? 1 : 0;
    return $r->closed;
  })->then (sub {
    test {
      is $result, "abcdef1";
    } $c;
  }, sub {
    test { ok 0 } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'ReadableStream reference discarded before read 2';

test {
  my $c = shift;
  my @read = map { DataView->new (ArrayBuffer->new_from_scalarref (\$_)) } ("abc", "def");
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      $_[1]->enqueue ($_) for @read;
      return $_[1]->close;
    },
  });
  my $r = $rs->get_reader ('byob');
  undef $rs;
  my $result = '';
  $r->read (DataView->new (ArrayBuffer->new (3)))->then (sub { $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref} });
  $r->read (DataView->new (ArrayBuffer->new (3)))->then (sub { $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref} });
  $r->closed->then (sub {
    test {
      is $result, "abcdef";
    } $c;
  }, sub {
    test { ok 0 } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'ReadableStream reference discarded before read';

test {
  my $c = shift;
  my @read = map { DataView->new (ArrayBuffer->new_from_scalarref (\$_)) } ("abc", "def");
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      $_[1]->enqueue ($_) for @read;
      return $_[1]->close;
    },
  });
  my $r = $rs->get_reader;
  my $result = '';
  $r->read->then (sub { $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref} });
  $r->read->then (sub { $result .= ${$_[0]->{value}->buffer->manakai_transfer_to_scalarref} });
  $r->closed->then (sub {
    test {
      is $result, "abcdef";
    } $c;
  }, sub {
    test { ok 0 } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'ReadableStream default reader + binary stream';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      open my $fh, '<', \"";
      $_[1]->byob_request->manakai_respond_by_sysread ($fh, 13);
    },
  });
  my $r = $rs->get_reader ('byob');
  $r->read (DataView->new (ArrayBuffer->new (4)))->catch (sub {
    my $e = $_[0];
    test {
      like $e, qr{^Perl I/O error: .+ at \Q@{[__FILE__]}\E line \Q@{[__LINE__-7]}\E};
      isa_ok $e, 'Streams::IOError';
      ok $e->errno;
      ok $e->message;
    } $c;
    done $c;
    undef $c;
  });
} n => 4, name => 'manakai_respond_by_sysread fh error';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      my $rc = $_[1];
      $rc->close;
    },
  });
  my $r = $rs->get_reader;
  my $result = '';
  return Promise->resolve->then (sub {
    return promised_run_until {
      return $r->read->then (sub {
        my $v = $_[0];
        return 0 if $v->{done};
        $result .= $v->{value}->manakai_to_string;
        return 1;
      });
    };
  })->then (sub {
    test {
      is $result, "";
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'read after closed';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      my $rc = $_[1];
      $rc->close;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $result = '';
  return Promise->resolve->then (sub {
    return promised_run_until {
      return $r->read (DataView->new (ArrayBuffer->new (3)))->then (sub {
        my $v = $_[0];
        return 0 if $v->{done};
        $result .= $v->{value}->manakai_to_string;
        return 1;
      });
    };
  })->then (sub {
    test {
      is $result, "";
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'read after closed';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    start => sub {
      my $rc = $_[1];
      $rc->enqueue (DataView->new (ArrayBuffer->new_from_scalarref (\"abc")));
      $rc->close;
    },
  });
  my $r = $rs->get_reader ('byob');
  my $result = '';
  return Promise->resolve->then (sub {
    return promised_run_until {
      return $r->read (DataView->new (ArrayBuffer->new (3)))->then (sub {
        my $v = $_[0];
        return 0 if $v->{done};
        $result .= $v->{value}->manakai_to_string;
        return 1;
      });
    };
  })->then (sub {
    test {
      is $result, "abc";
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'read after closed';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
  });
  my $reader = $rs->get_reader ('byob');
  my $v = DataView->new (ArrayBuffer->new (4));
  $v->buffer->_transfer; # detach
  return $reader->read ($v)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $error = $_[0];
    test {
      like $error, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line @{[__LINE__+5]}.};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'read view detached';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
  });
  my $reader = $rs->get_reader ('byob');
  my $v = DataView->new (ArrayBuffer->new (0));
  return $reader->read ($v)->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $error = $_[0];
    test {
      like $error, qr{^TypeError: The ArrayBufferView is empty at \Q@{[__FILE__]}\E line @{[__LINE__+5]}.};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'read view empty';

test {
  my $c = shift;
  Promise->resolve->then (sub {
    my $rs = ReadableStream->new ({
      type => 'bytes',
      start => sub {
        my $v = DataView->new (ArrayBuffer->new (4));
        $v->buffer->_transfer; # detach
        $_[1]->enqueue ($v);
      },
    });
  })->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $error = $_[0];
    test {
      like $error, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line @{[__LINE__-8]}.};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'enqueue detached view';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      $req->view->buffer->_transfer; # detach
      $req->respond (1);
    },
  });
  my $reader = $rs->get_reader ('byob');
  $reader->read (DataView->new (ArrayBuffer->new (43)))->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $error = $_[0];
    test {
      like $error, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line @{[__LINE__-9]}.};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'respond detached view';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      $req->view->buffer->_transfer; # detach
      $req->manakai_respond_by_sysread (my $fh);
    },
  });
  my $reader = $rs->get_reader ('byob');
  $reader->read (DataView->new (ArrayBuffer->new (43)))->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $error = $_[0];
    test {
      like $error, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line @{[__LINE__-9]}.};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'manakai_respond_by_sysread detached view';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      my $dv = DataView->new (ArrayBuffer->new (43));
      $dv->buffer->_transfer; # detach
      $req->respond_with_new_view ($dv);
    },
  });
  my $reader = $rs->get_reader ('byob');
  $reader->read (DataView->new (ArrayBuffer->new (43)))->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $error = $_[0];
    test {
      like $error, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line @{[__LINE__-9]}.};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'respond_with_new_view detached view';

test {
  my $c = shift;
  my $rs = ReadableStream->new ({
    type => 'bytes',
    pull => sub {
      my $req = $_[1]->byob_request;
      my $dv = DataView->new (ArrayBuffer->new (4));
      $dv->buffer->_transfer; # detach
      $req->manakai_respond_with_new_view ($dv);
    },
  });
  my $reader = $rs->get_reader ('byob');
  $reader->read (DataView->new (ArrayBuffer->new (43)))->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $error = $_[0];
    test {
      like $error, qr{^TypeError: ArrayBuffer is detached at \Q@{[__FILE__]}\E line @{[__LINE__-9]}.};
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'manakai_respond_with_new_view detached view';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
