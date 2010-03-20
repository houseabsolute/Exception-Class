use strict;
use warnings;

use File::Spec;

use Test::More;

use_ok('Exception::Class');

# There's actually a few tests here of the import routine.  I don't
# really know how to quantify them though.  If we fail to compile and
# there's an error from the Exception::Class::Base class then
# something here failed.
BEGIN {
    package FooException;

    use Exception::Class;
    use base qw(Exception::Class::Base);
}

use Exception::Class (
    'YAE' => { isa => 'SubTestException', alias => 'yae' },

    'SubTestException' => {
        isa         => 'TestException',
        description => q|blah'\\blah|
    },

    'TestException',

    'FooBarException' => { isa => 'FooException' },

    'FieldsException' => { isa => 'YAE', fields => [qw( foo bar )] },
    'MoreFieldsException' => { isa => 'FieldsException', fields => ['yip'] },

    'Exc::AsString',

    'Bool' => { fields => ['something'] },

    'ObjectRefs',
    'ObjectRefs2',
);

$Exception::Class::BASE_EXC_CLASS = 'FooException';
Exception::Class->import('BlahBlah');

# Accessors
{
    eval { Exception::Class::Base->throw( error => 'err' ); };

    isa_ok( $@, 'Exception::Class::Base', '$@' );

    is(
        $@->error, 'err',
        "Exception's error message should be 'err'"
    );

    is(
        $@->message, 'err',
        "Exception's message should be 'err'"
    );

    is(
        $@->description, 'Generic exception',
        "Description should be 'Generic exception'"
    );

    is(
        $@->package, 'main',
        "Package should be 'main'"
    );

    my $expect = File::Spec->catfile( 't', 'basic.t' );
    is(
        $@->file, $expect,
        "File should be '$expect'"
    );

    is(
        $@->line, 49,
        "Line should be 49"
    );

    is(
        $@->pid, $$,
        "PID should be $$"
    );

    is(
        $@->uid, $<,
        "UID should be $<"
    );

    is(
        $@->euid, $>,
        "EUID should be $>"
    );

    is(
        $@->gid, $(,
        "GID should be $("
    );

    is(
        $@->egid, $),
        "EGID should be $)"
    );

    ok(
        defined $@->trace,
        "Exception object should have a stacktrace"
    );
}

# Test subclass creation
{
    eval { TestException->throw( error => 'err' ); };

    isa_ok( $@, 'TestException' );

    is(
        $@->description, 'Generic exception',
        "Description should be 'Generic exception'"
    );

    eval { SubTestException->throw( error => 'err' ); };

    isa_ok( $@, 'SubTestException' );

    isa_ok( $@, 'TestException' );

    isa_ok( $@, 'Exception::Class::Base' );

    is(
        $@->description, q|blah'\\blah|,
        q|Description should be "blah'\\blah"|
    );

    eval { YAE->throw( error => 'err' ); };

    isa_ok( $@, 'SubTestException' );

    eval { BlahBlah->throw( error => 'yadda yadda' ); };

    isa_ok( $@, 'FooException' );

    isa_ok( $@, 'Exception::Class::Base' );
}

# Trace related tests
{
    ok(
        !Exception::Class::Base->Trace,
        "Exception::Class::Base class 'Trace' method should return false"
    );

    eval {
        Exception::Class::Base->throw(
            error      => 'has stacktrace',
            show_trace => 1,
        );
    };
    like(
        $@->as_string, qr/Trace begun/,
        "Setting show_trace to true should override value of Trace"
    );

    Exception::Class::Base->Trace(1);

    ok(
        Exception::Class::Base->Trace,
        "Exception::Class::Base class 'Trace' method should return true"
    );

    eval { argh(); };

    ok(
        $@->trace->as_string,
        "Exception should have a stack trace"
    );

    eval {
        Exception::Class::Base->throw(
            error      => 'has stacktrace',
            show_trace => 0,
        );
    };

    unlike(
        $@->as_string, qr/Trace begun/,
        "Setting show_trace to false should override value of Trace"
    );

    my @f;
    while ( my $f = $@->trace->next_frame ) { push @f, $f; }

    ok(
        ( !grep { $_->package eq 'Exception::Class::Base' } @f ),
        "Trace should contain frames from Exception::Class::Base package"
    );
}

# overloading
{
    Exception::Class::Base->Trace(0);
    eval { Exception::Class::Base->throw( error => 'overloaded' ); };

    is(
        "$@", 'overloaded',
        "Overloading in string context"
    );

    Exception::Class::Base->Trace(1);
    eval { Exception::Class::Base->throw( error => 'overloaded again' ); };

SKIP:
    {
        skip( "Perl 5.6.0 is broken.  See README.", 1 ) if $] == 5.006;

        my $re = qr/overloaded again.+eval {...}/s;

        my $x = "$@";
        like(
            $x, $re,
            "Overloaded stringification should include a stack trace"
        );
    }
}

