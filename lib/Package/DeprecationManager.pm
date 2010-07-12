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
        my ( $package, undef, undef, $sub ) = caller(1);

        my $compat_version = $registry->{$package};

        my $deprecated_at = $deprecated_at->{$sub};

        return
            if defined $compat_version
                && defined $deprecated_at
                && $compat_version lt $deprecated_at;

        return if $warned{$package}{$sub};

        if ( ! @_ ) {
            my $msg = "$sub has been deprecated";
            $msg .= " since version $deprecated_at"
                if defined $deprecated_at;

            @_ = $msg;
        }

        $warned{$package}{$sub} = 1;

        goto &Carp::cluck;
    };
}

1;

# ABSTRACT: Manage deprecation warnings for your distribution

__END__

=pod

=head1 SYNOPSIS

  ...

=head1 DESCRIPTION

=cut
