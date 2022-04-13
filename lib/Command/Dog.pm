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

Want a specific breed? Try `!dog <breed>`, eg `!dog corgi` or `!dog golden retriever`

For a full list of recognized breeds, see the list here: https://dog.ceo/dog-api/breeds-list

EOF
);

sub cmd_dog
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    my $pattern = $self->pattern;
    my $discord = $self->discord;
    my $breed = $msg->{'content'};
    $breed =~ s/$pattern//;

    $breed 
    ?   $self->_breed($breed)->then(sub{ $discord->send_message($channel_id, shift) }) 
    :   $self->_random()->then(sub{ $discord->send_message($channel_id, shift) });
}

sub _breed
{
    my ($self, $breed) = @_;

    # Sub breeds are submitted as "breed/subtype" in the API which is backwards for how people type them
    # So dogs like "Golden Retriever" have to be updated to "Retriever/Golden"
    if ( $breed =~ / / )
    {
        $breed =~ s/^(\w+) (\w+)$/$2\/$1/;
        #say "Updated breed to $breed";
    }

    return $self->dog->breed($breed)->then(sub{ shift->{'message'} // $self->_random() });
}

sub _random
{
    my $self = shift;

    return $self->dog->random()->then(sub{ shift->{'message'} })->catch(sub{ ":x: Sorry, couldn't find any dogs. Try again later!" });
}

1;
