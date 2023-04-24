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
my $info_id = $config->{'users'}{'info_id'};
my $info_name = $config->{'users'}{'info_name'};
my $my_id = $config->{'users'}{'my_id'};
my $my_name = $config->{'login'}{'username'};
my $duo = Component::Duolingo->new(
    'username' => $my_name,
);

sub main
{
    ok( $duo->load_cookies('xt/duo/cookies.txt'), 'Loaded Cookies'); # For now we are just going to assume the cookie is valid.
    ok($duo->jwt, "JWT Captured");
    ok($duo->csrf, "CSRF Captured");

    my $expected_id = $info_id;
    $duo->user_id_p($info_name)->then(sub
    {
        my $got = shift;
        is( $got, $expected_id, "Convert Username into User ID" ); 
    })->catch(sub
    {
        my $error = shift;
        say $error;
    })->wait;
}

main();

done_testing();
