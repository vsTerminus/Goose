package Component::DuckAPI;

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

# The API does not have a key but is public so I have no qualms about including the URL here.
has api_url => ( is => 'ro', default => 'https://random-d.uk/api/v1/random?type=png' );
has ua      => ( is => 'rw', builder => sub { 
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->inactivity_timeout(120);
        return $ua;
    });

sub random
{
    my $self = shift;

    my $promise = Mojo::Promise->new();
    my $url = Mojo::URL->new($self->api_url);

    $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;
            unless ( $tx->res->code == 200 )
            {
                my $error = { 'code' => $tx->res->code, 'error' => 'Could not retrieve a random duck from the Duck API' };
                $promise->resolve($error);
                return $promise;
            }
            if ( $tx->res->code == 200 and !defined $tx->res->json->{'url'} )
            {
                my $error = { 'code' => 404, 'error' => 'Duck API returned OK but did not include an image URL' };
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
