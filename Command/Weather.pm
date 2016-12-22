package Command::Weather;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_weather);

use Net::Discord;
use Bot::Goose;
use Component::OpenWeather;
use Component::Maps;
use Component::Database;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Weather";
my $access = 0; # Public
my $description = "Current Weather Conditions. Powered by Google Maps and Dark Sky API.";
my $pattern = '^(we?(ather)?) ?([^\s].*)?$';
my $function = \&cmd_weather;
my $usage = <<EOF;

Basic Usage: `!weather <Address>`
    The command accepts City Names, ZIP Codes, Postal Codes, and even Street Addresses.

    eg. `!weather Dildo, NL`
    eg. `!weather 80085`
    eg. `!weather V4G 1N4`

Shorthand: `!w` and `!we`

Store your location: `!weather set <zip, postal code, or city name>`
    - The bot will remember your location and in the future if you don't supply one.
    eg. `!weather` will use whatever value you told the bot to remember.
EOF
###########################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
     
    # Setting up this command module requires the Discord connection
    # and the Database component
    $self->{'bot'} = $params{'bot'};
    $self->{'discord'} = $self->{'bot'}->discord;
    $self->{'db'} = $self->{'bot'}->db;
    $self->{'maps'} = $self->{'bot'}->maps;
    $self->{'pattern'} = $pattern;

    # DarkSky Icon to Discord Emoji mappings
    $self->{'icons'} = {
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
    };

    # Register our command with the bot
    $self->{'bot'}->add_command(
        'command'       => $command,
        'access'        => $access,
        'description'   => $description,
        'usage'         => $usage,
        'pattern'       => $pattern,
        'function'      => $function,
        'object'        => $self,
    );
    
    return $self;
}

# There are two parts to this command:
#
# 1. Geocode the address the user requests with Google Maps
# 2. Pass the coordinates from GMaps to Dark Sky for the weather
#
# Also, the location can be cached for the duration of runtime,
# while the weather should be cached for 1 hour.
# This cuts down on unnecessary API calls, as I have a limit on both.
sub cmd_weather
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    defined $3 ? $args =~ s/$pattern/$3/i : undef $args;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    # Start "Typing"
    $discord->start_typing($channel);

#    my $ds = $self->{'darksky'};


    # Handle empty args - Check to see if they have a saved location.
    if (!defined $args or length $args == 0 )
    {
        $args = $self->get_stored_location($author);

        if ( !defined $args )
        {
            $discord->send_message($channel, $author->{'username'} . ": You must specify a location (eg, City, ZIP, Street Address, etc)");
            return;
        }
    }
    elsif ( $args =~ /^set ([^s].*)$/i )
    {
        my $location = $1;
        $location =~ s/^\<(.*)\>$/$1/; # In case of stupidity, remove < > from the username.
        $self->add_user($author->{'id'}, $author->{'username'}, $location);
        $discord->send_message( $channel, $author->{'username'} . ": I have updated your Weather Location to `$location`" );
        
        $args = $location;
    }

    # Now we have their desired location and can look it up.
    my $coords = $self->get_stored_coords($args);

    # If we have the coordinates cached already, just use those.
    if ( defined $coords and exists $coords->{'lat'} and exists $coords->{'lon'} )
    {
        $self->weather_by_coords($channel, $author, $coords->{'lat'}, $coords->{'lon'}, $coords->{'address'});
    }
    # If not, we'll have to geocode the query location.
    else
    {
        say localtime(time) . " Could not find cached coords for '$args'. Geocoding...";
        $self->{'bot'}->maps->geocode($args, sub
        {
            my $json = shift;
        
            my $lat = $json->{'geometry'}{'location'}{'lat'};
            my $lon = $json->{'geometry'}{'location'}{'lng'};
            my $formatted_address = $json->{'formatted_address'};
       
            #die("Could not retrieve coords from Component::Maps->geocode") unless defined $lat and defined $lon;

            unless ( defined $lat and defined $lon and defined $formatted_address )
            {
                $discord->send_message($channel, $author->{'username'} . ": Sorry, I can't find `" . $args . "`");
                say localtime(time) . " Could not geocode '$args'";
                return undef;
            }
    
            say localtime(time) . " Geocoding Results: $formatted_address ($lat,$lon)";
    
            # Store these coords.
            $self->add_coords($args, $lat, $lon, $formatted_address);
    
            # Now look up the weather.
            $self->weather_by_coords($channel, $author, $lat, $lon, $formatted_address);
        });
    }
}

sub weather_by_coords
{
    my ($self, $channel, $author, $lat, $lon, $address) = @_;

    # Take the coords and lookup the weather.
    $self->{'bot'}->darksky->weather($lat, $lon, sub
    {
        my $json = shift;

        my $formatted_weather = format_weather($json);

        my $icons= $self->{'icons'};
        my $icon = '';
        $icon = $icons->{$json->{'icon'}} if exists $icons->{$json->{'icon'}};

        $self->{'discord'}->send_message($channel, "**Weather for $address** $icon\n$formatted_weather");
    });
}

