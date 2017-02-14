package Command::Hook;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_webhook);

use Mojo::Discord;
use Bot::Goose;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Hook";
my $access = 2; # Owner Only - Should be Server-Owner Only once supported.
my $description = "Create a webhook in the current channel for the bot to use.";
my $pattern = '^(hook) ?(.*)$';
my $function = \&cmd_webhook;
my $usage = <<EOF;
Create a webhook in this channel: `!hook create`
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

sub cmd_webhook
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $bot = $self->{'bot'};
    my $replyto = '<@' . $author->{'id'} . '>';

    # First get the webhooks for this channel - make sure we don't already have one.
    $discord->get_channel_webhooks($channel, sub
    {
        my $json = shift;

        if ( ref $json eq ref {} and $json->{'code'} == 50013 )
        {
            $discord->send_message($channel, "I was unable to create a new webhook. Please ensure that I have the 'Manage Webhooks' permission and then try again.");
            return undef;
        }

        # Iterate through the webhooks looking for one matching the one in the config file.

        my $params = {  'name' => $bot->webhook_name,
                        'avatar' => $bot->webhook_avatar,
                     };

        foreach my $hook ( @{$json} )
        {
            if ( $hook->{'name'} eq $bot->webhook_name )
            {
                # Found it.
                $discord->send_message($channel, "Webhook '" . $hook->{'name'} . "' already exists. No need to create a new one.");
                return;
            }
        }


        $discord->create_webhook($channel, $params, sub
        {
            my $json = shift;

            if ( defined $json->{'name'} )
            {
                $discord->send_message($channel, "Successfully created a new webhook named '" . $json->{'name'} . "' for this channel.");

                # Store this for future use
                $bot->add_webhook($channel, $json);
            }
            elsif ( $json->{'code'} == 50013 )
            {
                $discord->send_message($channel, "I was unable to create a new webhook. Please ensure that I have the 'Manage Webhooks' permission and then try again.");
            }
            else
            {
                $discord->send_message($channel, "I was unable to create a new webhook, and I'm not sure why. Please try again later.");
                say Dumper($json);
            }
        });
    
    });
}

1;
