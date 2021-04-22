package Command::Dog;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_dog);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has dog                 => ( is => 'lazy', builder => sub { shift->bot->dog } );

has name                => ( is => 'ro', default => 'Dog' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Pick a dog, any dog' );
has pattern             => ( is => 'ro', default => '^dog ?' );
has function            => ( is => 'ro', default => sub { \&cmd_dog } );
has usage               => ( is => 'ro', default => <<EOF
Look at this dog!

!dog
EOF
);

sub cmd_dog
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->dog->random()->then(sub
        {
            my $json = shift;
            my $dog = $json->{'message'};
            $self->discord->send_message($channel_id, $dog);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any dogs. Try again later!");
        }
    );
}

1;
