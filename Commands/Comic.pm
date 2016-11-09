package Commands::Comic;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_comic);

use Net::Discord;
use Bot::Goose;
use Mojo::UserAgent;
use DBI;
use Data::Dumper;

###########################################################################################
# Command Info
my $command = "Comic";
my $description = "Displays a comic from the Cyanide & Happiness Random Comic Generator";
my $pattern = '^(rc|comic) ?(.*)$';
my $function = \&cmd_comic;
my $usage = <<EOF;
```!comic (or !rc)```
    Display a randomly generated comic

```!comic <panel number(s)>```
    Display a random comic, keeping certain panel(s) from the previous comic:
    
    __Examples:__

        `!comic 1`   (Keeps the first panel from the last comic)
        `!comic 23`  (Keeps the second and third panels)

```!comic order <panel numbers>```
    Re-order the panels from the previous comic.

    __Examples:__

        `!comic order 312`   (Third panel first)
        `!comic order 321`   (Reverse order)
    
    This likely will not work due to restrictions on the Comic Generator.

```!comic save [URL]```
    Save a comic you found particularly funny.

    If you provide a URL the bot will save the specified comic. If not, the bot will save the last comic that was generated in this channel.

    __Examples:__

        `!comic save http://files.explosm.net/rcg/whqcdlmfx.png` (Saves that comic)
        `!comic save` (Saves the last comic)

```!comic saved [ID]```
    Displays a previously saved comic. If you pass it a numeric ID it will display that comic (if it exists), otherwise it will select at random.

    __Examples:__

        `!comic saved`  (Display a random saved comic)
        `!comic saved 1` (Display the first saved comic)

EOF
###########################################################################################

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
     
    # Setting up this command module requires the Discord connection 
    $self->{'bot'} = $params{'bot'};
    my $bot = $self->{'bot'}; 
    
    $self->{'discord'} = $bot->discord;
    $self->{'pattern'} = $pattern;

    # Register our command with the bot
    $bot->add_command(
        'command'       => $command,
        'description'   => $description,
        'usage'         => $usage,
        'pattern'       => $pattern,
        'function'      => $function,
        'object'        => $self,
    );
    
    my $ua = Mojo::UserAgent->new;
    $ua->inactivity_timeout(5);
    $ua->max_connections(0);
    $self->{'ua'} = $ua;
    
    return $self;
}

sub cmd_comic
{
    my ($self, $channel, $author, $msg) = @_;

    my $ua = $self->{'ua'};

    my $args = $msg;
    my $pattern = $self->{'pattern'};
    $args =~ s/$pattern/$2/i;

    my $discord = $self->{'discord'};
    my $replyto = '<@' . $author->{'id'} . '>';
    my $comic;
    my $vars = "/?";

    # We can do some different things with this, like swapping.
    if ( defined $self->{$channel}{'lastcomic'} and $args =~ /^order (\d{3})$/i  )
    {
        my @order = split('', $1);
        my @parts = $self->{$channel}{'lastcomic'} =~ /(...)(...)(...)/;
        unshift @parts, "spacer";
        
        $comic = 'http://files.explosm.net/rcg/' . $parts[$order[0]] . $parts[$order[1]] . $parts[$order[2]] . '.png';

        $self->send_comic($channel, $comic);
    }
    elsif ( $args =~ /^save( (.+))?$/i )
    {
        my $comic = $2;
        
        if ( length $comic == 0 and defined $self->{$channel}{'lastcomic'} )
        {
            my $slug = $self->{$channel}{'lastcomic'};
            my $id = $self->add_comic($channel, $author, $slug);

            $discord->send_message($channel, "Comic saved! (`ID: $id`)");
        }
        elsif (defined $comic and $comic =~ /^(http\:\/\/files.explosm.net\/rcg\/)?([a-z]{9})(.png)?$/i )
        {
            my $slug = $2;
            my $id = $self->add_comic($channel, $author, $slug);

            $discord->send_message($channel, "Comic saved! (`ID: $id`)");
        }
        else
        {
            $discord->send_message($channel, "Could not save comic. Please see `!help comic` for syntax.");
        }
    }
    elsif ( $args =~ /^saved( (\d+))?$/i )
    {
        if ( defined $2 and length $2 > 0 )
        {
            my ($id, $comic) = split(',', $self->get_saved_by_id($2));

            $discord->send_message($channel, "$comic (`ID: $id`)");
        }
        else
        {
            my ($id, $comic) = split(',', $self->get_random_saved());

            $discord->send_message($channel, "$comic (`ID: $id`)");
        }
    }
    else
    {
        if ( defined $self->{$channel}{'lastcomic'} and $args =~ /(keep )?([123]{1,3})/i )
        {   
            my @keep = split('', $2);
            my @parts = $self->{$channel}{'lastcomic'} =~ /(...)(...)(...)/;
            unshift @parts, "spacer";

            foreach my $num (@keep)
            {
                $vars .= "$num=" . $parts[$num] . '&';
            }
        }

        my $url = 'http://explosm.net/rcg';
        $url .= $vars if length $vars > 2;

        $ua->get($url => sub {
            my ($ua, $tx) = @_;
            my $html = $tx->res->body;

            if ( $html =~ /src=\"\/\/(files.explosm.net\/rcg\/(.*).png)\"/ )
            {
                $comic = "http://" . $1;
            }
            
            $self->send_comic($channel, $comic);
        });
    }

}

sub send_comic
{
    my ($self, $channel, $comic) = @_;
    my $discord = $self->{'discord'};

    if ( defined $comic ) 
    {
        my $slug = substr($comic,-13,9);
        say "Lastcomic Slug: $slug";
        $self->{$channel}{'lastcomic'} = $slug;
    }
    else
    {
        $comic = "Unable to retrieve comic. Please try again."; # Else, error message
    }

    $discord->send_message($channel, $comic);
}

sub add_comic
{
    my ($self, $channel, $author, $slug) = @_;

    my $bot = $self->{'bot'};
    my $db = $bot->{'db'};

    my $sql = "INSERT INTO comics (slug, guild_id, channel_id, user_id, user_name) values (?, ?, ?, ?, ?)";
    my $guild = $bot->get_guild_by_channel($channel);
    say "SQL: $sql";
    say "Slug: $slug";
    say "Guild: $guild";
    say "Channel: $channel";
    say "Author ID: " . $author->{'id'};
    say "Author Name: " . $author->{'username'};
    $db->query($sql, $slug, $guild, $channel, $author->{'id'}, $author->{'username'});

    say "Querying ID for slug $slug";
    $sql = "SELECT id FROM comics WHERE slug=?";
    my $query = $db->query($sql, $slug);
    my @row = $query->fetchrow_array;
    my $id = $row[0];

    return $id;
}

sub get_saved_by_id
{
    my ($self, $id) = @_;

    my $bot = $self->{'bot'};
    my $db = $bot->db;

    my $sql = "SELECT slug FROM comics WHERE id=?";
    my $query = $db->query($sql, $id);
    my @row = $query->fetchrow_array;
    my $slug = $row[0];
   
    if ( $slug =~ /^[a-zA-Z]{9}$/ )
    {
        return $id . ',http://files.explosm.net/rcg/' . $slug . '.png';
    }
    else
    {
        return $self->get_random_saved();
    }
}

sub get_random_saved
{
    my $self = shift;
    my $db = $self->{'bot'}->db;

    my $sql = "SELECT count(id) FROM comics";
    my $query = $db->query($sql);
    my @row = $query->fetchrow_array;
    my $count = $row[0];

    my $num = int(rand($count))+1;

    return $self->get_saved_by_id($num);
}

1;
