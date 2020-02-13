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
async weather => sub
{
    my ($self, $lat, $lon) = @_;
    my $url = $self->api_url . '/' . $self->api_key . '/' . $lat . ',' . $lon;

    my $tx = await $self->ua->get_p($url);
    my $json = $tx->res->json;

    # Temperature, Feels Like, and Wind Speed should be provided in both units.
    # Wind direction should be provided in English 16-point compass rose directions.
    $json->{'currently'}{'temperature_c'} = ftoc($json->{'currently'}{'temperature'});
    $json->{'currently'}{'apparentTemperature_c'} = ftoc($json->{'currently'}{'apparentTemperature'});
    $json->{'currently'}{'windSpeed_km'} = kph($json->{'currently'}{'windSpeed'});
    $json->{'currently'}{'windBearing'} = wind_direction($json->{'currently'}{'windBearing'});

    # Create 'icon_url' and 'icon_emote'
    $json->{'currently'}{'icon_url'} = icon_url($json->{'currently'}{'icon'});
    $json->{'currently'}{'icon_emote'} = icon_emote($json->{'currently'}{'icon'});

    # Return only the current conditions
    return $json->{'currently'};
};

sub icon_url
{
    my $code = shift;

    my %codes = (
        'clear-day'             => 'http://i.imgur.com/HIQkdIt.png',
        'clear-night'           => 'http://i.imgur.com/sbsDekE.png',
        'rain'                  => 'http://i.imgur.com/oB7xaGs.png',
        'snow'                  => 'http://i.imgur.com/gEBNP3r.png',
        'sleet'                 => 'http://i.imgur.com/veklDbN.png',
        'wind'                  => 'http://i.imgur.com/Saq1Hvo.png',
        'fog'                   => 'http://i.imgur.com/Fh2kqYX.png',
        'cloudy'                => 'http://i.imgur.com/Zk3iwN6.png',
        'partly-cloudy-day'     => 'http://i.imgur.com/Hu9yAZm.png',
        'partly-cloudy-night'   => 'http://i.imgur.com/J0fcEhu.png',
        'tornado'               => 'http://i.imgur.com/3cqR9To.png',
        'hail'                  => 'http://i.imgur.com/OdRYPri.png',
    );

    return $codes{$code};
}

sub icon_emote
{
    my $code = shift;

    my %codes = (
        'clear-day'             => ':sun_with_face:',
        'clear-night'           => ':full_moon_with_face:',
        'rain'                  => ':cloud_rain:',
        'snow'                  => ':cloud_snow:',
        'sleet'                 => ':cloud_snow:',
        'wind'                  => ':dash:',
        'fog'                   => ':cloud:',
        'cloudy'                => ':cloud:',
        'partly-cloudy-day'     => ':partly_sunny:',
        'partly-cloudy-night'   => ':white_sun_cloud:',
        'tornado'               => ':cloud_tornado:',
        'thunderstorm'          => ':thunder_cloud_rain:',
        'hail'                  => ':cloud_snow:',
    );

    return $codes{$code};
}

sub ftoc
{
    my $f = shift;
    return ($f - 32) / (1.8);
}

sub kph
{
    my $mph = shift;
    return sprintf("%0.1f", ($mph * 1.609344));
}

sub wind_direction
{
    my $deg = shift;

    my @dirs = qw[North North-Northeast Northeast East-Northeast East East-Southeast Southeast South-Southeast South South-Southwest Southwest West-Southwest West West-Northwest Northwest North-Northwest];

    my $val = int(($deg/22.5)+.5);
    return $dirs[$val%16];
}

__PACKAGE__->meta->make_immutable;

1;
