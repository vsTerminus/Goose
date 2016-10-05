#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;

use Net::Discord;
use Config::Tiny;
use Mojo::IOLoop;
use Commands::NowPlaying;
use Commands::Comic;
use Data::Dumper;

# Fallback to "config.ini" if the user does not pass in a config file.
my $config_file = $ARGV[0] // 'config.ini';
my $config = Config::Tiny->read($config_file, 'utf8');
say localtime(time) . " Loaded Config: $config_file";

#######################
#
#   Discord
#
#######################

my $discord_name;
my $discord_id;

my $discord = Net::Discord->new(
    'token'     => $config->{'discord'}->{'token'},
    'name'      => $config->{'discord'}->{'name'},
    'url'       => $config->{'discord'}->{'redirect_url'},
    'version'   => '1.0',
    'callbacks' => {
        'on_ready'          => \&discord_on_ready,
        'on_message_create' => \&discord_on_message_create,
    },
    'reconnect' => $config->{'discord'}->{'auto_reconnect'},
    'verbose'   => $config->{'discord'}->{'verbose'},
);

# Set up commands
my %commands = (
    'nowplaying'   => Commands::NowPlaying->new('discord' => $discord, 'db_config' => $config->{'db'}, 'api_key' => $config->{'lastfm'}->{'api_key'}),
    'comic'        => Commands::RCG->new('discord' => $discord),
);


sub discord_on_ready
{
    my ($hash) = @_;

    $discord_name   = $hash->{'user'}{'username'};
    $discord_id     = $hash->{'user'}{'id'};
    
    $discord->status_update({'game' => 'Opulence'});

    say localtime(time) . " Connected to Discord.";
};

sub discord_on_message_create
{
    my $hash = shift;

    my $author = $hash->{'author'};
    my $msg = $hash->{'content'};
    my $channel = $hash->{'channel_id'};
    my @mentions = @{$hash->{'mentions'}};
    my $trigger = $config->{'discord'}->{'trigger'};

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
            foreach my $command (keys %commands)
            {
                $commands{$command}->on_message_create($channel, $author, $msg);
            }
        }
    }
}

if ( $config->{'discord'}->{'use_discord'} )
{
    # Configure the websocket connection for Discord Gateway
    $discord->init();

    # Kill the gateway every 15 seconds so we can test reconnecting
    # Mojo::IOLoop->recurring(15 => sub { $discord->disconnect("Disconnect Timer Fired") });
}

# Start the IOLoop unless it is already running. 
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
