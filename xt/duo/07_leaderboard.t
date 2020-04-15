use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(dies_ok);
use Mojo::UserAgent::CookieJar::Role::Persistent;
use Mojo::URL;
use Mojo::Promise;
use Config::Tiny;
use Data::Dumper;

require_ok( 'Component::Duolingo' );

my $config = Config::Tiny->read( 'xt/duo/duolingo.ini' );
my $leader_id = $config->{'users'}{'leader_id'};
my $leader_name = $config->{'users'}{'leader_name'};
my $my_id = $config->{'users'}{'my_id'};
my $my_name = $config->{'login'}{'username'};

my $duo = Component::Duolingo->new(
    'username' => $my_name,
    'password' => 'Not Required',
    'user_id'  => $my_id,
);

sub main
{
    ok( $duo->load_cookies('xt/duo/cookies.txt'), 'Loaded Cookies'); # For now we are just going to assume the cookie is valid.

=head1 These are covered by the third test, but you can uncomment them if you want to run them explicitely.

    $duo->leaderboard_p($leader_id)->then(sub
    {
        my $json = shift;
        ok(exists $json->{'tier'}, "Retrieved a leaderboard league with a User ID");
    })->wait;

    # Try again with a username
    $duo->leaderboard_p($leader_name)->then(sub
    {
        my $json = shift;
        ok(exists $json->{'tier'}, "Retrieved a leaderboard league with a Username");
    })->wait;

=cut

    # Get the league name
    # It will convert to ID and then look up by ID.
    # This test covers basically all of the leaderboard functionality in one go.
    $duo->league_p($leader_name)->then(sub
    {
        my $league = shift;
        say "League: $league";
        ok($league, "Retrieved a league by name");
    })->wait;
}

main();

done_testing();
