use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;
use Config::Tiny;

require_ok( 'Component::BunniesAPI' );

my $bunnies = Component::BunniesAPI->new();

memory_cycle_ok($bunnies, "No Memory Cycles");
weakened_memory_cycle_ok($bunnies, "No Weakened Memory Cycles");

done_testing();
