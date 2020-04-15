use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(dies_ok);
use Mojo::Promise;
use Mojo::UserAgent::CookieJar::Role::Persistent;
use Config::Tiny;
use File::Remove qw(remove);

my $config = Config::Tiny->read( 'xt/duo/duolingo.ini' );
my $username = $config->{'login'}{'username'};
my $password = $config->{'login'}{'password'};

say "Login as: " . $username . '//' . $password;

my $cookie_file = 'xt/duo/cookies.txt';

remove($cookie_file);
ok(!-f $cookie_file, "Existing cookies removed");

require_ok( 'Component::Duolingo' );

my $duo = Component::Duolingo->new(
    'username' => $username,
    'password' => $password,
);

$duo->login_p()->wait;
sleep(1) while !$duo->jwt;
ok($duo->jwt, "JWT Captured");
ok($duo->csrf, "CSRF Captured");

my $ua = $duo->ua;
my $cookie_jar = $ua->cookie_jar;
$cookie_jar->with_roles('+Persistent')->file($cookie_file);
$cookie_jar->save;

ok(-f $cookie_file, "Session Stored");

done_testing();
