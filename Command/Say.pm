package Command::Say;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_say);

use Mojo::Discord;
use Bot::Goose;
use Mojo::JSON qw(decode_json);
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Say";
my $access = 2; # Restricted to Owner
my $description = "Make the bot say something";
my $pattern = '^(say) (.+)$';
my $function = \&cmd_say;
my $usage = <<EOF;
Usage: !say something
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

sub cmd_say
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    eval 
    { 
        my $json = decode_json($args);
        $discord->send_message($channel, $json);
    };
    if ($@)
    {
        # Send as plaintext instead.
        $discord->send_message($channel, $args);
    }
}

1;
