use ExtUtils::MakeMaker;

WriteMakefile( NAME         => 'Exception::Class',
               VERSION_FROM => 'lib/Exception/Class.pm',
               PREREQ_PM    => { 'Class::Data::Inheritable' => 0.02,
                                 'Devel::StackTrace' => 1.10,
                                 'Test::More' => 0.46,
                               }
	     );
