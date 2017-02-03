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
my $description = "Look up the definition of a word or phrase.\nPowered by UrbanDictionary";
my $pattern = '^(def(ine)?|urban|ud) ?(.*)$';
my $function = \&cmd_define;
my $usage = <<EOF;
Usage: `!define <word or phrase>`
Example `!define Xyzzy`

See more results: `!define`

Aliases: `!def`, `!urban`, `!ud`
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
#            say Dumper($json);
   
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
    my $def = trunc($json->{'definition'});
    my $example = trunc($json->{'example'});

    undef $example if ( $example !~ /[A-Za-z0-9]/m );

    my $str = "__**$word**__ [**$thumbs**]" .
              "\n\n$def";
    $str .= "\n\n\n*$example*" if ( defined $example );
    $str .= "\n\n<$json->{'permalink'}>";
    
    return $str;
}

sub trunc
{
    my $str = shift;
    my $max = 500;
    
    # Do some formatting replacements
    $str =~ s/\`/'/gm;
    $str =~ s/\[word\](.*?)\[\/word\]/$1/igm;
    $str =~ s/\*//gm;
    $str =~ s/\_//gm;

    if ( length $str > $max )
    {
        for ( my $i = 0; $i < 20 and length $str > $max; $i++ )
        {
#            $str =~ s/\s*\n*$//gm;
            $str =~ s/^(.*)(\n(?:.*(?!\n)))+$//gm;
            $str =~ s/\n\s*\n*\s*$/\n/gm;
        }
        if ( length $str > $max )
        {
            say "Length is still " . length $str . ", resorting to substring.";
        }
        
        $str = substr($str,0,$max) if ( length $str > $max );

        $str .= "[...]";
    }

    return $str;
}

1;
