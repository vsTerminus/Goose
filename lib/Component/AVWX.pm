package Component::AVWX;

# AVWX provides METARs via REST api

use feature 'say';
use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::URL;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(metar);

# The API does not have a key but is public so I have no qualms about including the URL here.
has api_url => ( is => 'ro', default => 'https://avwx.rest/api/metar/' );
has token   => ( is => 'ro' );
has ua      => ( is => 'rw', builder => sub { 
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->inactivity_timeout(120);
        return $ua;
    });

sub metar
{
    my ($self, $icao) = @_;

    my $promise = Mojo::Promise->new();
    
    unless ( defined $self->token )
    {
        $promise->reject( { 'code' => -1, 'message' => 'Missing or invalid API token' } );
        return $promise;
    }
    unless ( defined $icao and $icao =~ /^[a-zA-Z0-9]{3,4}$/ )
    {
        $promise->reject( { 'code' => -1, 'message' => 'Invalid ICAO code' } );
        return $promise;
    }

    my $url = Mojo::URL->new($self->api_url . $icao );
    $url->query(airport => 'true',
                format  => 'json',
                onfail  => 'cache',
                token   => $self->token);

    $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;
            if ( $tx->error and $tx->error->{'code'} )
            {
                say Dumper($tx->error);
                my $error = { 'code' => $tx->error->{'code'}, 'message' => 'Could not retrieve METAR from AVWX API'};
                $promise->resolve($error);
                return $promise;
            }
            elsif ( $tx->res->code and $tx->res->code == 200 and !defined $tx->res->json->{'sanitized'} )
            {
                my $error = { 'code' => $tx->res->code, 'message' => 'AVWX API returned OK but did not include a sanitized METAR string' };
                $promise->resolve($error);
                return $promise;
            }
            elsif ( $tx->res->code and $tx->res->code != 200 )
            {
                my $error = { 'code' => $tx->res->code, 'message' => 'Could not retrieve METAR from AVWX API' };
                $promise->resolve($error);
                return $promise;
            }
            
            my $json = $tx->res->json;
            $json->{'code'} = $tx->res->code;
            $promise->resolve($json);
        })->catch(sub
        {
            my $error = shift;

            say Dumper($error);
            $promise->resolve($error);
        }
    );
    return $promise;
}

1;
