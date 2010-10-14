use strict;
use warnings;

use Test::Exception;
use Test::More;

use Test::Requires {
    'Test::Warn' => '0.21',
};

{
    throws_ok {
        eval 'package Foo; use Package::DeprecationManager;';
        die $@ if $@;
    }
    qr/^\QYou must provide a hash reference -deprecations parameter when importing Package::DeprecationManager/,
        'must provide a set of deprecations when using Package::DeprecationManager';
}

{
    package Foo;

    use Package::DeprecationManager -deprecations => {
        'Foo::foo'  => '0.02',
        'Foo::bar'  => '0.03',
        'Foo::baz'  => '1.21',
        'not a sub' => '1.23',
    };

    sub foo {
        deprecated('foo is deprecated');
    }

    sub bar {
        deprecated('bar is deprecated');
    }

    sub baz {
        deprecated();
    }

    sub quux {
        if ( $_[0] > 5 ) {
            deprecated(
                message => 'quux > 5 has been deprecated',
                feature => 'not a sub',
            );
        }
    }

    sub varies {
        deprecated("The varies sub varies: $_[0]");
    }

}

{
    package Bar;

    Foo->import();

    ::warning_is{ Foo::foo() }
        { carped => 'foo is deprecated' },
        'deprecation warning for foo';

    ::warning_is{ Foo::bar() }
        { carped => 'bar is deprecated' },
        'deprecation warning for bar';

    ::warning_is{ Foo::baz() }
        { carped => 'Foo::baz has been deprecated since version 1.21' },
        'deprecation warning for baz, and message is generated by Package::DeprecationManager';

    ::warning_is{ Foo::foo() } q{}, 'no warning on second call to foo';

    ::warning_is{ Foo::bar() } q{}, 'no warning on second call to bar';

    ::warning_is{ Foo::baz() } q{}, 'no warning on second call to baz';

    ::warning_is{ Foo::varies(1) }
        { carped => "The varies sub varies: 1" },
        'warning for varies sub';

    ::warning_is{ Foo::varies(2) }
        { carped => "The varies sub varies: 2" },
        'warning for varies sub with different error';

    ::warning_is{ Foo::varies(1) }
        q{},
        'no warning for varies sub with same message as first call';
}

{
    package Baz;

    Foo->import( -api_version => '0.01' );

    ::warning_is{ Foo::foo() }
        q{},
        'no warning for foo with api_version = 0.01';

    ::warning_is{ Foo::bar() }
        q{},
        'no warning for bar with api_version = 0.01';

    ::warning_is{ Foo::baz() }
        q{},
        'no warning for baz with api_version = 0.01';
}

{
    package Quux;

    Foo->import( -api_version => '1.17' );

    ::warning_is{ Foo::foo() }
        { carped => 'foo is deprecated' },
        'deprecation warning for foo with api_version = 1.17';

    ::warning_is{ Foo::bar() }
        { carped => 'bar is deprecated' },
        'deprecation warning for bar with api_version = 1.17';

    ::warning_is{ Foo::baz() }
        q{},
        'no warning for baz with api_version = 1.17';
}

{
    package Another;

    Foo->import();

    ::warning_is{ Foo::quux(1) }
        q{},
        'no warning for quux(1)';

    ::warning_is{ Foo::quux(10) }
        { carped => 'quux > 5 has been deprecated' },
        'got a warning for quux(10)';
}


{
    package Dep;

    use Package::DeprecationManager -deprecations => {
        'foo' => '1.00',
        },
        -ignore => [ 'My::Package1', 'My::Package2' ];

    sub foo {
        deprecated('foo is deprecated');
    }
}

{
    package Dep2;

    use Package::DeprecationManager -deprecations => {
        'bar' => '1.00',
        },
        -ignore => [ 'My::Package2' ];

    sub bar {
        deprecated('bar is deprecated');
    }
}

{
    package My::Package1;

    sub foo { Dep::foo() }
    sub bar { Dep2::bar() }
}

{
    package My::Package2;

    sub foo { My::Package1::foo() }
    sub bar { My::Package1::bar() }
}

{
    package My::Baz;

    ::warning_like{ My::Package2::foo() }
        qr/^foo is deprecated at t.basic\.t line \d+/,
        'deprecation warning for call to My::Package2::foo()';

    ::warning_like{ My::Package1::bar() }
        qr/^bar is deprecated at t.basic\.t line \d+/,
        'deprecation warning for call to My::Package1::bar()';
}

{
    package My::Baz;

    Dep->import( -api_version => '0.8' );

    ::warning_is{ My::Package2::foo() }
        q{},
        'no warning when calling My::Package2::foo()';
}

done_testing();
