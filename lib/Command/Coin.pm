package Command::Coin;
use feature 'say';

use Moo;
use strictures 2;

use Mojo::Discord;
use Bot::Goose;
use Math::Random::Secure qw(irand); # Cryptographically-secure, cross-platform replacement for rand()

use namespace::clean;

has bot             => ( is => 'ro' );
has discord         => ( is => 'lazy', builder => sub { shift->bot->discord } );

has name            => ( is => 'ro', default => 'Coin' );
has access          => ( is => 'ro', default => 0 ); # Public
has description     => ( is => 'ro', default => 'Flip a coin!' );
has pattern         => ( is => 'ro', default => '^(coin|flip) ?(.*)$' );
has function        => ( is => 'ro', default => sub { return \&cmd_coin } );
has usage           => ( is => 'ro', default => sub { return <<EOF;
Flip a coin! It will either be heads or tails.

**Usage:**

`!coin` or `!flip`

To flip multiple coins just add the number of coins you want to flip

`!flip 10` or `!coin 10`

EOF
});

has heads           => ( is => 'ro', default => 'https://i.imgur.com/JQcJHao.png' );
has tails           => ( is => 'ro', default => 'https://i.imgur.com/eViASNq.png' );


sub cmd_coin
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $pattern = $self->pattern;
    $args =~ s/$pattern/$2/i;
    $args = 1 if (!defined $args or $args =~ /^\s*$/ or $args !~ /^\d+$/ or $args < 1 or $args > 100000);
    say $args;

    my $discord = $self->discord;
    my $replyto = '<@' . $author->{'id'} . '>';

    my @coin = ($self->heads, $self->tails);

    if ( $args == 1 )
    {
        # Coin image
        $discord->send_message($channel, $coin[$self->_flip()]);
    }
    else
    {
        my $heads = 0;
        my $tails = 0;
        for ( my $i = 0; $i < $args; $i++ )
        {
            # 0 = heads
            # 1 = tails
            $self->_flip() ? $tails++ : $heads++;
        }
        my $winner = "Draw!";
        if ( $heads > $tails ) { $winner = "Heads!" }
        elsif ( $tails > $heads ) { $winner = "Tails!" }

        $discord->send_message($channel, "Result: " . $heads . "H " . $tails . "T\nWinner: " . $winner);
    }
}

sub _flip
{
    return irand(2);
}

__PACKAGE__->meta->make_immutable;

1;
