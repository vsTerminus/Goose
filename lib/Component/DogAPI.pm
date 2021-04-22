package Component::DogAPI;

use feature 'say';
use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::URL;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(random breed);

# The API does not have a key but is public so I have no qualms about including the URL here.
has api_url => ( is => 'ro', default => 'https://dog.ceo/api/' );
has ua      => ( is => 'rw', builder => sub { 
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->inactivity_timeout(120);
        return $ua;
    });

sub random
{
    my $self = shift;

    my $url = Mojo::URL->new($self->api_url)->path('breeds/image/random');
    return $self->_fetch($url);
}

sub breed
{
    my ($self, $breed) = @_;

    $breed = lc $breed;
    my $url = Mojo::URL->new($self->api_url)->path("breed/$breed/images/random");
    return $self->_fetch($url);
}


sub _fetch
{
    my ($self, $url) = @_;

    my $promise = Mojo::Promise->new();

    $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;
            unless ( $tx->res->code == 200 )
            {
                my $error = { 'code' => $tx->res->code, 'error' => 'Could not retrieve a random dog from the Dog API' };
                $promise->resolve($error);
                return $promise;
            }
            if ( $tx->res->code == 200 and !defined $tx->res->json->{'message'} )
            {
                my $error = { 'code' => 404, 'error' => $tx->res->json->{'status'} };
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
