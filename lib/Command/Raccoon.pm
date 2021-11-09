package Command::Raccoon;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_raccoon);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has some_random         => ( is => 'lazy', builder => sub { shift->bot->some_random } );

has name                => ( is => 'ro', default => 'Raccoon' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'You like raccoons, don\'t you?' );
has pattern             => ( is => 'ro', default => '^(raccoon|trashpanda) ?' );
has function            => ( is => 'ro', default => sub { \&cmd_raccoon } );
has usage               => ( is => 'ro', default => <<EOF
Look at this raccoon!

!raccoon

(There might be another name for this animal you can use also)
EOF
);

sub cmd_raccoon
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->some_random->animal('raccoon')->then(sub
        {
            my $json = shift;
            my $raccoon = $json->{'image'};
            $self->discord->send_message($channel_id, $raccoon);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any raccoons. Try again later!");
        }
    );
}

1;
