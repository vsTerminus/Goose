use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;
use Config::Tiny;

my $config = Config::Tiny->read( 'xt/peeled/peeled.ini' );
my $api_url = $config->{'api'}{'url'};

require_ok( 'Component::Peeled' );

my $peeled = Component::Peeled->new(
    'api_url' => $api_url,
);

memory_cycle_ok($peeled, "No Memory Cycles");
weakened_memory_cycle_ok($peeled, "No Weakened Memory Cycles");

done_testing();
