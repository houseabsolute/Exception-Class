use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      'NAME'	=> 'Exception::Class',
	      'VERSION_FROM' => 'Class.pm', # finds $VERSION
	      PREREQ_PM => { 'Class::Data::Inheritable' => 0.02,
			     'Devel::StackTrace' => 0.85 }
	     );

eval { require Exception::Class };

if ($Exception::Class::VERSION && $Exception::Class::VERSION <= 0.90)
{
    print <<'EOF';

This release is incompatible with all previous versions of
Exception::Class.  Please read the Changes file before installing this
module.
EOF

    print "Continue [Y/N]? ";
    chomp (my $yn = <STDIN>);

    exit 1 unless $yn =~ /^y/;
}
