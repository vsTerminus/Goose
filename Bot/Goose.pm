package Bot::Goose;

use v5.10;
use strict;
use warnings;

use Data::Dumper;

use Exporter qw(import);
our @EXPORT_OK = qw(add_command command get_patterns);

# This module mostly exists as a storage container for commands and any
# discord-related info that we might want to store, such as the guilds and channels we are connected to.
sub new
{
    my ($class, %params) = @_;
    my $self = {};

    $self->{'commands'} = {};
    $self->{'patterns'} = {};
    $self->{'waiting'} = {};
    
    bless $self, $class;
    return $self;
}

sub add_me
{
    my ($self, $user) = @_;
    say "Adding my ID as " . $user->{'id'};
    $self->{'id'} = $user->{'id'};
    add_user($self, $user);
}

sub my_id
{
    my $self = shift;

    return $self->{'id'};
}

sub my_name
{
    my $self = shift;
    my $id = $self->{'id'};
    return $self->{'users'}{$id}->{'username'}
}

sub my_user
{
    my $self = shift;
    my $id = $self->{'id'};
    return $self->{'users'}{$id};
}

sub add_user
{
    my ($self, $user) = @_;
    my $id = $user->{'id'};
    $self->{'users'}{$id} = $user;
}

sub remove_user
{
    my ($self, $id) = @_;

    delete $self->{'users'}{$id};
}


# Tell the bot it has connected to a new guild.
sub add_guild
{
    my ($self, $guild) = @_;

    # Nice and simple. Just add what we're given.
    $self->{'guilds'}{$guild->{'id'}} = $guild;
}

# Like adding, this removes the entry and then returns the list of connected guilds.
sub remove_guild
{
    my ($self, $id) = @_;

    delete $self->{'guilds'}{$id} if exists $self->{'guilds'}{$id};
}

# Return the list of guilds.
sub get_guilds
{
    my $self = shift;

    return keys %{$self->{'guilds'}};
}

sub get_patterns
{
    my $self = shift;
    return keys %{$self->{'patterns'}};
}

sub get_command
{
    my ($self, $pattern) = @_;

    my $command = $self->{'patterns'}{$pattern};
    #say Dumper($self->{'commands'}{$command});
    return $self->{'commands'}{$command};
}

# Command modules can use this function to register themselves with the bot.
# - Command
# - Usage
# - Pattern
# - Function
sub add_command
{
    my ($self, %params) = @_;

    my $command = lc $params{'command'};
    my $usage = $params{'usage'};
    my $pattern = $params{'pattern'};
    my $function = $params{'function'};
    my $object = $params{'object'};

    $self->{'commands'}->{$command}{'usage'} = $usage;
    $self->{'commands'}->{$command}{'pattern'} = $pattern;
    $self->{'commands'}->{$command}{'function'} = $function;
    $self->{'commands'}->{$command}{'object'} = $object;

    $self->{'patterns'}->{$pattern} = $command;

    say localtime(time) . " Registered new command: '$command' identified by '$pattern'";
}

# This function tells the bot that a particular command
# is expecting a reply from a particular user in a particular channel.
# The next message (regardless of content) from that user in that channel should
# be sent to that command.
sub expecting_reply
{
}

# This sub calls any of the registered commands and passes along the args
# Returns 1 on success or 0 on failure (if command does not exist)
sub command
{
    my ($self, $command, $args) = @_;

    $command = lc $command;

    if ( exists $self->{'commands'}{$command} )
    {
        $self->{'commands'}{$command}{'function'}->($args);
        return 1;
    }
    return 0;
}

1;
