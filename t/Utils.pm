package t::Utils;
use strict;
use warnings;
use utf8;
use lib './t/lib';

use Test::More;

use Teng;
use Teng::Schema::Loader;


BEGIN {
    eval "use DBD::SQLite";
    plan skip_all => 'needs DBD::SQLite for testing' if $@;
}

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

sub create_sqlite {
    my $dbh = shift;
    $dbh->do(q{
        CREATE TABLE user (
            id   integer,
            item_id integer,
            age  integer,
            name text,
            gender text,
            country text,
            primary key ( id )
        )
    });
    $dbh->do(q{
        CREATE TABLE item (
            id   integer,
            name text,
            primary key ( id )
        )
    });
}

sub setup_dbh {
    shift;
    my $file = shift || ':memory:';
    DBI->connect('dbi:SQLite:'.$file,'','',{RaiseError => 1, PrintError => 0, AutoCommit => 1});
}

sub prepare_teng {
    my $dbh = setup_dbh();
    create_sqlite($dbh);
    my $schema = Teng::Schema::Loader->load(
        dbh => $dbh,
        namespace => "FlipHole",
    );
    return Teng->new(dbh => $dbh, schema => $schema);
}

1;
