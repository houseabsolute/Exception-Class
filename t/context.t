#!/usr/bin/perl -w

use strict;

use Test::More tests => 2;

use Exception::Class (
    'Foo',
    'Bar' => { isa => 'Foo' },
);

Bar->NoContextInfo(1);

{
    eval { Foo->throw( error => 'foo' ) };

    my $e = Exception::Class->caught;

    ok( defined( $e->trace ), 'has trace detail' );
}

{
    eval { Bar->throw( error => 'foo' ) };

    my $e = Exception::Class->caught;

    ok( !defined( $e->trace ), 'has no trace detail' );
}

