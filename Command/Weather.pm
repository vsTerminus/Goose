package Command::Weather;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_weather);

use Net::Discord;
use Bot::Goose;
use Component::OpenWeather;
use Component::Database;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Weather";
my $description = "Look up the weather by City Name, US Zip Code, or Canadian Postal Code.";
my $pattern = '^(we?(ather)?) ?([^\s].*)?$';
my $function = \&cmd_weather;
my $usage = <<EOF;

Basic Usage: `!weather <City Name, US Zip Code, or Canadian Postal Code>`
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
    $self->{'pattern'} = $pattern;

    # Register our command with the bot
    $self->{'bot'}->add_command(
        'command'       => $command,
        'description'   => $description,
        'usage'         => $usage,
        'pattern'       => $pattern,
        'function'      => $function,
        'object'        => $self,
    );
    
    return $self;
}

sub cmd_weather
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$3/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    my $ow = $self->{'openweather'};


    # Handle empty args
    if (length $args < 2 )
    {
        # Now, do we have a database entry for this user?
        my $db = $self->{'db'};
       
        my $sql = "SELECT location FROM weather WHERE discord_id = ?";
        my $query = $db->query($sql, $author->{'id'});
   
        # Yes, we have them.
        if ( my $row = $query->fetchrow_hashref )
        {
            $args = $row->{'location'};
            say localtime(time) . ": Found stored location for " . $author->{'username'} . ": " . $args;
        }
        else
        {
            # Else, error.
            $discord->send_message($channel, $author->{'username'} . ": You must specify a location (City Name / US Zip Code / Canadian Postal Code)");
            return;
        }
    }
    elsif ( $args =~ /^set (\w+)/i )
    {
        my $location = $1;
        $location =~ s/^\<(.*)\>$/$1/; # In case of stupidity, remove < > from the username.
        $self->add_user($author->{'id'}, $author->{'username'}, $location);
        $discord->send_message( $channel, $author->{'username'} . ": I have updated your Weather Location to `$location`" );
        
        $args = $location;
    }


    $self->{'bot'}->openweather->weather($args, 
    sub {
        my $json = shift;

        say Dumper($json);

        say "Searching for: $args";

        if ( $json->{'cod'} == 502 )
        {
            $discord->send_message($channel, $author->{'username'} . ": Sorry, I can't find `$args`");
            return;
        }

        my $city = $json->{'name'};
        my $ccode = $json->{'sys'}{'country'};
        my $temp = $json->{'main'}{'temp'};
        my $temp_f = ctof($temp);
        #my $temp_min = $json->{'main'}{'temp_min'};
        #my $temp_min_f = ctof($temp_min);
        #my $temp_max = $json->{'main'}{'temp_max'};
        #my $temp_max_f = ctof($temp_max);
        my $weather = weather_types($json->{'weather'});
        my $wind_speed = $json->{'wind'}{'speed'};
        my $wind_speed_mph = mph($wind_speed);
        my $wind_deg = $json->{'wind'}{'deg'};
        my $wind_dir = wind_direction($wind_deg);

        my $wstr = $author->{'username'} . ": `Weather for $city, $ccode: ${temp}C/${temp_f}F, $weather. Winds ${wind_speed}kph/${wind_speed_mph}mph $wind_dir`";


        $discord->send_message($channel, $wstr);
    });
}

sub ctof
{
    my $c = shift;
    return sprintf("%0.1f", ($c * (9/5) + 32));
}

sub mph
{
    my $kph = shift;
    return sprintf("%0.1f", ($kph / 1.609344));
}

sub wind_direction
{
    my $deg = shift;

    my @dirs = qw[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW];

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
}



1;
