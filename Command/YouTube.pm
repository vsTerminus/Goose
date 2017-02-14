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

    if ( defined $args and length $args )
    {
        $self->{'previous'} = $args;

        $youtube->search($args, sub 
        {
            my $json = shift;
            
            $self->{'cache'}{$args} = $json->{'items'};

            $discord->send_message($channel, '[1/10] https://www.youtube.com/watch?v=' . $json->{'items'}[0]{'id'}{'videoId'});
        });
    }
    elsif ( exists $self->{'cache'}{$self->{'previous'}} )
    {
        my @arr = @{$self->{'cache'}{$self->{'previous'}}};
        my $num = scalar @arr;
        
        if ( $num > 0 )
        {
            shift @arr if ( $num == 10 );

            my $i = 11 - scalar @arr;
            
            my $item = shift @arr;
            $self->{'cache'}{$self->{'previous'}} = \@arr;
    

            $discord->send_message($channel, "[$i/10] " . 'https://www.youtube.com/watch?v=' . $item->{'id'}{'videoId'});
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

1;
