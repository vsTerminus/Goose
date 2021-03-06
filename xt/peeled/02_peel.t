use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(dies_ok);
use Mojo::Promise;
use Config::Tiny;
use File::Remove qw(remove);
use Data::Dumper;

my $config = Config::Tiny->read( 'xt/peeled/peeled.ini' );
my $api_url = $config->{'api'}{'url'};

require_ok( 'Component::Peeled' );

my $peeled = Component::Peeled->new(
    'api_url' => $api_url,
);

my $pass_name = 'mew';
my $expected_json = {
    'dex_no' => 151,
    'image_url' => 'https://pbs.twimg.com/media/EmguSqyXcAM6rcq.png',
    'tweet_url' => 'https://twitter.com/i/status/1326361032848257024',
};

my $fail_name = 'mewthree';
my $expected_error = { 
    'code' => 404, 
    'error' => 'Pokemon does not exist or has not yet been peeled'
}; 

sub main
{
    # Test pass
    $peeled->peel($pass_name)->then(sub
    {
        my $got_json = shift;
        is_deeply( $got_json, $expected_json, "Pokemon '$pass_name' returned expected fetched results" );
    })->catch(sub
    {
        fail(shift->{'error'});
    })->wait();

    # Test fail
    $peeled->peel($fail_name)->then(sub
    {
        fail("There should not be a pokemon named '$fail_name' but the API returned success.");
    })->catch(sub
    {
        my $got_error = shift;
        is_deeply( $got_error, $expected_error, "Pokemon '$fail_name' does not exist, API returns 404" );
    })->wait();
}
main();

done_testing();
