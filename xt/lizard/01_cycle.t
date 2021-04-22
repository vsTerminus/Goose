use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;
use Config::Tiny;

require_ok( 'Component::LizardAPI' );

my $lizard = Component::LizardAPI->new();

memory_cycle_ok($lizard, "No Memory Cycles");
weakened_memory_cycle_ok($lizard, "No Weakened Memory Cycles");

done_testing();
