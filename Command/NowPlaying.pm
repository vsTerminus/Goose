package Command::NowPlaying;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_nowplaying);

use Net::Discord;
use Net::Async::LastFM;
use DBI;
use Component::Database;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "NowPlaying";
my $access = 0; # Public
my $description = "Fetches Now Playing info from Last.FM and displays it in the channel";
my $pattern = '^(np|nowplaying|lastfm) ?(.*)$';
my $function = \&cmd_nowplaying;
my $usage = <<EOF;
```!nowplaying or !np or !lastfm```
    On first use the bot will ask you to use the set command (below) so it can associate your Discord ID to your Last.FM account.
    
    If the bot already knows your Last.FM account it will display your currently playing track from Last.FM

    !nowplaying, !np, and !lastfm are interchangeable.

```!lastfm set <Last.FM Username>```
    This tells the bot your Last.FM username so it can associate it to your Discord ID. 

    `Example:` !lastfm set vsTerminus

```!np <Last.FM Username>```
    The bot will look up the specified username instead of your own.

    `Example:` !nowplaying vsTerminus

```!np <\@DiscordUser>```
    If you specify a Discord username, the bot will look up that user's Last.FM account if it already has a Discord -> LastFM association stored for that user. If not, you will receive an error.

    `Example:` !nowplaying <\@231059560977137664>
EOF
############################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
    
    # Setting up this command module requires the Discord connection 
    # and Database info to be passed in so it can utilize them.
    # It also needs the last.fm api key.
    $self->{'bot'} = $params{'bot'};
    my $bot = $self->{'bot'}; 

    $self->{'discord'}  = $bot->discord;
    $self->{'db'}       = $bot->db;
    $self->{'api_key'}  = $params{'api_key'};
    $self->{'lastfm'}   = Net::Async::LastFM->new(api_key => $self->{'api_key'});
    $self->{'pattern'}  = $pattern;

    # Now register this command with the bot.

    $bot->add_command(
        'command'       => $command,
        'access'        => $access,
        'description'   => $description,
        'usage'         => $usage,
        'pattern'       => $pattern,
        'function'      => $function,
        'object'        => $self,
    );    

    return $self;
}

sub add_user
{
    my ($self, $discord_id, $discord_name, $lastfm_name) = @_;

    say localtime(time) . " Command::NowPlaying is adding a new mapping: $discord_id ($discord_name) -> $lastfm_name";

    my $db = $self->{'db'};
    
    my $sql = "INSERT INTO lastfm VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE discord_name = ?, lastfm_name = ?";
    $db->query($sql, $discord_id, $discord_name, $lastfm_name, $discord_name, $lastfm_name);
}

sub cmd_nowplaying
{
    my ($self, $channel, $author, $msg) = @_;

    my $user = $msg;
    my $pattern = $self->{'pattern'};
    $user =~ s/$pattern/$2/i;   # Strip the command out of the message, leaving just the args

    my $discord = $self->{'discord'};
    my $lastfm = $self->{'lastfm'};
    
    # First handle the set command.
    if ( $user =~ /^set (\w+)/i )
    {
        my $lastfm_name = $1;
        $lastfm_name =~ s/^\<(.*)\>$/$1/; # In case of stupidity, remove < > from the username.
        $self->add_user($author->{'id'}, $author->{'username'}, $lastfm_name);
        $discord->send_message( $channel, $author->{'username'} . ": I have updated your Last.FM username to `$lastfm_name`" );

        $self->nowplaying_by_username($channel, $author, $lastfm_name);
    }
    # Else, they are querying.
    elsif ( length $user )
    {
        # Are they querying a Discord Username or a Last.FM Username?
        if ( $user =~ /\<\@\!?(\d+)>/ )
        {
            # Discord user. $1 is the ID, $2 is the username.
            $self->nowplaying_by_id($channel, $author, $1);
        }
        else
        {
            $self->nowplaying_by_username($channel, $author, $user);
        }
    }
    else
    {
        $self->nowplaying_by_id($channel, $author, $author->{'id'});
    }
}

# The command function above is responsible for parsing the input and figuring out who to query (if anyone.)
# This sub does the actual work of finding someone's NowPlaying info and sending it to the Discord channel.
sub nowplaying_by_id
{
    my ($self, $channel, $author, $id) = @_;

    my $discord = $self->{'discord'};

    # Now, do we have a database entry for this user?
    my $db = $self->{'db'};
       
    my $sql = "SELECT lastfm_name FROM lastfm WHERE discord_id = ?";
    my $query = $db->query($sql, $id);
   
    # Yes, we have them.
    if ( my $row = $query->fetchrow_hashref )
    {
        my $lastfm_name = $row->{'lastfm_name'};
        $self->nowplaying_by_username($channel, $author, $row->{'lastfm_name'});
    }
    # We don't have them and they didn't specify a username. Ask for it.
    else
    {
        if ( $author->{'id'} == $id )   # Are they querying themselves?
        {
            $discord->send_message( $channel, "Sorry " . $author->{'username'} . ", I don't recognize you. Please tell me your Last.FM Username with the command: `!lastfm set <username>`." );
        }
        else # Querying someone else
        {
            $discord->send_message( $channel, "Sorry " . $author->{'username'} . ", I don't recognize that Discord user. You can try searching their Last.FM username instead if you know it." );
        }
    }
}

# This sub does NowPlaying by username.
sub nowplaying_by_username
{
    my ($self, $channel, $author, $username) = @_;
    my $discord = $self->{'discord'};
    my $lastfm = $self->{'lastfm'};
    $lastfm->nowplaying($username, "`artist - title (From album)`", sub {  
        $discord->send_message( $channel, $author->{'username'} . ": " . shift );
    });
}

1;
