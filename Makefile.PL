use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      'NAME'	=> 'Class::Exceptions',
	      'VERSION_FROM' => 'Class/Exceptions.pm', # finds $VERSION
	      'PM' => { 'Class/Exceptions.pm' => '$(INST_LIBDIR)/Class/Exceptions.pm' },

	     );
