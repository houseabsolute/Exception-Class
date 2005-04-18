#!/usr/bin/perl -w

use strict;

use Test::More tests => 4;

use Exception::Class ( 'Foo',
                       'Bar' => { isa => 'Foo' },
                     );

{
    eval { Foo->throw( error => 'foo' ) };

    my $e = Exception::Class->caught('Bar');

    ok( ! $e, 'caught returns false for wrong class' );
}

{
    eval { Foo->throw( error => 'foo' ) };

    my $e = Exception::Class->caught('Foo');

    ok( $e, 'caught returns exception for correct class' );
    isa_ok( $e, 'Foo' );
    is( $e->message, 'foo', 'message is "foo"' );
}
