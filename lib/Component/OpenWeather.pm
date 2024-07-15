package Component::OpenWeather;

use feature 'say';
use Moo;

use Mojo::UserAgent;
use Mojo::Promise;
use Mojo::URL;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(weather);

has api_key     => ( is => 'ro' );
has api_url     => ( is => 'ro', default => 'https://api.openweathermap.org' );
has ua          => ( is => 'rw', default => sub { Mojo::UserAgent->new } );

sub BUILD
{
    my $self = shift;

    $self->ua->connect_timeout(5);
    $self->ua->inactivity_timeout(120);
}

# Queries the OpenWeatherMap API for current weather by coords
# Is asynchronous and returns a promise
sub weather
{
    my ($self, $lat, $lon) = @_;

    my $promise = Mojo::Promise->new();

    my $key = $self->api_key;
    my $url = Mojo::URL->new($self->api_url);
    $url->path("/data/2.5/weather");
    $url->query("units=imperial&lat=$lat&lon=$lon&appid=$key");

    say "OpenWeather URL: " . $url;

    $self->ua->get_p($url)->then(sub
        {
            my $tx = shift;

            my $json = $tx->res->json;

            my $weather = ();
            $weather->{'temperature'} = $json->{'main'}{'temp'} // 0;
            $weather->{'temperature_c'} = ftoc($json->{'main'}{'temp'});

            $weather->{'apparentTemperature'} = $json->{'main'}{'feels_like'} // 0;
            $weather->{'apparentTemperature_c'} = ftoc($json->{'main'}{'feels_like'});

            $weather->{'tempLow'} = $json->{'main'}{'temp_min'} // 0;
            $weather->{'tempLow_c'} = ftoc($json->{'main'}{'temp_min'}) // 0;

            $weather->{'tempHigh'} = $json->{'main'}{'temp_max'} // 0;
            $weather->{'tempHigh_c'} = ftoc($json->{'main'}{'temp_max'}) // 0;

            $weather->{'windSpeed'} = $json->{'wind'}{'speed'} // 0;
            $weather->{'windSpeed_km'} = kph($json->{'wind'}{'speed'}) // 0;

            $weather->{'windGust'} = $json->{'wind'}{'gust'} // 0;
            $weather->{'windGust_km'} = kph($json->{'wind'}{'gust'}) // 0;

            $weather->{'windBearing'} = wind_direction($json->{'wind'}{'deg'});

            $weather->{'humidity'} = $json->{'main'}{'humidity'};

            foreach my $condition (@{$json->{'weather'}})
            {
                $condition->{'description'} =~ s/([\w']+)/\u\L$1/g;
                $weather->{'summary'} .= $condition->{'description'} . '/';
            }
            chop $weather->{'summary'};

            $weather->{'icon_url'} = icon_url(lc $json->{'weather'}[0]{'icon'}, lc $json->{'weather'}[0]{'id'});
            $weather->{'icon_emote'} = icon_emote(lc $json->{'weather'}[0]{'icon'}, lc $json->{'weather'}[0]{'id'});

            $promise->resolve($weather);
        }
    )->catch(sub
        {
            my $error = shift;
            $promise->resolve($error);
        }
    );
    
    return $promise;
}

sub icon_url
{
    my ($code, $id) = @_;

    my %codes = (
        '01d'   => 'https://i.imgur.com/HIQkdIt.png', # Clear Sky
        '01n'   => 'https://i.imgur.com/sbsDekE.png',
        '02d'   => 'https://i.imgur.com/8OcKgMz.png', # Few Clouds
        '02n'   => 'https://i.imgur.com/QP98RF0.png',
        '03d'   => 'https://i.imgur.com/Hu9yAZm.png', # Scattered Clouds
        '03n'   => 'https://i.imgur.com/J0fcEhu.png',
        '04d'   => 'https://i.imgur.com/pVVAnjs.png', # Broken Clouds
        '04n'   => 'https://i.imgur.com/pVVAnjs.png',
        '09d'   => 'https://i.imgur.com/Y0Av9qM.png', # Shower Rain
        '09n'   => 'https://i.imgur.com/Ac8gSeq.png',
        '10d'   => 'https://i.imgur.com/IXenc9M.png', # Rain
        '10n'   => 'https://i.imgur.com/IXenc9M.png',
        '11d'   => 'https://i.imgur.com/qGfKshP.png', # Thunderstorm
        '11n'   => 'https://i.imgur.com/NG2NDho.png',
        '13d'   => 'https://i.imgur.com/CAj3Frd.png', # Snow
        '13n'   => 'https://i.imgur.com/jkLwfel.png',
        '50d'   => 'https://i.imgur.com/Fh2kqYX.png', # Mist
        '50n'   => 'https://i.imgur.com/1wYZX1J.png',
    );

    my %ids = (
        '781'   => 'https://i.imgur.com/3cqR9To.png', # Tornado
        '804'   => 'https://i.imgur.com/Zk3iwN6.png', # Overcast
    );

    return $ids{$id} // $codes{$code};
}

sub icon_emote
{
    my ($code, $id) = @_;

    my %codes = (
        '01d'   => ':sun_with_face:',
        '01n'   => ':full_moon_with_face:',
        '02d'   => ':partly_sunny:',
        '02n'   => ':white_sun_cloud:',
        '03d'   => ':cloud:',
        '03n'   => ':cloud:',
        '04d'   => ':cloud:',
        '04n'   => ':cloud:',
        '09d'   => ':cloud_rain:',
        '09n'   => ':cloud_rain:',
        '10d'   => ':cloud_rain:',
        '10n'   => ':cloud_rain:',
        '11d'   => ':thunder_cloud_rain:',
        '11n'   => ':thunder_cloud_rain:',
        '13d'   => ':cloud_snow:',
        '13n'   => ':cloud_snow:',
        '50d'   => ':fog:'
    );

    return $codes{$code} // ':partly_sunny:';
}

sub ftoc
{
    my $f = shift // 0;
    return ($f - 32) / (1.8);
}

sub kph
{
    my $mph = shift // 0;
    return sprintf("%0.1f", ($mph * 1.609344));
}

sub wind_direction
{
    my $deg = shift // 0;

    my @dirs = qw[North North-Northeast Northeast East-Northeast East East-Southeast Southeast South-Southeast South South-Southwest Southwest West-Southwest West West-Northwest Northwest North-Northwest];

    my $val = int(($deg/22.5)+.5);
    return $dirs[$val%16];
}



1;
