package Command::Metar;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_metar);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has avwx                => ( is => 'lazy', builder => sub { shift->bot->avwx } );

has name                => ( is => 'ro', default => 'Metar' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Opaque weather information for nerds' );
has pattern             => ( is => 'ro', default => '^metar ?' );
has function            => ( is => 'ro', default => sub { \&cmd_metar } );
has usage               => ( is => 'ro', default => <<EOF
Get the weather in METAR format for any airport by ICAO.

!metar UWUU
EOF
);

sub cmd_metar
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
 
    my $args = $msg->{'content'};
    unless (defined $args and $args =~ /\b[a-zA-Z0-9]{3,4}$/)
    {
        $self->discord->send_message($channel_id, ":x: Missing or invalid ICAO code. Try searching <https://www.world-airport-codes.com/>.");
        return;
    }

    my $icao = $args;
    $icao =~ s/^.*(\b[a-zA-Z0-9]{3,4}$)/$1/;

    $self->avwx->metar($icao)->then(sub
        {
            my $json = shift;
            if ( $json->{'error'} )
            {
                $self->discord->send_message($channel_id, ":x: " . $json->error->{'message'});
            }
            elsif ( !defined $json->{'sanitized'} )
            {
                $self->discord->send_message($channel_id, ":x: Could not retrieve METAR for $icao");
            }
            else
            {
                my $sanitized = $json->{'sanitized'};
                $self->discord->send_message($channel_id, ":airplane_departure: " . $sanitized);
            }
        })->catch(sub{
            my $json = shift;
            say Dumper($json);
            $self->discord->send_message($channel_id, ":x: Could not retrieve METAR for $icao");
        }
    );
}

1;
