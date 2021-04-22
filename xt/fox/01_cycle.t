use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;
use Config::Tiny;

require_ok( 'Component::FoxAPI' );

my $fox = Component::FoxAPI->new();

memory_cycle_ok($fox, "No Memory Cycles");
weakened_memory_cycle_ok($fox, "No Weakened Memory Cycles");

done_testing();
