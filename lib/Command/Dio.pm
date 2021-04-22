package Command::Dio;
use feature 'say';

use Moo;
use strictures 2;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_dio);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Dio' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'It was me, Dio!' );
has pattern             => ( is => 'ro', default => '^dio ?' );
has function            => ( is => 'ro', default => sub { \&cmd_dio } );
has usage               => ( is => 'ro', default => <<EOF
It was me, Dio!

Usage: `!dio`
EOF
);

has dio                 => ( is => 'ro', default => 'https://tenor.com/view/dio-jojo-gif-7432836' );
has avatar              => ( is => 'ro', default => 'https://i.imgur.com/Y4giT4k.jpg' );

sub cmd_dio
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $message = $self->dio;

    # Send a message back to the channel
    if ( my $hook = $self->bot->has_webhook($channel) )
    {
        $message = {
            'content' => $self->dio,
            'embeds' => [ ],
            'username' => 'Dio',
            'avatar_url' => $self->avatar,
        };

        $self->discord->send_webhook($channel, $hook, $message);
    }
    else
    {
        $self->discord->send_message($channel, $message);
    }
}

1;
