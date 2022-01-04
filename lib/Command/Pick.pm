package Command::Pick;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_pick);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Pick' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Have the bot decide your fate, you wishy washy fuck.' );
has pattern             => ( is => 'ro', default => '^pick\d* ' );
has function            => ( is => 'ro', default => sub { \&cmd_pick } );
has usage               => ( is => 'ro', default => <<EOF
```!pick thing one, thing two, thing three```
    Give the bot a list of things to pick from, and separate each with a comma.
    You can have the bot pick from as many things as you want.
EOF
);

sub cmd_pick
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $bestof = $args =~ /^pick(\d+)/i ? $1 : 1;
    if ( $bestof > 99 )
    {
        #say "Reducing requested \"best of $bestof\" to \"best of 99\"";
        $bestof = 99;
    }
    elsif ( $bestof == 2 )
    {
        #say "That's silly. You can't have a best of 2. Turning it into a best of 3.";
        $bestof = 3;
    }
    my $firstto = int( $bestof / 2 ) + 1;
    #say "Best of $bestof is first to $firstto";

    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern//i;

    my $discord = $self->discord;
    my $replyto = '<@' . $author->{'id'} . '>';

    my @picks = split (/,+/, $args);

    my $count = scalar @picks;

    my %picks;
    my $winner;
    my $quiznos;


    for (0..$count-1)
    {
        $picks{$_} = 0;
        $picks[$_] =~ s/^ *//;
        $picks[$_] =~ s/ *$//;
    }    

    for (my $i = 0; $i < $count; $i++)
    {
        if ( $picks[$i] =~ /^\s*quiznos\s*$/i )
        {
            # Always pick Quiznos
            $winner = $i; 
            $quiznos = $i;
            #say "Quiznos is Number $i";
        }
    }

    while(1)
    {
        my $pick = defined $quiznos ? $quiznos : int(rand($count)); # ALWAYS pick Quiznos
        #say "Picked $pick => '$picks[$pick]'";
        $picks{$pick}++;

        if ( $picks{$pick} >= $firstto )
        {
            $winner = $pick;
            #say "Winner is $winner => '$picks[$winner]'";
            last;
        }
    }

    if ( !defined $quiznos and int(rand(75)) == 69 ) # Nice
    {
        # Sometimes pick Quiznos even if it's not in the list
        $winner = $count;
        $picks[$winner] = 'Quiznos';
        $picks{$winner} = '69';
        say "QUIZNOS!";
    }

    my @emotes = qw[<:duo_gold:699866744411390001> <:duo_silver:699866744444944395> <:duo_bronze:699866744365252658>];

    my $message;
    if ( $bestof > 1 )
    {
        $count == 2 ? $message = "**Best of $bestof**\n" : $message = "~~Best of $bestof~~ **First to $firstto**\n";
        my $i = 0;
        for my $key ( reverse sort { $picks{$a} cmp $picks{$b} } keys %picks )
        {
            $message .= $emotes[$i] . ' ' . $picks[$key] . ' (' . $picks{$key} . ')' . "\n";
            $i++;
            last if $i == 3;
        }
    }
    else
    {
        $message = ":point_right: $picks[$winner]";
    }

    # Send a message back to the channel
    $discord->send_message($channel, $message);
}

1;
