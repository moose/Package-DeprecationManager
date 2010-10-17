use strict;
use warnings;

use Test::More;

eval "require Package::DeprecationManager";
ok( ! $@, 'no errors loading require Package::DeprecationManager' );

done_testing();
