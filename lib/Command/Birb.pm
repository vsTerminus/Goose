package Command::Birb;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_birb);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has some_random         => ( is => 'lazy', builder => sub { shift->bot->some_random } );

has name                => ( is => 'ro', default => 'Birb' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'You like birbs, don\'t you?' );
has pattern             => ( is => 'ro', default => '^bir[bd] ?' );
has function            => ( is => 'ro', default => sub { \&cmd_birb } );
has usage               => ( is => 'ro', default => <<EOF
Look at this birb!

!birb

(!bird is also OK)
EOF
);

sub cmd_birb
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->some_random->animal('birb')->then(sub
        {
            my $json = shift;
            my $birb = $json->{'image'};
            $self->discord->send_message($channel_id, $birb);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any birbs. Try again later!");
        }
    );
}

1;