sub format_weather
{
    my $json = shift;

    my $temp_f = $json->{'temperature'};
    my $temp_c = ftoc($temp_f);
    my $feel_f = $json->{'apparentTemperature'};
    my $feel_c = ftoc($feel_f);
    my $cond = $json->{'summary'};
    my $wind_mi = $json->{'windSpeed'};
    my $wind_km = kph($wind_mi);
    my $wind_dir = wind_direction($json->{'windBearing'});
    my $humidity = int($json->{'humidity'} * 100);
           
    my $msg = "```perl\n" .
        "Temperature | ${temp_f}\N{DEGREE SIGN}F/${temp_c}\N{DEGREE SIGN}C\n" .
        "Feels Like  | ${feel_f}\N{DEGREE SIGN}F/${feel_c}\N{DEGREE SIGN}C\n" .
        "Conditions  | $cond, ${humidity}% Humidity\n" .
        "Winds       | $wind_dir ${wind_mi}mph/${wind_km}kph```";

    return $msg;
}

sub get_stored_location
{
    my ($self, $author) = @_;

    # 1 - Check Cache    
    if ( exists $self->{'cache'}{'userlocation'}{$author->{'id'}} )
    {
        say localtime(time) . " Found cached location for " . $author->{'username'} . ": " . $self->{'cache'}{'userlocation'}{$author->{'id'}};
        return $self->{'cache'}{'userlocation'}{$author->{'id'}};
    }
    # 2 - Check Database
    else
    {
        my $db = $self->{'db'};
   
        my $sql = "SELECT location FROM weather WHERE discord_id = ?";
        my $query = $db->query($sql, $author->{'id'});

        # Yes, we have them.
        if ( my $row = $query->fetchrow_hashref )
        {
            $self->{'cache'}{'userlocation'}{$author->{'id'}} = $row->{'location'};  # Cache this so we don't need to hit the DB all the time.
            say localtime(time) . " Found stored DB location for " . $author->{'username'} . ": " . $row->{'location'};
            return $row->{'location'};
        }
    }
    # 3 - We don't have a stored location for this user.
    return undef;
}

sub get_stored_coords
{
    my ($self, $location) = @_;

    die ("get_stored_coords was not given a location to look up") unless defined $location;

    # 1 - Check Cache
    if ( exists $self->{'cache'}{'coords'}{lc $location} )
    {
        say localtime(time) . " Found cached coordinates for location '$location': " . $self->{'cache'}{'coords'}{lc $location}{'address'};
        return $self->{'cache'}{'coords'}{lc $location};
    }
    # 2 - Check DB
    else
    {
        my $db = $self->{'db'};

        my $sql = "SELECT lat,lon,address FROM coords WHERE location = ?";
        my $query = $db->query($sql, lc $location);

        # Yes - We have coords
        if ( my $row = $query->fetchrow_hashref )
        {
            $self->{'cache'}{'coords'}{lc $location}{'lat'} = $row->{'lat'};
            $self->{'cache'}{'coords'}{lc $location}{'lon'} = $row->{'lon'};
            $self->{'cache'}{'coords'}{lc $location}{'address'} = $row->{'address'};

            say localtime(time) . " Found stored DB coordinates for location '$location': " . $row->{'lat'} . ',' . $row->{'lon'} . " - " . $row->{'address'};
            return $row;
        }
    }

    # 3 - We don't have a stored set of coords for this location yet.
    return undef
}


sub ctof
{
    my $c = shift;
    return sprintf("%0.1f", ($c * (9/5) + 32));
}

sub ftoc
{
    my $f = shift;
    return sprintf("%0.1f", ($f - 32) / (1.8));
}

sub mph
{
    my $kph = shift;
    return sprintf("%0.1f", ($kph / 1.609344));
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

sub weather_types
{
    my @arr = shift;

    my $str = "";

    my $size = scalar @arr;
    
    for( my $i = 0; $i < @arr; $i++)
    {
        if ( $i > 0 and $i < ($size-1) )
        {
            $str .= ", ";
        }

        $str .= $arr[$i][0]{'main'};
    }

    return $str;
}


sub add_user
{
    my ($self, $discord_id, $discord_name, $location) = @_;

    say localtime(time) . " Command::Weather is adding a new mapping: $discord_id ($discord_name) -> $location";

    my $db = $self->{'db'};
    
    my $sql = "INSERT INTO weather VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE discord_name = ?, location = ?";
    $db->query($sql, $discord_id, $discord_name, $location, $discord_name, $location);

    # Also cache this in memory for faster lookups
    $self->{'cache'}{'userlocation'}{$discord_id} = $location;
}

sub add_coords
{
    my ($self, $location, $lat, $lon, $address) = @_;

    say localtime(time) . " Command::Weather is adding new coordinates: $location -> $lat,$lon ($address)";

    my $db = $self->{'db'};

    my $sql = "INSERT INTO coords VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE lat = ?, lon = ?, address = ?";
    $db->query($sql, lc $location, $lat, $lon, $address, $lat, $lon, $address);

    # Also cache for in-memory lookups.
    $self->{'cache'}{'coords'}{lc $location}{'lat'} = $lat;
    $self->{'cache'}{'coords'}{lc $location}{'lon'} = $lon;
    $self->{'cache'}{'coords'}{lc $location}{'address'} = $address;
}

1;
