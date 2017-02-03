package Command::Define;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_define);

use Net::Discord;
use Bot::Goose;
use Component::UrbanDictionary;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Define";
my $access = 0; # Public
my $description = "Look up the definition of a word on UrbanDictionary";
my $pattern = '^(def(ine)?|urban|ud) ?(.*)$';
my $function = \&cmd_define;
my $usage = <<EOF;
Usage: `!define <word or phrase>`
Example `!define Xyzzy`
EOF
###########################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
     
    # Setting up this command module requires the Discord connection 
    $self->{'bot'} = $params{'bot'};
    $self->{'discord'} = $self->{'bot'}->discord;
    $self->{'urbandictionary'} = $self->{'bot'}->urbandictionary;
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

sub cmd_define
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$3/i;

    my $discord = $self->{'discord'};
    my $urban = $self->{'urbandictionary'};
    my $replyto = '<@' . $author->{'id'} . '>';

    # If they passed a word or phrase to search, look it up.
    if ( defined $args and length $args > 0 )
    {
        $urban->define($args, sub
        {
            my $json = shift;
            say Dumper($json);
   
            if ( $json->{'result_type'} eq 'no_results' )
            {
                $discord->send_message($channel, "No Results.");
                return;
            }

            my $def = shift @{$json->{'list'}};
            $self->{'cache'}{$channel} = $json->{'list'};
            my $num = scalar @{$json->{'list'}};
    
            $discord->send_message($channel, to_string($def));
        });
    }
    elsif ( exists $self->{'cache'}{$channel} )
    {
        my $def = shift @{$self->{'cache'}{$channel}};
        my $num = scalar @{$self->{'cache'}{$channel}};

        $discord->send_message($channel, to_string($def));

        delete $self->{'cache'}{$channel} if $num == 0;
    }
    else
    {
        $discord->send_message($channel, "No more results.");
    }
}

sub get_cached
{
    my ($self, $term) = @_;

    # Do we have this term cached? 
}

# Takes the definition JSON and returns a formatted string
sub to_string
{
    my $json = shift;

    my $tup = $json->{'thumbs_up'};
    my $tdn = $json->{'thumbs_down'};
    my $thumbs = $tup - $tdn;
    $thumbs = "+" . $thumbs if $thumbs > 0;
    my $word = ucfirst lc $json->{'word'};
    my $example = $json->{'example'};
    my $def = $json->{'definition'};

    # Do some formatting replacements
    $def =~ s/\`/'/g;
    $example =~ s/\`/'/g;

    return  "__**$word**__ (**$thumbs**)\n\n" .
            "$def\n\n**Example:**\n$example";
}

1;
