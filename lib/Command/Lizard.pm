package Command::Lizard;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_lizard);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has lizard                 => ( is => 'lazy', builder => sub { shift->bot->lizard } );

has name                => ( is => 'ro', default => 'Lizard' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Pick a lizard, any lizard' );
has pattern             => ( is => 'ro', default => '^lizard ?' );
has function            => ( is => 'ro', default => sub { \&cmd_lizard } );
has usage               => ( is => 'ro', default => <<EOF
Look at this lizard!

!lizard
EOF
);

sub cmd_lizard
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->lizard->random()->then(sub
        {
            my $json = shift;
            my $lizard = $json->{'url'};
            $self->discord->send_message($channel_id, $lizard);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any lizards. Try again later!");
        }
    );
}

1;
