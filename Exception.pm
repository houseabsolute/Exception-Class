package Exception;

use 5.005;

use strict;
use vars qw($VERSION $DO_TRACE %CLASSES);

use StackTrace;

use fields qw( error pid uid euid gid egid time trace );

use overload
    '""' => \&as_string,
    fallback => 1;

$VERSION = '0.15';

$DO_TRACE = 0;

# Create accessor routines
{
    no strict 'refs';
    foreach my $f (keys %{__PACKAGE__ . '::FIELDS'})
    {
	*{$f} = sub { my Exception $s = shift; return $s->{$f}; };
    }
}

1;

sub import
{
    my $class = shift;

    my %needs_parent;
 MAKE_CLASSES:
    while (my $subclass = shift)
    {
	my $def = ref $_[0] ? shift : {};
	$def->{isa} = $def->{isa} ? ( ref $def->{isa} ? $def->{isa} : [$def->{isa}] ) : [];

	# We already made this one.
	next if $CLASSES{$subclass};

	{
	    no strict 'refs';
	    foreach my $parent (@{ $def->{isa} })
	    {
		unless ( defined ${"$parent\::VERSION"} || @{"$parent\::ISA"} )
		{
		    $needs_parent{$subclass} = { parents => $def->{isa},
						 def => $def };
		    next MAKE_CLASSES;
		}
	    }
	}

	$class->_make_subclass( subclass => $subclass,
				def => $def || {} );
    }

    foreach my $subclass (keys %needs_parent)
    {
	# This will be used to spot circular references.
	my %seen;
	$class->_make_parents( \%needs_parent, $subclass, \%seen );
    }
}

sub _make_parents
{
    my $class = shift;
    my $h = shift;
    my $subclass = shift;
    my $seen = shift;
    my $child = shift; # Just for error messages.

    no strict 'refs';

    # What if someone makes a typo in specifying their 'isa' param?
    # This should catch it.  Either it's been made because it didn't
    # have missing parents OR it's in our hash as needing a parent.
    # If neither of these is true then the _only_ place it is
    # mentioned is in the 'isa' param for some other class, which is
    # not a good enough reason to make a new class.
    die "Class $subclass appears to be a typo as it is only specified in the 'isa' param for $child\n"
	unless exists $h->{$subclass} || $CLASSES{$subclass} || @{"$subclass\::ISA"};

    foreach my $c ( @{ $h->{$subclass}{parents} } )
    {
	# It's been made
	next if $CLASSES{$c} || @{"$c\::ISA"};

	die "There appears to be some circularity involving $subclass\n"
	    if $seen->{$subclass};

	$seen->{$subclass} = 1;

	$class->_make_parents( $h, $c, $seen, $subclass );
    }

    return if $CLASSES{$subclass} || @{"$subclass\::ISA"};

    $class->_make_subclass( subclass => $subclass,
			    def => $h->{$subclass}{def} );
}

sub _make_subclass
{
    my $class = shift;
    my %p = @_;

    my $subclass = $p{subclass};
    my $def = $p{def};

    my $isa;
    if ($def->{isa})
    {
	$isa = ref $def->{isa} ? join ' ', @{ $def->{isa} } : $def->{isa};
    }
    $isa ||= $class;

    my $code = <<"EOPERL";
package $subclass;

use vars qw(\$VERSION \$DO_TRACE);

use base qw($isa);

\$VERSION = '0.01';

\$DO_TRACE = 0;

1;

EOPERL


    if ($def->{description})
    {
	$code .= <<"EOPERL";
sub description
{
    return '$def->{description}';
}
EOPERL
    }

    eval $code;

    die $@ if $@;

    $CLASSES{$subclass} = 1;
}

sub throw
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    die $class->new(@_);
}

sub rethrow
{
    my Exception $self = shift;

    die $self;
}

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    {
	no strict 'refs';
	$self = bless [ \%{"${class}::FIELDS"} ], $class;
    }

    $self->_initialize(@_);

    return $self;
}

sub _initialize
{
    my Exception $self = shift;
    my %p = @_;

    # Try to get something useful in there (I hope).
    $self->{error} = $p{error} || $!;

    $self->{time} = time;
    $self->{pid}  = $$;
    $self->{uid}  = $<;
    $self->{euid} = $>;
    $self->{gid}  = $(;
    $self->{egid} = $);

    if ($self->do_trace)
    {
	$self->{trace} = StackTrace->new( ignore_class => __PACKAGE__ );
    }
}

sub description
{
    return 'Generic exception';
}

sub do_trace
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    {
	no strict 'refs';
	if ( defined ( my $val = shift ) )
	{
	    ${"$class\::DO_TRACE"} = $val;
	}

	return ${"$class\::DO_TRACE"};
    }
}

sub as_string
{
    my Exception $self = shift;

    my $str = $self->{error};
    if ($self->trace)
    {
	$str .= "\n\n" . $self->trace->as_string;
    }

    return $str;
}

__END__

=head1 NAME

Exception - A base (and default) class for real exception objects in Perl

