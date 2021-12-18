package Command::Weather;
use feature 'say';

use Moo;
use strictures 2;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_weather);

use Mojo::Discord;
use Bot::Goose;
use Component::Maps;
use Component::Database;
use Command::Weather::Content;
use Mojo::AsyncAwait;
use Data::Dumper;

use namespace::clean;

# The bot can provide us with some of our objects
has bot         => ( is => 'ro' );
has discord     => ( is => 'lazy', builder => sub { shift->bot->discord } );
has db          => ( is => 'lazy', builder => sub { shift->bot->db } );
has maps        => ( is => 'lazy', builder => sub { shift->bot->maps } );
has openweather => ( is => 'lazy', builder => sub { shift->bot->openweather } );

# The rest are specific to this command
has name        => ( is => 'ro', default => 'Weather' );
has access      => ( is => 'ro', default => 0 ); # Public
has description => ( is => 'ro', default => 'Current Weather Conditions. Powered by Google Maps, Dark Sky, and Environment Canada' );
has pattern     => ( is => 'ro', default => '^(?:w(?!ink)e?(?:ather)?) ?([^\s].*)?$' );
has function    => ( is => 'ro', default => sub { return \&cmd_weather } );

has content     => ( is => 'ro', default => sub { Command::Weather::Content->new() });
has cache       => ( is => 'rw', default => sub { {} }); 

has usage       => ( is => 'ro', default => sub { return <<EOF;
**Basic Usage:** `!weather <Address>`
    The command accepts City Names, ZIP Codes, Postal Codes, and even Street Addresses.

    eg. `!weather Moscow`
    eg. `!weather 58201`
    eg. `!weather M4B 1B5`

**Shorthand:** `!w` and `!we`

**Check someone else's weather:** `!weather <\@username>`

    eg. `!weather <\@231059560977137664>`

**Save Your Location:** `!weather set <location> ["name"]`
    - You can save a default location and any number of other named locations for the bot to remember.
    - Storing your location allows the bot to give you the weather without needing to be told where you are.
    - Passing a name is entirely optional. If you do pass one it must be in quotes.
    - If you do not pass a name it will be used as your default location.

**Saved Location Examples:**

    - `!w set Denver, Colorado` will set your default location to "Denver, Colorado"
    - `!w` will now display the weather in Denver.
    - `!w set Austin, Texas "work"` will set your "work" location to "Austin, Texas"
    - `!w` will still display the weather in Denver, but now `!w work` will display the weather in Austin.

EOF
});

