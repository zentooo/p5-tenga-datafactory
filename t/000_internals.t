#!perl -w
use Test::More;
use Test::Name::FromLine;
use Data::Util qw/:check/;

use t::Utils;

use TengA::DataFactory;

my $teng = t::Utils->prepare_teng;
my $df = TengA::DataFactory->new(teng => $teng);

$df->define("user1", +{
    table => "user",
    data => +{
        id => 1,
        age => 18,
        name => "nobuo",
        gender => "male",
        country => "USA",
    }
});

$df->trait("Adult", +{
    age => 20
});
$df->trait("Japanese girl", +{
    country => "JPN",
    gender => "female",
});

subtest("merge_data (parent)", sub {
    $df->define("user2", +{
        extend => "user1",
        data => +{
            id => 2,
            name => "sachiko",
            gender => "female",
        }
    });

    my $merged_data = $df->_merge_data($df->{_templates}{"user2"});
    is($merged_data->{id}, 2);
    is($merged_data->{name}, "sachiko");
});

subtest("merge_data (parent and traits)", sub {
    $df->define("user3", +{
        extend => "user1",
        data => +{
            id => 3,
            age => 18,
        },
        traits => ["Adult", "Japanese girl"],
    });

    my $merged_data = $df->_merge_data($df->{_templates}{"user3"});
    is($merged_data->{country}, "JPN", "country comes from trait");
    is($merged_data->{age}, 18, "age is overridden with self param");
});

subtest("merge_data (parent and traits and runtime parameter)", sub {
    $df->define("user4", +{
        extend => "user1",
        data => +{
            id => 3,
            age => 18,
        },
        traits => ["Adult", "Japanese girl"],
    });

    my $merged_data = $df->_merge_data($df->{_templates}{"user3"}, +{ id => 5 });
    is($merged_data->{country}, "JPN", "country comes from trait");
    is($merged_data->{age}, 18, "age is overridden with self param");
    is($merged_data->{id}, 5, "id comes from runtime parameter");
});

subtest("check_and_fill_data", sub {
    my $filled_data = $df->_check_and_fill_data("user", +{
        id => 6,
        age => sub { 18 },
    });
    ok(is_value($filled_data->{country}));
    ok(is_value($filled_data->{gender}));
    is($filled_data->{age}, 18);
});

done_testing;
