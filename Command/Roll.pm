package Command::Roll;
use feature 'say';

use Moo;
use strictures 2;

use Mojo::Discord;
use Bot::Goose;
use Math::Random::Secure qw(irand); # Cryptographically-secure, cross-platform replacement for rand()

use namespace::clean;

has bot             => ( is => 'rw', required => 1 );
has discord         => ( is => 'rw' );

has name            => ( is => 'ro', default => 'Roll' );
has access          => ( is => 'ro', default => 0 ); # Public
has description     => ( is => 'ro', default => 'Roll some dice' );
has pattern         => ( is => 'ro', default => '^(di(?:ce)|ro(?:ll)?) ?(.*)$' );
has function        => ( is => 'ro', default => sub { return \&cmd_roll } );
has usage           => ( is => 'ro', default => sub { return <<EOF;
Roll X number of Y sided dice with optional bonus.

Individual results will be displayed if you are rolling 25 or fewer dice.

**Usage:**

Format is `!roll [num dice]d[num sides]+[bonus]`

The number of dice is optional, will default to 1.
The number of sides is also optional, will default to 20.
The bonus is optional, will default to 0.

That means that `!roll` by itself is the equivalent of `!roll 1d20+0`.

**More examples:**

Roll a single 6-sided die: `!roll d6`
Roll four 6-sided dice: `!roll 4d6`
Roll 4 20-sided dice: `!roll 4`
Roll 4 20-sided dice with 10 bonus: `!roll 4+10`
Roll 10 100-sided dice with 69 bonus: `!roll 10d100+69`

**Aliases:**

Also accepts: !dice, !di, and !ro
EOF
});

sub BUILD
{
    my $self = shift;

    $self->discord( $self->bot->discord );
}

# This takes the modifier string and the rolls as an array
# It will figure out the min and max.
# It will modify the rolls array and return the total and the rolltext as two strings.
sub _do_modifier
{
    my ($self, $mod, @rolls) = @_;

    my $min = 2147483647;
    my $max = -2147483648;
    my $minpos = 0;
    my $maxpos = 0;
    my $total = 0;

    for (my $i = 0; $i < scalar @rolls; $i++)
    {
        my $roll = int($rolls[$i]);
        if ( $roll < $min ) { $min = $roll; $minpos = $i; }
        if ( $roll > $max ) { $max = $roll; $maxpos = $i; }
        $total += $roll;
    }

    # Now on to the possibilities.

    # Simplest case is, it's an integer bonus.
    if ( $mod =~ /^[+-]\d+/ )
    {
        # Do the math on the total. Simple enough.
        unless(int($mod) == 0)
        {
            $total += int($mod);
            push @rolls, int($mod);
        }
    }
    # Next: Add the Lowest
    elsif ( uc $mod eq '+L' )
    {
        # Much the same as above, just with whatever our lowest roll value was.
        $total += $min;
        push @rolls, $min;
    }
    # Add Highest
    elsif ( uc $mod eq '+H' )
    {
        $total += $max;
        push @rolls, $max;
    }
    # Here's where it gets different. Drop Lowest.
    elsif ( uc $mod eq '-L' )
    {
        $total -= $min;
        $rolls[$minpos] = "~~ " . $rolls[$minpos] . " ~~"; # Cross it out.
    }
    #  Same as above but for highest roll.
    elsif ( uc $mod eq '-H' )
    {
        $total -= $max;
        $rolls[$maxpos] = "~~ " . $rolls[$maxpos] . " ~~"; # Cross it out.
    }

    my $rolltext = '(' . join(' + ', @rolls) . ')';
    $rolltext =~ s/\+-/-/; # If there was a negative bonus.

    return $total, $rolltext;
}

# Takes all four elements of a roll
# - Number of rolls
# - Number of dice
# - Number of sides
# - Modifier(s)
# Returns two strings:
# - The Total
# - A string of the individual rolls
sub _roll
{
    my ($self, $num_rolls, $num_dice, $num_sides, $modifier) = @_;

    my @totals;
    my @rollsets;

    # Figure out if we have one or two modifiers, put them in an array.
    my @mods;
    if ( defined $modifier )
    {
        # If there is only one modifier and it is outside the brackets, put a fake +0 bonus in the string
        # to make the next part behave correctly.
        $modifier = '+0' . $modifier if ( substr($modifier,0,1) eq ')' );

        # Strip brackets
        $modifier =~ s/[()]//g;

        # Put the modifier(s) into an array
        @mods = ( $modifier =~ /([+-](?:\d+|[LH]))/gi );

        push @mods, '+0' if (scalar @mods == 1); # Make sure we always have two modifiers.
    }
    else
    {
        # No modifier? Make it +0+0
        @mods = ('+0', '+0');
    }
    #say scalar @mods . " mods: @mods" if scalar @mods;

    for( my $i = 0; $i < $num_rolls; $i++ )
    {
        my @rolls;

        # Roll the dice
        for( 1..$num_dice )
        {
            # irand is from Math::Random::Secure
            my $num = irand($num_sides)+1;

            # Add it to our list of rolls so far.
            push @rolls, $num;
        }

        my ($total, $rolltext) = $self->_do_modifier($mods[0], @rolls);

        # Track this roll set.
        push @totals, $total;
        push @rollsets, $rolltext;
        #say "Roll Set: $rolltext";
    }

    # Go back for a second round of modifier checking *iff*
    # there is a modifier or more than one roll set to display.
    if ( $mods[1] ne '+0' or scalar @totals > 1 )
    {
        return $self->_do_modifier($mods[1], @totals);
    }
    # If there is no second modifier and only one roll set, just return what we already have.
    else
    {
        return $totals[0], $rollsets[0];
    }
}

