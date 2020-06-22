package Command::Hoggit;
use feature 'say';

use Moo;
use strictures 2;

use Mojo::Promise;
use Time::Duration;
use Data::Dumper;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_template);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy',  builder => sub { shift->bot->discord } );
has hoggit              => ( is => 'lazy',  builder => sub { shift->bot->hoggit } );
has log                 => ( is => 'lazy',  builder => sub { shift->bot->log } );
has db                  => ( is => 'lazy',  builder => sub { shift->bot->db } );

has timer_seconds       => ( is => 'ro',    default => 60 );
has timer_sub           => ( is => 'ro',    default => sub 
    { 
        my $self = shift;
        Mojo::IOLoop->recurring($self->timer_seconds => sub 
            { $self->_monitor_poll }
        ) 
    }
);

has name                => ( is => 'ro', default => 'Hoggit' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'View Hoggit DCS MP Server Status' );
has pattern             => ( is => 'ro', default => '^(hoggit|dcs) ?' );
has function            => ( is => 'ro', default => sub { \&cmd_hoggit } );
has usage               => ( is => 'ro', default => <<EOF
View Hoggit server status for GAW and PGAW

Basic Usage: !hoggit [GAW|PGAW]
EOF
);

sub cmd_hoggit
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};
    my $pattern = $self->pattern;
    $args =~ s/$pattern//;

    my $json;

    if ( length $args )
    {
        if ( lc $args eq 'gaw' or lc $args eq 'pgaw' )
        {
            $self->_get_summary_p($args)->then(sub {
                    $self->discord->send_message($channel, shift);
            });
        }
        else
        {
            $self->discord->send_message($channel, 'Accepted servers are "GAW" and "PGAW"');
        }
    }
    else # Do both.
    {
        my @promises = map { $self->_get_summary_p($_) } ('GAW', 'PGAW');

        Mojo::Promise->all(@promises)->then(sub {
                my $summary = '';
                $summary .= $_->[0] foreach @_;
                $self->discord->send_message($channel, $summary);
        });
    }
}

# Get server info hash and return a Discord formatted summary.
sub _get_summary_p
{
    my ($self, $server) = @_;

    return unless lc $server eq 'gaw' or lc $server eq 'pgaw';

    my $promise = Mojo::Promise->new;

    $self->hoggit->server_info_p($server)->then(sub
        {
            my $json = shift;

            my $phase = 0;
            foreach my $airport ( @{$json->{'airports'}} )
            {
                my $name = $airport->{'Name'};
                my $blue = $airport->{'CoalitionID'} == 2 ? 1 : 0;

                $phase = 1 if $name eq 'Al Minhad AB' and $blue and $phase < 1;
                $phase = 2 if $name eq 'Khasab' and $blue and $phase < 2;
                $phase = 3 if $name eq 'Qeshm Island' and $blue and $phase < 3;
                $phase = 4 if $name eq 'Bandar Abbas Intl' and $blue and $phase < 4;
            }

            my @pgaw_phases = (
                'Fresh Map',
                'Strike the Peninsula - Al Minhad is Blue',
                'Crossing the Strait - Khasab is Blue',
                'Final Push - Qeshm is Blue',
                'Game Over - Bandar is Blue'
            );

            my $summary = ':desktop: ' . $json->{'missionName'} . "\n"
                . '```autohotkey' . "\n" # Autohotkey syntax highlighting works well here.
                . 'Players: ' . $json->{'players'} . '/' . $json->{'maxPlayers'} . "\n"
                . 'Restart: ' . duration(14400 - $json->{'uptime'}) . "\n"
                . 'Weather: ' . $json->{'wx'}{'name'} . '. METAR ' . $json->{'metar'} . "\n";
            $summary.= 'Phase:   ' . $pgaw_phases[$phase] . "\n" if lc $server eq 'pgaw';
            $summary .= '```' . "\n";

            $promise->resolve($summary);
        }
    );
}

# This sub is called on a timer
# It checks airport ownership to see if anything has changed since last time
# If there have been changes it writes a message to any channels found in the hoggit_channels table.
# Airfield ownership is stored in hoggit_airports
# 
# hoggit_channels has only an 'id' column
# hoggit_airports has 'id', 'name', and 'coalition'.
sub _monitor_poll
{
    my ($self) = @_;

    my @channels = @{$self->_channels};

    my $airports = $self->_airports;

    my $message;

    # This can be a foreach later that does both servers
    # But right now I only care about PGAW so I'm hard coding it.
    $self->hoggit->server_info_p('PGAW')->then(sub
        {
            my $json = shift;

            foreach my $airport ( @{$json->{'airports'}} )
            {
                my $name = $airport->{'Name'};
                my $id = $airport->{'Id'};
                my $coalition = _coalitions($airport->{'CoalitionID'});


                if ( exists $airports->{$id} and lc $coalition ne lc $airports->{$id}{'coalition'} )
                {
                    $self->_set_airport($id, $name, $coalition);

                    $message .= ':airplane: ' . $name . ' has been captured' . "\n" if lc $coalition eq 'blue';     
                    #say $message;
                }
            }

            if ( length $message > 0 )
            {
                foreach (@channels)
                {
                    my $channel = $_->[0];
                    say "Channel: " . $channel;

                    if ( my $hook = $self->bot->has_webhook($channel) )
                    {
                        my $hookparam = {
                            'content' => $message,
                            'username' => 'Persion Gulf At War',
                            'avatar_url' => 'https://i.imgur.com/emGf71B.png', # Hoggit Coat of Arms
                        };

                        $self->discord->send_webhook($channel, $hook, $hookparam);
                    }
                    else
                    {
                        $self->discord->send_message($channel, $message);
                    }
                }
            }
        }
    );
    
}

sub _coalitions
{
    my $in = shift;

    return 'invalid' unless $in >=0 and $in <= 2;

    my @coalitions = ('yellow', 'red', 'blue');

    return $coalitions[$in];
}

sub _delete_channel
{
    my ($self, $channel) = @_;

    if ( $channel =~ /^\d+$/ )
    {
        $self->db->do("DELETE FROM hoggit_channels WHERE id = ?", $channel);
    }
}

sub _add_channel
{
    my ($self, $channel) = @_;

    if ( $channel =~ /^\d+$/ )
    {
        $self->db->do("INSERT INTO hoggit_channels VALUES ( ? )", $channel);
    }
}

sub _set_airport
{
    my ($self, $id, $name, $coalition) = @_;

    return unless defined $id and $id =~ /^\d+$/ and defined $name and length $name > 0 and defined $coalition and $coalition =~ /^red|blue|yellow$/;

    my $query = "INSERT INTO hoggit_airports VALUES ( ?, ?, ? ) ON DUPLICATE KEY UPDATE coalition = ?";
    $self->db->do($query, $id, $name, $coalition, $coalition);
}

sub _channels
{
    my $self = shift;
    my $query = "SELECT id FROM hoggit_channels";
    my $dbh = $self->db->do($query);
    return $dbh->fetchall_arrayref([0]);
}

sub _airports
{
    my $self = shift;
    my $query = "SELECT * FROM hoggit_airports";
    my $dbh = $self->db->do($query);
    return $dbh->fetchall_hashref('id');
}

1;
