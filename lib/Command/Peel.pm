package Command::Peel;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Unicode::UCD 'charinfo';
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_peel);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has peeled              => ( is => 'lazy', builder => sub { shift->bot->peeled } );

has name                => ( is => 'ro', default => 'Peel' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Peel a Pokemon' );
has pattern             => ( is => 'ro', default => '^peel ?' );
has function            => ( is => 'ro', default => sub { \&cmd_peel } );
has usage               => ( is => 'ro', default => <<EOF
Peel a pokemon!

!peel <pokemon name>
eg, `!peel dustox`
EOF
);

sub cmd_peel
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    my $guild_id = $msg->{'guild_id'};
    my $guild = $self->discord->get_guild($guild_id);
    my $author = $msg->{'author'};
    my $message_id = $msg->{'id'};

    my $args = $msg->{'content'};
    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $reply = $self->usage;
    if ( defined $args and length $args > 1 and length $args < 50 )
    {
        $args =~ s/\\//; # Remove backslashes if someone escaped an emoji
        $args =~ s/\N{U+FE0F}//g; # Discord uses Variant Selector 16 ("Always Emoji") versions which the API doesn't recognize, so strip that extra character out.

        $self->bot->peeled->peel($args)->then(sub
        {
            my $json = shift;
            if ( exists $json->{'image_url'} )
            {
                $self->discord->send_message($channel_id, $json->{'image_url'});
            }
            else
            {
                $self->log->debug("Peeling pokemon '" . $args . "' failed: Pokemon not found" );
                $self->discord->send_message($channel_id, "Pokemon not found");
            }
        })->catch(sub
        {
            my $error = shift;
            $self->log->debug("Peeling pokemon '" . $args . "' failed. Error: " . $error->{'error'} );
            $self->discord->send_message($channel_id, "Error retrieving peeled pokemon ($error->{'error'})");
        });
    }
    else
    {
        $self->discord->send_message($channel_id, $reply);
    }
}

1;
