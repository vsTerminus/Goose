package Bot::Goose;
use feature 'say';

use Moo;
use strictures 2;

use Data::Dumper;
use Mojo::Discord;
use Mojo::IOLoop;
use Time::Duration;
use Component::Database;
use Component::YouTube;
use Component::DarkSky;
use Component::EnvironmentCanada;
use Component::Maps;
use Component::CAH;
use Component::UrbanDictionary;
use Component::Twitch;

use namespace::clean;

has permissions => ( is => 'ro', default => sub {
        {
            'CREATE_INSTANT_INVITE' => 0x00000001,
            'KICK_MEMBERS'          => 0x00000002,
            'BAN_MEMBERS'           => 0x00000004,
            'ADMINISTRATOR'         => 0x00000008,
            'MANAGE_CHANNELS'       => 0x00000010,
            'MANAGE_GUILD'          => 0x00000020,
            'ADD_REACTIONS'         => 0x00000040,
            'READ_MESSAGES'         => 0x00000400,
            'SEND_MESSAGES'         => 0x00000800,
            'SEND_TTS_MESSAGES'     => 0x00001000,
            'MANAGE_MESSAGES'       => 0x00002000,
            'EMBED_LINKS'           => 0x00004000,
            'ATTACH_FILES'          => 0x00008000,
            'READ_MESSAGE_HISTORY'  => 0x00010000,
            'MENTION_EVERYONE'      => 0x00020000,
            'USE_EXTERNAL_EMOJIS'   => 0x00040000,
            'CONNECT'               => 0x00100000,
            'SPEAK'                 => 0x00200000,
            'MUTE_MEMBERS'          => 0x00400000,
            'DEAFEN_MEMBERS'        => 0x00800000,
            'MOVE_MEMBERS'          => 0x01000000,
            'USE_VAD'               => 0x02000000,
            'CHANGE_NICKNAME'       => 0x04000000,
            'MANAGE_NICKNAMES'      => 0x08000000,
            'MANAGE_ROLES'          => 0x10000000,
            'MANAGE_WEBHOOKS'       => 0x20000000,
            'MANAGE_EMOJIS'         => 0x40000000,
        }
    }
);

has config              => ( is => 'ro' );
has commands            => ( is => 'rw' );
has patterns            => ( is => 'rw' );
has stats               => ( is => 'rw', default => sub { {} } );

has db                  => ( is => 'lazy', builder => sub { Component::Database->new(%{shift->config->{'db'}}) } );
has youtube             => ( is => 'lazy', builder => sub { Component::YouTube->new(%{shift->config->{'youtube'}}) } );
has darksky             => ( is => 'lazy', builder => sub { Component::DarkSky->new(%{shift->config->{'weather'}}) } );
has environmentcanada   => ( is => 'lazy', builder => sub { Component::EnvironmentCanada->new() } );
has maps                => ( is => 'lazy', builder => sub { Component::Maps->new('api_key' => shift->config->{'maps'}{'api_key'}) } );
has lastfm              => ( is => 'lazy', builder => sub { Mojo::WebService::LastFM->new('api_key' => shift->config->{'lastfm'}{'api_key'}) } );
has cah                 => ( is => 'lazy', builder => sub { Component::CAH->new('api_url' => shift->config->{'cah'}{'api_url'}) } );
has urbandictionary     => ( is => 'lazy', builder => sub { Component::UrbanDictionary->new() } );
has twitch              => ( is => 'lazy', builder => sub { Component::Twitch->new('api_key' => shift->config->{'twitch'}{'api_key'}) } );

has user_id             => ( is => 'rwp' );
has owner_id            => ( is => 'lazy', builder => sub { shift->config->{'discord'}{'owner_id'} } );
has trigger             => ( is => 'lazy', builder => sub { shift->config->{'discord'}{'trigger'} } );
has client_id           => ( is => 'lazy', builder => sub { shift->config->{'discord'}{'client_id'} } );
has webhook_name        => ( is => 'lazy', builder => sub { shift->config->{'discord'}{'webhook_name'} } );
has webhook_avatar      => ( is => 'lazy', builder => sub { shift->config->{'discord'}{'webhook_avatar'} } );

has discord             => ( is => 'lazy', builder => sub {
                            my $self = shift;
                            Mojo::Discord->new(
                                'token'     => $self->config->{'discord'}{'token'},
                                'name'      => $self->config->{'discord'}{'name'},
                                'url'       => $self->config->{'discord'}{'redirect_url'},
                                'version'   => '1.0',
                                'reconnect' => $self->config->{'discord'}{'auto_reconnect'},
                                'loglevel'  => $self->config->{'discord'}{'log_level'},
                                'logdir'    => $self->config->{'discord'}{'log_dir'},
                            )});

