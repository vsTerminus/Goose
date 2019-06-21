package Command::YouTube;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_youtube);

use Mojo::Discord;
use Bot::Goose;
use Component::YouTube;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "YouTube";
my $access = 0; # Public
my $description = "Search YouTube";
my $pattern = '^(youtube|you|yt) ?(.*)$';
my $function = \&cmd_youtube;
my $usage = <<EOF;
Search for a video: `!youtube Rick Roll`

More results: `!youtube`
EOF
############################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
     
    # Setting up this command module requires the Discord connection 
    my $bot = $params{'bot'};

    $self->{'bot'}     = $bot;
    $self->{'discord'} = $bot->discord;
    $self->{'youtube'} = $bot->youtube;
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

sub cmd_youtube
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    my $youtube = $self->{'youtube'};
    my $bot = $self->{'bot'};

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

    my $bot = $self->{'bot'};
    my $discord = $self->{'discord'};

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
