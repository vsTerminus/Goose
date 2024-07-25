package Command::Duolingo;
use feature 'say';

use Moo;
use strictures 2;

use Component::Duolingo;
use Mojo::Promise;
use Mojo::IOLoop;
use DateTime;
use Data::Dumper;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_duolingo);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has duo                 => ( is => 'lazy', builder => sub { shift->bot->duolingo } );
has db                  => ( is => 'lazy', builder => sub { shift->bot->db } );
has cache               => ( is => 'rw',   default => sub { {} });
has ff                  => ( is => 'lazy', builder => sub { shift->bot->ff } );

has name                => ( is => 'ro', default => 'Duolingo' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Look up Duolingo profile information' );
has pattern             => ( is => 'ro', default => '^duo(?:lingo)? ?' );
has function            => ( is => 'ro', default => sub { \&cmd_duolingo } );
has usage               => ( is => 'ro', default => <<EOF
Look up user profile information on Duolingo

Set your username: !duo set <your duolingo username>

Get your own info: !duo
Get someone else's info: !duo <duolingo username>
EOF
);

sub cmd_duolingo
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};
    my $pattern = $self->pattern;
    $args =~ s/$pattern//;
    my $duo_user;

    my $use_duo = $self->ff->get_flag("use_duolingo");
    unless ( $use_duo )
    {
        $self->discord->send_message($channel, ":x: Command is currently disabled");
        return;
    }

    # Check for login
    unless ( $self->duo->jwt and length $self->duo->jwt > 0 )
    {
        $self->discord->send_message($channel, ":x: Unable to log in; Config is missing JWT");
        return;
    }

    # !duo
    if ( length $args == 0 )
    {
        # Stored ID
        if ( my $duo_id = $self->_cached_id($author->{'id'}) )
        {
            $self->log->debug('[Duolingo.pm] [cmd_duolingo] Found stored Duolingo ID (' . $duo_id . ') for Discord ID ' . $author->{'id'});
            $duo_user = $duo_id;
        }
        # Not stored
        else
        {
            $self->discord->send_message($channel, "Sorry, I don't have your duolingo username on file.");
            $self->discord->send_dm($author->{'id'}, <<EOF
To set your Duolingo username use the following command: `!duo set <your username>`

For example, `!duo set TheLegend27`

You can do that here or in a public channel. Once set you'll be able to use `!duo`.
EOF
);
        }
    }
    # !duo @user
    elsif ( $args =~ /\<\@\&?\!?(\d+)\>/ )
    {
        my $discord_id = $1;
        
        if ( my $duo_id = $self->_cached_id($discord_id) )
        {
            $self->log->debug('[Duolingo.pm] [cmd_duolingo] Found stored Duolingo ID (' . $duo_id . ') for Discord ID ' . $discord_id);
            $duo_user = $duo_id;
        }
        else
        {
            $self->discord->send_message($channel, "Sorry, I don't have a duolingo username on file for that person.");
        }
    }
    # !duo set <[username]|[timezone]>
    elsif ( $args =~ /^set (.+)$/i )
    {
        my $duo_user = $1;
        my $timezone;
        
        $duo_user =~ s/ ?username //i;
        $duo_user =~ s/ ?timezone //i;

        # Look for a Timezone string, eg "America/Winnipeg" or "America/Kentucky/Louisville"
        if ( $duo_user =~ /([a-z-_]+\/[a-z-_]+(\/[a-z-_]+)?)/i )
        {
           $timezone = $1;
           say "Detected Timezone: " . Dumper($timezone);

           $duo_user =~ s/ ?$timezone ?//; # Remove it, leaving just the user name (or nothing)
        }

        $duo_user =~ s/\s//g; # Remove spaces from username (if there are any)

        if ( length $duo_user )
        {
            $self->duo->web_user_info_p($duo_user)->then(sub
            {
                my $json = shift;
                my $duo_id = $json->{'id'};

                if ( $timezone )
                {
                    $self->db->query('INSERT INTO duolingo (discord_id, duolingo_id, timezone) VALUES ( ?, ?, ? ) ON DUPLICATE KEY UPDATE duolingo_id = ?, timezone = ?', $author->{'id'}, $duo_id, $timezone, $duo_id, $timezone);
                }
                else
                {    
                    $self->db->query('INSERT INTO duolingo (discord_id, duolingo_id) VALUES ( ?, ? ) ON DUPLICATE KEY UPDATE duolingo_id = ?', $author->{'id'}, $duo_id, $duo_id);
                }

                # Also follow the user
                $self->duo->follow_p($json->{'id'});

                $self->discord->send_message($channel, "Your duolingo username is now: " . $duo_user);
            });
        }
        else # Just update the timezone
        {
            $self->db->query('UPDATE duolingo SET timezone = ? WHERE discord_id = ?', $timezone, $author->{'id'});
            $self->discord->send_message($channel, "Your timezone is now: " . $timezone);
        }
    }
    # We have a username/id, whether it was stored or passed
    if ( defined $duo_user )
    {
        if ( exists $self->cache->{$duo_user} and time <= $self->cache->{$duo_user}{'expires'} )
        {
            my $web = $self->cache->{$duo_user}{'web'};
            my $android = $self->cache->{$duo_user}{'android'};
            my $leaderboard = $self->cache->{$duo_user}{'leaderboard'};

            my $content = $self->_build_message({
                'web' => $web,
                'android' => $android,
                'leaderboard' => $leaderboard,
            });

            $self->_send_content($channel, $web->{'fullname'}, $content);
        }
        else
        {
            my $web_promise         = $self->duo->web_user_info_p($duo_user);
            my $android_promise     = $self->duo->android_user_info_p($duo_user);
            my $leaderboard_promise = $self->duo->leaderboard_p($duo_user);

            Mojo::Promise->all($web_promise, $android_promise, $leaderboard_promise)->then(sub
            {
                my ($web_tx, $android_tx, $leaderboard_tx) = @_;

                my $web_json         = $web_tx->[0];
                my $android_json     = $android_tx->[0];
                my $leaderboard_json = $leaderboard_tx->[0];

                my $content = $self->_build_message({
                        'web' => $web_json,
                        'android' => $android_json,
                        'leaderboard' => $leaderboard_json,
                    });
                
                $self->_cache_content({
                        'user' => $duo_user, 
                        'web' => $web_json,
                        'android' => $android_json,
                        'leaderboard' => $leaderboard_json
                    });
                $self->_store_current_course($android_json);
      
                $self->_send_content($channel, $web_json->{'fullname'}, $content);
            })->catch(sub
            {
                my $err = shift;
                say Dumper($err);
            });
        }
    }
}

