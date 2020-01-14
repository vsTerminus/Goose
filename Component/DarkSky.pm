package Component::DarkSky;

use feature 'say';
use Moo;

use Mojo::UserAgent;
use Mojo::AsyncAwait;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(weather);

has api_key     => ( is => 'ro' );
has api_url     => ( is => 'ro', default => 'https://api.darksky.net/forecast' );
has ua          => ( is => 'rw', default => sub { Mojo::UserAgent->new } );


sub BUILD
{
    my $self = shift;
   
    $self->ua->connect_timeout(5);
    $self->ua->inactivity_timeout(120);
}

# Queries the API for weather by Latitude and Longitude
# JSON results are returned or provided to a callback if defined.
async weather => sub
{
    my ($self, $lat, $lon, $callback) = @_;
    my $url = $self->api_url . '/' . $self->api_key . '/' . $lat . ',' . $lon;

    my $tx = await $self->ua->get_p($url);
    my $json = $tx->res->json;

    # Return only the current conditions
    ( defined $callback ) ? $callback->($json->{'currently'}) : return $json->{'currently'};
};

__PACKAGE__->meta->make_immutable;

1;
