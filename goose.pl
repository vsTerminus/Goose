#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;

binmode STDOUT, ":utf8";

use Config::Tiny;
use Bot::Goose;
use Command::NowPlaying;
use Command::Comic;
use Command::Help;
use Command::Avatar;
use Command::Pick;
use Command::Weather;
use Command::Leave;
use Data::Dumper;

# Fallback to "config.ini" if the user does not pass in a config file.
my $config_file = $ARGV[0] // 'config.ini';
my $config = Config::Tiny->read($config_file, 'utf8');
say localtime(time) . " Loaded Config: $config_file";

my $self = {};  # For miscellaneous information about this bot such as discord id

# Initialize the bot
my $bot = Bot::Goose->new(
    'discord'   => $config->{'discord'},
    'db'        => $config->{'db'},
#    'youtube'   => $config->{'youtube'},
    'weather'   => $config->{'weather'},
);

# Register the commands
# The new() function in each command will register with the bot.
if ( $config->{'lastfm'}{'use_np'} )
{
    Command::NowPlaying->new(
        'bot'       => $bot,
        'api_key'   => $config->{'lastfm'}->{'api_key'}
    );
}

if ( $config->{'comic'}{'use_comic'} )
{
    Command::Comic->new('bot' => $bot);
}

if ( $config->{'weather'}{'use_weather'} )
{
    Command::Weather->new(
        'bot'       => $bot,
        'api_key'   => $config->{'weather'}{'api_key'}
    );
}

Command::Help->new      ('bot' => $bot);
Command::Avatar->new    ('bot' => $bot);
Command::Pick->new      ('bot' => $bot);
Command::Leave->new     ('bot' => $bot);

# Start the bot
$bot->start();
