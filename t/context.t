#!/usr/bin/perl -w

use strict;

use Test::More tests => 4;

use Exception::Class ( 'Foo',
                       'Bar' => { isa => 'Foo', defaults => { no_context_info => 1 } },
                     );

{
    eval { Foo->throw( error => 'foo' ) };

    my $e = Exception::Class->caught;

    ok( defined($e->trace), 'has trace detail');
}

{
    eval { Foo->throw( error => 'foo', no_context_info => 1 ) };

    my $e = Exception::Class->caught;

    ok( !defined($e->trace), 'has no trace detail');
}

{
    eval { Bar->throw( error => 'foo', no_context_info => 0 ) };

    my $e = Exception::Class->caught;

    ok( defined($e->trace), 'has trace detail');
}

{
    eval { Bar->throw( error => 'foo' ) };

    my $e = Exception::Class->caught;

    ok( !defined($e->trace), 'has no trace detail');
}

