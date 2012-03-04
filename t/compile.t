use strict;
use warnings;

use Test::More 0.88;

eval "require Package::DeprecationManager";
ok( ! $@, 'no errors loading require Package::DeprecationManager' );

done_testing();
