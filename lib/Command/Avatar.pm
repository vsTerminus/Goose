package Command::Avatar;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_avatar);

has bot             => ( is => 'ro' );
has discord         => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log             => ( is => 'lazy', builder => sub { shift->bot->log } );

has name            => ( is => 'ro', default => 'Avatar' );
has access          => ( is => 'ro', default => 0 );
has description     => ( is => 'ro', default => "Display a user's avatar" );
has pattern         => ( is => 'ro', default => '^avatar ?' );
has function        => ( is => 'ro', default => sub { \&cmd_avatar } );
has usage           => ( is => 'ro', default => <<EOF
- `!avatar` - Display your own avatar
- `!avatar \@user` - Display someone else's avatar
EOF
);

has avatars         => ( is => 'ro', default => sub {
    [
        'http://i.imgur.com/yjMRuF0.png',
        'http://i.imgur.com/hI02I5p.png',
        'http://i.imgur.com/Y91CzhM.png',
        'http://i.imgur.com/y14nQAQ.png',
        'http://i.imgur.com/gZeA5Tc.jpg',
        'http://i.imgur.com/r2Qw3YE.jpg',
        'http://i.imgur.com/STX2FxZ.png',
        'http://i.imgur.com/GdCj0av.png',
        'http://i.imgur.com/KnuqLXW.png',
        'http://i.imgur.com/zsdbOj5.png',
    ]
});
    
sub cmd_avatar
{
    my ($self, $msg) = @_;

    my $discord = $self->discord;
    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};
    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $id = $author->{'id'};

    if ( $args =~ /\<\@\!?(\d+)\>/ )
    {
        $id = $1;
    }

    $discord->get_user($id, sub
    {
        my $json = shift;
        my $avatar = $json->{'avatar'};
        my $name = $json->{'username'};

        my $url = 'https://cdn.discordapp.com/avatars/' . $id . '/' . $avatar . '.jpg?size=1024';

        my $embed = $self->to_embed($name, $url);

        # Send a message back to the channel
        $self->send_message($channel, $embed);
    });
}

# Creates an embed hashref with the name and avatar url
sub to_embed
{
    my ($self, $name, $url) = @_;

    my $embed = {
        'title' => $name,
        'url' => $url,
        'type' => 'rich',
        'color' => 0xa0c0e6,
        'image' => {
            'url' => $url,
            'width' => 256,
            'height' => 256,
        },
    };

    return $embed;
}

# Takes an embed hashref and sends it as either a message or webhook
sub send_message
{
    my ($self, $channel, $embed) = @_;

    my $bot = $self->bot;
    my $discord = $self->discord;

    if ( my $hook = $bot->has_webhook($channel) )
    {
        my $num = rand(scalar @{$self->{'avatars'}});

        my $message = {
            'content' => '',
            'embeds' => [ $embed ],
            'username' => 'Avatar',
            'avatar_url' => $self->{'avatars'}[$num],
        };

        $discord->send_webhook($channel, $hook, $message);
    }
    else
    {
        my $message = {
            'content' => '',
            'embed' => $embed
        };

        $discord->send_message($channel, $message);
    }
  
}

1;
