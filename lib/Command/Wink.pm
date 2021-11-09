package Command::Wink;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_wink);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has some_random         => ( is => 'lazy', builder => sub { shift->bot->some_random } );

has name                => ( is => 'ro', default => 'Wink' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'You like animu, don\'t you?' );
has pattern             => ( is => 'ro', default => '^wink ?' );
has function            => ( is => 'ro', default => sub { \&cmd_wink } );
has usage               => ( is => 'ro', default => <<EOF
Winky face!

!wink
EOF
);

sub cmd_wink
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->some_random->animu('wink')->then(sub
        {
            my $json = shift;
            my $wink = $json->{'image'};
            $self->discord->send_message($channel_id, $wink);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any animu. Try again later!");
        }
    );
}

1;
