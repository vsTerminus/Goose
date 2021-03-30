package Command::Uptime;
use feature 'say';

use Moo;
use strictures 2;
use Time::Duration;
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

has 'last_ready'        => ( is => 'rw' );
has 'last_resumed'      => ( is => 'rw' );
has 'num_resumed'       => ( is => 'rw', default => 0 );
has 'num_ready'         => ( is => 'rw', default => 0 );
has 'created'           => ( is => 'ro', default => time );

has on_ready => ( is => 'ro', default => sub 
{ 
    my $self = shift;
    $self->discord->gw->on('READY' => sub { 
            $self->last_ready(time);
            $self->num_ready($self->num_ready+1);
        });
});

has on_resumed => ( is => 'ro', default => sub
{
    my $self = shift;
    $self->discord->gw->on('RESUMED' => sub { 
            $self->last_resumed(time);
            $self->num_resumed($self->num_resumed+1);
        });
});


sub cmd_uptime
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $bot_uptime = duration( time - $self->created );
    my $session_uptime = duration( time - $self->last_ready );
    my $connection_uptime = ( $self->last_resumed and $self->last_resumed > $self->last_ready ) ? duration( time - $self->last_resumed ) : duration( time - $self->last_ready );
    my $num_sessions = ( $self->num_ready != 1 ) ? $self->num_ready . " New Sessions" : $self->num_ready . " Session";
    my $num_resumes = ( $self->num_resumed != 1 ) ? $self->num_resumed . " Resumes" : $self->num_resumed . " Resume";

    # To-Do: Verbose version which also shows READY and RESUMED packet counts, current Sequence Number, and other info?


    # Send a message back to the channel
    my $uptime = ":chart_with_upwards_trend: `Bot           $bot_uptime`\n" .
               ":chart_with_downwards_trend: `Session       $session_uptime`\n" .
                 ":chart_with_upwards_trend: `Connection    $connection_uptime`\n" .
               ":chart_with_downwards_trend: `$num_sessions, $num_resumes`";

    $self->discord->send_message($channel, $uptime);
}

1;
