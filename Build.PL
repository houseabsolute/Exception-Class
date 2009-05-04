use 5.008001;

use strict;
use warnings;

use Module::Build;

my $build =
    Module::Build->new
        ( module_name => 'Exception::Class',
          license     => 'perl',
          requires    => { 'Class::Data::Inheritable' => '0.02',
                           'Devel::StackTrace'        => '1.20',
                           'Scalar::Util'             => '0',
                           'perl'                     => '5.008001',
                         },
          build_requires => { 'Test::More' => '0.46',
                            },
          sign               => 1,
          create_makefile_pl => 'traditional',
        );

$build->create_build_script;
