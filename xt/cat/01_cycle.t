use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;
use Config::Tiny;

require_ok( 'Component::CatAPI' );

my $cat = Component::CatAPI->new();

memory_cycle_ok($cat, "No Memory Cycles");
weakened_memory_cycle_ok($cat, "No Weakened Memory Cycles");

done_testing();
