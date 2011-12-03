#!perl -w
use Test::More;
use Test::Name::FromLine;
use Data::Util qw/:check/;

use t::Utils;

use TengA::DataFactory;

my $teng = t::Utils->prepare_teng;
my $df = TengA::DataFactory->new(teng => $teng);

subtest("simple data create", sub {

    $df->define("user1", +{
        table => "user",
        data => +{
            id => 1,
            item_id => 1,
            age => 18,
            name => "nobuo",
            gender => "male",
            country => "JPN",
        }
    });

    ok(is_hash_ref($df->{_templates}{"user1"}));

    #note explain $teng;
    $df->create("user1");

    ok($teng->single("user", +{ id => 1 }));
});

subtest("data autofill", sub {

    $df->define("user2", +{
        table => "user",
        data => +{
            id => 2,
            item_id => 1,
            age => 18,
        }
    });

    ok(is_hash_ref($df->{_templates}{"user2"}));

    $df->create("user2");

    ok($teng->single("user", +{ id => 2 }));
});

subtest("simple data create with dbh", sub {

    $df->define("user3", +{
        table => "user",
        data => +{
            id => 3,
            item_id => 1,
            age => 18,
            name => "nobuo",
            gender => "male",
            country => "JPN",
        }
    });

    ok(is_hash_ref($df->{_templates}{"user3"}));

    $df->create("user3");

    ok($teng->single("user", +{ id => 3 }));
});

done_testing;
