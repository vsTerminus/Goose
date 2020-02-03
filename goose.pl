#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;

binmode STDOUT, ":utf8";

use Config::Tiny;
use Bot::Goose;
use Command::NowPlaying;
use Command::Help;
use Command::Avatar;
use Command::Pick;
use Command::Weather;
use Command::Leave;
use Command::Info;
use Command::YouTube;
use Command::Say;
use Command::Hook;
use Command::PYX;
use Command::Define;
use Command::Twitch;
use Command::Roll;
use Command::MLB;
use Command::Uptime;
use Data::Dumper;

# Fallback to "config.ini" if the user does not pass in a config file.
my $config_file = $ARGV[0] // 'config.ini';
my $config = Config::Tiny->read($config_file, 'utf8');
say localtime(time) . " Loaded Config: $config_file";

# Initialize the bot
my $bot = Bot::Goose->new('config' => $config);

# Register the commands
# The new() function in each command will register with the bot.
$bot->add_moo_command( Command::Help->new           ('bot' => $bot) );
$bot->add_moo_command( Command::Say->new            ('bot' => $bot) );
$bot->add_moo_command( Command::Avatar->new         ('bot' => $bot) );
$bot->add_moo_command( Command::Pick->new           ('bot' => $bot) );
$bot->add_moo_command( Command::Leave->new          ('bot' => $bot) );
$bot->add_moo_command( Command::Info->new           ('bot' => $bot) );
$bot->add_moo_command( Command::Hook->new           ('bot' => $bot) );
$bot->add_moo_command( Command::Define->new         ('bot' => $bot) );
$bot->add_moo_command( Command::Twitch->new         ('bot' => $bot) );
$bot->add_moo_command( Command::Roll->new           ('bot' => $bot) );
$bot->add_moo_command( Command::MLB->new            ('bot' => $bot) );
$bot->add_moo_command( Command::Weather->new        ('bot' => $bot) )   if ( $config->{'weather'}{'use_weather'} );
$bot->add_moo_command( Command::Uptime->new         ('bot' => $bot) );
$bot->add_moo_command( Command::YouTube->new        ('bot' => $bot) )   if ( $config->{'youtube'}{'use_youtube'} );
$bot->add_moo_command( Command::NowPlaying->new     ('bot' => $bot) )   if ( $config->{'lastfm'}{'use_lastfm'} );
$bot->add_moo_command( Command::PYX->new            ('bot' => $bot) )   if ( $config->{'cah'}{'use_cah'} );

# Start the bot
$bot->start();
