# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..20\n"; }
END {print "not ok 1\n" unless $main::loaded;}

# There's actually a few tests here of the import routine.  I don't
# really know how to quantify them though.  If test.pl fails to
# compile and there's an error from the Exception::Class::Base class
# then something here failed.
BEGIN
{
    package FooException;

    use vars qw[$VERSION];

    use Exception::Class;
    use base qw(Exception::Class::Base);

    $VERSION = 0.01;

    1;
}

use Exception::Class ( 'YAE' => { isa => 'SubTestException' },
		       'SubTestException' => { isa => 'TestException',
					       description => 'blah blah' },
		       'TestException',
		       'FooBarException' => { isa => 'FooException' },
		     );


$Exception::Class::BASE_EXC_CLASS = 'FooException';
Exception::Class->import( 'BlahBlah' );

use strict;

$^W = 1;
$main::loaded = 1;

result( $main::loaded, "Unable to load Exception::Class module\n" );

# 2-5: Accessors
{
    eval { Exception::Class::Base->throw( error => 'err' ); };

    result( $@->isa('Exception::Class::Base'),
	    "\$\@ is not an Exception::Class::Base\n" );

    result( $@->error eq 'err',
	    "Exception's error message should be 'err' but it's '", $@->error, "'\n" );

    result( $@->description eq 'Generic exception',
	    "Description should be 'Generic exception' but it's '", $@->description, "'\n" );

    result( ! defined $@->trace,
	    "Exception object has a stacktrace but it shouldn't\n" );
}

# 6-14 : Test subclass creation
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
	    "SubTestException should be a subclass of TestException (triggers ->isa bug.  See README.)\n" );

    result( $@->isa( 'Exception::Class::Base' ),
	    "SubTestException should be a subclass of Exception::Class::Base (triggers ->isa bug.  See README.)\n" );

    result( $@->description eq 'blah blah',
	    "Description should be 'blah blah' but it's '", $@->description, "'\n" );

    eval { YAE->throw( error => 'err' ); };

    result( $@->isa( 'SubTestException' ),
	    "YAE should be a subclass of SubTestException (triggers ->isa bug.  See README.)\n" );

    eval { BlahBlah->throw( error => 'yadda yadda' ); };
    result( $@->isa('FooException'),
	    "BlahBlah should be a subclass of FooException\n" );
    result( $@->isa('Exception::Class::Base'),
	    "The BlahBlah class should be a subclass of Exception::Class::Base\n" );
}


# 15-18 : Trace related tests
{
    result( Exception::Class::Base->do_trace == 0,
	    "Exception::Class::Base class 'do_trace' method should return false\n" );

    Exception::Class::Base->do_trace(1);

    result( Exception::Class::Base->do_trace == 1,
	    "Exception::Class::Base class 'do_trace' method should return false\n" );

    eval { argh(); };

    result( $@->trace->as_string,
	    "Exception should have a stack trace\n" );

    my @f;
    while ( my $f = $@->trace->next_frame ) { push @f, $f; }

    result( ( ! grep { $_->package eq 'Exception::Class::Base' } @f ),
	    "Trace contains frames from Exception::Class::Base package\n" );
}

# 19-20 : overloading
{
    Exception::Class::Base->do_trace(0);
    eval { Exception::Class::Base->throw( error => 'overloaded' ); };

    result( "$@" eq 'overloaded', "Overloading is not working\n" );

    Exception::Class::Base->do_trace(1);
    eval { Exception::Class::Base->throw( error => 'overloaded again' ); };

    my $re;
    if ($] == 5.006)
    {
	$re = qr/overloaded again.+eval {...}\('error', 'overloaded again'\)/s;
    }
    else
    {
	$re = qr/overloaded again.+eval {...}\('Exception::Class::Base', 'error', 'overloaded again'\)/s
    }

    my $x = "$@" =~ /$re/;
    result( $x, "Overloaded stringification did not include the expected stack trace\n" );
}

sub argh
{
    Exception::Class::Base->throw( error => 'ARGH' );
}

sub result
{
    my $ok = !!shift;
    use vars qw($TESTNUM);
    $TESTNUM++;
    print "not "x!$ok, "ok $TESTNUM\n";
    print @_ if !$ok;
}
