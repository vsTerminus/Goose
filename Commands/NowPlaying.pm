package Commands::NowPlaying;

use v5.10;
use strict;
use warnings;

use Net::Discord;
use Net::Async::LastFM;
use DBI;
use Data::Dumper;

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    
    # Setting up this command module requires the Discord and Database connections to be passed in so it can utilize both.
    $self->{'discord'} = $params{'discord'};
    $self->{'dbh'} = $params{'dbh'};

    # We also need the Last.FM API Key to set up a Net::Async::LastFM object.
    $self->{'api_key'} = $params{'api_key'};
    $self->{'lastfm'} = Net::Async::LastFM->new(api_key => $self->{'api_key'});

    # This variable will be used for when the bot wants to have a "conversation" with the user to learn something, eg a username.
    $self->{'expectingreply'} = {};

    bless $self, $class;
    return $self;
}

# The main bot should call this for every module it has registered whenever a message comes in.
sub on_message_create
{
    my ($self, $channel, $author, $message) = @_;
    
    if ( $message =~ /^(np|nowplaying|lastfm) ?(\w*)/i)
    {
        cmd_nowplaying($self, $channel, $author, $2);
    }
    elsif ( exists $self->{'expectingreply'}->{$author->{'username'}} )
    {
        # If we are expecting a reply from a certain user, we can process it here.
        # The only reply this command expects would be a last.fm username.

        say "Adding " . $author->{'username'} . " -> " . $message;

        my $dbh = $self->{'dbh'};
        my $sql = "INSERT INTO lastfm VALUES (?, ?)";
        my $query = $dbh->prepare($sql);
        $query->execute($author->{'username'}, $message);

        delete $self->{'expectingreply'}->{$author->{'username'}};

        # Now run the query and show them what they are listening to.
        cmd_nowplaying($self, $channel, $author, $message);
    }
}

sub cmd_nowplaying
{
    my ($self, $channel, $author, $user) = @_;

    my $dbh = $self->{'dbh'};
    my $discord = $self->{'discord'};
    my $lastfm = $self->{'lastfm'};

    my $replyto = '<@' . $author->{'id'} . '>';
    my $toquery = length $user ? $user : $author->{'username'};
    
    # Now, do we have a database entry for this user?
    my $sql = "SELECT lastfm_name FROM lastfm WHERE discord_name = ?";
    my $query = $dbh->prepare($sql);
    $query->execute($toquery);

    if ( my $row = $query->fetchrow_hashref )
    {
        # Yes, we have them.
        my $lastfm_name = $row->{'lastfm_name'};
#        say "Found Database Entry. Discord user '$toquery' maps to LastFM user '$lastfm_name'";
        $toquery = $lastfm_name;

#        say "Querying Last.FM for user '$toquery'";

        my $np = $lastfm->nowplaying($toquery, "artist - title (From album)");
        $discord->send_message( $channel, "$replyto " . $np );
    }
    elsif ( length $user )
    {
        # No, we don't know who they are. We'll just query LastFM directly
#        say "Unrecognized user. Querying as-is.";
        my $np = $lastfm->nowplaying($user, "artist - title (From album)");
        $discord->send_message( $channel, "$replyto " . $np );
    }
    else
    {
#        say "Unrecognized user. Asking for Last.FM username";
        # They are requesting their own, but we don't have their username. Let's ask for it.
        $self->{'expectingreply'}->{$author->{'username'}} = 1; # This should tell the on_message_create function to look at the next message for a reply.
        $discord->send_message( $channel, "$replyto What is your Last.FM username?" );
    }
}

1;
