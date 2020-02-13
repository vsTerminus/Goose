package Component::OpenWeather;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(weather forecast);

use Mojo::UserAgent;
use Data::Dumper;

# This module exists to make it easier to include the database in command modules.
# The modules don't have to care about connection info or manually connecting, they can just call this module's 'do' function.

sub new
{
    my ($class, %params) = @_;
    my $self = {};
   
    my $api_key = $params{'api_key'};
    my $api_url = 'http://api.openweathermap.org/data/2.5/';
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(5);

    $self->{'ua'} = $ua;
    $self->{'api_key'} = $api_key;
    $self->{'api_url'} = $api_url;

    bless($self, $class); 
    return $self;
}

# Queries the API for weather by City Name or by Zip/Postal Code
# and then calls the appropriate function. That function will call the provided callback and supply the results.
sub weather
{
    my ($self, $q, $callback) = @_;

    # Is this a ZIP/Postal Code?
    if ( $q =~ /^(\d{5})|([A-Z][0-9][A-Z] ?[0-9][A-Z][0-9])$/i )
    {
        $self->weather_by_zip($q, $callback);
    }
    # Else, just search by City Name.
    else
    {
        $self->weather_by_name($q, $callback);
    }
}

# Looks up weather for a US Zip or Canadian Postal Code
# Sends the JSON results to the provided callback function.
sub weather_by_zip
{
    my ($self, $zip, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};

    my $ccode   = ( $zip =~ /^\d{5}$/ ? 'us' : 'ca' );
    $zip        =~ s/^(...)(...)$/$1 $2/ if ( $ccode eq 'ca' );    # API seems to require that space to be there, so make sure it is.

    my $url     = $api_url . '/weather?appid=' . $api_key . '&zip=' . $zip . '&units=metric&zip=' . $zip . ',' . $ccode;

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;

        $callback->($json);
    });
}

# Looks up weather by city name
# Sends the JSON results to the provided callback function
sub weather_by_name
{
    my ($self, $city, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};
    my $url     = $api_url . '/weather?appid=' . $api_key . '&q=' . $city . '&units=metric';

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;

        $callback->($json);
    });
}


1;
