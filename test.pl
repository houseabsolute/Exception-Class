# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $main::loaded;}

# Used to test the Exception class's import method.
BEGIN
{
    package FooException;

    use vars qw[$VERSION];

    use base qw(Exception);

    $VERSION = 0.01;

    1;
}

# There's actually a few tests here of the import routine.  Don't
# really know how to quantify them though.  If test.pl fails to
# compile and there's an error from the Exception class then something
# here failed.
use Exception ( 'YAE' => { isa => 'SubTestException' },
		'SubTestException' => { isa => 'TestException',
					description => 'blah blah' },
		'TestException',
		'FooBarException' => { isa => 'FooException' },
	      );
use strict;

$^W = 1;
$main::loaded = 1;

result( $main::loaded, "Unable to load Exception module\n" );

# 2-5: Accessors
{
    eval { Exception->throw( error => 'err' ); };

    result( $@->isa('Exception'),
	    "\$\@ is not an Exception\n" );

    result( $@->error eq 'err',
	    "Exception's error message should be 'err' but it's '", $@->error, "'\n" );

    result( $@->description eq 'Generic exception',
	    "Description should be 'Generic exception' but it's '", $@->description, "'\n" );

    result( ! defined $@->trace,
	    "Exception object has a stacktrace but it shouldn't\n" );
}

# 6-12 : Test subclass creation
{
    eval { TestException->throw( error => 'err' ); };

    result( $@->isa( 'TestException' ),
	    "TestException was thrown in class ", ref $@, "\n" );

    result( $@->description eq 'Generic exception',
	    "Description should be 'Generic exception' but it's '", $@->description, "'\n" );

    eval { SubTestException->throw( error => 'err' ); };

    result( $@->isa( 'SubTestException' ),
	    "SubTestException was thrown in class ", ref $@, "\n" );

    result( $@->isa( 'TestException' ),
	    "SubTestException should be a subclass of TestException\n" );

    result( $@->isa( 'Exception' ),
	    "SubTestException should be a subclass of Exception\n" );

    result( $@->description eq 'blah blah',
	    "Description should be 'blah blah' but it's '", $@->description, "'\n" );

    eval { YAE->throw( error => 'err' ); };

    result( $@->isa( 'SubTestException' ),
	    "YAE should be a subclass of SubTestException\n" );
}


# 13-16 : Trace related tests
{
    result( Exception->do_trace == 0,
	    "Exception class 'do_trace' method should return false\n" );

    Exception->do_trace(1);

    result( Exception->do_trace == 1,
	    "Exception class 'do_trace' method should return false\n" );

    eval { argh(); };

    result( $@->trace->as_string,
	    "Exception should have a stack trace\n" );

    my @f;
    while ( my $f = $@->trace->next_frame ) { push @f, $f; }

    result( ( ! grep { $_->package eq 'Exception' } @f ),
	    "Trace contains frames from Exception package\n" );
}

# 17 : overloading
{
    Exception->do_trace(0);
    eval { Exception->throw( error => 'overloaded' ); };

    my $e = "$@";
    result( $e eq 'overloaded', 'overloading is not working' );
}

sub argh
{
    Exception->throw( error => 'ARGH' );
}

sub result
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print @_ if !$ok;
}
