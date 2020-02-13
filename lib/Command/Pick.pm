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
has pattern             => ( is => 'ro', default => '^pick ?' );
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

    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern//i;

    my $discord = $self->discord;
    my $replyto = '<@' . $author->{'id'} . '>';

    my $quiznos = 0;

    my @picks = split (/,+/, $args);

    my $count = scalar @picks;
    my $pick = int(rand($count));

    $pick =~ s/^ *//;
    
    for (my $i = 0; $i < $count; $i++)
    {
        if ( $picks[$i] =~ /^\s*quiznos\s*$/i )
        {
            # Always pick Quiznos
            $pick = $i; 
            $quiznos = 1;
        }
    }

    # Send a message back to the channel
    $discord->send_message($channel, ":point_right: $picks[$pick]");
}

1;
