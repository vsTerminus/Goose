package Bot::Goose;
use feature 'say';

use Moo;
use strictures 2;

use Data::Dumper;
use Mojo::Discord;
use Component::Database;
use Component::YouTube;
use Component::DarkSky;
use Component::EnvironmentCanada;
use Component::Maps;
use Component::CAH;
use Component::UrbanDictionary;
use Component::Twitch;
use Mojo::IOLoop;

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
has stats               => ( is => 'rw', default => sub{ {'num_guilds' => 0} });

has db                  => ( is => 'rwp' );
has youtube             => ( is => 'rwp' );
has darksky             => ( is => 'rwp' );
has environmentcanada   => ( is => 'rwp' );
has maps                => ( is => 'rwp' );
has lastfm              => ( is => 'rwp' );
has cah                 => ( is => 'rwp' );
has urbandictionary     => ( is => 'rwp' );
has twitch              => ( is => 'rwp' );

has owner_id            => ( is => 'rwp' );
has user_id             => ( is => 'rwp' );
has trigger             => ( is => 'rwp' );
has playing             => ( is => 'rwp' );
has client_id           => ( is => 'rwp' );
has webhook_name        => ( is => 'rwp' );
has webhook_avatar      => ( is => 'rwp' );

has discord             => ( is => 'rwp' );

# There is almost definitely a better way to do this. Maybe goose.pl should be doing more up front?
sub BUILD {

    my $self = shift;

    $self->_set_discord(
        Mojo::Discord->new(
            'token'     => $self->config->{'discord'}{'token'},
            'name'      => $self->config->{'discord'}{'name'},
            'url'       => $self->config->{'discord'}{'redirect_url'},
            'version'   => '1.0',
            'callbacks' => {    # Discord Gateway Dispatch Event Types
                'READY'             => sub { $self->discord_on_ready(@_) },
                'GUILD_CREATE'      => sub { $self->discord_on_guild_create(@_) },
                'GUILD_UPDATE'      => sub { $self->discord_on_guild_update(@_) },
                'GUILD_DELETE'      => sub { $self->discord_on_guild_delete(@_) },
                'CHANNEL_CREATE'    => sub { $self->discord_on_channel_create(@_) },
                'CHANNEL_UPDATE'    => sub { $self->discord_on_channel_update(@_) },
                'CHANNEL_DELETE'    => sub { $self->discord_on_channel_delete(@_) },
                'TYPING_START'      => sub { $self->discord_on_typing_start(@_) }, 
                'MESSAGE_CREATE'    => sub { $self->discord_on_message_create(@_) },
                'MESSAGE_UPDATE'    => sub { $self->discord_on_message_update(@_) },
                'PRESENCE_UPDATE'   => sub { $self->discord_on_presence_update(@_) },
                'WEBHOOKS_UPDATE'   => sub { $self->discord_on_webhooks_update(@_) },
            },
            'reconnect' => $self->config->{'discord'}{'auto_reconnect'},
            'verbose'   => $self->config->{'discord'}{'verbose'},
        )
    );

    $self->_set_db               (Component::Database->new(%{$self->config->{'db'}}));
    $self->_set_youtube          (Component::YouTube->new(%{$self->config->{'youtube'}}));
    $self->_set_darksky          (Component::DarkSky->new(%{$self->config->{'weather'}}));
    $self->_set_environmentcanada(Component::EnvironmentCanada->new());
    $self->_set_maps             (Component::Maps->new(%{$self->config->{'maps'}}));
    $self->_set_lastfm           (Mojo::WebService::LastFM->new('api_key' => $self->config->{'lastfm'}{'api_key'}));
    $self->_set_cah              (Component::CAH->new('api_url' => $self->config->{'cah'}{'api_url'}));
    $self->_set_urbandictionary  (Component::UrbanDictionary->new());
    $self->_set_twitch           (Component::Twitch->new('api_key' => $self->config->{'twitch'}{'api_key'}));;

    $self->_set_owner_id         ($self->config->{'discord'}{'owner_id'});
    $self->_set_trigger          ($self->config->{'discord'}{'trigger'});
    $self->_set_playing          ($self->config->{'discord'}{'playing'});
    $self->_set_client_id        ($self->config->{'discord'}{'client_id'});
    $self->_set_webhook_name     ($self->config->{'discord'}{'webhook_name'});
    $self->_set_webhook_avatar   ($self->config->{'discord'}{'webhook_avatar'});

}

# Connect to discord and start running.
sub start
{
    my $self = shift;

    $self->{'discord'}->init();
    
    # Start the IOLoop unless it is already running. 
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running; 
}


sub discord_on_ready
{
    my ($self, $hash) = @_;

    $self->add_me($hash->{'user'});

    say localtime(time) . " Connected to Discord.";

    Mojo::IOLoop->recurring(60 => sub { $self->_set_status() });
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
    my ($self, $hash) = @_;

    $self->stats->{'num_guilds'}++;
}

sub discord_on_guild_delete
{
    my ($self, $hash) = @_;

    $self->stats->{'num_guilds'}--;
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
    my ($self, $hash) = @_;

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
            foreach my $pattern (keys $self->patterns)
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
}

sub discord_on_message_update
{
    my ($self, $hash) = @_;

    # Might be worth checking how old the message is, and if it's recent enough re-process it for commands?
    # Would let people fix typos without having to send a new message to trigger the bot.
    # Have to track replied message IDs in that case so we don't reply twice.
}

sub discord_on_presence_update
{
    my ($self, $hash) = @_;

    # Will be useful for a !playing command to show the user's currently playing "game".
}

sub add_me
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
