package Command::PYX;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_pyx);

use Mojo::Discord;
use Bot::Goose;
use Component::CAH;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "pretendyourexyzzy";
my $access = 0; # Public
my $description = "Play a single hand of Pretend You're Xyzzy - a Cards Against Humanity clone";
my $pattern = '^(cardsagainsthumanity|pretendyourexyzzy|pyx|cah) ?(.*)$';
my $function = \&cmd_pyx;
my $usage = <<EOF;
Make the bot play a totally random hand: `!pyx`
... with 1 blank:  `!pyx 1`
... with 2 blanks: `!pyx 2`
... with 3 blanks: `!pyx 3`

Make the bot fill in the blanks: `!pyx ____ is the name of my ____ coverband`

Play white cards with `w <card text>` and the bot will select a suitable black card at random.
... one card:  `!pyx w A Big Black Dick`
... two cards: `!pyx w Utilikilt w Paul and Storm`
etc 

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
    $self->{'cah'} = $self->{'bot'}->cah;
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

sub cmd_pyx
{
    my ($self, $channel, $author, $msg) = @_;

    $msg =~ s/[\`\*]//g;
    $msg =~ s/_+/____/g;

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';

    # If the user specifies a number or no args at all, go by pick
    # where the bot picks both the black and white cards.
    if ( !defined $args or $args =~ /^(w )?(\d+)$/ or $args =~ /^\s*$/ )
    {
        say "PYX By Pick";
        $self->by_pick($channel, $author, $args);
    }
    # If the user specifies w <card 1>... 
    # then the bot just has to pick a suitable black card
    elsif ( $args =~ /^w (.+)$/i )
    {
        say "PYX by White Cards";
        $self->by_white_cards($channel, $author, $args);
    }
    # Anything else should be treated like the user gave us a black card
    # and the bot just needs to fill in the blanks.
    else
    {
        say "PYX by Black Card";
        $self->by_black_card($channel, $author, $args);

    }
}


# User has supplied one or more white cards
# We need to select a suitable black card with the correct number of blanks
sub by_white_cards
{
    my ($self, $channel, $author, $args) = @_;

    my $cah = $self->{'cah'};
    my $discord = $self->{'discord'};

    my @cards = split / ?w /, $args; shift @cards; # Remove the first element, which will be empty.
    my $count = scalar @cards;

    say "User gave me $count white cards.";
    say "- $_" foreach @cards;

    $cah->random_black($count, sub {
        my $json = shift;
        say Dumper($json);

        my $text = $json->{'card'}{'text'};
        
        my $blanks = () = $text =~ /____/g;
        say "by_white_cards found $blanks blanks, expected $count";

        # Handle cases like "make a haiku" where they don't have the appropriate number of blanks and it will confuse things.
        while ( $blanks < $count )
        {
            $text .= ' ____ ';
            $blanks++;
        }


        foreach my $card (@cards)
        {
            if ( $card =~ /^\?+$/ )
            {
                # "w ?" should be replaced by a random card.
                my $new = $cah->random_white(1); # Blocking request - no callback.
                $card = $new->{'cards'}[0]{'text'};
                $card =~ s/\. *$//; # Remove the . at the end of the card.
            }
            $text =~ s/____/**$card**/;
        }

        $discord->send_message($channel, "$text");
    });
}

# User just said "Play a random hand" and may have specified the number of blanks they want to see.
# We have to pick a black card and then a suitable number of white cards to go in it.
sub by_pick
{
    my ($self, $channel, $author, $args) = @_;

    my $cah = $self->{'cah'};
    my $discord = $self->{'discord'};

    $args =~ /^(w ?)(\d+)$/;
    my $pick = $2;

#    say "User asked me for a Pick-$pick";
    
    $cah->random_black($2, sub {
        my $json = shift;
        say Dumper($json);

        if ( ref $json->{'card'} ne ref {} and !defined $json->{'card'} )
        {
            $discord->send_message($channel, "No matches.");
            return;
        }
        
        my $text = $json->{'card'}{'text'};
        $pick = $json->{'card'}{'pick'};
        my $count = () = $text =~ /____/g;
#        say "by_pick found $count blanks, expected $pick";

        # Handle cases like "make a haiku" where they don't have the appropriate number of blanks and it will confuse the by_black_card function.
        while ( $count < $pick )
        {
            $text .= ' ____ ';
            $count++;
        }

        # So now we have our black card. Let's fill it in with white cards.
        # We can use the by_black_card sub for this.
        $self->by_black_card($channel, $author, $text);

    });
}

# User supplied their own black card
# We need to fill in the blank(s) or answer the question if there are no blanks.
sub by_black_card
{
    my ($self, $channel, $author, $args) = @_;

    my $cah = $self->{'cah'};
    my $discord = $self->{'discord'};

    my $count = () = $args =~ /____/g;
    say "Found $count blanks";
    
    if ( $count > 0 )
    {
        $cah->random_white($count, sub {
            my $json = shift;

            say Dumper($json);

            foreach my $card (@{$json->{'cards'}})
            {
                my $text = $card->{'text'};
                $text =~ s/\.$//; # Remove the . at the end of the card.
                $args =~ s/____/**$text**/;
            }

            $discord->send_message($channel, $args);
        });
    }
    else
    {
        $cah->random_white($count, sub {
            my $json = shift;

            say Dumper($json);

            my $text = $json->{'cards'}[0]{'text'};
            $text =~ s/\.$//; # Remove the . at the end of the card.
            $args .= " **$text**";

            $discord->send_message($channel, $args);
        });
    }
}

1;
