use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      'NAME'	=> 'Exception::Class',
	      'VERSION_FROM' => 'Class.pm', # finds $VERSION
	      PREREQ_PM => { 'Class::Data::Inheritable' => 0.02,
			     'Devel::StackTrace' => 0.85 }
	     );
