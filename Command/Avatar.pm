package Command::Avatar;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_avatar);

use Net::Discord;
use Bot::Goose;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Avatar";
my $access = 0; # Public
my $description = "Display a user's avatar";
my $pattern = '^(avatar) ?(.*)$';
my $function = \&cmd_avatar;
my $usage = <<EOF;
- `!avatar` - Display your own avatar
- `!avatar \@user` - Display someone else's avatar
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

sub cmd_avatar
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};

    my $id = $author->{'id'};

    say Dumper($msg);
    
    if ( $args =~ /\<\@\!?(\d+)\>/ )
    {
        $id = $1;
    }

    say "Fetching avatar for ID: $id";

    $discord->get_user($id, sub
    {
        my $json = shift;
        my $avatar = $json->{'avatar'};
        my $name = $json->{'username'};

        my $url = 'https://cdn.discordapp.com/avatars/' . $id . '/' . $avatar . '.jpg';

        # Send a message back to the channel
        $discord->send_message($channel, "Avatar for **$name**: $url");
    });
}

1;