sub cmd_roll
{
    my ($self, $channel, $author, $msg) = @_;

    #say "cmd_roll: $channel, $author, $msg";

    my $args = $msg;
    my $pattern = $self->pattern;
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    # Multiple rolls can be separated by a space.
    my @rolls = split(' ', $args);

    #say "Rolls: @rolls";

    # Default roll if the user leaves it blank
    push @rolls, '1d20' if (!defined $args or $args =~ /^\s*$/);
   
    my $results;
    my $sum = 0;
    my $min = 2147483647;
    my $max = -2147483648;
    my $minpos = 0;
    my $maxpos = 0;
   
    # I need an index counter for dropping Low or High rolls, so using For instead of Foreach.
    for ( my $i = 0; $i < scalar @rolls; $i++)
    {
        my $roll = $rolls[$i];

        # A roll should look something like this: 2x(3d8+1)-L
        # Which basically reads: Roll 3 8-sided dice and add 1, then do it again and drop the Low score. (aka, roll 3d8+1 with advantage)
        # However, a lot of that is optional.
        # Pretty well any individual part of the expression should be fine on its own and the code should be able to default the rest.
        # The default roll would be 1x(1d20+0)+0

        # A number in front of the letter x is the multiplier.
        # The bracket is optional, and only needed if you have two modifiers.
        my $num_rolls = ( $roll =~ /^(\d+)x/i ) ? $1 : 1;

        # A number by itself is the number of dice to roll.
        # This should either be the first character in the string or following either x or (
        # It should also either be the last character in the string or followed by a letter d or even a ) (if they do something weird like 2x(5)
        my $num_dice = ( $roll =~ /(?:(?<=x)|(?<=\()|(?<=^))(\d+)(?:(?=d)|(?=\))|(?=$))/i ) ? $1 : 1;

        # The letter d followed by some digits would be the number of sides on the dice to roll. Easy one.
        my $num_sides = ( $roll =~ /d(\d+)/i ) ? $1 : 20;

        # Finally modifier, which will include bonus and/or a High or Low specification
        # We're looking for + or - followed by either digits or the letter L or H.
        # There may be one or two instances of this, and there may or may not be a ) in between them.
        # For example, it may be -L+1 or +2)-H etc, depending how the user formatted the roll.
        my $modifier = ( $roll =~ /((?:(?:[+-](?:\d+|[LH]))+\)?){1,2})$/i ) ? $1 : undef;

        # Set some (arbitrary) limits on the maximum number of dice, sides, and rolls to accept.
        if ( $num_rolls > 1000 ) { $discord->send_message($channel, "Too many rolls. Max 1000."); return; }
        if ( $num_dice > 1000 )  { $discord->send_message($channel, "Too many dice. Max 1000.");  return; }
        if ( $num_sides > 1000 ) { $discord->send_message($channel, "Too many sides. Max 1000."); return; }
        # And some not-so-arbitrary limits on the minimums.
        if ( $num_rolls < 1 )    { $discord->send_message($channel, "Not enough rolls. Min 1.");  return; }
        if ( $num_sides < 1 )    { $discord->send_message($channel, "Not enough sides. Min 1.");  return; }
        if ( $num_dice < 1 )     { $discord->send_message($channel, "Not enough dice. Min 1.");   return; }

        # This next section is purely cosmetic. It aims to keep
        # the bot's output consistent in format regardless of how
        # much or how little the user specified.
        $roll = "";
        $roll .= $num_rolls . 'x(';
        $roll .= $num_dice . 'd' . $num_sides;
        if ( defined $modifier )
        {
            my $num = () = $modifier =~ /[+-]/g;

            if ( $num >2 )
            {
                $discord->send_message($channel, "Too many modifiers. Max 2.");
                return;
            }
            elsif ( $num == 2 )
            {
                if ( $modifier !~ /\)/ )
                {
                    $modifier =~ s/^([+-].*)([+-].*)$/$1)$2/;
                }
            }
            elsif ( $num == 1 )
            {
                $modifier .= ')' unless $modifier =~ /\)/;
            }
            $roll .= $modifier;
        }
        else
        {
            $roll .= ')';
        }
        
        # Perform the roll, which should return the total and the individual rolls as two strings.
        my ($total, $rolltext) = $self->_roll($num_rolls, $num_dice, $num_sides, $modifier);
        #say "Returned Total: $total";
        #say "Returned Rolltext: $rolltext";

        # Add this total to our sum for the whole thing.
        # Also track min and max.
        $sum += $total;
        $min = $total if $total < $min;
        $max = $total if $total > $max;
        
        # Finally, set a limit on how many rolls to actually show individual results for.
        # Multiply the number of rolls by the number of dice and if the result is greater than 25
        # just show the total instead. Otherwise it gets pretty messy in chat.
        if ( ($num_rolls * $num_dice) <= 25 and ($num_rolls > 1 or $num_dice > 1) )
        {
            $results .= ":game_die: **$roll** => $rolltext = **$total**\n";
        }
        # Also, if we're only rolling one die there's no need to show individual results.
        else
        {
            $results .= ":game_die: **$roll** = **$total**\n";
        }
    }
    $results .= "**Sum**: $sum | **Low**: $min | **High**: $max\n" if ( scalar @rolls > 1 );

    $discord->send_message($channel, "$replyto\n$results");
}

__PACKAGE__->meta->make_immutable;

1;