sub _cache_content
{
    my ($self, $args) = @_;

    my $duo_user = $args->{'user'};
    $self->cache->{$duo_user}{'web'} = $args->{'web'};
    $self->cache->{$duo_user}{'android'} = $args->{'android'};
    $self->cache->{$duo_user}{'leaderboard'} = $args->{'leaderboard'};
    $self->cache->{$duo_user}{'expires'} = time + 60;    # Cache for 1 minute
    Mojo::IOLoop->timer(61 => sub { delete $self->cache->{$duo_user} if time > $self->cache->{$duo_user}{'expires'}; }); # Clean up cache entries after 5 minutes
}

sub _store_current_course
{
    my ($self, $json) = @_;

    my $lang_abbr = $json->{'learning_language'};
    my $id = $json->{'id'};
    my $query = 'UPDATE duolingo SET current_course = ? WHERE duolingo_id = ?';
    $self->db->query($query, $lang_abbr, $id);
}

# Get the duolingo ID from a discord ID
sub _cached_id
{
    my ($self, $discord_id) = @_;

    my $query = 'SELECT duolingo_id from duolingo where discord_id = ?';
    my $dbh = $self->db->query($query, $discord_id);
    my $row = $dbh->fetchrow_hashref;
    my $duo_id = $row->{'duolingo_id'} // undef;
    return $duo_id;
}

# Handles choosing between a webhook or a message
sub _send_content
{
    my ($self, $channel, $username, $content) = @_;

    # Angry owl if they haven't done a lesson yet. Happy owl if they have.
    my $duo_owl = $content =~ /duo_fire_unlit/ ? 'https://i.imgur.com/tGFScKd.png' : 'http://i.imgur.com/EdGBXeW.png';

    if (my $hook = $self->bot->has_webhook($channel) )
    {
        my $message = {
            'content' => $content,
            'username' => $username,
            'avatar_url' => $duo_owl,
        };

        $self->discord->send_webhook($channel, $hook, $message);
    }
    else
    {
        my $message = $content;
        $self->discord->send_message($channel, $message);
    }


}

# Takes a language code and returns a flag emoji
sub _flag
{
    my ($self, $lang) = @_;

    # Gonna have to start using custom emojis for this.
    my %flags = (
        'nn'    => ':flag_no:', # Nynorsk -> Norway
        'no-BO' => ':flag_no:', # Nynorsk -> Norway
        'nb'    => ':flag_no:', # Bokmål -> Norway
        'ja'    => ':flag_jp:', # Japanese -> Japan
        'zs'    => ':flag_cn:', # Chinese -> China
        'en'    => ':flag_gb:', # English -> Great Britain
        'hw'    => ':flag_us:', # Hawaiian -> USA
        'tlh'   => '<:flag_tlh:702749901813186664>', # Klingon -> Custom Klingon Flag Emoji
        'ko'    => ':flag_kr:', # Korean -> South Korea
    );

    my $flag = ( exists $flags{$lang} ? $flags{$lang} : ":flag_$lang:" );

    return $flag;
}

