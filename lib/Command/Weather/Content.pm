package Command::Weather::Content;

use Moo;
use strictures 2;

use namespace::clean;

# This is a helper file for the Weather command which stores all of the phrases,
# comments, etc the command displays along with current conditions.
# It exists largely to cut down on the size of the main Weather.pm file, and
# to better separate the code from the message content.

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
            "\N{DEGREE SIGN}F AND \N{DEGREE SIGN}C AGREE, -40 FUCKING SUCKS.",
            "HEY, DID YOU KNOW THAT -40\N{DEGREE SIGN}F IS ALSO -40\N{DEGREE SIGN}C?",
            "WHAT? IT'S -40 IN \N{DEGREE SIGN}F *AND* \N{DEGREE SIGN}C??? WHO CARES. IT'S FUCKING COLD EITHER WAY.",
        ],
        'freezing' => [
            "I HOPE YOU PLUGGED YOUR CAR IN.",
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
            "IT FEELS LIKE I'M STANDING IN A REFRIGERATOR",
            "HOT OR COLD. MAKE UP YOUR GODDAMN MIND!",
            "I HAVE NO IDEA HOW TO DRESS TODAY.",
            "I MISS SUMMER ALREADY.",
            "CAN I GO BACK INSIDE?",
            "DOES ANYONE KNOW HOW TO START A FIRE WITH A TWIG AND SOME STRING?",
            "BEING ON FIRE SOUNDS NICE RIGHT ABOUT NOW.",
        ],
        'wet' => [
            "MY UMBRELLA IS TOO SMALL",
            "MY UMBRELLA IS TOO BIG",
            "MY CLOTHES ARE SOAKED",
            "I'M SOAKED!",
            "STAY INSIDE!",
            "I'M GONNA MAKE IT SO WET FOR YOU",
            "I'M SO WET RIGHT NOW",
            "STOP, YOU'RE MAKING ME WET",
            ":musical_note: RAIN RAIN GO AWAY, DON'T COME BACK ANOTHER DAY",
            ":musical_note: RAIN RAIN GO AWAY",
            ":musical_note: RAIN RAIN.... FUCK OFF",
            "SINGING IN THE RAIN",
            "DANCING IN THE RAIN",
            "EWWWWWW",
            "HOORAY!",
        ],
        'humid' => [
            "I FEEL LIKE I'M STANDING IN A SWIMMING POOL... BUT IT'S EVERYWHERE",
            "SO FUCKING GROSS RIGHT NOW",
            "I'M SWEATING ENOUGH FOR THE BOTH OF US",
            "MY CLOTHES ARE SOAKED",
            "GROSS",
            "EW",
            "YUCK!",
            "WHYYY",
            "IT'S NOT THE HEAT, IT'S THE HUMIDITY",
            "FUUUUUUUCK",
            "I'M DROWNING IN MY OWN SWEAT",
        ],
        'cloudy' => [
            "WHO TURNED OFF THE SUN?",
            "WHERE'D THE FUCKING SUN GO?",
            "BRING BACK THE SUN!",
            "I MISS THE SUN",
            "REQUEST IFR CLEARANCE TO STAY THE FUCK INSIDE",
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
            "WARP ME TO HALIFAX",
            "I HAVE A BUSINESS INSTALLING STYROFOAM NUNS."
        ],
        'nice' => [
            "GO OUTSIDE!",
            "WHY ARE YOU STILL INSIDE?",
            "GET OFF THE COMPUTER AND GO OUTSIDE!",
            "GET OFF YOUR ASS AND GO OUTSIDE.",
            "WHY CAN'T IT BE LIKE THIS ALL YEAR?",
            "WEAR A SWEATER IF YOU DON'T LIKE IT.",
            "I LOVE IT",
            "BEST WEATHER",
            "FUCK YEAH!",
            "TOUCH GRASS!",
            "OUTDOOR NAP TIME!",
            "NO FURNACE, NO A/C, JUST OPEN WINDOWS",
            "OPEN THE WINDOWS!",
            "NOT TOO HOT, NOT TOO COLD",
            "GIVE ME FOUR GLASSES OF APPLE JUICE.",
            "YOU AND ME IN JAPAN. WATCH ME DANCE.",
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
            "MORE OF THIS PLEASE",
            "FUCK WINTER",
            "LET'S RUN THROUGH THE SPRINKLER!",
            "LET'S SET UP THE SLIP'N'SLIDE!",
            "APPLE JUICE! FOR HALF PRICE?!",
            "JESUS IS A RAISIN.",
        ],
        'hot' => [
            "THIS SUCKS.",
            "PERFECT WEATHER TO STAY INSIDE.",
            "HOPE YOU'VE GOT AIR CONDITIONING!",
            "HOPE YOU'VE GOT A HEAT PUMP!",
            "PERFECT WEATHER TO DO NOTHING.",
            "STOP, I CAN ONLY TAKE SO MUCH OFF!",
            "I MISS WINTER.",
            "WHY DO YOU LIVE HERE?",
            "DO YOU LIVE HERE ON PURPOSE?",
            "POOOOL!",
            "FUCK SUNBURNS!",
            "MAKE IT STOP!",
            "FUCK IT, WE'RE GOING TO THE LAKE!",
            "BRB, GONNA GO STAND IN THE FREEZER.",
            "BRB, FILLING THE BATHTUB WITH ICE CUBES.",
            "BRB, FILLING MY POCKETS WITH ICE CUBES.",
            "WHAT DO YOU SAY WE MAKE APPLE JUICE AND FAX IT TO EACH OTHER?",
            "DID YOU WATER YOUR AIRPORT, JIM?"
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
            "THIS FUCKING SUCKS.",
            "I'M CONSIDERING SLEEPING IN THE FREEZER.",
            "FUCK IT, WE'RE GOING TO THE LAKE!",
            "FUCK IT. I'M OUT!",
            "FUCK IT. LET'S MOVE TO ALASKA.",
            "FUCK IT. LET'S MOVE TO GREENLAND.",
            "FUCK IT. LET'S MOVE TO ANTARCTICA.",
            "I NEED AIR CONDITIONING FOR MY PANTS.",
            "I NEED AIR CONDITIONING FOR MY FACE.",
            "ARE YOU ON FIRE???",
            "WHY DO YOU LIVE WHERE THE AIR HURTS YOUR FACE?",
            "FUCK OFF, YOU GIANT YELLOW BALL OF EVIL!",
            "EVEN THE TREES ARE MELTING!",
            "I'D CALL FOR HELP BUT MY PHONE MELTED!",
            "EVERYTHING IS MELTING",
            "EVERYTHING IS ON FIRE",
            "(Please be safe)",
            "HOLY FUCK. ARE YOU DRINKING WATER YET?",
            "HOLY FUCK. DRINK SOME WATER!",
            "HOLY FUCK. TIME TO DRINK A GALLON OF WATER!",
            "HOLY FUCK. TIME TO DRINK A LITRE OF WATER!",
            "PERFECT DAY TO DRINK LOTS OF FUCKING WATER!",
            "DON'T FORGET TO DRINK SOME FUCKING WATER!",
            "DON'T FORGET YOUR FUCKING WATER BOTTLE!",
            "ANYONE WANNA COOK AN EGG ON THE SIDEWALK?",
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
            "TODAY'S WEATHER IS BROUGHT TO YOU BY PORNHUB",
            "TODAY'S WEATHER IS BROUGHT TO YOU BY BRAZZERS",
            "TODAY'S WEATHER IS BROUGHT TO YOU BY CHATURBATE",
            "TODAY'S WEATHER IS BROUGHT TO YOU BY REDTUBE",
            "NSFW!",
            "TODAY'S WEATHER IS NOT SAFE FOR WORK. GOOD EXCUSE TO STAY HOME!",
            "TODAY'S WEATHER IS NOT SAFE FOR WORK. UNLESS YOU'RE A PORNSTAR.",
            "FUCK. LITERALLY.",
            "WHAT'S THE SPEED LIMIT OF SEX? 68! BECAUSE AT 69 YOU BLOW A ROD.",
            "UHN TISS UHN TISS UHN TISS BABY",
            "BROWN CHICKEN BROWN COW",
            "BOW CHICKA WOW WOW",
            "THIS WEATHER MAKES ME HORNY",
            "I'M SO HARD RIGHT NOW",
            "37 DICKS! MY GIRLFRIEND SUCKED 37 DICKS! ...IN A ROW?",
            "THEY CALL IT A SLOPPY AARDVARK",
            "GIVE ME AN ALABAMA JACKHAMMER",
            "THEY CALL IT A SHORT STACK MOTOR BOAT RACK ATTACK",
            "GIMME THE NEW JERSEY JACKHAMMER",
            "WANT TO TRY THE AMISH JACKHAMMER?",
        ],
        'minussixtynine' => [
            "PUT THE FROZEN PENIS IN THE FROZEN VAGINA. NEVER MIND, NO, DON'T DO THAT.",
            "IF TWO BLOCKS OF ICE GOING AT IT IS YOUR THING.",
            "THAT MIGHT BE THE ONLY WAY TO STAY WARM RIGHT NOW.",
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
            'NICE',
            'PRETTY OK',
            'PRETTY NICE',
            'AWESOME',

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
        'wet' => [
            'WET!',
            'RAINING!',
        ],
        'humid' => [
            'GROSS!',
            'HUMID!',
        ],
        'cloudy' => [
            'CLOUDY!',
            'OVERCAST!',
            'DARK AND GLOOMY!',
            'GLOOMY!',
            'NOT VERY NICE!',
        ],
    }
});

