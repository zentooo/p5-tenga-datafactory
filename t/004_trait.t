#!perl -w
use strict;
use Test::More;
use Test::Name::FromLine;

use TengA::DataFactory;

use t::Utils;

my $teng = t::Utils->prepare_teng;

subtest("data creation with trait", sub {
    my $df = TengA::DataFactory->new(teng => $teng);

    $df->define("user_base", +{
        table => "user",
        data => +{
            id => $df->seq,
            item_id => $df->seq,
            age => 14,
            name => "nobuo",
            gender => "male",
            country => "JPN",
        }
    });

    $df->trait("Japanese boy", +{
        gender => 'male',
        country => "JPN",
    });

    $df->trait("American girl", +{
        gender => 'female',
        country => "USA",
    });

    $df->trait("Adult", +{
        age => 25,
    });

    $df->trait("Junior", +{
        age => 6,
    });

    $df->define("jungo", +{
       extend => "user_base",
       data => +{ name => "jungo" },
       traits => ["Japanese boy", "Adult"],
    });

    $df->define("kathy", +{
       extend => "user_base",
       data => +{ name => "kathy" },
       traits => ["American girl", "Junior"],
    });

    my $jungo = $df->create("jungo");
    my $kathy = $df->create("kathy");

    is($jungo->id, 1);
    is($jungo->item_id, 1);
    is($jungo->name, "jungo");
    is($jungo->gender, "male");
    is($jungo->country, "JPN");
    is($jungo->age, 25);

    is($kathy->id, 2);
    is($kathy->item_id, 2);
    is($kathy->name, "kathy");
    is($kathy->gender, "female");
    is($kathy->country, "USA");
    is($kathy->age, 6);

    # default value for type
    #$df->set_default("integer", 1);
});

done_testing;
