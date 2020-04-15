use Mojo::Base -strict;

use Test::More;
use Test::Memory::Cycle;

require_ok( 'Component::Duolingo');

my $duo = Component::Duolingo->new(
    'username' => 'user',
    'password' => 'pass',
);

memory_cycle_ok($duo, "No Memory Cycles");
weakened_memory_cycle_ok($duo, "No Weakened Memory Cycles");

done_testing();
