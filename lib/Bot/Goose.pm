package Bot::Goose;
use feature 'say';

use Moo;
use strictures 2;

use Data::Dumper;
use Mojo::Discord;
use Mojo::IOLoop;
use Mojo::WebService::LastFM;
use Time::Duration;
use Component::Database;
use Component::YouTube;
#use Component::DarkSky;
use Component::OpenWeather;
use Component::EnvironmentCanada;
use Component::Maps;
use Component::CAH;
use Component::UrbanDictionary;
use Component::Twitch;
use Component::Stats;
use Component::Duolingo;
use Component::Hoggit;
use Component::Peeled;
use Component::DogAPI;
use Component::CatAPI;
use Component::FoxAPI;
use Component::BunniesAPI;
use Component::DuckAPI;
use Component::LizardAPI;
use Component::AVWX;
use Component::SomeRandomAPI;
use Component::FeatureFlag;

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
has session             => ( is => 'rw', default => sub { {} } );
has status_timer        => ( is => 'rw' );

has db                  => ( is => 'lazy', builder => sub { Component::Database->new(%{shift->config->{'db'}}) } );
has ff                  => ( is => 'lazy', builder => sub { Component::FeatureFlag->new('db' => shift->db) } );
has youtube             => ( is => 'lazy', builder => sub { Component::YouTube->new(%{shift->config->{'youtube'}}) } );
has openweather         => ( is => 'lazy', builder => sub { Component::OpenWeather->new(%{shift->config->{'weather'}}) } );
has environmentcanada   => ( is => 'lazy', builder => sub { Component::EnvironmentCanada->new() } );
has avwx                => ( is => 'lazy', builder => sub { Component::AVWX->new('token' => shift->config->{'avwx'}{'api_key'}) } );
has maps                => ( is => 'lazy', builder => sub { Component::Maps->new('api_key' => shift->config->{'maps'}{'api_key'}) } );
has lastfm              => ( is => 'lazy', builder => sub { Mojo::WebService::LastFM->new('api_key' => shift->config->{'lastfm'}{'api_key'}) } );
has cah                 => ( is => 'lazy', builder => sub { Component::CAH->new('api_url' => shift->config->{'cah'}{'api_url'}) } );
has urbandictionary     => ( is => 'lazy', builder => sub { Component::UrbanDictionary->new() } );
has twitch              => ( is => 'lazy', builder => sub { Component::Twitch->new('api_key' => shift->config->{'twitch'}{'api_key'}) } );
has stats               => ( is => 'lazy', builder => sub { Component::Stats->new('db' => shift->db) } ); 
has duolingo            => ( is => 'lazy', builder => sub { 
    my $self = shift; 
    Component::Duolingo->new(
        'username'  => $self->config->{'duolingo'}{'username'},
        'password'  => $self->config->{'duolingo'}{'password'},
    ); 
});
has hoggit              => ( is => 'lazy', builder => sub { Component::Hoggit->new() } );
has peeled              => ( is => 'lazy', builder => sub { 
        my $self = shift;
        my $api_url = $self->config->{'peeled'}{'api_url'};
        Component::Peeled->new('api_url' => $api_url);
});

# Animal Pictures
has dog                 => ( is => 'lazy', builder => sub { Component::DogAPI->new() } );
has cat                 => ( is => 'lazy', builder => sub { Component::CatAPI->new() } );
has fox                 => ( is => 'lazy', builder => sub { Component::FoxAPI->new() } );
has bunnies             => ( is => 'lazy', builder => sub { Component::BunniesAPI->new() } );
has duck                => ( is => 'lazy', builder => sub { Component::DuckAPI->new() } );
has lizard              => ( is => 'lazy', builder => sub { Component::LizardAPI->new() } );
has some_random         => ( is => 'lazy', builder => sub { Component::SomeRandomAPI->new() } );

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
    #$self->discord_on_message_reaction_add();
    #$self->discord_on_message_reaction_remove();

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
        $self->_reset_session();

        say localtime(time) . " Connected to Discord.";

        $self->status_timer( Mojo::IOLoop->recurring(120 => sub { $self->_set_status() }) ) unless defined $self->status_timer;
    });
}

# Any stats which should be cleared when the bot reconnects (Eg, the number of guilds joined, the "last-connected" timestamp, etc) should be done here.
sub _reset_session
{
    my $self = shift;

    $self->session->{'num_guilds'} = 0;
    $self->session->{'last_connected'} = time;    
}

sub uptime
{
    my $self = shift;

    return duration(time - $self->session->{'last_connected'});
}

sub _set_status
{
    my $self = shift;
   
    my $status = {
       'name' => $self->session->{'num_guilds'} . ' servers',
       'type' => 3 # "Watching"
    };
    my $discord = $self->discord->status_update($status);
}

sub discord_on_guild_create
{
    my ($self) = @_;


    $self->discord->gw->on('GUILD_CREATE' => sub {
        $self->session->{'num_guilds'}++;
    });
}

sub discord_on_guild_delete
{
    my $self = shift;

    $self->discord->gw->on('GUILD_DELETE' => sub {
        $self->session->{'num_guilds'}--;
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
        my $guild_id = $hash->{'guild_id'};
        my $guild = $self->discord->get_guild($guild_id);
        my $guild_owner_id = $guild->{'owner_id'};
        my @mentions = @{$hash->{'mentions'}};
        my $trigger = $self->trigger;
        my $discord_name = $self->discord->name;
        my $discord_id = $self->user_id;
        my $message_id = $hash->{'id'};

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

                        $access = 0 unless defined $access;
                        if ( $access == 0 # Public commands
                                or ( $access == 1 and defined $owner and $owner == $author->{'id'} )  # Owner of the bot
                                or ( $access == 2 and defined $guild_owner_id and $guild_owner_id == $author->{'id'} ) ) # Owner of the server
                        {
                            my $object = $command->{'object'};
                            my $function = $command->{'function'};

                            # Track command usage in the DB
                            # Need to re-think this. I want to have insight into bot usage for troubleshooting but this doesn't really accomplish it.
                            #$self->stats->add_command(
                            #    'command'       => lc $command->{'name'},
                            #    'channel_id'    => $channel_id,
                            #    'user_id'       => $author->{'id'},
                            #    'timestamp'     => time
                            #);

                            $hash->{'content'} = $msg;  # We've made some changes to the message content, let's make sure those get passed on to the command.
                            $object->$function($hash);
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
    $self->log->info('[Goose.pm] [_add_me] My Discord ID: ' . $user->{'id'});
    $self->_set_user_id($user->{'id'});
}

# Return a list of all commands
sub get_commands
{
    my $self = shift;

    my $cmds = {};
    
    foreach my $key (keys %{$self->commands})
    {
        $cmds->{$key} = $self->commands->{$key}{'description'};
    }

    return $cmds;
}

sub get_command_by_name
{
    my ($self, $name) = @_;

    return $self->commands->{$name};
}

sub get_command_by_pattern
{
    my ($self, $pattern) = @_;

    return $self->get_command_by_name($self->{'patterns'}{$pattern});
}

sub add_command
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

    $self->log->debug('[Goose.pm] [add_moo_command] Registered new command: "' . $name . '" identified by "' . $command->pattern . '"');
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
