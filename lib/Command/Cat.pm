package Command::Cat;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_cat);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has cat                 => ( is => 'lazy', builder => sub { shift->bot->cat } );

has name                => ( is => 'ro', default => 'Cat' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Pick a cat, any cat' );
has pattern             => ( is => 'ro', default => '^cat ?' );
has function            => ( is => 'ro', default => sub { \&cmd_cat } );
has usage               => ( is => 'ro', default => <<EOF
Look at this cat!

!cat
EOF
);

sub cmd_cat
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    $self->cat->random()->then(sub
        {
            my $json = shift;
            my $cat = $json->{'url'};
            $self->discord->send_message($channel_id, $cat);
        })->catch(sub{
            $self->discord->send_message($channel_id, ":x: Sorry, couldn't find any cats. Try again later!");
        }
    );
}

1;
