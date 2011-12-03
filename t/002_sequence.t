#!perl -w
use strict;
use Test::More;
use Test::Name::FromLine;

use TengA::DataFactory;

use t::Utils;

my $teng = t::Utils->prepare_teng;

subtest("data creation with sequence", sub {
    my $df = TengA::DataFactory->new(teng => $teng);

    $df->sequence("ten", sub {
        my $n = shift;
        return $n * 10;
    });

    $df->define("user_base", +{
        table => "user",
        data => +{
            id => $df->seq,
            item_id => $df->seq("ten"),
            age => $df->seq,
            name => "nobuo",
            gender => "male",
            country => "JPN",
        }
    });

    $df->define("user1", +{
        extend => "user_base",
        data => +{
            name => "hoge",
        }
    });

    $df->define("user2", +{
        extend => "user_base",
        data => +{
            gender => sub { "female" },
        }
    });

    my $user1 = $df->create("user1");
    my $user2 = $df->create("user2");

    is($user1->age, 1);
    is($user1->item_id, 10);

    is($user2->age, 2);
    is($user2->item_id, 20);
});

done_testing;
