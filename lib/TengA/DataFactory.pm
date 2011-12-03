package TengA::DataFactory;
use 5.008_001;
use strict;
use warnings;

use Teng;
use Teng::Schema::Loader;

use Carp qw/croak/;
use Data::Util qw/:check/;
use Hash::Merge::Simple qw/merge/;
use String::Random;

our $VERSION = '0.01';


sub new {
    my $class = shift;
    my $opts = ref $_[0] ? $_[0] : +{@_};

    if ( ! $opts->{teng} && ! $opts->{dbh} ) {
        croak "mandatory parameter teng or dbh missing.";
    }

    if ( $opts->{dbh} ) {
        my $schema = Teng::Schema::Loader->load(
            dbh => $opts->{dbh},
            namespace => ($opts->{namespace} || "TengA::DataFactory::" . time . rand(10))
        );
        $opts->{teng} = Teng->new(dbh => $opts->{dbh}, schema => $schema);
    }

    $opts->{_templates} = +{};
    $opts->{_sequences} = +{};
    $opts->{_traits} = +{};
    $opts->{_rows} = +{};

    $opts->{string_random} = String::Random->new;

    $opts->{_sequences}{"__identity__"} = sub {
        return shift;
    };

    bless $opts, $class;
}

sub define {
    my ($self, $name, $params) = @_;

    croak "table name or parent template name should be specified." if ! $params->{table} && ! $params->{extend};
    croak sprintf("data with given name already exists: %s", $name) if $self->{_templates}{$name};

    $self->{_templates}{$name} = $params || +{};
}

sub define_seq {
    my ($self, $seq_name, $callback) = @_;
    croak sprintf("sequence with given name already exists: %s", $seq_name) if $self->{_sequences}{$seq_name};

    my $n = 1;
    $self->{_sequences}{$seq_name} = sub {
        $callback->($n++);
    };
}

sub seq {
    my ($self, $seq_name) = @_;

    if ( $seq_name ) {
        return $self->{_sequences}{$seq_name};
    }
    else {
        my $seq_name = "__identity__" . time . rand(10);

        # default sequence: behave like auto_increment
        $self->define_seq($seq_name, sub {
            return shift;
        });
        return $self->{_sequences}{$seq_name};
    }
}

sub trait {
    my ($self, $trait_name, $params) = @_;
    croak sprintf("trait with given name already exists: %s", $trait_name) if $self->{_traits}{$trait_name};
    $self->{_traits}{$trait_name} = $params;
}

sub create {
    my ($self, $name, $params) = @_;

    my $template = $self->{_templates}{$name} or croak "specified data name not found";

    my $table = $template->{table} ? $template->{table} : $self->_resolve_table($template->{extend});
    croak sprintf("there are no such table: %s", $table) unless $self->{teng}->schema->get_table($table);

    my $data = $self->_merge_data($template, $template->{data}, $params);

    return ($self->{_rows}{$name} = $self->{teng}->insert($table, $self->_check_and_fill_data($table, $data)));
}

sub _merge_data {
    my ($self, $template, $params) = @_;

    # merge priority: parent < traits < (self) < runtime params

    my $merged_data = +{};

    if ( $template->{extend} ) {
        $merged_data = merge($merged_data, $self->{_templates}{$template->{extend}}{data});
    }

    if ( $template->{traits} ) {
        if ( is_string($template->{traits}) ) {
            $merged_data = merge($merged_data, $self->{_traits}{$template->{traits}});
        }
        elsif ( is_array_ref($template->{traits}) ) {
            $merged_data = merge($merged_data, $self->{_traits}{$_}) for @{$template->{traits}};
        }
    }

    $merged_data = merge($merged_data, $template->{data});

    $merged_data = merge($merged_data, $params) if $params;

    return $merged_data;
}

sub _resolve_table {
    my ($self, $parent_name) = @_;
    $self->{_templates}{$parent_name}{"table"};
}

sub _check_and_fill_data {
    my ($self, $table, $data) = @_;
    my $table_schema = $self->{teng}->schema->get_table($table);

    my $filled_data = +{};

    for my $column (@{$table_schema->columns}) {
        if ( ! defined $data->{$column} ) {
            $filled_data->{$column} = $self->_generate_data($table_schema->get_sql_type($column));
        }
        elsif ( ref $data->{$column} eq "CODE" ) {
            $filled_data->{$column} = $data->{$column}->();
        }
        else {
            $filled_data->{$column} = $data->{$column};
        }
    }

    return $filled_data;
}

sub _generate_data {
    my ($self, $sql_type) = @_;

    # integer like
    if ( $sql_type && $sql_type == 4 ) {
        return $self->seq("__identity__")->();
    }
    # string like
    elsif ( $sql_type && $sql_type == 12 ) {
        return $self->{string_random}->randregex("[A-Za-z0-9]{32}");
    }

    return int(rand(10) * 10);
}

1;
__END__

=head1 NAME

TengA::DataFactory - Perl extention to do something

=head1 VERSION

This document describes TengA::DataFactory version 0.01.

=head1 SYNOPSIS

    use TengA::DataFactory;

=head1 DESCRIPTION

# TODO

=head1 INTERFACE

=head2 Functions

=head3 C<< hello() >>

# TODO

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

L<perl>

=head1 AUTHOR

zentooo E<lt>ankerasoy@gmail.comE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2011, zentooo. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
