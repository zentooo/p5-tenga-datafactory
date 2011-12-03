#!perl -w
use strict;
use Test::More;
use Test::Name::FromLine;

use TengA::DataFactory;

use t::Utils;

my $teng = t::Utils->prepare_teng;

subtest("data creation with extend", sub {
    my $df = TengA::DataFactory->new(teng => $teng);

    $df->define("user1", +{
        table => "user",
        data => +{
            id => 1,
            age => 18,
            name => "nobuo",
            gender => "male",
            country => "JPN",
        }
    });

    $df->define("user2", +{
        extend => "user1",
        data => +{
            id => 2,
            gender => sub { "female" },
        }
    });

    my $user2 = $df->create("user2");

    ok($user2);
    is($user2->gender, "female");
});

done_testing;
