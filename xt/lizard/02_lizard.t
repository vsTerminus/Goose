use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(dies_ok);
use Mojo::Promise;
use Config::Tiny;
use File::Remove qw(remove);
use Data::Dumper;

require_ok( 'Component::LizardAPI' );

my $lizard = Component::LizardAPI->new();

sub main
{
    # Test pass
    $lizard->random()->then(sub
    {
        my $got_json = shift;
        is( $got_json->{'code'}, 200, "HTTP 200" );
        ok( $got_json->{'url'} =~ /^https:\/\//, "Looks like a valid link" );
    })->catch(sub
    {
        fail(shift->{'error'});
    })->wait();
}
main();

done_testing();
