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
use Command::Play;
use Command::Info;
use Command::YouTube;
use Command::Say;
use Command::Hook;
use Command::PYX;
use Command::Define;
use Command::Twitch;
use Data::Dumper;

# Fallback to "config.ini" if the user does not pass in a config file.
my $config_file = $ARGV[0] // 'config.ini';
my $config = Config::Tiny->read($config_file, 'utf8');
say localtime(time) . " Loaded Config: $config_file";

my $self = {};  # For miscellaneous information about this bot such as discord id

# Initialize the bot
my $bot = Bot::Goose->new(%{$config});

# Register the commands
# The new() function in each command will register with the bot.
Command::Help->new          ('bot' => $bot);
Command::Say->new           ('bot' => $bot);
Command::Avatar->new        ('bot' => $bot);
Command::Pick->new          ('bot' => $bot);
Command::Leave->new         ('bot' => $bot);
Command::Play->new          ('bot' => $bot);
Command::Info->new          ('bot' => $bot);
Command::Hook->new          ('bot' => $bot);
Command::Define->new        ('bot' => $bot);
Command::Twitch->new        ('bot' => $bot);
Command::YouTube->new       ('bot' => $bot) if ( $config->{'youtube'}{'use_youtube'} );
Command::Comic->new         ('bot' => $bot) if ( $config->{'comic'}{'use_comic'} );
Command::Weather->new       ('bot' => $bot) if ( $config->{'weather'}{'use_weather'} );
Command::NowPlaying->new    ('bot' => $bot) if ( $config->{'lastfm'}{'use_lastfm'} );
Command::PYX->new           ('bot' => $bot) if ( $config->{'cah'}{'use_cah'} );

# Start the bot
$bot->start();
