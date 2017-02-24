package Command::Twitch;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_twitch);

use Mojo::Discord;
use Bot::Goose;
use Component::Twitch;
use Component::Database;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Twitch";
my $access = 0; # Public
my $description = "Search Twitch";
my $pattern = '^(twitch|tw) ?(.*)$';
my $function = \&cmd_twitch;
my $usage = <<EOF;
Search for a stream channel: `!twitch <twitch username>`

Set your own twitch channel: `!twitch set <twitch username>`

Link your twitch channel: `!twitch`

Link someone else's twitch channel: `!twitch \@username`

EOF
############################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
     
    # Setting up this command module requires the Discord connection 
    my $bot = $params{'bot'};

    $self->{'bot'}      = $bot;
    $self->{'discord'}  = $bot->discord;
    $self->{'twitch'}   = $bot->twitch;
    $self->{'db'}       = $bot->db;
    $self->{'pattern'}  = $pattern;

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

# This command will search Channels and Streams and return result(s) as Rich Embeds
sub cmd_twitch
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    my $twitch = $self->{'twitch'};

    # Storing their Twitch Username and ID
    if ( defined $args and $args =~ /set (.*)$/i )
    {
        # Query the name, get the channel ID, and then store both.
        my $twitch_name = $1;

        $twitch->search('channels', $twitch_name, sub
        {
            my $json = shift;

            my $db = $self->{'db'};
    
            my $discord_id = $author->{'id'};
            my $discord_name = $author->{'username'};
            my $twitch_id = $json->{'channels'}[0]{'_id'};
                 
            my $sql = "INSERT INTO twitch VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE discord_name = ?, twitch_name = ?, twitch_id = ?";
            $db->query($sql, $discord_id, $discord_name, $twitch_id, $twitch_name, $discord_name, $twitch_name, $twitch_id);
    
            $self->{'cache'}{$discord_id} = $twitch_id; # Cache this so we don't have to check the DB all the time.
    
#            $discord->send_message($channel, "I have updated your Twitch info.");

            # Check if they are streaming
            my $stream = $twitch->get_stream($twitch_id);
    
            # Now display the new results.
            $self->get_twitch_info($channel, $twitch_id);

        });
    }
    # Searching by Discord Mention
    elsif ( defined $args and $args =~ /\<\@\!?(\d+)\>/ )
    {
        # Looking up another user. Do we have their info?
        my $twitch_id = $self->get_stored_id($1);

        if ( defined $twitch_id)
        {
            $self->get_twitch_info($channel, $twitch_id);
        }
        else
        {
            $discord->send_message($channel, $author->{'username'} . ": Sorry, I don't have a twitch name on record for that user.");
        }
    }
    # Searching by twitch username
    elsif ( defined $args and length $args > 1 )
    {
        $twitch->search('channels', $args, sub 
        {
            my $json = shift;

            $self->get_twitch_info($channel, $json->{'channels'}[0]{'_id'});
        });
    }
    # Searching by their own Discord ID
    elsif ( !defined $args or length $args < 2 )
    {
        # Do we have their info saved already?
        my $twitch_id = $self->get_stored_id($author->{'id'});

        if ( defined $twitch_id )
        {
            $self->get_twitch_info($channel, $twitch_id);
        }
        else
        {
            $discord->send_message($channel, $author->{'username'} . ": I don't know your Twitch username. Set it with `!twitch set yournamehere`.");
        }
    }
}

# Check cache and DB for a stored ID
sub get_stored_id
{
    my ($self, $discord_id) = @_;

    # Step 1 - Check Cache
    if ( exists $self->{'cache'}{$discord_id} )
    {
        say localtime(time) . ": Found Twitch ID in Cache";
        return $self->{'cache'}{$discord_id};
    }
    # Step 2 - Check DB
    else
    {
        my $db = $self->{'db'};
 
        my $sql = "SELECT twitch_id FROM twitch WHERE discord_id = ?";
        my $query = $db->query($sql, $discord_id);

        # Have them
        if ( my $row = $query->fetchrow_hashref )
        {
            say localtime(time) . ": Found Twitch ID in DB";
            return $row->{'twitch_id'};
        }
        # Don't have them
        else
        {
            return undef;
        }
    }
}

# Query twitch channel and stream
sub get_twitch_info
{
    my ($self, $channel, $twitch_id) = @_;
    
    my $twitch = $self->{'twitch'};

    $twitch->get_stream($twitch_id, sub
    {
        my $stream_json = shift;

        if ( defined $stream_json->{'stream'} )
        {
            $stream_json->{'stream'}{'channel'}{'live'} = 1;
            my $embed = $self->to_embed($stream_json->{'stream'} );

            $self->send_message($channel, $embed);
        }
        else
        {
            $twitch->get_channel($twitch_id, sub
            {
                my $json_channel = shift;

                my $hash = {
                    'channel' => $json_channel,
                };

                my $embed = $self->to_embed($hash);
                $self->send_message($channel, $embed);
            });
        }
    });
}

# Create an embed hashref and return it
sub to_embed
{
    my ($self, $json) = @_;

    my $fields;

    my $title = $json->{'channel'}{'display_name'};

    if ( defined $json->{'_id'} ) # Stream is live, show viewers and game
    {
        $title = "[LIVE] " . $title;

        $fields = [
            {
                'name' => 'Viewers',
                'value' => $json->{'viewers'},
                'inline' => \1,
            },
            {
                'name' => 'Game',
                'value' => $json->{'game'},
                'inline' => \1,
            }
        ];
    }
    else # Stream is offline, followers and views
    {
        $title = "[Offline] " . $title;

        $fields = [
            {
                'name' => 'Followers',
                'value' => $json->{'channel'}{'followers'},
                'inline' => \1,
            },
            {
                'name' => 'Views',
                'value' => $json->{'channel'}{'views'},
                'inline' => \1,
            }
        ];
    }

    my $embed = {
        'title' => $title,
        'type' => 'rich',
        'description' => $json->{'channel'}{'status'},
        'url' => $json->{'channel'}{'url'},
        'color' => 0x6441a5,
        'timestamp' => $json->{'channel'}{'updated_at'},
        'thumbnail' => {
            'url' => $json->{'channel'}{'logo'},
            'height' => 100,
            'width' =>100
        },
        'fields' => $fields,
    };
    
    return $embed;

    my $message = {
        #'content' => '<' . $json->{'url'} . '>',
        'content' => '',
        'embed' => $embed,
    };

}

# Takes an embed object and sends it via message or webhook (depending if we have one)
sub send_message
{
    my ($self, $channel, $embed) = @_;

    my $bot = $self->{'bot'};
    my $discord = $self->{'discord'};

    if ( my $hook = $bot->has_webhook($channel) )
    {
        my $message = {
            'content' => '',
            'embeds' => [ $embed ],
            'username' => 'Twitch',
            'avatar_url' => 'http://i.imgur.com/IiZWqhx.png', # Twitch Logo
        };

        $discord->send_webhook($channel, $hook, $message);
    }
    else
    {
        my $message = {
            'content' => '',
            'embed' => $embed,
        };

        $discord->send_message($channel, $message);
    }

}

1;
