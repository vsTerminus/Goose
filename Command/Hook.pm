package Command::Hook;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_help);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Hook' );
has access              => ( is => 'ro', default => 2 ); # 0 = Public, 1 = Bot-Owner Only, 2 = Bot-Owner or Server-Owner Only
has description         => ( is => 'ro', default => 'Create a webhook in the current channel for the bot to use.' );
has pattern             => ( is => 'ro', default => '^hook ?' );
has function            => ( is => 'ro', default => sub { \&cmd_webhook } );
has usage               => ( is => 'ro', default => <<EOF
Create a webhook in this channel

Usage: !hook create
EOF
);

sub cmd_webhook
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
        foreach my $hook ( @{$json} )
        {
            if ( $hook->{'name'} eq $bot->webhook_name )
            {
                # Found it.
                $discord->send_message($channel, "Webhook '" . $hook->{'name'} . "' already exists. No need to create a new one.");
                return;
            }
        }

        $bot->create_webhook($channel, sub
        {
            my $json = shift;

            if ( defined $json->{'name'} )
            {
                $discord->send_message($channel, "Successfully created a new webhook named '" . $json->{'name'} . "' for this channel.");
            }
            else
            {
                $discord->send_message($channel, "I was unable to create a new webhook. Please ensure that I have the 'Manage Webhooks' permission and then try again.");
            }
        });
    
    });
}

1;