# Logging
has loglevel            => ( is => 'lazy', builder => sub { shift->config->{'discord'}{'log_level'} } );
has logdir              => ( is => 'lazy', builder => sub { shift->config->{'discord'}{'log_dir'} } );
has logfile             => ( is => 'ro', default => 'goose-bot.log' );
has log                 => ( is => 'lazy', builder => sub { 
                                my $self = shift; 
                                Mojo::Log->new( 
                                    'path' => $self->logdir . '/' . $self->logfile, 
                                    'level' => $self->loglevel
                                );
                            });

# Connect to discord and start running.
sub start
{
    my $self = shift;

    # This is a bit of a hack - I'm not exactly proud of it
    # Something to revisit in the future, I'm sure.
    # The idea is, in order for the event handler to have access to THIS module's $self,
    # it needs to be enclosed by a sub that has access to $self already.
    # If I don't want to define all of the handler subs in full inside of start(),
    # one alternative is to just call all of the encapsulating subs one by one here to set them up.
    $self->discord_on_ready();
    $self->discord_on_guild_create();
    $self->discord_on_guild_update();
    $self->discord_on_guild_delete();
    $self->discord_on_channel_create();
    $self->discord_on_channel_update();
    $self->discord_on_channel_delete();
    $self->discord_on_typing_start();
    $self->discord_on_message_create();
    $self->discord_on_message_update();
    $self->discord_on_presence_update();
    $self->discord_on_webhooks_update();

    $self->log->info('[Goose.pm] [BUILD] New session beginning ' .  localtime(time));
    $self->discord->init();
    
    # Start the IOLoop unless it is already running. 
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running; 
}


sub discord_on_ready
{
    my $self = shift;

    $self->discord->gw->on('READY' => sub 
    {
        my ($gw, $hash) = @_;

        $self->_add_me($hash->{'user'});
        $self->_reset_stats();

        say localtime(time) . " Connected to Discord.";

        Mojo::IOLoop->recurring(60 => sub { $self->_set_status() });
    });
}

# Any stats which should be cleared when the bot reconnects (Eg, the number of guilds joined, the "last-connected" timestamp, etc) should be done here.
sub _reset_stats
{
    my $self = shift;

    $self->stats->{'num_guilds'} = 0;
    $self->stats->{'last_connected'} = time;    
}

sub uptime
{
    my $self = shift;

    return duration(time - $self->stats->{'last_connected'});
}

sub _set_status
{
    my $self = shift;
   
    my $status = {
       'name' => $self->stats->{'num_guilds'} . ' servers',
       'type' => 3 # "Watching"
    };
    my $discord = $self->discord->status_update($status);
}

sub discord_on_guild_create
{
    my $self = shift;

    $self->discord->gw->on('GUILD_CREATE' => sub {
        $self->stats->{'num_guilds'}++;
    });
}

sub discord_on_guild_delete
{
    my $self = shift;

    $self->discord->gw->on('GUILD_DELETE' => sub {
        $self->stats->{'num_guilds'}--;
    });
}

# Might do something with these?
# The tracking of information is done by the Mojo::Discord library now,
# so we only need these if we're going to have the bot actually do something when they happen.
sub discord_on_guild_update{}
sub discord_on_channel_create{}
sub discord_on_channel_update{}
sub discord_on_channel_delete{}
sub discord_on_webhooks_update{}
sub discord_on_typing_start{}

sub discord_on_message_create
{
    my $self = shift;

    $self->discord->gw->on('MESSAGE_CREATE' => sub 
    {
        my ($gw, $hash) = @_;

        my $author = $hash->{'author'};
        my $msg = $hash->{'content'};
        my $channel_id = $hash->{'channel_id'};
        my @mentions = @{$hash->{'mentions'}};
        my $trigger = $self->trigger;
        my $discord_name = $self->discord->name;
        my $discord_id = $self->user_id;

        my $channels = $self->discord->channels;

        # Look for messages starting with a mention or a trigger, but not coming from a bot.
        if ( !(exists $author->{'bot'} and $author->{'bot'}) and $msg =~ /^(\<\@\!?$discord_id\>|\Q$trigger\E)/i )
        {
            $msg =~ s/^((\<\@\!?$discord_id\>.? ?)|(\Q$trigger\E))//i;   # Remove the username. Can I do this as part of the if statement?

            if ( defined $msg )
            {
                # Get all command patterns and iterate through them.
                # If you find a match, call the command fuction.
                foreach my $pattern (keys %{$self->patterns})
                {
                    if ( $msg =~ /$pattern/si )
                    {
                        my $command = $self->get_command_by_pattern($pattern);
                        my $access = $command->{'access'};
                        my $owner = $self->owner_id;

                        if ( defined $access and $access > 0 and defined $owner and $owner != $author->{'id'} )
                        {
                            # Sorry, no access to this command.
                            say localtime(time) . ": '" . $author->{'username'} . "' (" . $author->{'id'} . ") tried to use a restricted command and is not the bot owner.";
                        }
                        elsif ( ( defined $access and $access == 0 ) or ( defined $owner and $owner == $author->{'id'} ) )
                        {
                            my $object = $command->{'object'};
                            my $function = $command->{'function'};
                            $object->$function($channel_id, $author, $msg);
                        }
                    }
                }
            }
        }
    });
}

