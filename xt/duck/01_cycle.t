use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;
use Config::Tiny;

require_ok( 'Component::DuckAPI' );

my $duck = Component::DuckAPI->new();

memory_cycle_ok($duck, "No Memory Cycles");
weakened_memory_cycle_ok($duck, "No Weakened Memory Cycles");

done_testing();
