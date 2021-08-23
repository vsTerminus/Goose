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
has db                  => ( is => 'lazy', builder => sub { shift->bot->db } );
has cache               => ( is => 'rw', default => sub { {} } );

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
    my $author = $msg->{'author'};

    my $args = $msg->{'content'};

    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $icao;

    # Set a location
    if ( $args =~ /^set / )
    {
        my $name = 'default';
        if ( $args =~ /set ([a-zA-Z0-9]{3,4})( "(.*)")?$/ )
        {
            $icao = $1;
            $name = $3 // 'default';
        }
        say "ICAO => Name: $icao => $name";

        $self->add_user($author->{'id'}, $author->{'username'}, $icao, $name);
        $self->discord->send_message( $channel_id, "Updated metar mapping: $name => $icao" );
    }
    else
    {
        say "Checking for stored location. Args: '$args'";
        # Check if this is a stored location first.

        if ( $icao = $self->get_stored_location($author, $args) )
        {
            say "Stored location found";
            $self->bot->log->debug('[Metar.pm] [cmd_metar] Found stored location for user: ' . $author->{'id'} . ' => ' . $icao);
        }
        elsif ( $args =~ /\b([a-zA-Z0-9]{3,4})\b/ )
        {
            say "Matching args for icao pattern";
            $icao = $1;
            say "ICAO: $icao";
        }
        elsif ( length $args > 0 )
        {
            say "$args is not a valid ICAO";
            $self->discord->send_message($channel_id, ":x: Missing or invalid ICAO code. Try searching <https://www.world-airport-codes.com/>.");
            return;
        }
        else
        {
            say "I don't have a default ICAO on file for you. Try `!metar set <ICAO code>` eg, `!metar set KJFK`";
            $self->discord->send_message($channel_id, ":x: I don't have a default ICAO on file for you. Try `!metar set <ICAO code>` eg, `!metar set KJFK`\nYou can try searching <https://www.world-airport-codes.com/> for your nearest airport.");
            return;
        }
    }


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

sub add_user
{
    my ($self, $discord_id, $discord_name, $icao, $icao_name) = @_;

    $icao_name = 'default' unless defined $icao_name;
    $self->bot->log->debug("[Metar.pm] [add_user] Adding a new mapping: $discord_id ($discord_name) -> $icao ($icao_name)");

    my $db = $self->db;

    my $sql = "INSERT INTO metar VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE discord_name = ?, icao = ?, name = ?";
    $db->query($sql, $discord_id, $discord_name, $icao, $icao_name, $discord_name, $icao, $icao_name);

    # Also cache this in memory for faster lookups
    $self->cache->{'icao'}{$discord_id}{$icao_name} = $icao;
}

sub get_stored_location
{
    my ($self, $author, $name) = @_;

    $name = (defined $name and length $name > 0) ? lc $name : 'default';

    # 1 - Check Cache    
    my $cached = $self->cache->{'icao'}{$author->{'id'}}{$name};

    if ( defined $cached and length $cached > 0 )
    {
        return $cached;
    }
    # 2 - Check Database
    else
    {
        my $db = $self->db;
   
        my $sql = "SELECT icao FROM metar WHERE discord_id = ? AND name = ?";
        $name = 'default' unless defined $name;
        my $query = $db->query($sql, $author->{'id'}, $name);

        # Yes, we have them.
        if ( my $row = $query->fetchrow_hashref )
        {
            $self->cache->{'icao'}{$author->{'id'}}{$name} = $row->{'icao'};  # Cache this so we don't need to hit the DB all the time.
            $self->bot->log->debug("[Metar.pm] [get_stored_location] Found stored DB location for " . $author->{'id'} . ": " . $row->{'icao'});
            return $row->{'icao'};
        }
    }
    # 3 - We don't have a stored location for this user.
    return undef;
}

1;