sub _build_message
{
    my ($self, $args) = @_;

    my $web = $args->{'web'};
    my $android = $args->{'android'};
    my $leaderboard = $args->{'leaderboard'};

    # Some custom emoji used here
    my $duo_xp_silver = "<:duo_xp_silver:975965671479459870>";
    my $duo_xp_gold = "<:duo_xp_gold:975986422941114378>";
    my $duo_fire_lit = "<:duo_fire_lit:975968995796725790>";
    my $duo_fire_unlit = "<:duo_fire_unlit:975968995893215302>";
    my $duo_egg = "<:duo_egg:975980206202425414>";
    my $duo_egg_cracked = "<:duo_egg_cracked:975980206164680794>";
    
    # We get all of the courses back, so we can loop through them
    # Limit to three courses max
    my @courses;
    foreach my $course (@{$android->{'courses'}})
    {
        my $title = $course->{'title'};
        my $lang_abbr = $course->{'learningLanguage'};
        my $flag = $self->_flag($lang_abbr);
        my $course_xp = $course->{'xp'};
   
        my $msg = "$flag $title $duo_xp_silver $course_xp Course XP";
        push @courses, $msg;
    }
    my @top3 = splice(@courses, 0, 3);

    my $total_xp = $android->{'totalXp'} // 0;

    my $query = $self->db->query('SELECT timezone FROM duolingo WHERE duolingo_id = ?', $android->{'id'});
    my $row = $query->fetchrow_hashref;
    my $timezone = ( $row ? $row->{'timezone'} : 'America/Winnipeg' );
    my $now = DateTime->now(time_zone => $timezone);


    # Notes:
    # To get today's XP I need the calendar, which only comes from the web API
    # So I guess I have to fetch both APIs and use info from both.
    # Fak.

    # Also still need to figure out how to get the Leaderboard ID.

    # Use the calendar structure to figure out how much XP the user has today
    my $xp = 0;

    my $calendar = $web->{'calendar'};
    my $num_lessons = 0;
    foreach my $event (@{$calendar})
    {
        if ( exists $event->{'datetime'} )
        {
            my $dt = DateTime->from_epoch(
                epoch => substr( $event->{'datetime'}, 0, 10 ),
                time_zone => $timezone,
            );

            if ( $dt->day == $now->day )
            {
                if ( exists $event->{'improvement'} and defined $event->{'improvement'} )
                {
                    $xp += $event->{'improvement'};
                    $num_lessons++;
                    if ( exists $event->{'event_type'} and defined $event->{'event_type'} )
                    {
                        say $event->{'event_type'} . " => " . $event->{'improvement'} . " XP";
                    }
                    else
                    {
                        say "Unknown Lesson Type => " . $event->{'improvement'} . " XP";
                    }
                }
            }
        }
        else
        {
            say Dumper($event);
        }
    }
    $num_lessons .= $num_lessons == 1 ? " lesson" : " lessons";

    # Finally, get leaderboard league
    my @tiers = qw(Bronze Silver Gold Sapphire Ruby Emerald Amethyst Pearl Obsidian Diamond);
    my $tier = $leaderboard->{'tier'};
    my $streak = $leaderboard->{'streak_in_tier'};
    my $days = $android->{'streak'} // 0;
    my $league = $tiers[$tier];
    my $league_emoji = _league_emoji($tier);


    my $msg = '';
    # Flag Language - Level
    # Streak - Exp Today
    #$msg .= $_ . "\n" foreach (@top3); # Display the most recent three languages
    $msg .= $top3[0] // "Profile Unavailable"; # Just the first line.
    $msg .= $xp > 0 ? "\n$duo_fire_lit " : "\n$duo_fire_unlit ";
    $msg .= $days . " day";
    $msg .= "s" if $days != 1;
    $msg .= " ";
    $msg .= $xp > 0 ? "$duo_egg $xp XP Today ($num_lessons)" : "$duo_egg_cracked No lessons yet today";
    $msg .= "\n$league_emoji $league League";
    $msg .= " x$streak" if $streak > 1;
    $msg .= " $duo_xp_gold $total_xp Total XP";

    return $msg;
}

sub _league_emoji
{
    my $tier = shift;

    my @emojis = qw(
        <:duo_bronze:699866744365252658>
        <:duo_silver:699866744444944395>
        <:duo_gold:699866744411390001>
        <:duo_sapphire:699866744193548310> 
        <:duo_ruby:699866744201674809> 
        <:duo_emerald:699866744583487568>
        <:duo_amethyst:699866744562515988>
        <:duo_pearl:699866744415715409>
        <:duo_obsidian:699866744478629899>
        <:duo_diamond:699866743979376722>
    );

    return $emojis[$tier];
}

1;
