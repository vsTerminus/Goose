package Command::Fox;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_fox);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has fox                 => ( is => 'lazy', builder => sub { shift->bot->fox } );

has name                => ( is => 'ro', default => 'Fox' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Pick a fox, any fox' );
has pattern             => ( is => 'ro', default => '^fox ?' );
has function            => ( is => 'ro', default => sub { \&cmd_fox } );
has usage               => ( is => 'ro', default => <<EOF
Look at this fox!

!fox
EOF
);

sub cmd_fox
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->fox->random()->then(sub
        {
            my $json = shift;
            my $fox = $json->{'image'};
            $self->discord->send_message($channel_id, $fox);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any foxes. Try again later!");
        }
    );
}

1;
