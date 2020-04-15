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
    'password' => 'Not Required'
);

sub main
{
    ok( $duo->load_cookies('xt/duo/cookies.txt'), 'Loaded Cookies'); # For now we are just going to assume the cookie is valid.

    my $expected_id = $info_id;

=head1 This test is unnecessary because the second one does it to determine the ID, but you can uncomment to run if you want.

    $duo->web_user_info_p($info_name)->then(sub
    {
        my $json = shift;
        my $got_id = $json->{'id'};

        is( $got_id, $expected_id, "Retrieve Web User Info using a username" );
    })->wait;

=cut

    $duo->android_user_info_p($info_name)->then(sub
    {
        my $json = shift;
        my $got_id = $json->{'id'};

        is( $got_id, $expected_id, "Retrieve Android User Info using a username" );
    })->wait;

}

main();

done_testing();
