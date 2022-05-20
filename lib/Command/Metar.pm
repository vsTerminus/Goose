package Command::Metar;
use feature 'say';
use utf8;

use Moo;
use strictures 2;
use Geo::ICAO qw(code2airport);
use DateTime;
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

# We can fill this with elements of the METAR that have already been decoded so we don't match them twice.
has decoded             => ( is => 'rw', default => sub { {} } );    


sub cmd_metar
{
    my ($self, $msg) = @_;

    my $channel_id = $msg->{'channel_id'};
    my $author = $msg->{'author'};

    my $args = $msg->{'content'};

    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $icao;
    my $decode = ( $args =~ s/^-?d(ecode)? ?// ) ? 1 : 0;
    say "args: $args";
    say "decode: $decode";

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
                my $decoded = "";

                if ( $decode )
                {
                    my @parts = split(' ',$sanitized);

                    my $padding = 0;
                    $padding = length $_ > $padding ? length $_ : $padding foreach (@parts);
                    say "Longest word in METAR is $padding characters long";
                    $padding+=2; # Add a little extra space beyond the longest word in the METAR

                    # We can rely on Airport, Datetime, and Wind always being present and in this order
                    # After that we have to start iterating and looking for patterns.
                    my $airport = code2airport($parts[0]);
                    my $datetime = _decode_time($parts[1]);
                    my $wind = _decode_wind($parts[2]);
                    if ( $parts[3] =~ /^(\d+)V(\d+)$/ )
                    {
                        $parts[2] .= " " . $parts[3];
                        splice @parts,3,1;
                    }

                    $decoded = "\n\n```\n" .
                    sprintf("%-${padding}s", $parts[0]) . " => $airport\n" .
                    sprintf("%-${padding}s", $parts[1]) . " => $datetime\n" .
                    sprintf("%-${padding}s", $parts[2]) . " => $wind\n";

                    # This is as far as we can go without iterating, because stuff starts getting optional
                    for ( my $i = 3; $i < scalar @parts; $i++ )
                    {
                        # Horizontal Visibility in Statute Miles or in Meters
                        if ( $parts[$i] =~ /^[0-9\/]+SM$/ or $parts[$i] =~ /^\d{4,}$/ )
                        {
                            $decoded .= sprintf("%-${padding}s", $parts[$i]) . " => " . _decode_visibility($parts[$i]) . "\n";
                        }
                        # Runway Visual Range (RVR)
                        elsif ( $parts[$i] =~ /^R[0-9LRC]+\/([MP]?\d+(V[MP]?\d+)?FT)\/?([DUN])?$/ )
                        {
                            $decoded .= sprintf("%-${padding}s", $parts[$i]) . " => " . _decode_rvr($parts[$i]) . "\n";
                        }
                        # Temperature and Dewpoint
                        elsif ( $parts[$i] =~ /^M?\d+\/M?\d+$/ )
                        {
                            $decoded .= sprintf("%-${padding}s", $parts[$i]) . " => " . _decode_temperature($parts[$i]) . "\n";
                        }
                        # Present Weather
                        elsif ( $parts[$i] =~ /^([+-])?(MI|BC|PR|DR|BL|SH|TS|FZ)?(DZ|RA|SN|SG|IC|PL|GR|GS|UP|BR|FG|FU|VA|DU|SA|HZ|PO|SQ|FC|SS|DS)+$/ )
                        {
                            $decoded .= sprintf("%-${padding}s", $parts[$i]) . " => " . _decode_present_weather($parts[$i]) . "\n";
                        }
                        # Cloud layers aloft
                        elsif ( $parts[$i] =~ /^(SKC|FEW|SCT|BKN|OVC|CLR|VV)/ )
                        {
                            $decoded .= sprintf("%-${padding}s", $parts[$i]) . " => " . _decode_layers_aloft($parts[$i]) . "\n";
                        }
                        # Altimeter / QNH
                        elsif ( $parts[$i] =~ /^(A|Q)\d{4}/ )
                        {
                            $decoded .= sprintf("%-${padding}s", $parts[$i]) . " => " . _decode_altimeter($parts[$i]) . "\n";
                        }
                    }

                    # Close the formatting block
                    $decoded .= "```\n";

                }

                $self->discord->send_message($channel_id, ":airplane_departure: " . $sanitized . $decoded);
            }
        })->catch(sub{
            my $json = shift;
            say Dumper($json);
            $self->discord->send_message($channel_id, ":x: Could not retrieve METAR for $icao");
        }
    );
}

