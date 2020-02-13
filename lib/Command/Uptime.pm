package Command::Uptime;
use feature 'say';

use Moo;
use strictures 2;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_template);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Uptime' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Display time elapsed since last reconnect' );
has pattern             => ( is => 'ro', default => '^up(time)? ?' );
has function            => ( is => 'ro', default => sub { \&cmd_uptime } );
has usage               => ( is => 'ro', default => <<EOF
Display the time elapsed since the bot last reconnected to Discord

Usage: !uptime
EOF
);

sub cmd_uptime
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    # Send a message back to the channel
    $self->discord->send_message($channel, ":chart_with_upwards_trend: " . $self->bot->uptime);
}

1;
