package Component::CatAPI;

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

has api_key => ( is => 'ro', default => 'none' ); # Doesn't seem to be required??? API returns reasults with or without the api_key parameter.
has api_url => ( is => 'ro', default => sub {
        my $self = shift;
        my $url = Mojo::URL->new('https://api.thecatapi.com/v1/images/search')->query('api_key' => $self->api_key);
    });
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
                my $error = { 'code' => $tx->res->code, 'error' => 'Could not retrieve a random cat from the Cat API' };
                $promise->reject($error);
                return $promise;
            }
            if ( $tx->res->code == 200 and !defined $tx->res->json->[0]->{'url'} )
            {
                my $error = { 'code' => 404, 'error' => 'The Cat API returned OK but did not provide a valid URL' };
                $promise->reject($error);
                return $promise;
            }
            
            my $json = $tx->res->json->[0];
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
