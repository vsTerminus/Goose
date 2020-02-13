package Component::Maps;

use feature 'say';

use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::AsyncAwait;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(geocode);

has api_url     => ( is => 'ro', default => 'https://maps.googleapis.com/maps' );
has api_key     => ( is => 'ro' );
has ua          => ( is => 'lazy', builder => sub { my $ua =  Mojo::UserAgent->new; $ua->connect_timeout(5); } );

# Returns lat/long coords for supplied address string
async geocode => sub
{
    my ($self, $addr) = @_;

    $addr =~ s/ /+/g; # Replace spaces with + for the URL
    my $url     = $self->api_url . '/api/geocode/json?key=' . $self->api_key . '&address=' . $addr;

    my $tx = await $self->ua->get_p($url);

    my $json = $tx->res->json;
        
    # Send back the first result only.
    my $result = $json->{'results'}[0];

    return $result;
};

1;
