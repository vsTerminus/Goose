package Command::PYX;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_pyx);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has cah                 => ( is => 'lazy', builder => sub { shift->bot->cah } );

has name                => ( is => 'ro', default => 'PYX' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Play a single hand of Pretend You\'re Xyzzy - a Cards Against Humanity clone' );
has pattern             => ( is => 'ro', default => '^(cah|pyx)(\d+)? ' );
has function            => ( is => 'ro', default => sub { \&cmd_pyx } );
has usage               => ( is => 'ro', default => <<EOF
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
);

has default_max_words   => ( is => 'ro', default => 8 ); # By default, restrict random white cards to at most this many words

sub cmd_pyx
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    $args =~ s/[\`\*]//gs;
    $args =~ s/_+/____/gs;

    my $pattern = $self->pattern;
    my ($cmd, $max_words) = ( $args =~ /$pattern/is );
    $max_words = $self->default_max_words unless $max_words and $max_words > 0 and $max_words < 100;
    say "Max Words: " . $max_words;

    $args =~ s/$pattern//si;

    my $discord = $self->discord;
    my $replyto = '<@' . $author->{'id'} . '>';

    # If the user specifies a number or no args at all, go by pick
    # where the bot picks both the black and white cards.
    if ( !defined $args or $args =~ /^(w )?(\d+)$/si or $args =~ /^\s*$/s )
    {
        #say "PYX By Pick";
        $self->by_pick($channel, $author, $args);
    }
    # If the user specifies w <card 1>... 
    # then the bot just has to pick a suitable black card
    elsif ( $args =~ /^w (.+)$/si )
    {
        #say "PYX by White Cards";
        $self->by_white_cards($channel, $author, $args, $max_words);
    }
    # Anything else should be treated like the user gave us a black card
    # and the bot just needs to fill in the blanks.
    else
    {
        #say "PYX by Black Card";
        $self->by_black_card($channel, $author, $args, $max_words);

    }
}


# User has supplied one or more white cards
# We need to select a suitable black card with the correct number of blanks
sub by_white_cards
{
    my ($self, $channel, $author, $args, $max_words) = @_;

    my $cah = $self->cah;
    my $discord = $self->discord;
    $args = " " . $args;

    my @cards = split(/ w /i, $args); shift @cards; # Remove the first element, which will be empty.
    my $count = scalar @cards;

    say "User gave me $count white cards.";
    say "Cards: " . join('+', @cards);

    $cah->random_black($count, sub {
        my $json = shift;
        #say Dumper($json);

        my $text = $json->{'card'}{'text'};
        
        my $blanks = () = $text =~ /____/sg;
        #say "by_white_cards found $blanks blanks, expected $count";

        # Handle cases like "make a haiku" where they don't have the appropriate number of blanks and it will confuse things.
        while ( $blanks < $count )
        {
            $text .= ' ____ ';
            $blanks++;
        }


        foreach my $card (@cards)
        {
            if ( $card =~ /^\?+$/s )
            {
                # "w ?" should be replaced by a random card.
                my $new = $cah->random_white(1, $max_words); # Blocking request - no callback.
                $card = $new->{'cards'}[0]{'text'};
                $card =~ s/\. *$//s; # Remove the . at the end of the card.
            }
            $text =~ s/____/**$card**/s;
        }

        $discord->send_message($channel, "$text");
    });
}

# User just said "Play a random hand" and may have specified the number of blanks they want to see.
# We have to pick a black card and then a suitable number of white cards to go in it.
sub by_pick
{
    my ($self, $channel, $author, $args) = @_;

    my $cah = $self->cah;
    my $discord = $self->discord;

    $args =~ /^(w ?)(\d+)$/s;
    my $pick = $2;

#    say "User asked me for a Pick-$pick";
    
    $cah->random_black($2, sub {
        my $json = shift;
        #say Dumper($json);

        if ( ref $json->{'card'} ne ref {} and !defined $json->{'card'} )
        {
            $discord->send_message($channel, "No matches.");
            return;
        }
        
        my $text = $json->{'card'}{'text'};
        $pick = $json->{'card'}{'pick'};
        my $count = () = $text =~ /____/sg;
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
    my ($self, $channel, $author, $args, $max_words) = @_;

    my $cah = $self->cah;
    my $discord = $self->discord;

    my $count = () = $args =~ /____/sg;
    #say "Found $count blanks";
    
    if ( $count > 0 )
    {
        $cah->random_white($count, $max_words, sub {
            my $json = shift;

            #say Dumper($json);

            foreach my $card (@{$json->{'cards'}})
            {
                my $text = $card->{'text'};
                $text =~ s/\.$//s; # Remove the . at the end of the card.
                $text = uc $text if $args !~ /[a-z]/s; # If the white card is all caps, the black card should be too.
                $args =~ s/____/**$text**/s;
            }

            $discord->send_message($channel, $args);
        });
    }
    else
    {
        $cah->random_white($count, $max_words, sub {
            my $json = shift;

            #say Dumper($json);

            my $text = $json->{'cards'}[0]{'text'};
            $text =~ s/\.$//s; # Remove the . at the end of the card.
            $text = uc $text if $args !~ /[a-z]/s; # If the white card is all caps, the black card should be too.
            $args .= " **$text**";

            $discord->send_message($channel, $args);
        });
    }
}

1;
