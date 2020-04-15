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
my $follow_id = $config->{'users'}{'follow_id'};
my $follow_name = $config->{'users'}{'follow_name'};
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

    $duo->unfollow_p($follow_id)->then(sub
    {
        my $json = shift;
        is_deeply($json, {}, 'Empty Set response');
    })->wait;
}

main();

done_testing();
