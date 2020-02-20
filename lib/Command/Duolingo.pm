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
our @EXPORT_OK = qw(cmd_template);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has duo                 => ( is => 'lazy', builder => sub { shift->bot->duolingo } );
has db                  => ( is => 'lazy', builder => sub { shift->bot->db } );
has cache               => ( is => 'rw',   default => sub { {} });

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

    # Check for login
    unless ( $self->duo->jwt )
    {
        $self->duo->login_p()->then(sub{ $self->cmd_duolingo($msg) });
        return undef;
    }


    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};

    my $args = $msg->{'content'};
    
    my $pattern = $self->pattern;
    $args =~ s/$pattern//;

    my $duo_user;

    # !duo
    if ( length $args == 0 )
    {
        # Stored ID
        if ( my $duo_id = $self->_get_stored_id($author->{'id'}) )
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
        
        if ( my $duo_id = $self->_get_stored_id($discord_id) )
        {
            $self->log->debug('[Duolingo.pm] [cmd_duolingo] Found stored Duolingo ID (' . $duo_id . ') for Discord ID ' . $discord_id);
            $duo_user = $duo_id;
        }
        else
        {
            $self->discord->send_message($channel, "Sorry, I don't have a duolingo username on file for that person.");
        }
    }
    # !duo top##
    elsif ( $args =~ /^top ?(\d+)$/ )
    {
        my $num = ( $1 > 0 and $1 <= 10 ? $1 : 10 );

        say "Displaying the Top $num people on the leaderboard";

        my $dt = DateTime->now;
        #        $dt->set_timezone('America/Winnipeg');

        my $timestamp = $dt->strftime("%Y.%m.%d %H:%M:%S");
        say "Timestamp: $timestamp";
        $self->duo->leaderboard_p('week', $timestamp)->then(sub
        { 
            my $json = shift;

            say Data::Dumper->Dump([$json], ['json']);
        });
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
            $self->duo->user_info_p($duo_user)->then(sub
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
                $self->discord->send_message($channel, "Your duolingo username is now: " . $duo_user);
            });
        }
        else # Just update the timezone
        {
            $self->db->query('UPDATE duolingo SET timezone = ? WHERE discord_id = ?', $timezone, $author->{'id'});
            $self->discord->send_message($channel, "Your timezone is now: " . $timezone);
        }
    }
    else
    {
        $duo_user = $args;
    }

    # We have a username/id, whether it was stored or passed
    if ( defined $duo_user )
    {
        if ( exists $self->cache->{$duo_user} and time <= $self->cache->{$duo_user}{'expires'} )
        {
            say "Cached!";
            my $json = $self->cache->{$duo_user}{'json'};

            my $content = $self->_build_message($json);

            $self->_send_content($channel, $json->{'fullname'}, $content);
        }
        else
        {
            say "Not Cached";
            $self->duo->user_info_p($duo_user)->then(sub
            {
                my $json = shift;
                
                $self->cache->{$duo_user}{'json'} = $json;
                $self->cache->{$duo_user}{'expires'} = time + 60;    # Cache for 1 minute
                Mojo::IOLoop->timer(61 => sub { delete $self->cache->{$duo_user} if time > $self->cache->{$duo_user}{'expires'}; }); # Clean up cache entries after 5 minutes
        
                my $content = $self->_build_message($json);     # Pull out certain fields and format it for Discord

                $self->_send_content($channel, $json->{'fullname'}, $content);
            });
    }
    }
}

# Handles choosing between a webhook or a message
sub _send_content
{
    my ($self, $channel, $username, $content) = @_;


    if (my $hook = $self->bot->has_webhook($channel) )
    {
        my $message = {
            'content' => $content,
            'username' => $username,
            'avatar_url' => 'http://i.imgur.com/EdGBXeW.png', # Duolingo owl
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

    return ":alien:" if $lang eq 'kl'; # Klingon - special case.

    my %flags = (
        'nn'    => 'no', # Nynorsk -> Norway
        'nb'    => 'no', # Bokmål -> Norway
        'ja'    => 'jp', # Japanese -> Japan
        'zs'    => 'cn', # Chinese -> China
    );

    my $flag = ":flag_";
    $flag .= ( exists $flags{$lang} ? $flags{$lang} : $lang );
    $flag .= ":";

    return $flag;
}

sub _build_message
{
    my ($self, $json) = @_;

    my $lang_abbr = $json->{'learning_language'};
    my $flag = $self->_flag($lang_abbr); # Countries with multiple languages will have multiple language codes that may not match a country flag. We can fix these as we find them.
    my $lang_data = $json->{'language_data'}{$lang_abbr};

    my $query = $self->db->query('SELECT timezone FROM duolingo WHERE duolingo_id = ?', $json->{'id'});
    my $row = $query->fetchrow_hashref;
    my $timezone = ( $row ? $row->{'timezone'} : 'America/Winnipeg' );
    my $now = DateTime->now(time_zone => $timezone);

    # Use the calendar structure to figure out how much XP the user has today
    my $xp = 0;
    my $calendar = $json->{'calendar'};
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
                $xp += $event->{'improvement'};
                say $event->{'event_type'} . " => " . $event->{'improvement'} . " XP";
            }
        }
        else
        {
            say Dumper($event);
        }
    }

    # Use the language_data structure to count crowns ("levels_finished")
    my $crowns = 0;
    my $lessons = 0;
    foreach my $skill (@{$lang_data->{'skills'}})
    {
        $crowns += $skill->{'levels_finished'};
        $lessons++ if $skill->{'levels_finished'};
        #say "" . $skill->{'title'} . ' => ' . $skill->{'levels_finished'} . ' => ' . $crowns if $skill->{'levels_finished'};
    }

    my $msg = '';
    # Flag Language - Level
    # Streak - Exp Today
    $msg .= $flag . ' ' . $json->{'learning_language_string'};
    $msg .= " - " . $lang_data->{'points'} . " XP\n";
    $msg .= ":crown: " . $crowns . " Crown";
    $msg .= 's' if $crowns != 1;
    $msg .= " - " . $lessons . " Lesson";
    $msg .= 's' if $lessons != 1;
    $msg .= "\n:fire: " . $lang_data->{'streak'} . " day";
    $msg .= "s" if $lang_data->{'streak'} != 1;
    $msg .= " - $xp XP Today";

    return $msg;
}

sub _get_stored_id
{
    my ($self, $discord_id) = @_;

    my $query = $self->db->query('SELECT * from duolingo where discord_id = ?', $discord_id);
   
    if ( my $row = $query->fetchrow_hashref )
    {
        return $row->{'duolingo_id'};
    }
    return undef;
}



1;
