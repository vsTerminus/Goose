package Component::SomeRandomAPI;

use feature 'say';
use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::URL;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(random);

has api_url => ( is => 'ro', default => 'https://some-random-api.ml' );
has ua      => ( is => 'rw', builder => sub { 
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->inactivity_timeout(120);
        return $ua;
    });

sub animal
{
    my ($self, $animal) = @_;

    say "Getting a random '$animal'";
    my $promise = Mojo::Promise->new();
    my $url = Mojo::URL->new($self->api_url);
    $url->path("/animal/$animal");

    $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;
            unless ( $tx->res->code == 200 )
            {
                my $error = { 'code' => $tx->res->code, 'error' => 'Could not retrieve a random "' . $animal . '" from the Some-Random API' };
                $promise->resolve($error);
                return $promise;
            }
            if ( $tx->res->code == 200 and !defined $tx->res->json->{'image'} )
            {
                my $error = { 'code' => 404, 'error' => 'Some-Random API returned OK but did not include an image URL' };
                $promise->resolve($error);
                return $promise;
            }
            
            my $json = $tx->res->json;
            $json->{'code'} = $tx->res->code;
            $promise->resolve($json);
        })->catch(sub
        {
            my $error = shift;
            $promise->resolve($error)
        }
    );
    return $promise;
}

1;
