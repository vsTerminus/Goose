use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(dies_ok);
use Mojo::Promise;
use Mojo::UserAgent::CookieJar::Role::Persistent;
use Config::Tiny;
use File::Remove qw(remove);

my $config = Config::Tiny->read( 'xt/duo/duolingo.ini' );
my $username = $config->{'login'}{'username'};
my $jwt = $config->{'login'}{'jwt'};
my $csrf = $config->{'login'}{'csrf'};

say "Login as: " . $username;

my $cookie_file = 'xt/duo/cookies.txt';

require_ok( 'Component::Duolingo' );

my $duo = Component::Duolingo->new(
    'username'  => $username,
);

ok(-f $cookie_file, "Found cookies.txt");
ok($duo->load_cookies($cookie_file), "Loaded cookies.txt");
ok($duo->jwt, "JWT Captured");
ok($duo->csrf, "CSRF Captured");

done_testing();
