package Commands::Help;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_help);

use Net::Discord;
use Bot::Goose;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Help";
my $description = "This command lists all commands currently available to the bot, and can display detailed information for each.";
my $pattern = '^(help) ?(.*)$';
my $function = \&cmd_help;
my $usage = <<EOF;
Basic usage: !help
Command-specific usage: !help <command>
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
        'description'   => $description,
        'usage'         => $usage,
        'pattern'       => $pattern,
        'function'      => $function,
        'object'        => $self,
    );
    
    return $self;
}

sub cmd_help
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $bot = $self->{'bot'};
    my $replyto = '<@' . $author->{'id'} . '>';

    my $commands = $bot->get_commands;
    my $trigger = $bot->trigger;

    if ( defined $args and length $args > 0 )
    {
        my $command = $bot->get_command_by_name($args);

        if ( defined $command )
        {
            my $help_str = "__**" . ucfirst $args . "**__: \n\n`" . $command->{'description'} . "`\n\n";
            $help_str .= "__**Usage:**__\n\n" . $command->{'usage'};

            $discord->send_message($channel, $help_str);
        }
        else
        {
            $discord->send_message($channel, "Sorry, no command exists by that name.");
        }
    }
    else    # Display all
    {
        my $help_str = "This bot has the following commands available: \n\n```";
        foreach my $key (keys %{$commands})
        {
            $help_str .= "- $key\n";
        }
        $help_str .= "```\nUse `" . $trigger . "help <command>` to see more about a specific command.";
    
        # Send a message back to the channel
        $discord->send_message($channel, $help_str);
    }
}

1;
