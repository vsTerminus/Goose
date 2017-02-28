package Command::Roll;

use strict;
use warnings;
use v5.10;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_template);

use Mojo::Discord;
use Bot::Goose;

###########################################################################################
# Command Info
my $command = "Roll";
my $access = 0; # Public
my $description = "Roll some dice";
my $pattern = '^(di(?:ce)|ro(?:ll)?) ?(.*)$';
my $function = \&cmd_roll;
my $usage = <<EOF;
Roll X number of Y sided dice with optional bonus.

Individual results will be displayed if you are rolling 25 or fewer dice.

Usage:

Format is `!roll [num dice]d[num sides]+[bonus]`

The number of dice is optional, will default to one.
The number of sides is also optional, will default to 20.
The bonus is optional, will default to 0.

That means that `!roll` by itself is the equivalent of `!roll 1d20+0`.

More examples:

Roll a single 6-sided die: `!roll d6`
Roll four 6-sided dice: `!roll 4d6`
Roll 4 20-sided dice: `!roll 4`
Roll 4 20-sided dice with 10 bonus: `!roll 4+10`
Roll 10 100-sided dice with 69 bonus: `!roll 10d100+69`

Aliases:

Also accepts: !dice, !di, and !ro
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

sub cmd_roll
{
    my ($self, $channel, $author, $msg) = @_;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    my $num_dice = ( $args =~ /^(\d+)/ ) ? $1 : 1;
    my $num_sides = ( $args =~ /d(\d+)/ ) ? $1 : 20;
    my $bonus = ( $args =~ /\+(\d+)$/ ) ? $1 : 0;

    my $total = 0;
    my $rolls = "";

    for(1..$num_dice)
    {
        my $num = int(rand($num_sides))+1;
        $total += $num;

        $rolls .= "$num+" if $num_dice > 1 and $num_dice < 25;
    }
    $total += $bonus;

    $rolls = ":  `" . $rolls . "$bonus`" if ( length $rolls );

    $discord->send_message($channel, 'Rolling ' . $num_dice . 'd' . $num_sides . '+' . $bonus . ' ' . $rolls . "\nResult: **$total**");
}

1;
