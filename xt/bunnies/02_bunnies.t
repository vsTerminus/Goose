use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(dies_ok);
use Mojo::Promise;
use Config::Tiny;
use File::Remove qw(remove);
use Data::Dumper;

require_ok( 'Component::BunniesAPI' );

my $bunnies = Component::BunniesAPI->new();

sub main
{
    # Test pass
    $bunnies->random()->then(sub
    {
        my $got_json = shift;
        is( $got_json->{'code'}, 200, "HTTP 200" );
        ok( $got_json->{'media'}{'gif'} =~ /^https:\/\/.*\.gif$/, "Looks like a valid link" );
    })->catch(sub
    {
        fail(shift->{'error'});
    })->wait();
}
main();

done_testing();
