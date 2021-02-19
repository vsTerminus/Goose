package Command::Role;
use feature 'say';

use Moo;
use strictures 2;

use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Data::Dumper;

use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_template);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );
has db                  => ( is => 'lazy', builder => sub { shift->bot->db } );
has channels            => ( is => 'lazy', builder => sub {
    my $self = shift;
    my $query = "SELECT * from role_channels";
    my $dbh = $self->db->do($query);
    $dbh = fetchall_hashref();
    say Dumper($dbh);
    return $dbh
});

has name                => ( is => 'ro', default => 'Role Manager' );
has access              => ( is => 'ro', default => 1 ); # 0 = Public, 1 = Bot Owner Only, 2 = Server Owner Only
has description         => ( is => 'ro', default => 'Manage user self-serve roles' );
has pattern             => ( is => 'ro', default => '^roles? ?' );
has function            => ( is => 'ro', default => sub { \&cmd_role } );
has usage               => ( is => 'ro', default => <<EOF
Use this command to manage user-self-serve roles in your server.

Link emojis to roles, set channel(s) to watch, and then go post your message telling users to react with specific emojis to opt in or out of roles on your server!

Connect an emoji to a role:
`!role link :mega: \@announcements`
`!role link :flag_ca: \@canadians`
`!role link :eggplant: \@hornyjail`

This works with custom emoji as well, as long as it's from your server (so the bot can see and use it).

Disconnect an emoji from a role:
`!role unlink :mega:`
`!role unlink :flag_ca:`
`!role unlink :eggplant:`

List currently configured roles. (Any of these will work):
`!role list`
`!role info`
`!role status`
`!roles`

Post a role opt-in message:
`!role post Literally any message here, just make sure you include the :emojis: that you want people to use so the bot knows which ones to auto-react with.`
eg, `!role post React with :mega: to receive server announcements.`
You can include up to 10 emojis per message. Any more will be ignored.

EOF
);

has on_message_reaction_add => ( is => 'ro', default => sub 
{ 
    my $self = shift;
    $self->discord->gw->on('MESSAGE_REACTION_ADD' => sub
    {
        my ($gw, $hash) = @_;
        my $message_id = $hash->{'message_id'};
        my $guild_id = $hash->{'guild_id'};
        my $channel_id = $hash->{'channel_id'};
        my $user_id = $hash->{'user_id'};
        my $emoji_str = _create_emoji_str($hash);

        if ( $self->_is_actionable($guild_id, $message_id, $user_id, $emoji_str) )
        {
            $self->_add_role($guild_id, $emoji_str, $user_id);
            $self->log->debug('[on_message_reaction_add] Added role <details here>');
        }
        
    })
});

has on_message_reaction_remove => ( is => 'ro', default => sub 
{ 
    my $self = shift;
    $self->discord->gw->on('MESSAGE_REACTION_REMOVE' => sub
    {
        my ($gw, $hash) = @_;
        my $guild_id = $hash->{'guild_id'};
        my $channel_id = $hash->{'channel_id'};
        my $emoji_str = _create_emoji_str($hash);
        my $user_id = $hash->{'user_id'};
        
        if ( $self->_is_actionable($guild_id, $channel_id, $user_id, $emoji_str) )
        {
            $self->_remove_role($guild_id, $emoji_str, $user_id);
            $self->log->debug('[on_message_reaction_remove] Removed role <details here>');
        }
    })
});

sub cmd_role
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
    
    #$self->bot->log->debug('[Template.pm] [cmd_template] ' . Data::Dumper->Dump([$msg], ['msg']));
    #say Data::Dumper->Dump([$args], ['args']);

    # The if / else blocks make this function too long and ugly, but I really didn't feel like breaking it out. Sorry.


    #### LIST
    my $reply = "Configured Self Serve Roles:\n";
    say "Args: '" . $args . "'";
    if ( $args =~ /^(list|info|status)?$/i )
    {
        say "List roles!";
        my $query = 'select * from roles where guild_id = ?';
        my $dbh = $self->db->do($query, $guild_id);

        my $rows = $dbh->fetchall_arrayref();

        if ( scalar @$rows )
        {
            foreach my $row (@$rows)
            {
                say Dumper($row);
                my $emoji = _decode_emoji($row->[1]);


                say $emoji . '=> <@&' . $row->[2] . ">";
                $reply .= $emoji . ' => <@&' . $row->[2] . ">\n";

                # John is going to add 400 roles to his server just to see what happens if it hits max message length...
                # So every 500 characters we'll send whatever we have and keep going.
                if ( length $reply > 500 )
                {
                    $self->discord->send_message($channel_id, $reply);
                    $reply = "";
                }
            }
            $self->discord->send_message($channel_id, $reply) if length $reply > 0; # Don't send an empty reply in case we hit 500 characters on the final linked role.
        }
        else
        {
            $reply = "No self-serve roles configured for this server. Try `!help role` to learn how."
        }
    }

    #### LINK
    elsif ( $args =~ /^link /i )
    {
        my ($link, $emoji_str, $role_str) = split ' ', $args;

        # Check syntax
        unless ( length $emoji_str and length $role_str ) { $self->discord->send_message($channel_id, 'Usage: `!role link :emoji: @role`'); return undef }

        my $role_id = $role_str; $role_id =~ s/[^0-9]//g;

        # Check role exists on this server
        unless ( exists $guild->roles->{$role_id} ) { $self->discord->send_message($channel_id, ':x: That role does not exist on this server.'); return undef }

        # Check the emoji exists on this server
        unless ( $self->_emoji_is_local($guild, $emoji_str) ) { $self->discord->send_message($channel_id, ':x: `' . $emoji_str . '` must be available on this server for me to use it.'); return undef }

        # Assuming we made it this far, the data should be OK.
        my $query = "INSERT INTO roles VALUES ( ?, ?, ? ) ON DUPLICATE KEY UPDATE role_id = ?";
        $self->db->do($query, $guild_id, _encode_emoji($emoji_str), $role_id, $role_id);
        #$self->discord->send_message($channel_id, ':white_check_mark: ' . $emoji_str . ' => ' . $role_str);

        $self->discord->send_ack($channel_id, $message_id);
    }


    #### UNLINK
    elsif ( $args =~ /^unlink (.*)$/i )
    {
        my $emoji_str = $1;

        unless ( length $emoji_str ) { $self->discord->send_message($channel_id, '`Usage: !role unlink :emoji:`'); return undef }        
        #unless ( $self->_emoji_is_local($guild, $emoji_str) ) { $self->discord->send_message($channel_id, ':x: `' . $emoji_str . '` must be available on this server for me to use it.'); return undef }

        my $query = "DELETE FROM roles WHERE guild_id = ? AND emoji_str = ?";
        my $dbh = $self->db->do($query, $guild_id, _encode_emoji($emoji_str));

        $self->discord->send_ack($channel_id, $message_id);
    }


    #### POST
    elsif ( $args =~ /^post /i )
    {
        $args =~ s/^post //i;

        my $query = "INSERT INTO role_posts VALUES ( ?, ?, ? )";
        $self->db->do($query, $guild_id, $channel_id, $message_id);

        $self->discord->delete_message($channel_id, $message_id);

        $self->discord->send_message($channel_id, $args);

        # Find emojis in the message :|
        # Just loop through the defined emojis and match for them?
        # Add each one as a reaction
    }
}