sub _decode_altimeter
{
    my ($altpart) = @_;

    my $to_return = "";
    say "Altimeter / QNH";
    say $altpart;
    my $first = substr $altpart,0,1;
    $altpart = substr $altpart,1;

    if ( $first eq 'A' )
    {
        $to_return .= "Altimeter ";
        $to_return .= substr $altpart,0,2;
        $to_return .= ".";
        $to_return .= substr $altpart,2,2;
        $to_return .= " inches of mercury";
    }
    elsif ( $first eq 'Q' )
    {
        $to_return .= "QNH $altpart millibars";
    }

    return $to_return;
}

sub _decode_layers_aloft
{
    my ($cloudpart) = @_;

    my $to_return = "";

    my $clouds = {
        'SKC' => 'Sky Clear, no clouds',
        'FEW' => 'Few Clouds',
        'SCT' => 'Scattered Clouds',
        'BKN' => 'Broken Clouds',
        'OVC' => 'Overcast',
        'CLR' => 'Clear Below 10,000ft',
        'VV' => 'Vertical Visibility',
        'CB' => 'Cumulonimbus',
        'TCU' => 'Towering Cumulus',
        'CAVOK' => 'Cloud And Visibility OK'
    };

    my ($type, $height, $cv) = $cloudpart =~ /^(SKC|FEW|SCT|BKN|OVC|CLR|VV|CB|TCU|CAVOK)(\d{3})?(CB|TCU)?$/;

    $to_return .= $clouds->{$type} if exists $clouds->{$type};
    $height *= 100;
    $to_return .= " above ${height}ft";

    if ( defined $cv )
    {
        $to_return .= ", " . $clouds->{$cv} if exists $clouds->{$cv};
    }

    return ucfirst $to_return;
}

sub _decode_present_weather
{
    my ($weatherpart) = @_;

    my $weathers = {
        # Descriptors
        'MI' => 'Shallow',
        'BC' => 'Patches of ',
        'PR' => 'Partial',
        'DR' => 'Drifting',
        'BL' => 'Blowing',
        'SH' => 'Showers of ',
        'TS' => 'Thunderstorm',
        # Precipitation
        'DZ' => 'Drizzle',
        'RA' => 'Rain',
        'SN' => 'Snow',
        'SG' => 'Snow grains',
        'IC' => 'Ice crystals',
        'PL' => 'Ice pellets',
        'GR' => 'Hail',
        'GS' => 'Snow pellets',
        'UP' => 'Unknown precipitation',
        # Obscuration
        'BR' => 'Mist',
        'FG' => 'Fog',
        'FU' => 'Smoke',
        'VA' => 'Volcanic ash',
        'DU' => 'Dust',
        'SA' => 'Sand',
        'HZ' => 'Haze',
        # Other
        'PO' => 'Dust devils',
        'SQ' => 'Squalls',
        'FC' => 'Funnel cloud', # Note: +FC is a Tornado or Waterspout
        'SS' => 'Sandstorm', # darude
        'DS' => 'Duststorm',
    };
    say "Present weather";
    say $weatherpart;

    my $to_return = "";
    if ( $weatherpart =~ /^[+-]/ )
    {
        $to_return = substr($weatherpart, 0, 1);
        $weatherpart = substr $weatherpart, 1;
        $to_return eq '+' ? $to_return = 'Heavy ' : $to_return = 'Light ';
    }
    say $to_return;
    my $parts_counter = 0;
    while ( length $weatherpart >= 2 and $parts_counter < 10 )
    {
        my $next = substr $weatherpart, 0, 2;
        $weatherpart = substr $weatherpart, 2;
        say "Looking at: $next";
        say "Remaining weathers: $weatherpart";
        say $to_return;
        $to_return .= " and " if $parts_counter > 0;
        $to_return .= $weathers->{$next} if exists $weathers->{$next};
        $parts_counter++;
    }
    say ucfirst $to_return;

    return $to_return;
}

