package Component::DarkSky;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(weather);

use Mojo::UserAgent;
use Data::Dumper;

# This module exists to make it easier to include the database in command modules.
# The modules don't have to care about connection info or manually connecting, they can just call this module's 'do' function.

sub new
{
    my ($class, %params) = @_;
    my $self = {};
   
    my $api_key = $params{'api_key'};
    my $api_url = 'https://api.darksky.net/forecast';
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(5);

    $self->{'ua'} = $ua;
    $self->{'api_key'} = $api_key;
    $self->{'api_url'} = $api_url;

    bless($self, $class); 
    return $self;
}

# Queries the API for weather by Latitude and Longitude
# JSON results are provided to the callback function.
sub weather
{
    my ($self, $lat, $lon, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};

    my $url     = $api_url . "/$api_key/$lat,$lon";

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;

        # We're only dealing with current weather here, so don't send the historical/hourly/forecast stuff. Just current conditions.
        $callback->($json->{'currently'});
    });
}

1;
