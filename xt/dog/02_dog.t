use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(dies_ok);
use Mojo::Promise;
use Config::Tiny;
use File::Remove qw(remove);
use Data::Dumper;

require_ok( 'Component::DogAPI' );

my $dog = Component::DogAPI->new();

sub main
{
    # Test random
    $dog->random()->then(sub
    {
        my $got_json = shift;
        is( $got_json->{'code'}, 200, "HTTP 200" );
        is( $got_json->{'status'}, "success", "success" );
        ok( $got_json->{'message'} =~ /^https:\/\//, "Looks like a valid link" );
    })->catch(sub
    {
        fail(shift->{'error'});
    })->wait();

    # Test breed
    $dog->breed('Corgi')->then(sub
    {
        my $got_json = shift;
        is( $got_json->{'code'}, 200, "HTTP 200" ); is( $got_json->{'status'}, "success", "success" );
        ok( $got_json->{'message'} =~ /^https:\/\//, "Looks like a valid link" );
    })->catch(sub
    {
        fail(shift->{'error'});
    })->wait();

}
main();

done_testing();