sub _decode_rvr
{
    my ($rvrpart) = @_;

    say "Runway visual range";
    my $to_return = "";

    my ($runway, $visibility) = $rvrpart =~ /^R([0-9LRC]+)\/([MP]?\d+(V[MP]?\d+)?FT)/;
    
    $runway =~ s/L/ Left/;
    $runway =~ s/C/ Center/;
    $runway =~ s/R/ Right/; 
    $to_return .= "Runway $runway visibility";
    say $to_return;


    if ( $visibility =~ /V/ )
    {
        $visibility =~ s/V/ft to /;
        $visibility = "variable from " . $visibility;
    }
    $visibility =~ s/P/>/g;
    $visibility =~ s/M/</g;
    $visibility =~ s/FT/ft/;

    $to_return .= " " . $visibility;

    say $to_return;

    if ( my $trend = $rvrpart =~ /\/([DUN])$/ )
    {
        if ( $trend eq 'D' ) { $trend = ', trending down' }
        elsif ( $trend eq 'U' ) { $trend = ', trending up' }
        elsif ( $trend eq 'N' ) { $trend = ', no trend' }
        else { $trend = "Unrecognized Trend ($trend)" }
        $to_return .= ' ' . $trend;
        say $to_return;
    }

    return $to_return;
}

sub _decode_time
{
    my ($timepart) = @_;

    my $day = substr $timepart,0,2;
    my $hour = substr $timepart,2,2;
    my $minute = substr $timepart,4,2;
    my $now = DateTime->now()->truncate( to => 'day');

    my $to_return = "Weather observed at " . $now->ymd . " $hour:$minute UTC";
}

sub _decode_wind
{
    my ($windpart) = @_;

    my $to_return;

    if ( $windpart eq '00000KT' )
    {
        $to_return = "Winds Calm";
    }
    else
    {
        my ($direction, $sustained, $g, $gust, $variable, $from, $to) = $windpart =~ /^(VRB|\d{3})(\d{2})(G(\d{2,3}))?KT ?((\d+)V(\d+))?$/;
        say "Direction: $direction";
        say "Sustained: $sustained";
        say "Gust: $gust" if $gust;

        if ( $direction eq 'VRB' and defined $variable )
        {
            $to_return = "Winds Variable from $from° to $to° at $sustained knots";
        }
        elsif ( $direction eq 'VRB' )
        {
            $to_return = "Winds Variable at $sustained knots";
        }
        else
        {
            $to_return = "Wind from $direction° at $sustained knots";
        }
        $to_return .= ", gusting to $gust knots" if $gust;
    }

    return $to_return;
}

sub _decode_visibility
{
    my ($visibpart) = @_;

    my $to_return;

    if ( $visibpart =~ /SM$/ )
    {
        say "Visibility in Statute Miles";
        if ( $visibpart eq '1SM' ) { $to_return = "Horizontal visibility is 1 statute mile" }
        else
        {
            $to_return = "Horizontal visibility is $visibpart";
            $to_return =~ s/SM$/ statute miles/;
        }
    }
    elsif ( $visibpart =~ /^\d{4,}$/ )
    {
        say "Visibility in meters";
        $to_return = "Horizontal visibility is ";
        if ( $visibpart eq '0000' ) { $to_return .= '<50 meters'}
        elsif ( $visibpart eq '9999' ) { $to_return .= '>10 kilometers' }
        else { $to_return = $visibpart . " meters" }
    }
    else
    {
        say "Unrecognized Visibility format";
        $to_return = "Unable to decode Horizontal Visibility";
    }
    return $to_return;
}

sub _decode_temperature
{
    my ($temppart) = @_;
    say "Temperature and Dew Point";

    my $to_return = "Temperature is " . $temppart;

    $to_return =~ s/M00/0/g;
    $to_return =~ s/M/Minus /g;
    $to_return =~ s/\//°C, Dew Point is /;
    $to_return .= "°C";
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
