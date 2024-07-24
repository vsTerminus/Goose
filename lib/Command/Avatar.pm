package Command::Avatar;
use feature 'say';

use Moo;
use Data::Dumper;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_avatar);

has bot             => ( is => 'ro' );
has discord         => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log             => ( is => 'lazy', builder => sub { shift->bot->log } );

has name            => ( is => 'ro', default => 'Avatar' );
has access          => ( is => 'ro', default => 0 );
has description     => ( is => 'ro', default => "Display a user's avatar" );
has pattern         => ( is => 'ro', default => '^avatar ?' );
has function        => ( is => 'ro', default => sub { \&cmd_avatar } );
has usage           => ( is => 'ro', default => <<EOF
- `!avatar` - Display your own avatar
- `!avatar \@user` - Display someone else's avatar
EOF
);
    
sub cmd_avatar
{
    my ($self, $msg) = @_;

    my $discord = $self->discord;
    my $channel_id = $msg->{'channel_id'};
    my $guild_id = $msg->{'guild_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};
    my $pattern = $self->pattern;
    $args =~ s/$pattern//i;

    my $user_id = $author->{'id'};

    if ( $args =~ /\<\@\!?(\d+)\>/ )
    {
        $user_id = $1;
    }

    # No API calls, just access information passively stored by the library.
    my $guild_member = $discord->get_guild_member($guild_id, $user_id);

    unless ( defined $guild_member )
    {
        $discord->send_message($channel_id, ":x: I cannot find that user's avatar.");
        return;
    }

    my $guild_nick = $guild_member->nick if defined $guild_member;
    my $guild_avatar_id = $guild_member->avatar if defined $guild_member;
    my $global_name = $guild_member->{'user'}->{'global_name'};
    my $discriminator = $guild_member->{'user'}->{'discriminator'};
    my $user_name = $guild_member->{'user'}->{'username'};
    my $user_avatar_id = $guild_member->{'user'}->{'avatar'};

    my $avatar_url = Mojo::URL->new('https://cdn.discordapp.com/');
    $avatar_url->path( $guild_avatar_id ? 
        "/guilds/$guild_id/users/$user_id/avatars/$guild_avatar_id.png" : 
        "/avatars/$user_id/$user_avatar_id.png"
    );
    $avatar_url->query("size=1024");

    my $display_name;
        if      ( defined $guild_nick )     { $display_name = "$guild_nick (\@$user_name)"; }   # Server Nickname
        elsif   ( defined $global_name )    { $display_name = "$global_name (\@$user_name)"; }  # Global Name
        elsif   ( $discriminator > 0 )      { $display_name = "$user_name\#$discriminator"; }   # Bots
        else                                { $display_name = $user_name; }                     # Fallback

    my $avatar_message = {
        'content' => '',
        'embed' => {
            'title' => $display_name,
            'url' => $avatar_url->to_string,
            'type' => 'rich',
            'color' => 0xa0c0e6,
            'image' => {
                'url' => $avatar_url->to_string,
                'width' => 256,
                'height' => 256,
            }
        }
    };

    $discord->send_message($channel_id, $avatar_message);
}

1;
