package Command::RedPanda;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_redpanda);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has some_random         => ( is => 'lazy', builder => sub { shift->bot->some_random } );

has name                => ( is => 'ro', default => 'RedPanda' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'You like red pandas, don\'t you?' );
has pattern             => ( is => 'ro', default => '^redpanda ?' );
has function            => ( is => 'ro', default => sub { \&cmd_redpanda } );
has usage               => ( is => 'ro', default => <<EOF
Look at this red panda!

!redpanda

(For black and white pandas, try !panda)
EOF
);

sub cmd_redpanda
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->some_random->animal('red_panda')->then(sub
        {
            my $json = shift;
            my $panda = $json->{'image'};
            $self->discord->send_message($channel_id, $panda);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any red pandas. Try again later!");
        }
    );
}

1;
