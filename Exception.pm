package Exception;

use 5.005;

use strict;
use vars qw($VERSION $DO_TRACE %CLASSES);

use StackTrace;

use fields qw( error pid uid euid gid egid time trace );

$VERSION = '0.01';

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

    # What if someone makes a type in specifying their 'isa' param?
    # This should catch it.  Either it's been made (and we returned
    # above) because it didn't have missing parents OR it's in our
    # hash as needing a parent.  If neither of these is true then the
    # _only_ place it is mentioned is in the 'isa' param for some
    # other class, which is not a good enough reason to make a new
    # class.
    die "Class $subclass appears to be a typo as it is only specified in the 'isa' param for $child\n"
	unless exists $h->{$subclass} || $CLASSES{$subclass} || @{"$subclass\::ISA"};

    foreach my $c ( @{ $h->{$subclass}{parents} } )
    {
	# It's been made
	next if $CLASSES{$c} || @{"$c\::ISA"};

	die "There appears to be some circularity involving $subclass\n"
	    if $seen->{$subclass};

	$seen->{$subclass} = 1;

	$class->_make_parents( $h, $c, $subclass );
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
    $isa ||= __PACKAGE__;

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

    $CLASSES{$subclass} = 1;

    die $@ if $@;
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
	$self->{trace} = StackTrace->new( ignore_class => ref $self );
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

    no strict 'refs';
    my $val;
    if ( defined ( $val = shift ) )
    {
	${"$class\::DO_TRACE"} = $val;
    }

    return ${"$class\::DO_TRACE"};
}


__END__

=head1 NAME

Exception - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Exception;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Exception was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
