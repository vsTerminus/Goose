package Command::Duck;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_duck);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has duck                 => ( is => 'lazy', builder => sub { shift->bot->duck } );

has name                => ( is => 'ro', default => 'Duck' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Pick a duck, any duck' );
has pattern             => ( is => 'ro', default => '^duck ?' );
has function            => ( is => 'ro', default => sub { \&cmd_duck } );
has usage               => ( is => 'ro', default => <<EOF
Look at this duck!

!duck
EOF
);

sub cmd_duck
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->duck->random()->then(sub
        {
            my $json = shift;
            my $duck = $json->{'url'};
            $self->discord->send_message($channel_id, $duck);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any ducks. Try again later!");
        }
    );
}

1;
