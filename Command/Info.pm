package Command::Info;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_info);

use Net::Discord;
use Bot::Goose;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Info";
my $access = 0; # Public
my $description = "Display information about the bot, including framework, creator, and source code";
my $pattern = '^info ?.*$';
my $function = \&cmd_info;
my $usage = <<EOF;
Usage: `!info`
EOF
###########################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
     
    # Setting up this command module requires the Discord connection 
    $self->{'bot'} = $params{'bot'};
    $self->{'discord'} = $self->{'bot'}->discord;
    $self->{'pattern'} = $pattern;

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

sub cmd_info
{
    my ($self, $channel, $author) = @_;

    my $discord = $self->{'discord'};
    my $bot = $self->{'bot'};

    my $info;
    
    # We can use some special formatting with the webhook.
    if ( my $hook = $bot->has_webhook($channel) )
    {
        $info = "**Info**\n" .
                "I am a Goose Bot by <\@143909249074855936>\n" .
                "I am a semi-useful chat-bot that provides services such as `!weather`, `!nowplaying`, and `!youtube`\n" .
                "Try the `!help` command for a complete listing. \n\n" .
                "**Source Code**\n" .
                "I am open source! I am written in Perl and built on the [Net::Discord](<https://github.com/vsTerminus/Net-Discord>) library.\n" .
                "My source code is available [on GitHub](<https://github.com/vsTerminus/Goose>).\n\n" .
                "**Add Me**\n" .
                "[Click here](<https://discordapp.com/oauth2/authorize?client_id=231059560977137664&scope=bot&permissions=536890368>) to add me to your own server, or share this link with your server admin if you don't have sufficient access.\n\n" .
                "**Join My Server**\n" .
                "I have a public Discord server you can join where you can monitor my github feed and mess with the bot without irritating all your friends. [Check it out!](<https://discord.gg/FuKTcHF>)";

        $discord->send_webhook($channel, $hook, $info);
                
    }
    else
    {
        $info = "**Info**\n" .
                'I am a Goose Bot by <@143909249074855936>' . "\n" .
                "I am a semi-useful chat-bot that provides services such as `!weather`, `!nowplaying`, and `!youtube`\n".
                "Try the `!help` command for a complete listing.\n\n" .
                "**Source Code**\n" .
                "I am open source! I am written in Perl, and am built on the Net::Discord library `[1]`\n" .
                "My source code is available on GitHub `[2]`\n\n" .
                "**Add Me**\n" .
                "You can add me to your own server(s) by clicking the link below `[3]` or by sharing it with your server admin.\n\n".
                "**Join My Server**\n" .
                "I have a public Discord server you can join where you can monitor my github feed and mess with the bot without irritating all your friends. Check it out below! `[4]`\n\n" .
                "**Links**\n".
                "`[1]` <https://github.com/vsTerminus/Net-Discord>\n".
                "`[2]` <https://github.com/vsTerminus/Goose>\n".
                "`[3]` <https://discordapp.com/oauth2/authorize?client_id=231059560977137664&scope=bot&permissions=536890368>\n" .
                "`[4]` <https://discord.gg/FuKTcHF>\n";


        $discord->send_message($channel, $info);
    }
}

1;
