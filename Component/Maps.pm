package Component::Maps;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(geocode);

use Mojo::UserAgent;
use Data::Dumper;

# This module connects to the Google Maps API

sub new
{
    my ($class, %params) = @_;
    my $self = {};
   
    my $api_key = $params{'api_key'};
    my $api_url = 'https://maps.googleapis.com/maps';
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(5);

    $self->{'ua'} = $ua;
    $self->{'api_key'} = $api_key;
    $self->{'api_url'} = $api_url;
    
    bless($self, $class); 
    return $self;
}

# Returns lat/long coords for supplied address string
sub geocode
{
    my ($self, $addr, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};
    $addr =~ s/ /+/g; # Replace spaces with + for the URL
    my $url     = $api_url . '/api/geocode/json?key=' . $api_key . '&address=' . $addr;

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;
        
        # Send back the first result only.
        my $result = $json->{'results'}[0];

        $callback->($result);
    });
}

1;
