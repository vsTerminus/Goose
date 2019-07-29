package Command::Weather::Content;

use Moo;
use strictures 2;

use namespace::clean;

# This is a helper file for the Weather command which stores all of the phrases,
# icon links, emotes, comments, etc the command displays along with current conditions.
# It exists largely to cut down on the size of the main Weather.pm file, and
# to better separate the code from the message content.

has icons => ( is => 'ro', default => sub
{
    # DarkSky Icon to Discord Emoji mappings
    {
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
    }
});

has webhook_icons => ( is => 'ro', default => sub
{
    # If we have a webhook in the channel we can use images for avatars instead of emoji!
    {
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
    }
});

has comment => ( is => 'ro', default => sub
{
    {
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
            "I HAVEN'T SEEN THE SUN FOR MONTHS.",
            "FUCK THIS,",
            "EWWWWWW",
            "I NEED A SPACE HEATER FOR MY FACE",
            "MY EYELIDS ARE FROZEN SHUT",
            "MY FACE HURTS",
            "I CAN'T FEEL MY EVERYTHING",
            "I'M MOVING TO MEXICO",
            "GROSS",
            "I MISS SUMMER",
            "CAN IT BE NOT WINTER PLEASE?",
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
            "PUT THE YOU KNOW WHAT IN THE YOU KNOW WHERE",
            "VULCANIZE THE WHOOPEE STICK IN THE HAM WALLET",
            "CATTLE PROD THE OYSTER DITCH WITH THE LAP ROCKET",
            "BATTER DIP THE CRANNY AXE IN THE GUT LOCKER",
            "RETROFIT THE PUDDING HATCH WITH THE BOINK SWATTER",
            "MARINATE THE NETHER ROD IN THE SQUISH MITTEN",
            "POWER DRILL THE YIPPEE BOG WITH THE DUDE PISTON",
            "PRESSURE WASH THE QUIVER BONE IN THE BITCH WRINKLE",
            "CANNONBALL THE FIDDLE COVE WITH THE PORK STEEPLE",
        ],
        'minussixtynine' => [
            "PUT THE FROZEN PENIS IN THE FROZEN VAGINA. NEVER MIND, NO, DON'T DO THAT.",
            "IF TWO BLOCKS OF ICE GOING AT IT IS YOUR THING.",
            "THAT MIGHT BE THE ONLY WAY TO START WARM RIGHT NOW.",
            "ARE YOU HAPPY TO SEE ME OR IS YOUR DICK JUST FROZEN LIKE THAT?",
            "IT'S LIKE WATCHING TWO POLAR BEARS GO AT IT.",
            "EVERYTHING IS NUMB. ARE YOU IN YET?",
            "IF ERECTION LASTS MORE THAN 4 HOURS IT MIGHT BE FROZEN SOLID.",
            "MY NIPPLES ARE LITERALLY ICICLES RIGHT NOW.",
            "I COULD LITERALLY CUT STEEL WITH MY NIPPLES.",
            "JUST KIDDING. FUCK THAT.",
            "FUCK NO. YOU DROP YOUR PANTS IN THIS WEATHER AND SEE HOW IT GOES.",
        ]
    }
});

has itsfucking => ( is => 'ro', default => sub
{
    {
        'frozen' => [
            "FROZEN!",
            "WHAT THE FUCK?!",
            "FRIGID!",
            "COLDER THAN MARS!",
            "EW!",
            "COLDER THAN THE NORTH POLE!",
            "COLDER THAN A HANDJOB FROM AN EDMONTON HOOKER!",
            ":musical_note: COLD AS ICE :notes:",
            "FROSTBITE TERRITORY",
            "TIME TO MOVE SOMEWHERE WARMER!",
            "PERFECT WEATHER TO BE ON FIRE!",
            "DANGEROUS TO GO OUTSIDE!",
            ".... FUCK THIS!"
        ],
        'minus40' => [
            "MINUS 40!",
            "-40!",
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
        'minussixtynine' => [
            'SEXYTIME!'
        ],
    }
});

# Returns a comment based on the temperature and conditions
# Takes both real and feel temperatures in c and f.
sub itsfucking_comment
{
    my ($self, $temp_f, $temp_c, $feel_f, $feel_c, $cond) = @_;

    my $ret = "IT'S FUCKING ";

    my @arr;
    my @com;

    if ( int($temp_c) == -40 || int($feel_c) == -40 ) # -40
    {
        @arr = @{$self->itsfucking->{'minus40'}};
        @com = @{$self->comment->{'minus40'}};
    }
    elsif ( $feel_c <= -34 ) # -35 and below
    {
        @arr = @{$self->itsfucking->{'frozen'}};
        @com = @{$self->comment->{'frozen'}};
    }
    elsif ( $feel_c < -20 ) # -34 to -21
    {
        @arr = @{$self->itsfucking->{'freezing'}};
        @com = @{$self->comment->{'freezing'}};
    } 
    elsif ( $feel_c < 0 ) # -20 to -1
    {
        @arr = @{$self->itsfucking->{'cold'}};
        @com = @{$self->comment->{'cold'}};
    }
    elsif ( $feel_c < 9 ) # 0 to 8 
    {
        @arr = @{$self->itsfucking->{'cool'}};
        @com = @{$self->comment->{'cool'}};
    }
    elsif ( $feel_c < 18 ) # 9 to 17
    {
        @arr = @{$self->itsfucking->{'alright'}};
        @com = @{$self->comment->{'alright'}};
    }
    elsif ( $feel_c < 25 ) # 18 to 24
    {
        @arr = @{$self->itsfucking->{'nice'}};
        @com = @{$self->comment->{'nice'}};
    }
    elsif ( $feel_c < 31 ) # 25 - 30
    {
        @arr = @{$self->itsfucking->{'warm'}};
        @com = @{$self->comment->{'warm'}};
    }
    elsif ( $feel_c < 35 ) # 30-34
    {
        @arr = @{$self->itsfucking->{'hot'}};
        @com = @{$self->comment->{'hot'}};
    }
    elsif ( $feel_c >= 35 ) # 35+
    {
        @arr = @{$self->itsfucking->{'boiling'}};
        @com = @{$self->comment->{'boiling'}};
    }

    if ( int($temp_f) == 69 or int($temp_c) == 69 or int($feel_f) == 69 or $feel_c == 69 )
    {
        @arr = @{$self->itsfucking->{'sixtynine'}};
        @com = @{$self->comment->{'sixtynine'}};
    }

    if ( int($temp_f) == -69 or int($temp_c) == -69 or int($feel_f) == -69 or int($feel_c) == -69 )
    {
        @arr = @{$self->itsfucking->{'minussixtynine'}};
        @com = @{$self->comment->{'minussixtynine'}};
    }

    my $size = scalar @arr;

    my $num = int(rand($size));
    $ret .= "**" . $arr[$num] . "**";

    $size = scalar @com;
    $num = int(rand($size));
    $ret .= " (*" . $com[$num] . "*)";

    return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
