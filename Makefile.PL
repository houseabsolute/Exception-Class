use ExtUtils::MakeMaker;

WriteMakefile( NAME         => 'Exception::Class',
               VERSION_FROM => 'Class.pm',
               PREREQ_PM    => { 'Class::Data::Inheritable' => 0.02,
                                 'Devel::StackTrace' => 1.01,
                                 'Test::More' => 0.46,
                               }
	     );