sub discord_on_message_update
{
    my $self = shift;

    # Might be worth checking how old the message is, and if it's recent enough re-process it for commands?
    # Would let people fix typos without having to send a new message to trigger the bot.
    # Have to track replied message IDs in that case so we don't reply twice.
    $self->discord->gw->on('MESSAGE_UPDATE' => sub
    {
        my ($gw, $hash) = @_;

        $self->log->debug("MESSAGE_UPDATE");
        $self->log->debug(Data::Dumper->Dump([$hash], ['hash']));
    });
}

sub discord_on_presence_update
{
    my $self = shift;
}

sub _add_me
{
    my ($self, $user) = @_;
    say "Adding my ID as " . $user->{'id'};
    $self->_set_user_id($user->{'id'});
}

# Return a list of all commands
sub get_commands
{
    my $self = shift;

    my $cmds = {};
    
    foreach my $key (keys %{$self->{'commands'}})
    {
        $cmds->{$key} = $self->{'commands'}->{$key}{'description'};
    }

    return $cmds;
}

sub get_command_by_name
{
    my ($self, $name) = @_;

    return $self->{'commands'}{$name};
}

sub get_command_by_pattern
{
    my ($self, $pattern) = @_;

    return $self->get_command_by_name($self->{'patterns'}{$pattern});
}

sub add_moo_command
{
    my ($self, $command) = @_;

    my $name = $command->name;
    $self->{'commands'}->{$name}{'name'} = ucfirst $name;
    $self->{'commands'}->{$name}{'access'} = $command->access;
    $self->{'commands'}->{$name}{'usage'} = $command->usage;
    $self->{'commands'}->{$name}{'description'} = $command->description;
    $self->{'commands'}->{$name}{'pattern'} = $command->pattern;
    $self->{'commands'}->{$name}{'function'} = $command->function;
    $self->{'commands'}->{$name}{'object'} = $command;

    $self->{'patterns'}->{$command->pattern} = $name;

    say localtime(time) . " Registered new Moo Command: '$name' identified by '$command->pattern'";
}

# Command modules can use this function to register themselves with the bot.
# - Command
# - Access Level Required (Default 0 - public, 1 - Bot Owner)
# - Description
# - Usage
# - Pattern
# - Function
sub add_command
{
    my ($self, %params) = @_;

    my $command = lc $params{'command'};
    my $access = $params{'access'};
    my $description = $params{'description'};
    my $usage = $params{'usage'};
    my $pattern = $params{'pattern'};
    my $function = $params{'function'};
    my $object = $params{'object'};

    $self->{'commands'}->{$command}{'name'} = ucfirst $command;
    $self->{'commands'}->{$command}{'access'} = $access;
    $self->{'commands'}->{$command}{'usage'} = $usage;
    $self->{'commands'}->{$command}{'description'} = $description;
    $self->{'commands'}->{$command}{'pattern'} = $pattern;
    $self->{'commands'}->{$command}{'function'} = $function;
    $self->{'commands'}->{$command}{'object'} = $object;

    $self->{'patterns'}->{$pattern} = $command;

    say localtime(time) . " Registered new command: '$command' identified by '$pattern'";
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

# Check if a webhook already exists - return it if so.
# If not, create one and add it to the webhooks hashref.
# Is non-blocking if callback is defined.
sub create_webhook
{
    my ($self, $channel, $callback) = @_;

    return $_ if ( $self->has_webhook($channel) );

    # If we don't have one cached we should check to see if we have Manage Webhooks


    # Create a new webhook
    my $discord = $self->discord;

    my $params = {
        'name' => $self->webhook_name, 
        'avatar' => $self->webhook_avatar 
    };

    if ( defined $callback )
    {
        $discord->create_webhook($channel, $params, sub
        {
            my $json = shift;

            if ( defined $json->{'name'} ) # Success
            {
                $callback->($json);
            }
            elsif ( $json->{'code'} == 50013 ) # No permission
            {
                say localtime(time) . ": Unable to create webhook in $channel - Need Manage Webhooks permission";
                $callback->(undef);
            }
            else
            {
                say localtime(time) . ": Unable to create webhook in $channel - Unknown reason";
                $callback->(undef);
            }
        });
    }
    else
    {
        my $json = $discord->create_webhook($channel); # Blocking

        return defined $json->{'name'} ? $json : undef;
    }
}

sub add_webhook
{
    my ($self, $channel, $json) = @_;

    $self->{'webhooks'}{$channel} = $json;
    return $self->{'webhooks'}{$channel};
}

# Get the list of webhooks from $discord
# and look for one matching our channel id and webhook_name.
sub has_webhook
{
    my ($self, $channel) = @_;

    my $hooks = $self->discord->get_cached_webhooks($channel);
    if ( $hooks )
    {
        foreach my $hook (@$hooks)
        {
            return $hook if ( $hook->{'name'} eq $self->webhook_name )
        }
    }
    return undef;
}

__PACKAGE__->meta->make_immutable;

1;
