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

**Basic Usage:** `!weather <Address>`
    The command accepts City Names, ZIP Codes, Postal Codes, and even Street Addresses.

    eg. `!weather Dildo, NL`
    eg. `!weather 80085`
    eg. `!weather V4G 1N4`

**Shorthand:** `!w` and `!we`

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

    # If we have a webhook in the channel we can use images for avatars instead of emoji!
    $self->{'webhook_icons'} = {
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
    };

    $self->{'comment'} = {
        'frozen' => [
            'WHAT THE FUCK?!?!?!',
            'ARE YOU OK?',
            'HOW ARE YOU EVEN ALIVE?',
            'DO PEOPLE LIVE HERE??',
            'LET IT GO, LET IT GO, THE COLD NEVER BOTHERED ME ANYWAY',
            'JESUS TITTYFUCKING CHRIST',
            'DO YOU REQUIRE ASSISTANCE?',
            'STAY IN YOUR IGLOO!',
            'YUP. FLUFFY\'S FROZEN.',
            'MOM, THE CAT IS FROZEN!',
            'THE POOL IS FROZEN.',
            'MAXIMUM SHRINKAGE!',
            'FUCK THIS I\'M OUT.',
            'JUST MOVE ALREADY!',
            "I HAVEN'T SEEN THE SUN FOR MONTHS."
        ],
        'minus40' => [
            "IN \N{DEGREE SIGN}C OR \N{DEGREE SIGN}F??? YES.",
            "IT'S TOO COLD FOR JOKES ABOUT -40 BEING THE SAME IN \N{DEGREE SIGN}C AND \N{DEGREE SIGN}F!",
            "HAHAHA. IT'S THE SAME TEMPERATURE IN \N{DEGREE SIGN}C AND \N{DEGREE SIGN}F! ISN'T THAT FUNNY?",
            "EQUAL RIGHTS FOR ALL TWO TEMPERATURE SCALES.",
            "\N{DEGREE SIGN}F AND \N{DEGREE SIGN}C AGREE, -40 FUCKING SUCKS.",
        ],
        'freezing' => [
            "I HOPE YOU PLUGGED YOUR CAR IN.",
            "ARE YOU AN ESKIMO?",
            "MAJOR SHRINKAGE!",
            "WHY DO YOU LIVE HERE?",
            "THIS IS A JOKE, RIGHT?",
            "MY LIPS ARE NUMB.",
            "I CAN'T FEEL MY TOES.",
            "I CAN'T FEEL MY FINGERS.",
            "MY EYELIDS ARE FROZEN SHUT.",
            "I CAN'T FEEL MY FACE.",
            "SO THIS IS WHAT FROSTBITE FEELS LIKE.",
            "WHY DOES ANYONE LIVE HERE?",
            "THIS FUCKING SUCKS."
        ],
        'cold' => [
            "SHRINKAGE!",
            "GO FOR A SWIM. I DARE YOU.",
            "SNOWMOBILE WEATHER!",
            "SKI TRIP!",
            "DO YOU LIVE HERE ON PURPOSE?",
            "THIS SUCKS.",
            "PERFECT WEATHER TO STAY INSIDE.",
            "DO YOU EVEN KNOW WHAT A TOQUE IS?",
            "ARE YOU WEARING YOUR TOQUE?",
            "UNLESS YOU'RE A MOOSE.",
            "UNLESS YOU'RE A POLAR BEAR.",
            "UNLESS YOU'RE A PENGUIN.",
        ],
        'cool' => [
            "SWEATER OR JACKET?",
            "JACKET OFF. JACK ET OFF. JACK IT OFF.",
            "IT FEELS LIKE I'M STANDING IN A REFRIGERATOR",
            "HOT OR COLD. MAKE UP YOUR GODDAMN MIND!",
            "I HAVE NO IDEA HOW TO DRESS TODAY.",
            "I MISS SUMMER ALREADY.",
            "CAN I GO BACK INSIDE?",
            "DOES ANYONE KNOW HOW TO START A FIRE WITH A TWIG AND SOME STRING?",
            "BEING ON FIRE SOUNDS NICE RIGHT ABOUT NOW.",
        ],
        'alright' => [
            "I CAN DEAL WITH THIS, I SUPPOSE.",
            "I MEAN, IT COULD BE WORSE.",
            "I MEAN, IT COULD BE BETTER.",
            "IT COULD BE BETTER, I GUESS.",
            "IT COULD BE WORSE, I GUESS.",
            "MEH.",
            "FINE. I GUESS.",
            "ALL SIGNS POINT TO 'MEH'",
            "TODAY'S WEATHER WILL BE 'MEH' WITH A CHANCE OF DOOM!",
        ],
        'nice' => [
            "GO OUTSIDE!",
            "WHY ARE YOU STILL INSIDE?",
            "GET OFF THE COMPUTER AND GO OUTSIDE!",
            "GET OFF YOUR ASS AND GO OUTSIDE.",
            "WHY CAN'T IT BE LIKE THIS ALL YEAR?",
            "IF YOU'RE CANADIAN.",
            "UNLESS YOU'RE AN AMERICAN.",
            "UNLESS YOU'RE A WIMP.",
            "WEAR A SWEATER IF YOU DON'T LIKE IT.",
        ],
        'warm' => [
            "THAT'S MORE LIKE IT!",
            "SUN'S OUT GUNS OUT!",
            "BEACH DAY BRO!",
            "BIKINI TANS!",
            "POOOOOOL!",
            "TIME TO WORK ON MY TAN.",
            "PASS THE SUNSCREEN.",
            "I NEED ONE HUNDRED BEERS. EXACTLY ONE HUNDRED. THANKS.",
            "THIS CALLS FOR A ~~BUD~~ CAN OF FLOWERY GRAIN WATER!",
            "THIS CALLS FOR A BEER!",
            "TRACK DAY BRO!",
        ],
        'hot' => [
            "THIS SUCKS.",
            "PERFECT WEATHER TO STAY INSIDE.",
            "HOPE YOU'VE GOT AIR CONDITIONING!",
            "PERFECT WEATHER TO DO NOTHING.",
            "STOP, I CAN ONLY TAKE SO MUCH OFF!",
            "I MISS WINTER.",
            "WHY DO YOU LIVE HERE?",
            "DO YOU LIVE HERE ON PURPOSE?",
            "POOOOL!",
            "FUCK SUNBURNS!",
            "MAKE IT STOP!",
        ],
        'boiling' => [
            "WHAT THE FUCK?!?!?!",
            "HOW DO PEOPLE LIVE HERE?",
            "I'M MELTING!",
            "MOM, FLUFFY MELTED.",
            "YUP, THE CAT MELTED.",
            "STAY INSIDE UNLESS YOU WANT TO DIE.",
            "YOU DON'T DRIVE A BLACK CAR, DO YOU?",
            "THE CAR IS MELTED TO THE DRIVEWAY!",
            "I'M CONSIDERING SLEEPING IN THE FRIDGE.",
            "ARE YOU OKAY???",
            "HOW ARE YOU STILL ALIVE?",
            "DO YOU REQUIRE ASSISTANCE?",
            "SHOULD I CALL 911?",
            "FUCK THIS.",
            "THIS FUCKING SUCKS."
        ],
        'sixtynine'  => [
            "OH LA LA",
            "PUT THE YOU KNOW WHAT, IN THE YOU KNOW WHERE",
            "VULCANIZE THE WHOOPEE STICK, IN THE HAM WALLET",
            "CATTLE PROD THE OYSTER DITCH, WITH THE LAP ROCKET",
            "BATTER DIP THE CRANNY AXE, IN THE GUT LOCKER",
            "RETROFIT THE PUDDING HATCH, WITH THE BOINK SWATTER",
            "MARINATE THE NETHER ROD, IN THE SQUISH MITTEN",
            "POWER DRILL THE YIPPEE BOG, WITH THE DUDE PISTON",
            "PRESSURE WASH THE QUIVER BONE, IN THE BITCH WRINKLE",
            "CANNONBALL THE FIDDLE COVE, WITH THE PORK STEEPLE",
        ]
    };

    $self->{'itsfucking'} = {
        'frozen' => [
            "FROZEN!", 
            "RETARDED COLD!",
            "WHAT THE FUCK?!",
            "FRIGID!",
            "COLDER THAN MARS!",
            "INSANELY COLD!"
        ],
        'minus40' => [
            "MINUS 40!",
        ],
        'freezing' => [
            "FREEZING!",
        ],
        'cold' => [
            "COLD!"
        ],
        'cool' => [
            "COOL!",
        ],
        'alright' => [
            'ALRIGHT.',
            'OKAY, I GUESS.',
            'NOT BAD.',
            'OKAY.'
        ],
        'nice' => [
            'NICE'
        ],
        'warm' => [
            'WARM!'
        ],
        'hot' => [
            'HOT!'
        ],
        'boiling' => [
            'BOILING!',
            'TOO HOT!',
            'WAY TOO HOT!',
            'CRAZY HOT!',
            'SCORCHING!',
            'HOTTER THAN VENUS!',
            'HOTTER THAN MERCURY!',
            'DEADLY HOT!',
            'WHAT THE FUCK?!'
        ],
        'sixtynine' => [
            'SEXYTIME!'
        ],
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
    # Only do this if we aren't using a webhook, because the webhook won't stop the typing message.
    $discord->start_typing($channel) unless $self->{'bot'}->has_webhook($channel);

#    my $ds = $self->{'darksky'};


    # Handle empty args - Check to see if they have a saved location.
    if (!defined $args or length $args == 0 )
    {
        $args = $self->get_stored_location($author);

        if ( !defined $args )
        {
            my $msg = $author->{'username'} . ": Sorry, I don't have a default location for you on record.\n\n" .
                "**Set your default location**\n" .
                "- Use `!w set <location>`\n" .
                "- Example, `!w set 10001` or `!w set Singapore`\n\n" .
                "Your location can be a zip code, city name, postal code, or even street address.";
            $discord->send_message($channel, $msg);
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

            my $msg = $author->{'username'} . ": I have updated your default Weather location to `$location`\n";

            $discord->send_message( $channel, $msg );
        
            $args = $location;
        }
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

    my $json;

    # First check to see if we have cached weather.
    if ( exists $self->{'cache'}{'weather'}{"$lat,$lon"} and time < $self->{'cache'}{'weather'}{"$lat,$lon"}{'expires'} )
    {
        $json = $self->{'cache'}{'weather'}{"$lat,$lon"}{'json'};

        my $formatted_weather = $self->format_weather($json);
    
        $self->send_weather($channel, $lat, $lon, $address, $json, $formatted_weather);
    }
    # If we don't have cached weather (or it is expired), ask DarkSky for it.
    else
    {
        say localtime(time) . " Requesting weather for $lat,$lon";
        # Take the coords and lookup the weather.
        $self->{'bot'}->darksky->weather($lat, $lon, sub
        {
            $json = shift;
            #say Dumper($json);

            # Cache the results;
            $self->{'cache'}{'weather'}{"$lat,$lon"}{'json'} = $json;
            $self->{'cache'}{'weather'}{"$lat,$lon"}{'expires'} = time + 3600; # Good for one hour.
    
            my $formatted_weather = $self->format_weather($json);
            #say "Formatted Weather: $formatted_weather";
    
            $self->send_weather($channel, $lat, $lon, $address, $json, $formatted_weather); # This sub handles whether it's a message or webhook.
        });
    }
}

sub send_weather
{
    my ($self, $channel, $lat, $lon, $address, $json, $formatted_weather) = @_;

    # Do we have a webhook here?
    if ( my $hook = $self->{'bot'}->has_webhook($channel) )
    {
        my $avatars = $self->{'webhook_icons'};
        my $avatar = 'http://i.imgur.com/BVCiYSn.png'; # default
        $avatar = $avatars->{$json->{'icon'}} if exists $avatars->{$json->{'icon'}};    # per-weather icons

        # Webhooks restrict usernames to 3-32 chars in length.
        $address = "Weather for $address" if ( length $address < 3 );
        $address = substr($address,0,29) . "..." if ( length $address > 32 );

        my $hookparam = {
            'username' => $address,
            'avatar_url' => $avatar,
            'content' => $formatted_weather . "\n[View Radar and Forecast](<https://darksky.net/forecast/$lat,$lon>)",
        };

        $self->{'discord'}->send_webhook($channel, $hook, $hookparam, sub { my $json = shift; say Dumper($json) if defined $json; });
    }
    else # Regular message.
    {
        my $icons= $self->{'icons'};
        my $icon = '';
        $icon = $icons->{$json->{'icon'}} if exists $icons->{$json->{'icon'}};
            
        $self->{'discord'}->send_message($channel, "**Weather for $address** $icon\n$formatted_weather\n");
    }
}

sub format_weather
{
    my ($self, $json) = @_;

    my $temp_f = round($json->{'temperature'});
    my $temp_c = round(ftoc($temp_f));
    my $feel_f = round($json->{'apparentTemperature'});
    my $feel_c = round(ftoc($feel_f));
    my $cond = $json->{'summary'};
    my $wind_mi = $json->{'windSpeed'};
    my $wind_km = kph($wind_mi);
    my $wind_dir = wind_direction($json->{'windBearing'});
    my $humidity = int($json->{'humidity'} * 100);
        
    my $fuckingweather = $self->itsfucking($feel_f, $feel_c, $cond);

    my $msg = "```c\n" .
        "Temperature | ${temp_f}\N{DEGREE SIGN}F/${temp_c}\N{DEGREE SIGN}C\n" .
        "Feels Like  | ${feel_f}\N{DEGREE SIGN}F/${feel_c}\N{DEGREE SIGN}C\n" .
        "Conditions  | $cond, ${humidity}% Humidity\n" .
        "Winds       | $wind_dir ${wind_mi}mph/${wind_km}kph```\n" .
        "$fuckingweather";

    return $msg;
}

sub get_stored_location
{
    my ($self, $author, $name) = @_;

    $name = defined $name ? lc $name : 'default';

    # 1 - Check Cache    
    my $cached = $self->{'cache'}{'userlocation'}{$author->{'id'}}{$name};

    if ( defined $cached and length $cached > 0 )
    {
        return $cached;
    }
    # 2 - Check Database
    else
    {
        my $db = $self->{'db'};
   
        my $sql = "SELECT location FROM weather WHERE discord_id = ? AND name = ?";
        $name = 'default' unless defined $name;
        my $query = $db->query($sql, $author->{'id'}, $name);

        # Yes, we have them.
        if ( my $row = $query->fetchrow_hashref )
        {
            $self->{'cache'}{'userlocation'}{$author->{'id'}}{$name} = $row->{'location'};  # Cache this so we don't need to hit the DB all the time.
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
    return $c * (9/5) + 32;
}

sub ftoc
{
    my $f = shift;
    return ($f - 32) / (1.8);
}

sub round
{
    my $n = shift;

    # Add .5 for positive numbers
    # Subtract .5 for negative numbers
    # This makes int() behave as expected.
    $n+= ( $n > 0 ? 0.5 : -0.5 );
    
    return int($n);
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
    my ($self, $discord_id, $discord_name, $location, $location_name) = @_;

    say localtime(time) . " Command::Weather is adding a new mapping: $discord_id ($discord_name) -> $location";

    my $db = $self->{'db'};
    

    $location_name = 'default' unless defined $location_name;

    my $sql = "INSERT INTO weather VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE discord_name = ?, location = ?";
    $db->query($sql, $discord_id, $discord_name, $location, $location_name, $discord_name, $location);
        
    # Also cache this in memory for faster lookups
    $self->{'cache'}{'userlocation'}{$discord_id}{$location_name} = $location;
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

# Returns a comment based on the temperature and conditions
# Takes temp in C
sub itsfucking
{
    my ($self, $temp_f, $temp, $cond) = @_;

    my $ret = "IT'S FUCKING ";

    my @arr;
    my @com;

    if ( int($temp) == -40 || int($temp_f) == -40 ) # -40
    {
        @arr = @{$self->{'itsfucking'}{'minus40'}};
        @com = @{$self->{'comment'}{'minus40'}};
    }
    elsif ( $temp <= -34 ) # -35 and below
    {
        @arr = @{$self->{'itsfucking'}{'frozen'}};
        @com = @{$self->{'comment'}{'frozen'}};
    }
    elsif ( $temp < -20 ) # -34 to -21
    {
        @arr = @{$self->{'itsfucking'}{'freezing'}};
        @com = @{$self->{'comment'}{'freezing'}};
    } 
    elsif ( $temp < 0 ) # -20 to -1
    {
        @arr = @{$self->{'itsfucking'}{'cold'}};
        @com = @{$self->{'comment'}{'cold'}};
    }
    elsif ( $temp < 9 ) # 0 to 8 
    {
        @arr = @{$self->{'itsfucking'}{'cool'}};
        @com = @{$self->{'comment'}{'cool'}};
    }
    elsif ( $temp < 18 ) # 9 to 17
    {
        @arr = @{$self->{'itsfucking'}{'alright'}};
        @com = @{$self->{'comment'}{'alright'}};
    }
    elsif ( $temp < 25 ) # 18 to 24
    {
        @arr = @{$self->{'itsfucking'}{'nice'}};
        @com = @{$self->{'comment'}{'nice'}};
    }
    elsif ( $temp < 31 ) # 25 - 30
    {
        @arr = @{$self->{'itsfucking'}{'warm'}};
        @com = @{$self->{'comment'}{'warm'}};
    }
    elsif ( $temp < 35 ) # 30-34
    {
        @arr = @{$self->{'itsfucking'}{'hot'}};
        @com = @{$self->{'comment'}{'hot'}};
    }
    elsif ( $temp >= 35 ) # 35+
    {
        @arr = @{$self->{'itsfucking'}{'boiling'}};
        @com = @{$self->{'comment'}{'boiling'}};
    }

    if ( int($temp_f) == 69 )
    {
        @arr = @{$self->{'itsfucking'}{'sixtynine'}};
        @com = @{$self->{'comment'}{'sixtynine'}};
    }

    my $size = scalar @arr;

    my $num = int(rand($size));
    $ret .= "**" . $arr[$num] . "**";

    $size = scalar @com;
    $num = int(rand($size));
    $ret .= " (*" . $com[$num] . "*)";

    return $ret;
}

1;
