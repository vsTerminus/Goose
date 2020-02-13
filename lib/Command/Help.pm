package Command::Help;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_help);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Help' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'List all commands currently available to the bot, or detailed information about a specific command' );
has pattern             => ( is => 'ro', default => '^help ?' );
has function            => ( is => 'ro', default => sub { \&cmd_help } );
has usage               => ( is => 'ro', default => <<EOF
Basic Usage: `!help`

Advanced Usage: `!help <Command>`
Eg: `!help uptime`
EOF
);

sub cmd_help
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $discord = $self->discord;
    my $bot = $self->bot;
    my $replyto = '<@' . $author->{'id'} . '>';

    my $commands = $bot->get_commands;
    my $trigger = $bot->trigger;

    if ( defined $args and length $args > 0 )
    {
        my $command = undef;
        foreach my $pattern (%{$bot->patterns})
        {
            if ( $args =~ /$pattern/i ) 
            {
                $command = $bot->get_command_by_pattern($pattern);
                last;
            }
        }

        if ( defined $command )
        {
            my $help_str = "__**" . $command->{'name'} . "**__: \n\n`" . $command->{'description'} . "`\n\n";
            $help_str .= "__**Usage:**__\n\n" . $command->{'usage'};

            # Reply via DM, ack the message with a checkmark reaction
            $discord->send_ack_dm($channel, $msg->{'id'}, $author->{'id'}, $help_str);
        }
        else
        {
            $discord->send_message($channel, "Sorry, no command exists by that name.");
        }
    }
    else    # Display all
    {
        my $help_str = "This bot has the following commands available: \n\n";

        my @public;
        my @restricted;
        foreach my $key (sort keys %{$commands})
        {
            my $command = $bot->get_command_by_name($key);
            my $access = $command->{'access'};
            ( defined $access and $access > 0 ) ? push @restricted, $key : push @public, $key;
        }

        $help_str .= "**Public**:```\n";
        foreach my $key (@public)
        {
            $help_str .= "- $key\n";
        }

        $help_str .= "```\n\n**Restricted to Owner:**```\n";
        foreach my $key (@restricted)
        {
            $help_str .= "- $key\n";
        }
        $help_str .= "```\nUse `" . $trigger . "help <command>` to see more about a specific command.";

        my $client_id = $bot->client_id();
    
        # Send a message back to the user via DM
        $discord->send_ack_dm($channel, $msg->{'id'}, $author->{'id'}, $help_str);
    }
}

1;
