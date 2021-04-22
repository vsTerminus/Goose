use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;
use Config::Tiny;

require_ok( 'Component::DogAPI' );

my $dog = Component::DogAPI->new();

memory_cycle_ok($dog, "No Memory Cycles");
weakened_memory_cycle_ok($dog, "No Weakened Memory Cycles");

done_testing();
