#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;

use Net::Discord;
use Config::Tiny;
use Mojo::IOLoop;
use Bot::Goose;
use Components::Database;
use Data::Dumper;

# Fallback to "config.ini" if the user does not pass in a config file.
my $config_file = $ARGV[0] // 'config.ini';
my $config = Config::Tiny->read($config_file, 'utf8');
say localtime(time) . " Loaded Config: $config_file";

my $self = {};  # For miscellaneous information about this bot such as discord id

# Initialize the bot
my $bot = Bot::Goose->new();

my $discord = Net::Discord->new(
    'token'     => $config->{'discord'}->{'token'},
    'name'      => $config->{'discord'}->{'name'},
    'url'       => $config->{'discord'}->{'redirect_url'},
    'version'   => '1.0',
    'callbacks' => {
        'on_ready'          => \&discord_on_ready,
        'on_guild_create'   => \&discord_on_guild_create,
        'on_message_create' => \&discord_on_message_create,
    },
    'reconnect' => $config->{'discord'}->{'auto_reconnect'},
    'verbose'   => $config->{'discord'}->{'verbose'},
);

# Database
my $db = Components::Database->new(%{$config->{'db'}});

# Now Playing command
if ( $config->{'lastfm'}{'use_np'} )
{
    # Include the module
    use Commands::NowPlaying;

    # Instantiate it, which should register the command with the bot
    # as part of its new() function.
    Commands::NowPlaying->new(
        'bot'       => $bot,
        'discord'   => $discord, 
        'db'        => $db,
        'api_key'   => $config->{'lastfm'}->{'api_key'}
    );
}

if ( $config->{'comic'}{'use_comic'} )
{
    use Commands::Comic;
    Commands::Comic->new(
        'bot'       => $bot,
        'discord'   => $discord
    );
}

sub discord_on_ready
{
    my ($hash) = @_;

    $bot->add_me($hash->{'user'});
    
    $discord->status_update({'game' => $config->{'discord'}{'playing'}});

    say localtime(time) . " Connected to Discord.";
}

sub discord_on_guild_create
{
    my ($hash) = @_;

    say "Adding guild: " . $hash->{'id'} . " -> " . $hash->{'name'};

    $bot->add_guild($hash);
}

sub discord_on_message_create
{
    my $hash = shift;

    my $author = $hash->{'author'};
    my $msg = $hash->{'content'};
    my $channel = $hash->{'channel_id'};
    my @mentions = @{$hash->{'mentions'}};
    my $trigger = $config->{'discord'}->{'trigger'};
    my $discord_name = $bot->my_name();
    my $discord_id = $bot->my_id();

    foreach my $mention (@mentions)
    {
        my $id = $mention->{'id'};
        my $username = $mention->{'username'};

        # Replace the mention IDs in the message body with the usernames.
        $msg =~ s/\<\@$id\>/$username/;
    }

    if ( $msg =~ /^($discord_name|\Q$trigger\E)/i )
    {
        $msg =~ s/^(($discord_name.? ?)|(\Q$trigger\E))//i;   # Remove the username. Can I do this as part of the if statement?

        if ( defined $msg )
        {
            foreach my $pattern ($bot->get_patterns())
            {
                if ( $msg =~ /$pattern/i )
                {
                    my $command = $bot->get_command($pattern);
                    my $object = $command->{'object'};
                    my $function = $command->{'function'};
                    $object->$function($channel, $author, $msg);
                }
            }
        }
    }
}

# Configure the websocket connection for Discord Gateway
$discord->init();

# Start the IOLoop unless it is already running. 
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