=head1 SYNOPSIS

  use Exception ( 'MyException',
                  'AnotherException' => { isa => 'MyException' },
                  'YetAnotherException' => { isa => 'AnotherException',
                                             description => 'These exceptions are related to IPC' } );

  eval { MyException->throw( error => 'I feel funny.'; };

  print $@->error, "\n";

  MyException->trace(1);
  eval { MyException->throw( error => 'I feel funnier.'; };

  print $@->error, "\n", $@->trace->as_string, "\n";
  print join ' ',  $@->euid, $@->egid, $@->uid, $@->gid, $@->pid, $@->time;

  # catch
  if ($@->isa('MyException'))
  {
     do_something();
  }
  elsif ($@->isa('FooException'))
  {
     go_foo_yourself();
  }
  else
  {
     $@->rethrow;
  }

=head1 DESCRIPTION

Exception is a base class for true Exception objects in Perl.  It is
designed to make structured exception handling simpler by encouraging
people to use hierarchies of exceptions in their applications.

It features a simple interface allowing programmers to 'declare'
Exception classes at compile time.  It can also be used as a base
class for classes stored in files (aka modules ;) ) that contain
Exception subclasses.

In addition, it can be used as a simple Exception class in and of
itself.

=head1 DECLARING EXCEPTION CLASSES

The 'use Exception' syntax lets you automagically create the relevant
Exception subclasses.  You can also create subclasses via the
traditional means of external modules loaded via 'use'.  These two
methods may be combined.

The syntax for the magic declarations is as follows:

'MANDATORY CLASS NAME" => \%optional_hashref

The hashref may contain two options (for now):

=over 4

=item * isa

This is the class's parent class.  If this isn't provided the class
which was "use'd" is assumed to be the parent (see below).  This lets
you create arbitrarily deep class hierarchies.  This can be any other
Exception subclass in your declaration _or_ a subclass loaded from a
module.

If you create an Exception class in a file (let's call this class
FooInaFileException) and then 'use' this class like you would 'use'
Exception, as in:

  use FooInaFileException ( 'BarException',
                            'BazException' => { isa => 'BarException' } );

then the default base class will become FooInaFileException, _not_
Exception.

CAVEAT: If you want to automagically subclass an Exception class
loaded from a file, then you _must_ compile the class (via use or
require or some other magic) _before_ you do 'use Exception' or you'll
get a compile time error.  This may change with the advent of Perl
5.6's CHECK blocks, which could allow even more crazy automagicalness
(which may or may not be a good thing).

=item * description

Each exception class has a description method that returns a fixed
string.  This should describe the exception _class_ (as opposed the
particular exception being thrown).  This is useful for debugging if
you start catching exceptions you weren't expecting (particularly if
someone forgot to document them) and you don't understand the error
messages.

=back

The Exception class's magic attempts to detect circular class
hierarchies and will die if it finds one.  It also detects missing
links in a chain so if you declare Bar to be a subclass of Foo and
never declare Foo then it will also die.  My tests indicate that this
is functioning properly but this functionality is still somewhat
experimental.

=head1 CLASS METHODS

=over 4

=item * do_trace($true_or_false)

Each Exception subclass can be set individually to make a StackTrace
object when an exception is thrown.  The default is to not make a
trace.  Calling this method with a value changes this behavior.  It
always returns the current value (after any change is applied).

=item * throw( error => $error_message )

This method creates a new Exception object with the given error
message.  If no error message is given, $! is used.  It then die's
with this object as its argument.

=item * new( error => $error_message )

Returns a new Exception object with the given error message.  If no
error message is given, $! is used.

=item * description

Returns the description for the given Exception subclass.  The
Exception base class's description is 'Generic exception' (this may
change in the future).  This is also an object method.

=back

=head1 OBJECT METHODS

=over 4

=item * rethrow

Simple dies with the object as its sole argument.  It's just syntactic
sugar.  This does not change any of the object's attribute values.

=item * error

Returns the error message associated with the exception.

=item * pid

Returns the pid at the time the exception was thrown.

=item * uid

Returns the real user id at the time the exception was thrown.

=item * gid

Returns the real group id at the time the exception was thrown.

=item * euid

Returns the effective user id at the time the exception was thrown.

=item * egid

Returns the effective group id at the time the exception was thrown.

=item * time

Returns the time in seconds since the epoch at the time the exception
was thrown.

=item * trace

Returns the trace object associated with the Exception if do_trace was
true at the time it was created or undef

=item * as_string

Returns a string form of the error message (something like what you'd
expect from die).  If there is a trace available then it also returns
this in string form (like croak).

=back

=head1 OVERLOADING

The Exception object is overloaded so that stringification produces a
normal error message.  It just calls the as_string method described
above.  This means that you just print $@ after an eval and not worry
about whether or not its an actual object.

=head1 USAGE RECOMMENDATION

If you're creating a complex system that throws lots of different
types of exceptions consider putting all the exception declarations in
one place.  For an app called Foo you might make a Foo::Exceptions
module and use that in all your code.  This module could just contain
the code to make Exception do its automagic class creation.  This
allows you to more easily see what exceptions you have and makes it
easier to keep track of them all (as opposed to looking at the top of
10-20 different files).  It's also ever so slightly faster as the
Exception->import method doesn't get called over and over again
(though a given class is only ever made once).

You may want to create a real module to subclass Exception as well,
particularly if you want your exceptions to have more methods.  Read
the L<DECLARING EXCEPTION CLASSES> section for more details.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 SEE ALSO

StackTrace

=cut
