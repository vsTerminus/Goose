package Commands::NowPlaying;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_nowplaying);

use Net::Discord;
use Net::Async::LastFM;
use DBI;
use Data::Dumper;

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    
    # Setting up this command module requires the Discord connection 
    # and Database info to be passed in so it can utilize them.
    # It also needs the last.fm api key.
    $self->{'discord'} = $params{'discord'};
    $self->{'db_config'} = $params{'db_config'};
    $self->{'dbh'} = undef;
    $self->{'api_key'} = $params{'api_key'};
    $self->{'lastfm'} = Net::Async::LastFM->new(api_key => $self->{'api_key'});

    bless $self, $class;

    # Now register this command with the bot.
    $self->{'bot'} = $params{'bot'};
    my $bot = $self->{'bot'};

    my $command = "NowPlaying";
    my $description = "Fetches Now Playing info from Last.FM and displays it in the channel";
    my $usage = <<EOF;
Basic usage: !nowplaying or !lastfm or !np

On first use, the bot will ask for your username. Repeat the command but this time also give it your Last.FM username.
The bot will remember and you won't have to specify anymore.
You can change your username with !np set <new username here> (eg, !np set xXxEdgelord69420xXx)

You can also pass a username, optionally as a Discord username mention.
Eg, !np vsTerminus and !np \@vsTerminus will both work.
EOF
    my $pattern = '^(np|nowplaying|lastfm) ?(.*)$';
    $self->{'pattern'} = $pattern;
    my $function = \&cmd_nowplaying;

    $bot->add_command(
        'command'       => $command,
        'description'   => $description,
        'usage'         => $usage,
        'pattern'       => $pattern,
        'function'      => $function,
        'object'        => $self,
    );    

    return $self;
}

sub db_connect
{
    my $self = shift;

    # MySQL Connection
    my $dsn = 'DBI:' . $self->{'db_config'}->{'type'} . ':' . $self->{'db_config'}{'name'};
    my $user = $self->{'db_config'}->{'user'};
    my $pass = $self->{'db_config'}->{'pass'};

    my $dbh = DBI->connect_cached($dsn, $user, $pass) or die "Could not connect to database\n$@";

    $self->{'dbh'} = $dbh;
    return $dbh;
}

sub add_user
{
    my ($self, $discord_name, $lastfm_name) = @_;

#    say localtime(time) . " Commands::NowPlaying is adding a new mapping: $discord_name -> $lastfm_name";

    my $dbh = db_connect($self);
    
    my $sql = "INSERT INTO lastfm VALUES (?, ?) ON DUPLICATE KEY UPDATE lastfm_name = ?";
    my $query = $dbh->prepare($sql);
    $query->execute($discord_name, $lastfm_name, $lastfm_name);
}

sub cmd_nowplaying
{
    my ($self, $channel, $author, $msg) = @_;

    my $user = $msg;
    my $pattern = $self->{'pattern'};
    $user =~ s/$pattern/$2/i;

    my $dbh = db_connect($self); # Connect if necessary
    my $discord = $self->{'discord'};
    my $lastfm = $self->{'lastfm'};

    my $replyto = '<@' . $author->{'id'} . '>';
    my $toquery = length $user ? $user : $author->{'username'};
    
    # First handle the set command.
    if ( $user =~ /^set (\w+)/i )
    {
        add_user($self, $author->{'username'}, $1);
        $discord->send_message( $channel, "$replyto I have updated your Last.FM username to '$1'" );

        my $np = $lastfm->nowplaying($1, "artist - title (From album)");
        $discord->send_message( $channel, "$replyto " . $np );
    }
    # Else, they are querying.
    else
    {
   
        # Now, do we have a database entry for this user?
       
        my $sql = "SELECT lastfm_name FROM lastfm WHERE discord_name = ?";
        my $query = $dbh->prepare($sql);
        $query->execute($toquery);
    
        # Yes, we have them.
        if ( my $row = $query->fetchrow_hashref )
        {
            my $lastfm_name = $row->{'lastfm_name'};
            $toquery = $lastfm_name;
    
            my $np = $lastfm->nowplaying($toquery, "artist - title (From album)");
            $discord->send_message( $channel, "$replyto " . $np );
        }
        # We don't have them, but they gave us (hopefully) their username.
        elsif ( length $user )
        {
            add_user($self, $author->{'username'}, $user);  # Add the new mapping.
            $discord->send_message( $channel, "$replyto Thanks. I will remember you as '$user'. You can change this any time with 'lastfm set <new username>'" );
            my $np = $lastfm->nowplaying($user, "artist - title (From album)");
            $discord->send_message( $channel, "$replyto " . $np );
        }
        # We don't have them and they didn't specify a username. Ask for it.
        else
        {
            $discord->send_message( $channel, "$replyto Sorry, I don't recognize you yet. Please try again, and this time include your Last.FM username." );
        }
    }
}

1;