# Returns a comment based on the temperature and conditions
# Takes both real and feel temperatures in c and f.
sub itsfucking_comment
{
    my ($self, $temp_f, $temp_c, $feel_f, $feel_c, $cond, $humidity) = @_;

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
    # Above zero we can look at conditions for signs of rain
    elsif ( $cond =~ /rain/i )
    {
        @arr = @{$self->itsfucking->{'wet'}};
        @com = @{$self->comment->{'wet'}};
    }
    elsif ( $feel_c < 9 ) # 0 to 8 
    {
        @arr = @{$self->itsfucking->{'cool'}};
        @com = @{$self->comment->{'cool'}};
    }
    # When it's not too hot but it's cloudy, it's not "nice" or "warm", it's cloudy.
    elsif ( $feel_c < 30 and ( $cond =~ /Overcast/i ))
    {
        @arr = @{$self->itsfucking->{'cloudy'}};
        @com = @{$self->comment->{'cloudy'}};
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
    # Above 25C, anything >= 90% humidity
    elsif ( $humidity >= 90 )
    {
        @arr = @{$self->itsfucking->{'humid'}};
        @com = @{$self->comment->{'humid'}};
    }
    elsif ( $feel_c < 31 ) # 25 - 30
    {
        @arr = @{$self->itsfucking->{'warm'}};
        @com = @{$self->comment->{'warm'}};
    }
    # Above 30C, anything >= 75% humidity
    elsif ( $humidity >= 75 )
    {
        @arr = @{$self->itsfucking->{'humid'}};
        @com = @{$self->comment->{'humid'}};
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