# Test using message as hash key to constructor
{
    eval { Exception::Class::Base->throw( message => 'err' ); };

    is(
        $@->error, 'err',
        "Exception's error message should be 'err'"
    );

    is(
        $@->message, 'err',
        "Exception's message should be 'err'"
    );
}

{
    {

        package X::Y;

        use Exception::Class (__PACKAGE__);

        sub xy_die () { __PACKAGE__->throw( error => 'dead' ); }

        eval {xy_die};
    }

    is(
        $@->error, 'dead',
        "Error message should be 'dead'"
    );
}

# subclass overriding as_string

sub Exc::AsString::as_string { return uc $_[0]->error }

{
    eval { Exc::AsString->throw( error => 'upper case' ) };

    is(
        "$@", 'UPPER CASE',
        "Overriding as_string in subclass"
    );
}

# fields

{
    eval { FieldsException->throw( error => 'error', foo => 5 ) };

    can_ok( $@, 'foo' );

    is(
        $@->foo, 5,
        "Exception's foo method should return 5"
    );
}

# more fields.
{
    eval {
        MoreFieldsException->throw( error => 'error', yip => 10, foo => 15 );
    };

    can_ok( $@, 'foo' );

    is(
        $@->foo, 15,
        "Exception's foo method should return 15"
    );

    can_ok( $@, 'yip' );

    is(
        $@->yip, 10,
        "Exception's foo method should return 10"
    );
}

sub FieldsException::full_message {
    return join ' ', $_[0]->message, "foo = " . $_[0]->foo;
}

# fields + full_message

{
    eval { FieldsException->throw( error => 'error', foo => 5 ) };

    like(
        "$@", qr/error foo = 5/,
        "FieldsException should stringify to include the value of foo"
    );
}

# single arg constructor
{
    eval { YAE->throw('foo') };

    ok(
        $@,
        "Single arg constructor should work"
    );

    is(
        $@->error, 'foo',
        "Single arg constructor should just set error/message"
    );
}

# no refs
{
    ObjectRefs2->NoRefs(0);

    eval { Foo->new->bork2 };
    my $exc = $@;

    my @args = ( $exc->trace->frames )[1]->args;

    ok(
        ref $args[0],
        "References should be saved in the stack trace"
    );
}

# aliases
{

    package FooBar;

    use Exception::Class (
        'SubAndFields' => {
            fields => 'thing',
            alias  => 'throw_saf',
        }
    );

    eval { throw_saf 'an error' };
    my $e = $@;

    ::ok( $e, "Throw exception via convenience sub (one param)" );
    ::is( $e->error, 'an error', 'check error message' );

    eval { throw_saf error => 'another error', thing => 10 };
    $e = $@;

    ::ok( $e, "Throw exception via convenience sub (named params)" );
    ::is( $e->error, 'another error', 'check error message' );
    ::is( $e->thing, 10, 'check "thing" field' );

    ::is( $e->package, __PACKAGE__, 'package matches current package' );
}

{

    package BarBaz;

    use overload '""' => sub {'overloaded'};
}

{
    sub throw { TestException->throw( error => 'dead' ) }

    TestException->Trace(1);

    eval { throw( bless {}, 'BarBaz' ) };
    my $e = $@;

    unlike(
        $e->as_string, qr/\boverloaded\b/,
        'overloading is ignored by default'
    );

    TestException->RespectOverload(1);

    eval { throw( bless {}, 'BarBaz' ) };
    $e = $@;

    like( $e->as_string, qr/\boverloaded\b/, 'overloading is now respected' );
}

{
    my %classes = map { $_ => 1 } Exception::Class::Classes();

    ok( $classes{TestException},
        'TestException should be in the return from Classes()' );
}

{
    sub throw2 { TestException->throw( error => 'dead' ); }

    eval { throw2('abcdefghijklmnop') };
    my $e = $@;

    like( $e->as_string, qr/'abcdefghijklmnop'/,
        'arguments are not truncated by default' );

    TestException->MaxArgLength(10);

    eval { throw2('abcdefghijklmnop') };
    $e = $@;

    like(
        $e->as_string, qr/'abcdefghij\.\.\.'/,
        'arguments are now truncated'
    );
}

done_testing();

sub argh {
    Exception::Class::Base->throw( error => 'ARGH' );
}

package Foo;

sub new {
    return bless {}, shift;
}

sub bork {
    my $self = shift;

    ObjectRefs->throw('kaboom');
}

sub bork2 {
    my $self = shift;

    ObjectRefs2->throw('kaboom');
}
