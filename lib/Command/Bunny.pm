package Command::Bunny;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_bunny);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has bunnies             => ( is => 'lazy', builder => sub { shift->bot->bunnies } );

has name                => ( is => 'ro', default => 'Bunny' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Pick a bunny, any bunny' );
has pattern             => ( is => 'ro', default => '^bunny ?' );
has function            => ( is => 'ro', default => sub { \&cmd_bunny } );
has usage               => ( is => 'ro', default => <<EOF
Look at this bunny!

!bunny
EOF
);

sub cmd_bunny
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->bunnies->random()->then(sub
        {
            my $json = shift;
            my $bunny = $json->{'media'}{'gif'};
            $self->discord->send_message($channel_id, $bunny);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any bunnies. Try again later!");
        }
    );
}

1;
