package Exception::Class;

use 5.005;

use strict;
use vars qw($VERSION $BASE_EXC_CLASS %CLASSES);

BEGIN { $BASE_EXC_CLASS ||= 'Exception::Class::Base'; }

$VERSION = '0.95';

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
    $isa ||= $BASE_EXC_CLASS;

    my $code = <<"EOPERL";
package $subclass;

use vars qw(\$VERSION);

use base qw($isa);

\$VERSION = '1.1';

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

package Exception::Class::Base;

use Class::Data::Inheritable;
use Devel::StackTrace;

use base qw(Class::Data::Inheritable);

__PACKAGE__->mk_classdata('Trace');

use overload
    '""' => \&as_string,
    fallback => 1;

use vars qw($VERSION);

$VERSION = '1.2';

# Create accessor routines
BEGIN
{
    my @fields = qw( message pid uid euid gid egid time trace package file line );

    no strict 'refs';
    foreach my $f (@fields)
    {
	*{$f} = sub { my $s = shift; return $s->{$f}; };
    }
    *{'error'} = \&message;
}

1;

sub throw
{
    my $proto = shift;

    $proto->rethrow if ref $proto;

    die $proto->new(@_);
}

sub rethrow
{
    my $self = shift;

    die $self;
}

sub new
{
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;

    $self->_initialize(@_);

    return $self;
}

sub _initialize
{
    my $self = shift;
    my %p = @_;

    # Try to get something useful in there (I hope).  Or just give up.
    $self->{message} = $p{message} || $p{error} || $! || '';

    $self->{show_trace} = $p{show_trace} if exists $p{show_trace};

    $self->{time} = CORE::time; # without CORE:: sometimes makes a warning (why?)
    $self->{pid}  = $$;
    $self->{uid}  = $<;
    $self->{euid} = $>;
    $self->{gid}  = $(;
    $self->{egid} = $);

    my $x = 0;
    # move back the stack til we're out of this package
    $x++ while defined caller($x) && UNIVERSAL::isa( scalar caller($x), __PACKAGE__ );
    $x-- until caller($x);

    @{ $self }{ qw( package file line ) } = (caller($x))[0..2];

    $self->{trace} = Devel::StackTrace->new( ignore_class => __PACKAGE__ );
}

sub description
{
    return 'Generic exception';
}

sub as_string
{
    my $self = shift;

    my $str = $self->{message};
    if ( exists $self->{show_trace} ? $self->{show_trace} : $self->Trace )
    {
	$str .= "\n\n" . $self->trace->as_string;
    }

    return $str;
}

__END__

=head1 NAME

Exception::Class - A module that allows you to declare real exception classes in Perl

=head1 SYNOPSIS

  use Exception::Class (
                  'MyException',
                  'AnotherException' => { isa => 'MyException' },
                  'YetAnotherException' => { isa => 'AnotherException',
                                             description => 'These exceptions are related to IPC' }                                  );

  eval { MyException->throw( error => 'I feel funny.'; };

  print $@->error, "\n";

  MyException->Trace(1);
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

Exception::Class allows you to declare exceptions in your modules in a
manner similar to how exceptions are declared in Java.

It features a simple interface allowing programmers to 'declare'
exception classes at compile time.  It also has a base exception
class, Exception::Class::Base, that can be used for classes stored in
files (aka modules ;) ) that are subclasses.

It is designed to make structured exception handling simpler and
better by encouraging people to use hierarchies of exceptions in their
applications.

NOTE: This module does not implement any try/catch syntax.  Please see
the L<OTHER EXCEPTION MODULES (try/catch syntax)> for more information
on how to get this syntax.

=head1 DECLARING EXCEPTION CLASSES

The 'use Exception::Class' syntax lets you automagically create the
relevant Exception::Class::Base subclasses.  You can also create
subclasses via the traditional means of external modules loaded via
'use'.  These two methods may be combined.

The syntax for the magic declarations is as follows:

'MANDATORY CLASS NAME' => \%optional_hashref

The hashref may contain two options:

=over 4

=item * isa

This is the class's parent class.  If this isn't provided then the
class name is $Exception::Class::BASE_EXC_CLASS is assumed to be the
parent (see below).

This parameter lets you create arbitrarily deep class hierarchies.
This can be any other Exception::Class::Base subclass in your
declaration _or_ a subclass loaded from a module.

To change the default exception class you will need to change the
value of $Exception::Class::BASE_EXC_CLASS _before_ calling C<import>.
To do this simply do something like this:

BEGIN { $Exception::Class::BASE_EXC_CLASS = 'SomeExceptionClass'; }

If anyone can come up with a more elegant way to do this please let me
know.

CAVEAT: If you want to automagically subclass a Exception::Class::Base
class loaded from a file, then you _must_ compile the class (via use
or require or some other magic) _before_ you do 'use Exception::Class'
or you'll get a compile time error.  This may change with the advent
of Perl 5.6's CHECK blocks, which could allow even more crazy
automagicalness (which may or may not be a good thing).

