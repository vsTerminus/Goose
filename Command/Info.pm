package Command::Info;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_info);

use Net::Discord;
use Bot::Goose;

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

    my $info =  "```\nInfo```\n" .
                'I am a Goose Bot by <@143909249074855936>' . "\n" .
                "I perform some semi-useful chat related functions, mostly involving interactions with APIs from other services.\n\n" .
                "```\nCode```\n" .
                "I am written in Perl, and am built on the Net::Discord library \n(https://github.com/vsTerminus/Net-Discord)\n\n" .
                "My source code is available on GitHub \n(https://github.com/vsTerminus/Goose)\n\n" .
                "```\nAdd Me```\n" .
                "You can add me to your own server(s) by clicking the link below, or share it with the server admin if you don't have enough permissions.\n\nhttps://discordapp.com/oauth2/authorize?client_id=231059560977137664&scope=bot&permissions=19456";

    $discord->send_message($channel, $info);
}

1;
