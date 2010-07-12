package Package::DeprecationManager;

use strict;
use warnings;

use Carp qw( croak );
use Params::Util qw( _HASH );
use Sub::Install;

sub import {
    shift;
    my %args = @_;

    croak
        'You must provide a hash reference -deprecations parameter when importing Package::DeprecationManager'
        unless $args{-deprecations} && _HASH( $args{-deprecations} );

    my %registry;

    my $import = _build_import( \%registry );
    my $warn = _build_warn( \%registry, $args{-deprecations} );

    my $caller = caller();

    Sub::Install::install_sub(
        {
            code => $import,
            into => $caller,
            as   => 'import',
        }
    );

    Sub::Install::install_sub(
        {
            code => $warn,
            into => $caller,
            as   => 'deprecated',
        }
    );

    return;
}

sub _build_import {
    my $registry = shift;

    return sub {
        my $class = shift;
        my %args  = @_;

        $args{-api_version} ||= delete $args{-compatible};

        $registry->{ caller() } = $args{-api_version}
            if $args{-api_version};

        return;
    };
}

sub _build_warn {
    my $registry      = shift;
    my $deprecated_at = shift;

    my %warned;

    return sub {
        my %args = @_ < 2 ? ( message => shift ) : @_;

        my ( $package, undef, undef, $sub ) = caller(1);

        unless ( defined $args{feature} ) {
            $args{feature} = $sub;
        }

        my $compat_version = $registry->{$package};

        my $deprecated_at = $deprecated_at->{ $args{feature} };

        return
            if defined $compat_version
                && defined $deprecated_at
                && $compat_version lt $deprecated_at;

        return if $warned{$package}{ $args{feature} };

        if ( defined $args{message} ) {
            @_ = $args{message};
        }
        else {
            my $msg = "$args{feature} has been deprecated";
            $msg .= " since version $deprecated_at"
                if defined $deprecated_at;

            @_ = $msg;
        }

        $warned{$package}{ $args{feature} } = 1;

        goto &Carp::cluck;
    };
}

1;

# ABSTRACT: Manage deprecation warnings for your distribution

__END__

=pod

=head1 SYNOPSIS

  package My::Class;

  use Package::DeprecationManager -deprecations => {
      'My::Class::foo' => '0.02',
      'My::Class::bar' => '0.05',
      'feature-X'      => '0.07',
  };

  sub foo {
      deprecated( 'Do not call foo!' );

      ...
  }

  sub bar {
      deprecated();

      ...
  }

  sub baz {
      my %args = @_;

      if ( $args{foo} ) {
          deprecated(
              message => ...,
              feature => 'feature-X',
          );
      }
  }

  package Other::Class;

  use My::Class -api_version => '0.04';

  My::Class->new()->foo(); # warns
  My::Class->new()->bar(); # does not warn
  My::Class->new()->far(); # does not warn again

=head1 DESCRIPTION

This module allows you to manage a set of deprecations for one or more modules.

When you import C<Package::DeprecationManager>, you must provide a set of
C<-deprecations> as a hash ref. The keys are "feature" names, and the values
are the version when that feature was deprecated.

In many cases, you can simply use the fully qualified name of a subroutine or
method as the feature name. This works for cases where the whole subroutine is
deprecated. However, the feature names can be any string. This is useful if
you don't want to deprecate an entire subroutine, just a certain usage.

As part of the import process, C<Package::DeprecationManager> will export two
subroutines into its caller. It proves an C<import()> sub for the caller and a
C<deprecated()> sub.

The C<import()> sub allows callers of I<your> class to specify an C<-api_version>
parameter. If this is supplied, then deprecation warnings are only issued for
deprecations for api versions earlier than the one specified.

You must call C<deprecated()> sub in each deprecated subroutine. When called,
it will issue a warning using C<Carp::cluck()>.

The C<deprecated()> sub can be called in several ways. If you do not pass any
arguments, it will generate an appropriate warning message. If you pass a
single argument, this is used as the warning message.

Finally, you can call it with named arguments. Currently, the only allowed
names are C<message> and C<feature>. The C<feature> argument should correspond
to the feature name passed in the C<-deprecations> hash.

If you don't explicitly specify a feature, the C<deprecated()> sub uses
C<caller()> to identify its caller, using its fully qualified subroutine name.

Deprecation warnings are only issued once for a given package, regardless of
how many times the deprecated sub/method is called.

=head1 BUGS

Please report any bugs or feature requests to
C<bug-package-deprecationmanager@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 DONATIONS

If you'd like to thank me for the work I've done on this module, please
consider making a "donation" to me via PayPal. I spend a lot of free time
creating free software, and would appreciate any support you'd care to offer.

Please note that B<I am not suggesting that you must do this> in order
for me to continue working on this particular software. I will
continue to do so, inasmuch as I have in the past, for as long as it
interests me.

Similarly, a donation made in this way will probably not make me work on this
software much more, unless I get so many donations that I can consider working
on free software full time, which seems unlikely at best.

To donate, log into PayPal and send money to autarch@urth.org or use the
button on this page: L<http://www.urth.org/~autarch/fs-donation.html>

=head1 CREDITS

The idea for this functionality and some of its implementation was originally
created as L<Class::MOP::Deprecated> by Goro Fuji.

=cut