=item * description

Each exception class has a description method that returns a fixed
string.  This should describe the exception _class_ (as opposed to the
particular exception being thrown).  This is useful for debugging if
you start catching exceptions you weren't expecting (particularly if
someone forgot to document them) and you don't understand the error
messages.

=back

The Exception::Class magic attempts to detect circular class
hierarchies and will die if it finds one.  It also detects missing
links in a chain so if you declare Bar to be a subclass of Foo and
never declare Foo then it will also die.  My tests indicate that this
is functioning properly but this functionality is still somewhat
experimental.

=head1 Exception::Class::Base CLASS METHODS

=over 4

=item * Trace($true_or_false)

Each Exception::Class::Base subclass can be set individually to
include a a stracktrace when the C<as_string> method is called..  The
default is to not include a stacktrace.  Calling this method with a
value changes this behavior.  It always returns the current value
(after any change is applied).

This value is inherited by any subclasses.  However, if this value is
set for a subclass, it will thereafter be independent of the value in
Exception::Class::Base.

This is a class method, not an object method.

=item * throw( message => $message ) OR throw ( error => $error )

This method creates a new Exception::Class::Base object with the given
error message.  If no error message is given, $! is used.  It then
die's with this object as its argument.

This method also takes a C<show_trace> parameter which indicates
whether or not the particular exception object being created should
show a stacktrace when its C<as_string> method is called.  This
overrides the value of C<Trace> for this class if it is given.

=item * new( message => $message ) OR new ( error => $error )

Returns a new Exception::Class::Base object with the given error
message.  If no message is given, $! is used instead.

This method also takes a C<show_trace> parameter which indicates
whether or not the particular exception object being created should
show a stacktrace when its C<as_string> method is called.  This
overrides the value of C<Trace> for this class if it is given.

=item * description

Returns the description for the given Exception::Class::Base subclass.
The Exception::Class::Base class's description is 'Generic exception'
(this may change in the future).  This is also an object method.

=back

=head1 Exception::Class::Base OBJECT METHODS

=over 4

=item * rethrow

Simply dies with the object as its sole argument.  It's just syntactic
sugar.  This does not change any of the object's attribute values.
However, it will cause C<caller> to report the die as coming from
within the Exception::Class::Base class rather than where rethrow was
called.

=item * message

Returns the message associated with the exception.  This is synonymous
with the C<error> method.

=item * error

Returns the error message associated with the exception.  This is
synonymous with the C<message> method.

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

=item * package

Returns the package from which the exception was thrown.

=item * file

Returns the file within which the exception was thrown.

=item * line

Returns the line where the exception was thrown.

=item * trace

Returns the trace object associated with the object.

=item * as_string

Returns a string form of the error message (something like what you'd
expect from die).  If the class or object is set to show traces then
then it also includes this in string form (like Carp::confess).

=back

=head1 OVERLOADING

The Exception::Class::Base object is overloaded so that
stringification produces a normal error message.  It just calls the
as_string method described above.  This means that you can just
C<print $@> after an eval and not worry about whether or not its an
actual object.  It also means an application or module could do this:

 $SIG{__DIE__} = sub { Exception::Class::Base->throw( error => join '', @_ ); };

and this would probably not break anything (unless someone was
expecting a different type of exception object from C<die>).

=head1 USAGE RECOMMENDATION

If you're creating a complex system that throws lots of different
types of exceptions consider putting all the exception declarations in
one place.  For an app called Foo you might make a Foo::Exceptions
module and use that in all your code.  This module could just contain
the code to make Exception::Class do its automagic class creation.
This allows you to more easily see what exceptions you have and makes
it easier to keep track of them all (as opposed to looking at the top
of 10-20 different files).  It's also ever so slightly faster as the
Class::Exception->import method doesn't get called over and over again
(though a given class is only ever made once).

This might look something like this:

  package Foo::Bar::Exceptions;

  use Exception::Class ( Foo::Bar::Exception::Smell =>
                         { description => 'stinky!' },

                         Foo::Bar::Exception::Taste =>
                         { description => 'like, gag me with a spoon!' },

                         ... );

You may want to create a real module to subclass
Exception::Class::Base as well, particularly if you want your
exceptions to have more methods.  Read the L<DECLARING EXCEPTION
CLASSES> for more details.

=head1 OTHER EXCEPTION MODULES (try/catch syntax)

If you are interested in adding try/catch/finally syntactic sugar to
your code then I recommend you check out Graham Barr's Error module,
which implements this syntax.  It also includes its own base exception
class, Error::Simple.

If you would prefer to use the Exception::Class::Base included with
this module, you'll have to add this to your code somewhere:

  push @Exception::Class::Base::ISA, 'Error';

It's a hack but apparently it works.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=head1 SEE ALSO

Devel::StackTrace

=cut
