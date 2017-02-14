package Command::Play;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_play);

use Mojo::Discord;
use Bot::Goose;

###########################################################################################
# Command Info
my $command = "Play";
my $access = 1; # Restricted
my $description = "Set the bot's 'Playing' status";
my $pattern = '^(play) ?(.*)$';
my $function = \&cmd_play;
my $usage = <<EOF;
Set a status: `!play with myself`
Clear the current status: `!play`
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

sub cmd_play
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';


    $self->{'bot'}->{'playing'} = $args;
    $self->{'discord'}->status_update({'game' => $args});
    
    # Send a message back to the channel
    $discord->send_message($channel, "Bot is now playing: `$args`");
}

1;
