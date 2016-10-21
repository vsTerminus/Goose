package Commands::Comic;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_comic);

use Net::Discord;
use Bot::Goose;
use Mojo::UserAgent;
use DBI;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Comic";
my $description = "Displays a comic from the Cyanide & Happiness Random Comic Generator";
my $pattern = '^(rc|comic) ?(.*)$';
my $function = \&cmd_comic;
my $usage = <<EOF;
```!comic (or !rc)```
    Display a randomly generated comic

```!comic <panel number(s)>```
    Display a random comic, keeping certain panel(s) from the previous comic:
    
    __Examples:__

        `!comic 1`   (Keeps the first panel from the last comic)
        `!comic 23`  (Keeps the second and third panels)

```!comic order <panel numbers>```
    Re-order the panels from the previous comic.

    __Examples:__

        `!comic order 312`   (Third panel first)
        `!comic order 321`   (Reverse order)
    
    This likely will not work due to restrictions on the Comic Generator.

EOF
###########################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
     
    # Setting up this command module requires the Discord connection 
    $self->{'bot'} = $params{'bot'};
    my $bot = $self->{'bot'}; 
    
    $self->{'discord'} = $bot->discord;
    $self->{'pattern'} = $pattern;

    # Register our command with the bot
    $bot->add_command(
        'command'       => $command,
        'description'   => $description,
        'usage'         => $usage,
        'pattern'       => $pattern,
        'function'      => $function,
        'object'        => $self,
    );
    
    return $self;
}

sub cmd_comic
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';
    my $ua = Mojo::UserAgent->new;
    my $comic;
    my $vars = "/?";

    # We can do some different things with this, like swapping.
    if ( defined $self->{$channel}{'lastcomic'} and $args =~ /^order (\d{3})$/  )
    {
        my @order = split('', $1);
        my @parts = $self->{$channel}{'lastcomic'} =~ /(...)(...)(...)/;
        unshift @parts, "spacer";
        
        $comic = 'http://files.explosm.net/rcg/' . $parts[$order[0]] . $parts[$order[1]] . $parts[$order[2]] . '.png';
    }
    else
    {
        if ( defined $self->{$channel}{'lastcomic'} and $args =~ /(keep )?([123]{1,3})/i )
        {   
            my @keep = split('', $2);
            my @parts = $self->{$channel}{'lastcomic'} =~ /(...)(...)(...)/;
            unshift @parts, "spacer";

            foreach my $num (@keep)
            {
                $vars .= "$num=" . $parts[$num] . '&';
            }
        }

        my $url = 'http://explosm.net/rcg';
        $url .= $vars if length $vars > 2;

        my $html = $ua->get($url)->res->body;

        for(my $i=0; $i < 3; $i++)
        {
            if ( $html =~ /src=\"\/\/(files.explosm.net\/rcg\/(.*).png)\"/ )
            {
                $comic = "http://" . $1;
                last;
            }
            sleep(1);
        }
    }

    if ( defined $comic )
    {
        $discord->send_message($channel, $comic);
        $self->{$channel}{'lastcomic'} = substr($comic,-13,9);  # Track the last URL delivered.
    }
    else
    {
        $discord->send_message($channel, "Unable to retrieve comic. Please try again.");
    }
}

1;
