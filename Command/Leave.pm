package Command::Leave;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_guilds);

use Net::Discord;
use Bot::Goose;

###########################################################################################
# Command Info
my $command = "Leave";
my $description = "Leave a specified guild";
my $pattern = '^(leave) ?(.*)$';
my $function = \&cmd_leave;
my $access = 1;   # Restricted - Bot Owner only. Should overhaul access a bit in the future, but for now this is fine.
my $usage = <<EOF;
Basic usage: !leave <Guild ID>
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
    $self->{'access'} = $access;

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

sub cmd_leave
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    my $bot = $self->{'bot'};

    my $id = $msg;
    $id =~ s/^leave (\d+)$/$1/i;

    say "Checking for Guild ID: $id";
    
    my $user = '@me';
    say $discord->get_guilds($user);

    if ( my $guild = $bot->get_guild($id) )
    {
        my $guild_name = $guild->{'name'};

        $discord->send_message($channel, "Leaving Server: `$id ($guild_name)`");
        $discord->leave_guild($user, $id);
    }
    else
    {
        $discord->send_message($channel, "Sorry " . $author->{'username'} . ", I don't appear to be connected to that server.");
    }
}

1;
