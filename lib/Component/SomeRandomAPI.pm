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
    
    return $self->random('animal', $animal);
}

sub animu
{
    my ($self, $animu) = @_;

    return $self->random('animu', $animu);
}

sub random
{
    my ($self, $category, $thing) = @_;

    my $promise = Mojo::Promise->new();
    my $url = Mojo::URL->new($self->api_url);
    $url->path("/$category/$thing");

    $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;
            unless ( $tx->res->code == 200 )
            {
                my $error = { 'code' => $tx->res->code, 'error' => 'Could not retrieve a random "' . $thing . '" from the Some-Random API' };
                $promise->resolve($error);
                return $promise;
            }

            my $json;
            if ( $tx->res->code == 200 )
            {
                $json->{'code'} = $tx->res->code;
                if ( defined $tx->res->json->{'image'} )
                {
                    $json->{'image'} = $tx->res->json->{'image'};
                }
                elsif ( defined $tx->res->json->{'link'} )
                {
                    $json->{'image'} = $tx->res->json->{'link'};
                }
                
                $promise->resolve($json);
            }
            else
            {
                my $error = { 'code' => 404, 'error' => 'Some-Random API returned OK but did not include an image URL' };
                $promise->resolve($error);
                return $promise;
            }
        })->catch(sub
        {
            my $error = shift;
            $promise->resolve($error)
        }
    );
    return $promise;
}

1;
