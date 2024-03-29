package TengA::DataFactory;
use 5.008_001;
use strict;
use warnings;

use Teng;
use Teng::Schema::Loader;

use Carp qw/croak/;
use Data::Util qw/:check/;
use Hash::Merge::Simple qw/merge/;
use Time::Piece::MySQL;
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

    my $n = 1;
    $opts->{_sequences}{"__identity__"} = sub {
        return $n++;
    };

    bless $opts, $class;
}

sub define {
    my ($self, $name, $params) = @_;

    croak "table name or parent template name should be specified." if ! $params->{table} && ! $params->{extend};
    croak sprintf("template already exists: %s", $name) if $self->{_templates}{$name};

    $self->{_templates}{$name} = $params || +{};
}

sub define_seq {
    my ($self, $seq_name, $callback, $init) = @_;
    croak sprintf("sequence already exists: %s", $seq_name) if $self->{_sequences}{$seq_name};

    my $n = $init || 1;
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
    croak sprintf("trait already exists: %s", $trait_name) if $self->{_traits}{$trait_name};
    $self->{_traits}{$trait_name} = $params;
}

sub create {
    my ($self, $name, $params) = @_;

    croak sprintf("data already created: %s", $name) if $self->{_rows}{$name};
    my $template = $self->{_templates}{$name} or croak sprintf("template not found: %s", $name);

    my $table = $template->{table} ? $template->{table} : $self->_resolve_table($template->{extend});
    croak sprintf("there are no such table: %s", $table) unless $self->{teng}->schema->get_table($table);

    my $data = $self->_merge_data($template, $template->{data}, $params);

    return ($self->{_rows}{$name} = $self->{teng}->insert($table, $self->_check_and_fill_data($table, $data)));
}

sub delete {
    my ($self, $name) = @_;
    croak sprintf("data seems not to be created yet: %s", $name) unless defined $self->{_rows}{$name};
    $self->{_rows}{$name}->delete && delete $self->{_rows}{$name};
}

sub delete_all {
    my ($self) = @_;
    for my $key (keys %{$self->{_rows}} ) {
        $self->{_rows}{$key}->delete && delete $self->{_rows}{$key};
    }
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
            $filled_data->{$column} = $data->{$column}->($table, $column);
        }
        else {
            $filled_data->{$column} = $data->{$column};
        }
    }

    return $filled_data;
}

sub _generate_data {
    my ($self, $sql_type) = @_;

    return int(rand(1) * 10000000) unless $sql_type;

    # looks like integer
    if ( $sql_type == 4 ) {
        return $self->seq("__identity__")->();
    }
    # looks like float
    elsif ( $sql_type == 6 || $sql_type == 8 ) {
        return rand(6);
    }
    # looks like string
    elsif ( $sql_type == 1 || $sql_type == 12 ) {
        return $self->{string_random}->randregex("[A-Za-z0-9]{32}");
    }
    # looks like date
    elsif ( $sql_type == 9 ) {
        return localtime()->mysql_date;
    }
    # looks like time
    elsif ( $sql_type == 10 ) {
        return localtime()->mysql_time;
    }
    # looks like datetime or timestamp
    elsif ( $sql_type == 11 ) {
        return localtime()->mysql_datetime;
    }
    else {
        return int(rand(1) * 10000000);
    }
}

1;
__END__

=head1 NAME

TengA::DataFactory - create test data easily with Teng

=head1 VERSION

This document describes TengA::DataFactory version 0.01.

=head1 SYNOPSIS

    use TengA::DataFactory;

    my $df = TengA::DataFactory->new(teng => $teng); # teng instance

    $df->define("user_base", +{
        table => "user",
        data => +{
            id => $df->seq,
            name => "foo",
            country => "Japan",
            address => "bar"
        }
    });

    $df->define("nobita", +{
        extend => "user_base",
        data => +{
            name => "Nobi Nobita",
        }
    });

    $df->create("nobita"); # data created with defined parameter, inherited parameter and auto-filled values

=head1 DESCRIPTION

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
