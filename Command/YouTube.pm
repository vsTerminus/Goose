package Command::YouTube;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_youtube);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'YouTube' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Search YouTube' );
has pattern             => ( is => 'ro', default => '^(yt|you|youtube) ?' );
has function            => ( is => 'ro', default => sub { \&cmd_youtube } );
has usage               => ( is => 'ro', default => <<EOF
Search for a video: `!youtube Rick Roll`

More results: `!youtube`
EOF
);

sub cmd_youtube
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $discord = $self->discord;
    my $replyto = '<@' . $author->{'id'} . '>';

    my $bot = $self->bot;
    my $youtube = $bot->youtube;

    if ( defined $args and length $args )
    {
        $youtube->search($args, sub 
        {
            my $json = shift;
            
            my $item = shift @{$json->{'items'}};
            $self->{'cache'}{$channel} = $json->{'items'};

            my $embed = $self->to_embed($item);
            my $url = 'https://youtube.com/watch?v=' . $item->{'id'}{'videoId'};
            $discord->send_message($channel, $url);
        });
    }
    elsif ( exists $self->{'cache'}{$channel} )
    {
        my @arr = @{$self->{'cache'}{$channel}};
        my $num = scalar @arr;
        
        if ( $num > 0 )
        {
            my $item = shift @arr;
            $self->{'cache'}{$channel} = \@arr;

            my $embed = $self->to_embed($item);
            my $url = 'https://youtube.com/watch?v=' . $item->{'id'}{'videoId'};
            $discord->send_message($channel, $url);
        }
        else
        {
            $discord->send_message($channel, "No more results.");
        }
    }
    else
    {
        $discord->send_message($channel, "Please tell me what to search for like this: `!youtube <search phrase>`");
    }
}

sub to_embed
{
    my ($self, $json) = @_;

    my $description = $json->{'snippet'}{'description'};
    $description = substr($description,0,50) . "..." if ( length $description > 50 );

    my $embed = {
        'title' => $json->{'snippet'}{'title'},
        'description' => $description,
        'type' => 'rich',
        'url' => 'https://youtube.com/watch?v=' . $json->{'id'}{'videoId'},
        'thumbnail' => {
            'url' => $json->{'snippet'}{'thumbnails'}{'medium'}{'url'},
            'width' => $json->{'snippet'}{'thumbnails'}{'medium'}{'width'},
            'height' => $json->{'snippet'}{'thumbnails'}{'medium'}{'height'},
        },
        # Embedding a video doesn't actually work, but I'll leave this here commented out in case they ever change that.
#        'video' => {
#            'url' => 'http://youtube.com/embed/' . $json->{'id'}{'videoId'},
#            'height' => 480,
#            'width' => 480,
#        },
        'timestamp' => $json->{'snippet'}{'publishedAt'},
        'color' => 0xdf2925,
        'author' => {
            'name' => $json->{'snippet'}{'channelTitle'},
            'url' => 'https://youtube.com/channel/' . $json->{'snippet'}{'channelId'},
        }
    };


    return $embed;
}

sub send_message
{
    my ($self, $channel, $embed) = @_;

    my $bot = $self->bot;
    my $discord = $self->discord;

    if ( my $hook = $bot->has_webhook($channel) )
    {
        my $param = {
            'username' => "YouTube",
            'content' => '',
            'embeds' => [ $embed ],
            'avatar_url' => 'http://i.imgur.com/bOSQa41.png', #YouTube logo
        };

        $discord->send_webhook($channel, $hook, $param);
    }
    else
    {
        my $message = {
            'content' => '',
            'embed' => $embed,
        };
        $discord->send_message($channel, $message);
    }
}

1;