sub _emoji_is_local
{
    my ($self, $guild, $emoji_str) = @_;

    # If custom emoji, make sure it exists on this server
    if ( $emoji_str =~ /\:(\d+)\>$/ )
    {
        my $emoji_id = $1;
        return ( exists $guild->emojis->{$emoji_id} );
    }
    return 1;
}

sub _encode_emoji
{
    my ($emoji) = @_;

    return $emoji if $emoji =~ /\:/; # Ignore custom emoji

    return unpack 'H*', encode_utf8($emoji);
}

sub _decode_emoji
{
    my ($octets) = @_;

    return $octets if $octets =~ /\:/; # Ignore custom emoji

    return decode_utf8( pack 'H*', $octets );
}

sub _create_emoji_str
{
    my $hash = shift;

    # Emoji is either just the 'name' field if a utf8 character
    my $emoji_str = $hash->{'emoji'}{'name'};
    # or a custom emoji with a name and an id
    if ( defined $hash->{'emoji'}{'id'} and $hash->{'emoji'}{'id'} =~ /^\d+$/ )
    {
        $emoji_str = '<:' . $hash->{'emoji'}{'name'} . ':' . $hash->{'emoji'}{'id'} . '>';
    }
    return $emoji_str;
}

sub _is_actionable
{
    my ($self, $guild_id, $message_id, $user_id, $emoji_str) = @_;

    return ( 
        $self->bot->user_id != $user_id                         # Ignore our own reactions
        and $self->_bot_can_manage_roles($guild_id)             # Do we have the MANAGE_ROLES permission?
        and $self->_is_watched_message($guild_id, $message_id)  # Is this a channel we are watching on this server?
        and $self->_is_watched_emoji($guild_id, $emoji_str)     # Is this an emoji configured with a role on this server?
    );
}

sub _is_watched_message
{
    my ($self, $guild_id, $message_id) = @_;

    my $query = "SELECT * from role_posts where guild_id = ? and message_id = ?";
    my $dbh = $self->db->do($query, $guild_id, $message_id);
    my $rows = $dbh->fetchall_arrayref();
    return scalar @$rows;
}

sub _is_watched_emoji
{
    my ($self, $guild_id, $emoji_str) = @_;

    my $query = "SELECT * from roles where guild_id = ? and emoji_str = ?";
    my $dbh = $self->db->do($query, $guild_id, _encode_emoji($emoji_str));
    my $rows = $dbh->fetchall_arrayref();
    return scalar @$rows;
}


sub _bot_can_manage_roles
{
    my ($self, $guild_id) = @_;

    return $self->discord->gw->user_has_permission($guild_id, $self->bot->user_id, $self->bot->permissions->{'MANAGE_ROLES'});
}

sub _linked_role
{
    my ($self, $guild_id, $emoji_str) = @_;

    my $query = "SELECT role_id from roles where guild_id = ? and emoji_str = ?";
    my $dbh = $self->db->do($query, $guild_id, _encode_emoji($emoji_str));
    my $row = $dbh->fetchrow_hashref();
    return $row->{'role_id'} // undef;
}

sub _add_role
{
    my ($self, $guild_id, $emoji_str, $user_id) = @_;

    my $role_id = $self->_linked_role($guild_id, $emoji_str);

    $self->discord->add_guild_member_role($guild_id, $user_id, $role_id);
}

sub _remove_role
{
    my ($self, $guild_id, $emoji_str, $user_id) = @_;

    my $role_id = $self->_linked_role($guild_id, $emoji_str);

    $self->discord->remove_guild_member_role($guild_id, $user_id, $role_id);
}

1;
