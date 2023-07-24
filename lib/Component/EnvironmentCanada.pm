package Component::EnvironmentCanada;

use feature 'say';
use Moo;
use strictures 2;

use Mojo::UserAgent;
use Mojo::AsyncAwait;
use Mojo::DOM;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(weather);

has api_url     => ( is => 'ro', default => 'https://dd.weather.gc.ca/citypage_weather/xml' );
has site_list   => ( is => 'ro', default => 'https://dd.weather.gc.ca/citypage_weather/xml/siteList.xml' );
has ua          => ( is => 'rw', default => sub { Mojo::UserAgent->new } );

sub BUILD
{
    my $self = shift;

    $self->ua->connect_timeout(5);
    $self->ua->inactivity_timeout(120);

}

# Queries the API for weather by City and Province
# JSON results are provided to the callback function.
async weather => sub 
{
    my ($self, $city, $province) = @_;

    my ($tx, $dom, $site_code, $json);

    # First we need to figure out the URL for the XML file with our weather in it
    $tx = await $self->ua->get_p($self->site_list);
    $dom = Mojo::DOM->new->xml(1)->parse($tx->res->text);

    foreach my $site ($dom->find('site')->each)
    {
        my $name = $site->at('nameEn')->text;
        my $p_code = $site->at('provinceCode')->text;
        next unless $name =~ /$city/i and lc $p_code eq lc $province;

        $site_code = $site->{'code'};
        last;
    }

    return undef unless defined $site_code;

    my $weather_url = $self->api_url . '/' . (uc $province) . '/' . $site_code . '_e.xml'; #_e for english

    undef $tx; undef $dom;
    
    # Now get current conditions
    $tx = await $self->ua->get_p($weather_url);
    $dom = Mojo::DOM->new->xml(1)->parse($tx->res->text);
    my $curr = $dom->at('currentConditions');

    say "Weather URL: " . $weather_url;

    # Extract values needed by weather command, put them in a hash.
    $json = {
        'temperature_c'         => $curr->at('temperature')->text,
        'windBearing'           => wind_direction($curr->at('wind')->at('direction')->text),
        'windSpeed_km'          => $curr->at('wind')->at('speed')->text,
        'windGust_km'           => $curr->at('wind')->at('gust')->text,
        'humidity'              => $curr->at('relativeHumidity')->text,
    };

    $json->{'windSpeed_km'} = 0 if $json->{'windSpeed_km'} eq '' or lc $json->{'windSpeed_km'} eq 'calm';
    $json->{'windGust_km'} = 0 if $json->{'windGust_km'} eq '';

    # Looks like the Current Conditions and WindChill and Humidex are sometimes blank with Environment Canada
    # so we need to handle that.
    $json->{'apparentTemperature_c'} = $curr->at('temperature')->text; # Default to just the temperature.

    # Look for WindChill (Winter) or Humidex (Summer)
    $json->{'apparentTemperature_c'} = $curr->at('windChill')->text if ( defined $curr->at('windChill') );
    $json->{'apparentTemperature_c'} = $curr->at('humidex')->text if ( defined $curr->at('humidex') );

    $json->{'summary'} = ( length $curr->at('condition')->text ? $curr->at('condition')->text : 'Unknown' );

    if ( length $curr->at('iconCode')->text )
    {
        $json->{'icon'}         = $curr->at('iconCode')->text,
        $json->{'icon_url'}     = icon_url($json->{'icon'}),
        $json->{'icon_emote'}   = icon_emote($json->{'icon'}),
    }

    # Tempature, Feels Like, and Wind Speed should be provided in both units.
    $json->{'temperature'}          = ctof($json->{'temperature_c'});
    $json->{'apparentTemperature'}  = ctof($json->{'apparentTemperature_c'});
    $json->{'windSpeed'}            = mph($json->{'windSpeed_km'});
    $json->{'windGust'}             = mph($json->{'windGust_km'});

    # Weather Warnings
    if ( my $warn = $dom->at('warnings')->at('event') )
    {
        $json->{'warning'} = $warn->{'description'};
    }

    return $json;
};

sub icon_url
{
    my $code = shift;

    return 'https://weather.gc.ca/weathericons/' . $code . '.gif';
}

sub icon_emote
{
    my $code = shift;

    my %emotes = (
        '00'   => ':sun_with_face:',
        '01'   => ':sun_with_face:',
        '02'   => ':partly_sunny:',
        '03'   => ':partly_sunny:',
        '06'   => ':cloud_rain:',
        '07'   => ':cloud_rain:',
        '08'   => ':cloud_snow:',
        '10'  => ':cloud:',
        '11'  => ':cloud_rain:',
        '12'  => ':cloud_rain:',
        '13'  => ':cloud_rain:',
        '14'  => ':cloud_rain:',
        '15'  => ':cloud_snow:',
        '16'  => ':cloud_snow:',
        '17'  => ':cloud_snow:',
        '18'  => ':cloud_snow:',
        '19'  => ':thunder_cloud_rain:',
        '23'  => ':cloud:',
        '24'  => ':cloud:',
        '25'  => ':cloud_snow:',
        '26'  => ':snowflake:',
        '27'  => ':cloud_snow:',
        '28'  => ':cloud_rain:',
        '30'  => ':full_moon_with_face:',
        '31'  => ':full_moon_with_face:',
        '32'  => ':partly_sunny:',
        '33'  => ':partly_sunny:',
        '36'  => ':cloud_rain:',
        '37'  => ':cloud_rain:',
        '38'  => ':cloud_snow:',
        '39'  => ':thunder_cloud_rain:',
        '40'  => ':cloud_snow:',
        '41'  => ':cloud_tornado:',
        '42'  => ':cloud_tornado:',
        '43'  => ':dash:',
        '44'  => ':cloud:',
        '45'  => ':cloud_tornado:',
        '46'  => ':thunder_cloud_rain:',
        '47'  => ':thunder_cloud_rain:',
        '48'  => ':ocean:',
    );

    return $emotes{$code};
}



sub wind_direction
{
    my $in = shift;

    my %table = (
        'N'     => 'North',
        'E'     => 'East',
        'S'     => 'South',
        'W'     => 'West',
        'NE'    => 'Northeast',
        'SE'    => 'Southeast',
        'SW'    => 'Southwest',
        'NW'    => 'Northwest',
        'NNE'   => 'North-Northeast',
        'ENE'   => 'East-Northeast',
        'ESE'   => 'East-Southeast',
        'SSE'   => 'South-Southeast',
        'SSW'   => 'South-Southwest',
        'WSW'   => 'West-Southwest',
        'WNW'   => 'West-Northwest',
        'NNW'   => 'North-Northwest'
    );

    return $table{uc $in} // 'None';
}

sub ctof
{
    my $c = shift;
    return $c * (9/5) + 32;
}

sub mph
{
    my $kph = shift;
    return sprintf("%0.1f", ($kph / 1.609344));
}

__PACKAGE__->meta->make_immutable;

1;