###########################################################################################
# There are two parts to this command:
#
# 1. Geocode the address the user requests with Google Maps
# 2. Pass the coordinates from GMaps to Dark Sky for the weather
#
# Also, the location can be cached for the duration of runtime,
# while the weather should be cached for 1 hour.
# This cuts down on unnecessary API calls, as I have a limit on both.
async cmd_weather => sub
{
    my ($self, $msg) = @_;
    
    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    $args =~ s/we?(ather)? ?//;
    my $discord = $self->discord;
    my $replyto = '<@' . $author->{'id'} . '>';

    # Handle empty args - Check to see if they have a saved location.
    if (!defined $args or length $args == 0 )
    {
        $args = $self->get_stored_location($author);

        if ( !defined $args )
        {
            my $msg = 
                "**How to set your default Weather location**\n\n" .
                "`!w set <location>`\n\n" .
                "Some examples:\n" .
                "- By Zip Code: `!w set 60659`\n" .
                "- By Postal Code: `!w set V5K 1B1`\n" .
                "- By City Name: `!w set London, England` or `!w set London, ON`\n\n" .
                "To update your location, just use the command again with a different location.\n" .
                "You can set your default location here in the private message, or in any public channel.";

            $discord->send_message($channel, 'Sorry ' . $author->{'username'} . ", I don't have a default location for you on record.");
            $discord->send_dm($author->{'id'}, $msg);

            return;
        }
    }
    elsif ( $args =~ /^set ([^\s].*)$/i )
    {
        my $location = $1;
        $location =~ s/^\<(.*)\>$/$1/; # In case of stupidity, remove < > from the location.

        if ( my @arr = ($args =~ m/^set (.*) \"(.+)\"$/ ) )
        {
            my $new_location = $arr[0];
            my $location_name = $arr[1];
            $location_name = lc $location_name;

            $self->add_user($author->{'id'}, $author->{'username'}, $new_location, $location_name);
            $discord->send_message( $channel, $author->{'username'} . ": I have saved '$new_location' as Location '$location_name'.");

            $args = $1;
        }
        else    # Default location
        {
            $self->add_user($author->{'id'}, $author->{'username'}, $location);

            my $msg = "Default weather location for " . $author->{'username'} . " is now: `$location`\n";

            $discord->send_message( $channel, $msg );
        
            $args = $location;
        }
    }
    # By @mention
    elsif ( $args =~ /^\<\@\!?(\d+)\>$/ )
    { 
        unless ( $args = $self->get_stored_location({id => $1}) )
        {
            $discord->send_message($channel, "Sorry " . $author->{'username'} . ", I don't have a stored location for that user.");
        }
        $self->bot->log->debug("[Weather.pm] [cmd_weather] Found stored location for $1: $args");
    }
    else # Check to see if this is a stored location.
    {
        $args =~ s/^\s*//; $args =~ s/\s*$//;
        if ( my $location = $self->get_stored_location($author, $args) )
        {
            $args = $location;
        }
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
        say "-> Geocoding args: $args";
        my $json = await $self->geocode($args);
    
        my $lat = $json->{'geometry'}{'location'}{'lat'};
        my $lon = $json->{'geometry'}{'location'}{'lng'};
        my $formatted_address = $json->{'formatted_address'};
   
        #die("Could not retrieve coords from Component::Maps->geocode") unless defined $lat and defined $lon;

        unless ( defined $lat and defined $lon and defined $formatted_address )
        {
            $discord->send_message($channel, $author->{'username'} . ": Sorry, I can't find `" . $args . "`");
            $self->bot->log->debug("[Weather.pm] [cmd_weather] Could not geocode '$args'");
            return undef;
        }

        # Store these coords.
        $self->add_coords($args, $lat, $lon, $formatted_address);

        # Now look up the weather.
        $self->weather_by_coords($channel, $author, $lat, $lon, $formatted_address);
    }
};

async geocode => sub
{
    my ($self, $args) = @_;

    my $json = await $self->bot->maps->geocode($args);

    return $json;
};

async weather_by_coords => sub
{
    my ($self, $channel, $author, $lat, $lon, $address) = @_;

    my $json;

    # First check to see if we have cached weather.
    if ( exists $self->cache->{'weather'}{"$lat,$lon"} and time < $self->cache->{'weather'}{"$lat,$lon"}{'expires'} )
    {
        $json = $self->cache->{'weather'}{"$lat,$lon"}{'json'};

        my $formatted_weather = $self->format_weather($json);
        $formatted_weather =~ s/FUCKING.*$/**FUCKING, AUSTRIA**/ if $address =~ /Fucking, Austria/;
        $formatted_weather =~ s/IT'S FUCKING.*$/**nice.** :smirk:/ if $formatted_weather =~ /SEXYTIME/ and $json->{'temperature'} > 0 and rand(1) > 0.75;
    
        $self->send_weather($channel, $lat, $lon, $address, $json, $formatted_weather);
    }
    # If we don't have cached weather (or it is expired), ask OpenWeather or Environment Canada for it
    else
    {

        my $weather_found = 0;
        if ( $address =~ /Canada$/ )
        {
            my ($city, $province) = ($address =~ /^(?:.*, )?([^,]+), ([^,]+), Canada$/);
            $province = substr($province,0,2);
            $self->bot->log->debug("Requesting weather for $city, $province from Environment Canada");

            $json = await $self->bot->environmentcanada->weather($city, $province);

            if ( defined $json )
            {
                $weather_found = 1;
            }
        }
        unless ( $weather_found )
        {
            $self->bot->log->debug("Requesting weather for $lat,$lon from Dark Sky");
            $json = await $self->bot->openweather->weather($lat, $lon);
        }

        # Cache the results;
        $self->cache->{'weather'}{"$lat,$lon"}{'json'} = $json;
        $self->cache->{'weather'}{"$lat,$lon"}{'expires'} = time + 3600; # Good for one hour.

        my $formatted_weather = $self->format_weather($json);
        $formatted_weather =~ s/FUCKING.*$/**FUCKING, AUSTRIA**/ if $address =~ /Fucking, Austria/;
        $formatted_weather =~ s/IT'S FUCKING.*$/**nice.** :smirk:/ if $formatted_weather =~ /SEXYTIME/ and $json->{'temperature'} > 0 and rand(1) > 0.75;

        $self->send_weather($channel, $lat, $lon, $address, $json, $formatted_weather); # This sub handles whether it's a message or webhook.
    }
};

sub send_weather
{
    my ($self, $channel, $lat, $lon, $address, $json, $formatted_weather) = @_;

    # Do we have a webhook here?
    if ( my $hook = $self->bot->has_webhook($channel) )
    {
        my $avatar = 'http://i.imgur.com/BVCiYSn.png'; # default
        $avatar = $json->{'icon_url'} if exists $json->{'icon_url'};

        
        my $header = ( exists $json->{'warning'} ? "**$address - " . $json->{'warning'} . "**" : "**$address**" );

        my $forecast_url = Mojo::URL->new('https://openweathermap.org/find');
        $forecast_url->query(q => $address);

        my $hookparam = {
            'username' => "Current Weather",
            'avatar_url' => $avatar,
            'content' => "$header\n" . $formatted_weather . "\n[View Forecast](<$forecast_url>)",
        };

        $self->discord->send_webhook($channel, $hook, $hookparam);
    }
    else # Regular message.
    {
        my $icon = $json->{'icon_emote'} // ":sun_with_face:";

        my $warning = ( exists $json->{'warning'} ? $json->{'warning'} . "\n" : "" );
            
        $self->discord->send_message($channel, "**Weather for $address** $icon\n$warning$formatted_weather\n");
    }
}

sub format_weather
{
    my ($self, $json) = @_;

    my $temp_f = round($json->{'temperature'});
    my $temp_c = round($json->{'temperature_c'});
    
    my $feel_f = round($json->{'apparentTemperature'});
    my $feel_c = round($json->{'apparentTemperature_c'});

    my $wind_mi = round($json->{'windSpeed'});
    my $wind_km = round($json->{'windSpeed_km'});

    my $gust_mi = round($json->{'windGust'});
    my $gust_km = round($json->{'windGust_km'});

    my $wind_dir = $json->{'windBearing'};

    # Accept percent or decimal value
    my $humidity = $json->{'humidity'};
    $humidity *= 100 if $humidity <= 1;
    $humidity = int($humidity);
    
    my $cond = $json->{'summary'};

    my $fuckingweather = $self->content->itsfucking_comment($temp_f, $temp_c, $feel_f, $feel_c, $cond);

    my $winds = "Calm";
    $winds = "$wind_dir ${wind_mi}mph/${wind_km}kph" unless $wind_mi == 0 or $wind_km == 0;
    $winds .= " Gust ${gust_mi}mph/${gust_km}kph" unless $gust_mi == 0 or $gust_km == 0;

    my $msg = "```c\n" .
        "Temperature | ${temp_f}\N{DEGREE SIGN}F/${temp_c}\N{DEGREE SIGN}C\n" .
        "Feels Like  | ${feel_f}\N{DEGREE SIGN}F/${feel_c}\N{DEGREE SIGN}C\n" .
        "Conditions  | $cond, ${humidity}% Humidity\n" .
        "Winds       | $winds```\n" .
        "$fuckingweather";

    return $msg;
}

sub get_stored_location
{
    my ($self, $author, $name) = @_;

    $name = defined $name ? lc $name : 'default';

    # 1 - Check Cache    
    my $cached = $self->cache->{'userlocation'}{$author->{'id'}}{$name};

    if ( defined $cached and length $cached > 0 )
    {
        return $cached;
    }
    # 2 - Check Database
    else
    {
        my $db = $self->db;
   
        my $sql = "SELECT location FROM weather WHERE discord_id = ? AND name = ?";
        $name = 'default' unless defined $name;
        my $query = $db->query($sql, $author->{'id'}, $name);

        # Yes, we have them.
        if ( my $row = $query->fetchrow_hashref )
        {
            $self->cache->{'userlocation'}{$author->{'id'}}{$name} = $row->{'location'};  # Cache this so we don't need to hit the DB all the time.
            $self->bot->log->debug("[Weather.pm] [get_stored_location] Found stored DB location for " . $author->{'id'} . ": " . $row->{'location'});
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
    if ( exists $self->cache->{'coords'}{lc $location} )
    {
        $self->bot->log->debug("[Weather.pm] [get_stored_coords] Found cached coordinates for location '$location': " . $self->cache->{'coords'}{lc $location}{'address'});
        return $self->cache->{'coords'}{lc $location};
    }
    # 2 - Check DB
    else
    {
        my $db = $self->db;

        my $sql = "SELECT lat,lon,address FROM coords WHERE location = ?";
        my $query = $db->query($sql, lc $location);

        # Yes - We have coords
        if ( my $row = $query->fetchrow_hashref )
        {
            $self->cache->{'coords'}{lc $location}{'lat'} = $row->{'lat'};
            $self->cache->{'coords'}{lc $location}{'lon'} = $row->{'lon'};
            $self->cache->{'coords'}{lc $location}{'address'} = $row->{'address'};

            $self->bot->log->debug("[Weather.pm] [get_stored_coords] Found stored DB coordinates for location '$location': " . $row->{'lat'} . ',' . $row->{'lon'} . " - " . $row->{'address'});
            return $row;
        }
    }

    # 3 - We don't have a stored set of coords for this location yet.
    return undef
}

sub round
{
    my $n = shift // 0;

    # Add .5 for positive numbers
    # Subtract .5 for negative numbers
    # This makes int() behave as expected.
    $n+= ( $n > 0 ? 0.5 : -0.5 );
    
    return int($n);
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
    my ($self, $discord_id, $discord_name, $location, $location_name) = @_;

    $self->bot->log->debug("[Weather.pm] [add_user] Adding a new mapping: $discord_id ($discord_name) -> $location");

    my $db = $self->db;
    

    $location_name = 'default' unless defined $location_name;

    my $sql = "INSERT INTO weather VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE discord_name = ?, location = ?";
    $db->query($sql, $discord_id, $discord_name, $location, $location_name, $discord_name, $location);
        
    # Also cache this in memory for faster lookups
    $self->cache->{'userlocation'}{$discord_id}{$location_name} = $location;
}

sub add_coords
{
    my ($self, $location, $lat, $lon, $address) = @_;

    $self->bot->log->debug("[Weather.pm] [add_coords] Adding new coordinates: $location -> $lat,$lon ($address)");

    my $db = $self->db;

    my $sql = "INSERT INTO coords VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE lat = ?, lon = ?, address = ?";
    $db->query($sql, lc $location, $lat, $lon, $address, $lat, $lon, $address);

    # Also cache for in-memory lookups.
    $self->cache->{'coords'}{lc $location}{'lat'} = $lat;
    $self->cache->{'coords'}{lc $location}{'lon'} = $lon;
    $self->cache->{'coords'}{lc $location}{'address'} = $address;
}

__PACKAGE__->meta->make_immutable;

1;
