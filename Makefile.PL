use ExtUtils::MakeMaker;

WriteMakefile( NAME         => 'Exception::Class',
               VERSION_FROM => 'Class.pm',
               PREREQ_PM    => { 'Class::Data::Inheritable' => 0.02,
                                 'Devel::StackTrace' => 1.00,
                                 'Test::More' => 0.46,
                               }
	     );
