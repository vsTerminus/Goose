package Command::Say;
use feature 'say';

use Moo;
use strictures 2;
use Mojo::JSON qw(decode_json);
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_say);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Say' );
has access              => ( is => 'ro', default => 1 ); # 0 = Public, 1 = Bot-Owner Only, 2 = Server Owner (when supported)
has description         => ( is => 'ro', default => 'Make the bot say something' );
has pattern             => ( is => 'ro', default => '^say ?' );
has function            => ( is => 'ro', default => sub { \&cmd_say } );
has usage               => ( is => 'ro', default => <<EOF
Usage: !say something
EOF
);

sub cmd_say
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $discord = $self->discord;
    my $replyto = '<@' . $author->{'id'} . '>';

    eval 
    { 
        my $json = decode_json($args);
        $discord->send_message($channel, $json);
    };
    if ($@)
    {
        # Send as plaintext instead.
        $discord->send_message($channel, $args);
    }
}

1;
