package Command::Card;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Games::Cards;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_card);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has game                => ( is => 'lazy', builder => sub { Games::Cards::Game->new() });
has decks               => ( is => 'lazy', builder => sub { {} });
has hands               => ( is => 'lazy', builder => sub { {} });

has name                => ( is => 'ro', default => 'Card' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Pick a card, any card' );
has pattern             => ( is => 'ro', default => '^card ?' );
has function            => ( is => 'ro', default => sub { \&cmd_card } );
has usage               => ( is => 'ro', default => <<EOF
Pick a card!

!card
EOF
);

sub cmd_card
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    my $guild_id = $msg->{'guild_id'};
    my $guild = $self->discord->get_guild($guild_id);
    my $author = $msg->{'author'};
    my $author_id = $author->{'id'};
    my $message_id = $msg->{'id'};

    my $args = $msg->{'content'};
    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $reply = $self->usage;

    my $deck = $self->decks->{$channel_id};
    unless ( $deck )
    {
        $self->bot->log->debug("[Card.pm] [cmd_card] Creating new deck for channel $channel_id");
        $deck = new Games::Cards::Deck ($self->game, $channel_id);
        $self->_shuffle_deck($deck);
    }
    
    # Allow users to manually shuffle the deck at any time
    if ( $args =~ /shuffle/i )
    {
        $self->bot->log->debug("[Card.pm] [cmd_card] User requested a manual shuffle in channel $channel_id");
        $self->_recall_cards($deck);
        $self->_shuffle_deck($deck);
        $self->decks->{$channel_id} = $deck;
        $self->discord->send_message($channel_id, "The deck has been shuffled!");
        return $deck;
    }

    my $hand = $self->hands->{$channel_id}{$author_id};
    unless ( $hand )
    {
        $self->bot->log->debug("[Card.pm] [cmd_card] Creating new hand for user ID $author_id in channel ID $channel_id");  
        $hand = new Games::Cards::Hand ($self->game, $channel_id . $author_id);
    }

    unless ( $deck->size )
    {
        $self->bot->log->debug("[Card.pm] [cmd_card] Recalling all cards back to the deck in channel $channel_id to prepare to shuffle");
        $self->_recall_cards($deck);
        $self->bot->log->debug("[Card.pm] [cmd_card] Shuffling the deck in channel ID $channel_id because all cards have been dispensed");
        $self->_shuffle_deck($deck);
    }

    if ( $deck->size )
    {
        $self->bot->log->debug("[Card.pm] [cmd_card] Dealing one card from deck $channel_id to user $author_id");
        $deck->give_cards($hand, 1);
        $self->bot->log->debug("[Card.pm] [cmd_card] Hand contents: " . $self->_print_hand($hand));
        $self->bot->log->debug("[Card.pm] [cmd_card] Deck size: " . $deck->size);

        $self->decks->{$channel_id} = $deck;
        $self->hands->{$channel_id}{$author_id} = $hand;

        my $card_code = $hand->{'cards'}[-1]->print("short"); $card_code =~ s/\s//g;
        my $card_name = $hand->{'cards'}[-1]->print("long");


        my $image = "lib/Command/Card/images/$card_code.png";
        my $name = "$card_code.png";
        my $message = "";
        $message = ":musical_note: The Ace of Spades, the Ace of Spades! :metal:" if $card_code eq 'AS';
        #my $message = "Your hand: `" . $self->_print_hand($hand) . "`";
        $self->discord->send_image($channel_id, {'content' => $message, 'name' => $name, 'path' => $image});
    }
    else
    {
        $self->bot->log->debug("[Card.pm] [cmd_card] Unable to deal card from empty deck in channel $channel_id");
        $self->discord->send_message($channel_id, ":x: Something went wrong - The deck for this channel is empty.");
    }
}

# Pass in a deck and it will return all dispensed cards back to the deck
sub _recall_cards
{
    my ($self, $deck) = @_;

    my $channel_id = $deck->name;

    $self->bot->log->debug("[Card.pm] [_recall_cards] Returning all cards for channel $channel_id to the deck");
    
    if ( exists $self->hands->{$channel_id} )
    {
        foreach my $author_id (keys %{$self->hands->{$channel_id}})
        {
            my $hand = $self->hands->{$channel_id}{$author_id};
            $self->bot->log->debug("[Card.pm] [_recall_cards] Hand for user $author_id returns " . $hand->size . " cards to the deck");
            $hand->give_a_card($deck, 0) while ($hand->size); # Return each card back to the deck, one at a time. No way to do this in bulk?
            $self->hands->{$channel_id}{$author_id} = $hand;
        }
    }
    else
    {
        $self->bot->log->debug("[Card.pm] [_recall_cards] No hands exist yet in channel $channel_id. Nothing to do!");
    }

    return $deck;
}

# Pass in a deck and it will be shuffled. Has the advantage of logging and error checking.
sub _shuffle_deck
{
    my ($self, $deck) = @_;

    my $channel_id = $deck->name;

    if ( $deck->size )
    {
        $self->bot->log->debug("[Card.pm] [_shuffle_deck] Shuffling deck in channel $channel_id");
        $deck->shuffle;
    }
    else
    {
        $self->bot->log->debug("[Card.pm] [_shuffle_deck] Cannot shuffle empty deck in channel $channel_id");
        return undef;
    }

    return $deck;
}


# Return a formatted hand string for display
sub _print_hand
{
    my ($self, $hand) = @_;

    my $hand_short = "No Cards";
    if ( $hand->size )
    {
        $hand_short = $hand->print("short");
        $hand_short =~ s/^\d+:  //;
        $hand_short =~ s/\s+/ /sg;
        $hand_short =~ s/\n//sg;
        chomp $hand_short;
    }

    return $hand_short;
}

1;
