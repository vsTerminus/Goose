package Command::Starboard;
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

has name                => ( is => 'ro', default => 'Star Board' );
has access              => ( is => 'ro', default => 2 ); # 0 = Public, 1 = Bot Owner Only, 2 = Server Owner Only
has description         => ( is => 'ro', default => 'Manage Star Board channel and settings' );
has pattern             => ( is => 'ro', default => '^(starboard|sb) ?' );
has function            => ( is => 'ro', default => sub { \&cmd_starboard } );
has usage               => ( is => 'ro', default => <<EOF
Use this command to manage the Star Board channel in your server.
Alias: `!sb`
### Uses:
```
!sb
!sb on|off
!sb set channel [#channel-name]
!sb set mode <inclusive|exclusive>
!sb set threshold <1-9>
!sb include [#channel-name]
!sb exclude [#channel-name]
```
### More Details:
`!sb`
Display current Star Board Config, including the list of included or excluded channels.

`!sb on|off`
Turn Star Board functionality on or off
All existing configuration and messages will be preserved, this just tells the bot to either start or stop monitoring reaction events.

`!sb set channel [#channel-name]`
Set the "Star Board" channel. This is where the bot will post messages when they have enough star reactions.
If you do not specify a channel it will use the current one.

`!sb set mode <inclusive|exclusive>`
Set the mode the bot operates in.
"Inclusive" mode will monitor for reactions in all channels except those which you manually exclude.
"Exclusive" mode will ignore all channels by default, and only watch the ones you manually include.

`!sb set threshold <1-9>`
How many :star: reactions should a message require before the bot posts it to the Star Board?
Note: Lowering this will not retroactively affect messages. It only checks when a reaction is added.

`!sb include [#channel-name]`
In "Exclusive" mode, this tells the bot that it should monitor this channel's reactions.
In "Inclusive" mode, this is how you undo a previous exclusion.
If you do not specify a channel the bot will include the current channel.

`!sb exclude <#channel-name>`
In "Inclusive" moode, this tells the bot that it should ignore reactions in this channel.
In "Exclusive" mode, this is how you under a previous inclusion.
If you do not specify a channel the bot will exclude the current channel.

EOF
);

has info                => ( is => 'ro', default => <<EOF
The bot will capture whatever the user's name and avatar are **at the moment their message reaches the reaction threshold** and use that to crosspost the message.
If the user then changes their name or avatar the bot *will not* go back and update the Star Board post.

The same applies to message content: Whatever the message says at the moment it reaches the threshold is what the bot will post.
If the user then edits their message, those changes *will not* be reflected on the Star Board post.

If someone removes a reaction from the message after it has already been posted, the bot **will not** remove it from the Star Board.
This prevents some abuse cases and spam, mostly.

If the author of a message that gets posted to the Star Board would like it removed, they have two options:
**Option 1:** They can delete the original message. This will trigger the bot to delete the corresponding Star Board post immediately.
**Option 2:** They can simply react to the Star Board message with ":x:" and the bot will delete the post and flag the original message as "ineligible" to be posted ever again.

Inclusive Mode is the default, and assumes that you probably want *most or all* of your channels to be eligible for Star Board, but maybe you have one or two you'd like to exclude.

Exclusive Mode, if you switch to it, assumes that you probably want *only a few specific chanels* to be eligible for Star Board, and if you have a huge channel list this is easier than excluding dozens of channels.

Attachments are not fully supported due to limitations with the Discord API Rich Embeds. At most 10 attachments can be included, and support is mostly limited to images.

EOF
);

has star_emoji              => ( is => 'ro', default => "\x{2b50}");
has x_emoji                 => ( is => 'ro', default => "\x{274c}");

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

        say "---- Reaction Event ----";
        say "Emoji: $emoji_str";
        say Dumper($hash);

        # If something gets posted on the Star Board and a user wants it removed (Without deleting the original message),
        # they can react to the Star Board post with :x: and the bot should remove the post.
        # The message ID should remain in the star_messages DB table, that way the message cannot be re-posted in the future.
        if ( $emoji_str eq $self->x_emoji )
        {
            $self->_is_x_reaction_actionable($guild_id, $channel_id, $message_id, $user_id, $emoji_str)->then(sub
            {
                say "Author wants message deleted.";
                $self->discord->delete_message($self->_starboard_channel($guild_id), $message_id);
            })->catch(sub
            {
                my $error = shift;
                say "Reaction is not actionable: [$error]";
            })
        }
        # Any time :star: is left on a message, check a variery of conditions first and then crosspost the message to the Star Board if all conditions are met.
        elsif ( $emoji_str eq $self->star_emoji )
        {
            $self->_is_star_reaction_actionable($guild_id, $channel_id, $message_id, $user_id, $emoji_str)->then(sub
            {
                $self->_post_to_starboard($guild_id, $channel_id, $message_id);
            })->catch(sub
            {
                my $error = shift;
                say "Reaction is not actionable: [$error]";
            })
        }
        # Else - this is not a :star: or an :x: so there's nothing to do.
    })
});

has on_message_delete => ( is => 'ro', default => sub
{
    my $self = shift;
    $self->discord->gw->on('MESSAGE_DELETE' => sub
    {
        # If this is a Star Board message we should also delete it.
        my ($gw, $hash) = @_;
        my $guild_id = $hash->{'guild_id'};
        my $channel_id = $hash->{'channel_id'};
        my $message_id = $hash->{'id'};

        $self->_remove_starboard_message($guild_id, $channel_id, $message_id);
    })
});


##########################
#
# Main Command
#
##########################



sub cmd_starboard
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

    say "Star Board command received";
    say "Args: [$args]";

    # On or Off
    if ( $args =~ /^on$/i )
    {
        if ( $self->_starboard_channel($guild_id) )
        {
            say "Turning Star Board On";
            $self->discord->send_message($channel_id, $self->_set_starboard_enabled($guild_id) ? ":white_check_mark: Star Board functionality is enabled" : ":x: Something went wrong. Star Board could not be enabled.");
        }
        else
        {
            say "Cannot enable Star Board. Channel is not configured.";
            $self->discord->send_message($channel_id, ":x: Cannot enable Star Board. Channel is not configured, use `!sb set channel #channel-name` first.")
        }
    }
    elsif ( $args =~ /^off$/i )
    {
        say "Turning Star Board Off";
        $self->discord->send_message($channel_id, $self->_set_starboard_disabled($guild_id) ? ":white_check_mark: Star Board functionality is disabled" : ":x: Something went wrong. Star Board could not be disabled.");
    }

    # Set config variables
    elsif ( $args =~ /^set ?/i )
    {
        say "Star Board Set";
        $args =~ s/^set ?//i;
        say "Args: [$args]";

        # Set channel for Star Board
        if ( $args =~ /^channel ?/i )
        {
            $args =~ s/^channel ?//i;
            my $sb_channel_id = $self->_extract_channel_id($args);
            say "Set Channel";
            say "Args: [$args]";
            say "SB Channel ID: [$sb_channel_id]";

            if ( length $args == 0 )
            {
                $self->_set_starboard_channel($guild_id, $channel_id);
                $self->discord->send_message($channel_id, "Star Board set to <#" . $self->_starboard_channel($guild_id) . ">");
            }
            else
            {
                # Mojo Discord keeps track of every channel it can see, so we can simply have the library verify whether this is a valid channel.
                if ( $self->discord->channel_exists($guild_id, $sb_channel_id) )
                {
                    $self->_set_starboard_channel($guild_id, $sb_channel_id);
                    $self->discord->send_message($channel_id, "Star Board set to <#$sb_channel_id>");
                }
                else
                {
                    $self->discord->send_message($channel_id, ":x: Invalid channel. Could not update Star Board.");
                }
            }
        }

        # Set threshold for number of star reactions
        elsif ( $args =~ /^threshold ?/i )
        {
            say "Set Threshold";
            $args =~ s/^threshold ?//i;
            say "Args: [$args]";

            if ( $args =~ /^\d$/ and $args > 0 and $args < 10 )
            {
                $self->discord->send_message($channel_id, "Threshold set to **" . $self->_set_starboard_threshold($guild_id, $args) . "** :star: reactions");
            }
            else
            {
                $self->discord->send_message($channel_id, ":x: Accepted range is 1-9");
            }
        }
        
        # Set inclusive/exclusive mode
        elsif ( $args =~ /^mode ?/i )
        {
            say "Set Mode";
            $args =~ s/^mode ?//i;
            say "Args: [$args]";

            if ( lc $args eq 'inclusive' or lc $args eq 'woke')
            {
                $self->discord->send_message($channel_id, "Star Board will include all channels by default. Use `!sb exclude #channel-name` to exclude individual channels.");
                $self->_set_starboard_mode($guild_id, 'inclusive');
            }
            elsif (lc $args eq 'exclusive' )
            {
                $self->discord->send_message($channel_id, "Star Board will exclude all channels by default. Use `!sb include #channel-name` to include individual channels.");
                $self->_set_starboard_mode($guild_id, 'exclusive');
            }
            elsif (length $args == 0)
            {
                $self->discord->send_medssage($channel_id, "Star Board is currently in '" . $self->_starboard_mode($guild_id) . "' mode. Valid modes are 'inclusive' and 'exclusive'.");
                $self->_starboard_mode($guild_id);
            }
            else
            {
                $self->discord->send_message($channel_id, ":x: Accepted modes are 'inclusive' and 'exclusive'");
            }
        }
    }

    # Include and Exclude channels
    elsif ( $args =~ /include ?/i )
    {
        say "Include a Channel";
        $args =~ s/include ?//i;
        say "Args: [$args]";
        my $target_channel_id = $args =~ /^\<\#\d+\>$/ ? $self->_extract_channel_id($args) : $channel_id;
        say "This Channel: $channel_id -- Target Channel: $target_channel_id";

        my $starboard_channel_id = $self->_starboard_channel($guild_id);
        if ( $target_channel_id == $starboard_channel_id )
        {
            $self->discord->send_message($channel_id, ":x: <#$starboard_channel_id> is the Star Board channel and cannot be included.");
            return;
        }

        # In inclusive mode we use the exclude channels list.
        # In exclusive mode we use the include channels list.
        # Look at the mode we're in right now and then determine what needs to be done.
        $self->_starboard_mode($guild_id) eq 'inclusive' ? 
            $self->_remove_from_excluded($guild_id, $target_channel_id) : 
            $self->_add_to_included($guild_id, $target_channel_id);
        $self->discord->send_message($channel_id, "Star Board will include <#$target_channel_id>");
    }
    elsif ( $args =~ /exclude ?/i )
    {
        say "Exclude a Channel";
        $args =~ s/exclude ?//i;
        say "Args: [$args]";
        my $target_channel_id = $args =~ /^\<\#\d+\>$/ ? $self->_extract_channel_id($args) : $channel_id;
        say "This Channel: $channel_id -- Target Channel: $target_channel_id";

        my $starboard_channel_id = $self->_starboard_channel($guild_id);
        if ( $target_channel_id == $starboard_channel_id )
        {
            $self->discord->send_message($channel_id, ":information_source: <#$starboard_channel_id> is the Star Board channel and is automatically excluded");
            return;
        }

        # In inclusive mode we use the exclude channels list.
        # In exclusive mode we use the include channels list.
        # Look at the mode we're in right now and then determine what needs to be done.
        $self->_starboard_mode($guild_id) eq 'inclusive' ? 
            $self->_add_to_excluded($guild_id, $target_channel_id) : 
            $self->_remove_from_included($guild_id, $target_channel_id);
        $self->discord->send_message($channel_id, "Star Board will exclude <#$target_channel_id>");
    }

    # Display current configuration
    elsif ( $args =~ /^\s*$/ )
    {
        # Threshold is a NOT NULL field, so if a config exists it will be defined.
        # Easy way to check if a config exists while getting a value we need anyway.
        my $threshold = $self->_starboard_threshold($guild_id);
        $self->discord->send_message($channel_id, ":x: Not Configured.\nSee `!help starboard` for usage.") and return unless defined $threshold;

        my $enabled = $self->_starboard_enabled($guild_id) ? "On" : "Off";
        my $mode = ucfirst $self->_starboard_mode($guild_id);
        my $channel_id = $self->_starboard_channel($guild_id);
        my $linked_channel = defined $channel_id ? "<#$channel_id>" : '**Not Set**';

        my $config = "Star Board is **$enabled**\n" .
        "Star Board Channel: $linked_channel\n" .
        "Star Board Mode: **$mode**\n" .
        "Star Board Threshold: **$threshold :star:**";

        my $channels;
        if ( $self->_starboard_mode($guild_id) eq 'inclusive' )
        {
            $channels = "Star Board is monitoring reactions in all channels";
            
            my $channel_list = $self->_excluded_channels($guild_id);
            $channel_list .= "<#" . $self->_starboard_channel($guild_id) . ">";
            $channels .= " except:\n$channel_list" if $channel_list;
        }
        else
        {
            $channels = "Star Board is ignoring reactions in all channels";
            
            my $channel_list = $self->_included_channels($guild_id);
            $channels .= " except:\n$channel_list" if $channel_list;
        }

        $self->discord->send_message($channel_id, "Current Star Board Config:\n------------------------------\n$config\n\n$channels\n------------------------------\n");
    }
    else
    {
        say "Unrecognized Args: $args";
    }
}

##########################
#
# Helper Functions
#
##########################


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

# This function builds an embedded recreation of the identified message and posts it to the Star Board channel.
# This allows for some useful "surrounding contextual information" such as when and where the original was posted.
sub _post_to_starboard
{
    my ($self, $guild_id, $channel_id, $message_id) = @_;

    my $starboard_channel_id = $self->_starboard_channel($guild_id);
    #my $starboard_webhook = $self->bot->has_webhook($starboard_channel_id);

    #say "---- Webhook ----";
    #say Dumper($starboard_webhook);

    # We need to look up the message object first
    my $message_content = $self->discord->get_channel_message_p($channel_id, $message_id)->then(sub
    {
        my $message = shift;

        say "---- Message ----";
        say Dumper($message);

        my $user_id = $message->{'author'}->{'id'};
        my $user_name = $message->{'author'}->{'username'};
        my $user_avatar_id = $message->{'author'}->{'avatar'};
        my $message_timestamp = $message->{'timestamp'};
        my $message_content = $message->{'content'};
        my $message_attachments = $message->{'attachments'};
        my $message_embeds = $message->{'embeds'};
        my $global_name = $message->{'author'}->{'global_name'};
        my $discriminator = $message->{'author'}->{'discriminator'};
        my $starboard_message_content = '';

        # The bot passively tracks guild member info when the Gateway provides it.
        # We can leverage that to get the user's nickname and avatar on the server.
        # These are things which the "get_channel_message" call does not return.
        my $guild_member = $self->discord->get_guild_member($guild_id, $user_id);
        say "---- Guild Member ----";
        say Dumper($guild_member);
        my $guild_nick = $guild_member->nick if defined $guild_member;
        my $guild_avatar_id = $guild_member->avatar if defined $guild_member;

        # There are a lot of ways to identify a user on Discord and we want to be as respectful/accurate as possible.
        # Prioritize Server Profile names, then Global names.
        # Maintain support for the old Discriminator system, which Bots still use.
        # Webhooks only return a username, so when all other info is missing just display the username.
        my $display_name;
        if      ( defined $guild_nick )     { $display_name = "$guild_nick (\@$user_name)"; }   # Server Nickname
        elsif   ( defined $global_name )    { $display_name = "$global_name (\@$user_name)"; }  # Global Name
        elsif   ( $discriminator > 0 )      { $display_name = "$user_name\#$discriminator"; }   # Bots
        else                                { $display_name = $user_name; }                     # Webhooks

        # Avatars are a similar but slightly less complex story.
        # Users can define their own avatar per-server, and
        # we should respect that and use it when applicable.
        # Note, the URL for guild-specific avatars includes the guild ID.
        my $avatar_url = Mojo::URL->new('https://cdn.discordapp.com/');
        
        # Should probably have a function for this in the library...
        $avatar_url->path( $guild_avatar_id ? 
            "/guilds/$guild_id/users/$user_id/avatars/$guild_avatar_id.png" : 
            "/avatars/$user_id/$user_avatar_id.png"
        );
        $avatar_url->query("size=64");

        my $message_url = Mojo::URL->new("https://discord.com")->path("/channels/$guild_id/$channel_id/$message_id");
        $message_content .= "\n\n[View Original Message](" . $message_url->to_string . ")";

        say "Avatar URL: $avatar_url";

        my $channel = $self->discord->get_channel($guild_id, $channel_id);
        my $channel_name = $channel->{'name'};

        my $primary_embed = {
            'title' => $display_name,
            'url' => $message_url->to_string,
            'timestamp' => $message_timestamp,
            'description' => $message_content,
            'thumbnail' => {
                'url' => $avatar_url->to_string,
                'height' => 64,
                'width' => 64
            },
            'footer' => {
                'text' => "Posted In #$channel_name"
            },
            'type' => 'rich',
            'color' => 0xa0c0e6,
        };

        my $embeds = [ $primary_embed ];

        foreach my $attachment (@$message_attachments)
        {
            my $converted_embed = {};
            if ( $attachment->{'content_type'} =~ /image/i )
            {
                $converted_embed = {
                    'title' => $attachment->{'filename'},
                    'url' => $attachment->{'url'},
                    'image' => {
                        'url' => $attachment->{'url'},
                        'height' => $attachment->{'height'},
                        'width' => $attachment->{'width'},
                    }
                }
            }
            else
            {
                $converted_embed = {
                    'title' => $attachment->{'content_type'},
                    'url' => $attachment->{'url'},
                    'fields' => [
                        {
                            'name' => $attachment->{'filename'},
                            'value' => $attachment->{'url'}
                        }
                    ]
                }
            }
            push @$embeds, $converted_embed;
        }

        foreach my $attachment (@$message_embeds)
        {
            say "---- Message Embed ----";
            say Dumper($attachment);
            my $converted_embed = {};
            if ( $attachment->{'type'} eq 'image' ) # or ($attachment->{'type'} eq 'rich' and exists $attachment->{'image'}) )
            {
                $converted_embed = {
                    'url' => $attachment->{'url'},
                    'image' => {
                        'url' => $attachment->{'url'}
                    }
                };
                push @$embeds, $converted_embed;
            }
            elsif ( $attachment->{'type'} eq 'gifv' )
            {
                $converted_embed = {
                    'url' => $attachment->{'url'},
                    'description' => '(Thumbnail Only - Video Embeds Do Not Work)',
                    'image' => $attachment->{'thumbnail'},
                };
                push @$embeds, $converted_embed;
            }
            elsif ( $attachment->{'type'} eq 'rich' )
            {
                push @$embeds, $attachment;
            }
            
            # Not sure what to do with other embed types honestly
        }

        my $embed_max = scalar @$embeds < 10 ? (scalar @$embeds - 1) : 9; # Max 10 embeds allowed
        my $starboard_message = {
            'content' => $starboard_message_content,
            'embeds' => [@$embeds[0..$embed_max]], 
            #'username' => 'Star Board',
            #'avatar_url' => 'https://images.emojiterra.com/google/noto-emoji/unicode-15/color/512px/2b50.png'
        };

        say "---- Star Board Message ----";
        say Dumper($starboard_message);

        #$self->discord->send_webhook($starboard_channel_id, $starboard_webhook, $starboard_message, sub {
        $self->discord->send_message($starboard_channel_id, $starboard_message, sub {
            my $message = shift;

            my $starboard_message_id = $message->{'id'};

            if (defined $starboard_message_id)
            {
                say "Message Posted Successfully";
                $self->_add_starboard_message($guild_id, $user_id, $channel_id, $message_id, $starboard_channel_id, $starboard_message_id);
            }
        });
    });
}

# Specifically for removing already-posted messages if the author wants them removed
sub _is_x_reaction_actionable
{
    my ($self, $guild_id, $channel_id, $message_id, $user_id, $emoji_str) = @_;

    my $promise = Mojo::Promise->new;

    # Some things we *don't* care about here:
    # Star Board doesn't have to be on.
    # We don't have to be in the current Star Board channel, because that can change with time.
    # We don't care how many reactions there already are.

    # What makes an :x: reaction "Actionable"?
    say "Is :x: reaction actionable?";

    # 1. The reaction is an :x:
    # This was checked before we entered this function but it never hurts to check again.
    $promise->reject("Reaction is not an :x:") and return $promise unless $emoji_str eq $self->x_emoji;
    say "Reaction is :x:";

    # 2. The message is a posted starboard message.
    my $message = $self->_get_original_message($guild_id, $channel_id, $message_id);
    $promise->reject("Message is not a Star Board post") and return $promise unless defined $message;
    say "Message is a Star Board post.";

    # 3. The emoji author and the original message author are the same
    $promise->reject("Reaction author and Message Author do not match") and return $promise unless $user_id == $message->{'user_id'};
    say "Reaction and Message Authors are the same";
    
    # And that's about it. Much simpler than :star: reaction criteria.
    $promise->resolve();

    return $promise;
}

# Specifically for adding new messages to the starboard
sub _is_star_reaction_actionable
{
    my ($self, $guild_id, $channel_id, $message_id, $user_id, $emoji_str) = @_;

    my $promise = Mojo::Promise->new;

    # What makes a reaction "actionable"?
    say "Is :star: reaction actionable?";
    
    # 1. Star Board is turned on / enabled for this guild
    $self->_starboard_enabled($guild_id) or ($promise->reject("Star Board is not enabled") and return $promise);
    say "1. Star Board is Enabled";

    # 2. There is a Star Board channel configured for this guild and the bot is aware of this channel existing
    my $starboard_channel_id = $self->_starboard_channel($guild_id); # Store in a var because we need it later
    ( defined $starboard_channel_id and $self->discord->channel_exists($guild_id, $channel_id) ) or ($promise->reject("Star Board channel is not configured") and return $promise);
    say "2. Star Board Channel is defined";

    # 3. We're not in the starboard channel right now
    $starboard_channel_id ne $channel_id or ($promise->reject("Message is already in the Star Board channel") and return $promise);
    say "3. We're not in the starboard channel";

    # Bot users can send rich embeds now without needing a webhook, so this is actually unncessary
    # The only advantage of using one is being able to set the name and avatar to whatever I want,
    # but it also comes with embed type limitations, so probably not worth using. 
    # More importantly, sending a webhook message cannot return the posted message id, which I need.
    # This means posting a regular message is the clear choice. Plus it's simpler and requires fewer permissions.
    # Leaving it here for context.
    #
    # 4. We have a webhook in the Star Board channel
    #if ( !defined $self->bot->has_webhook($starboard_channel_id) )
    #{
    #    say "No webhook in Star Board Channel. Attempting to create one...";
    #    # Try to create the webhook before giving up
    #    if ( ! $self->bot->create_webhook($starboard_channel_id) )
    #    {
    #        $promise->reject("Webhook does not exist for this channel");
    #        return $promise;
    #    }
    #    # Else success!
    #}
    #say "4. Webhook exists";

    # 4. The reaction is a :star:
    # This is checked before we even call this function, but let's be safe and double-check.
    $emoji_str eq $self->star_emoji or ($promise->reject("The reaction is not a :star:") and return $promise);
    say "4. The reaction is a :star:";

    # 5. It's not a reaction posted by the bot
    $user_id != $self->bot->user_id or ($promise->reject("The bot's own reactions do not count towards the threshold") and return $promise);
    say "5. It's not a self-react";

    # 6. If mode is Inclusive, we're not in an Excluded channel. If mode is Exclusive, we are in an Included channel.
    my $is_included_channel =   ( lc $self->_starboard_mode($guild_id) eq 'exclusive' ?
                                $self->_is_included_channel($guild_id, $channel_id) :
                                !$self->_is_excluded_channel($guild_id, $channel_id) )
                                or ($promise->reject("Reaction is not in an included channel") and return $promise);
    say "6. This is an Included Channel";

    # 7. We've reached the threshold number of :star: reactions

    $self->discord->get_reactions_p($channel_id, $message_id, $emoji_str)->then(sub
    {
        my $json = shift;

        my $num_reactions = scalar @{$json};
        $num_reactions >= $self->_starboard_threshold($guild_id) or ($promise->reject("Not enough reactions to meet threshold") and return $promise);
        say "7. Reaction Threshold Met";

        # 8. We haven't already posted this message on the Star Board
        ($promise->reject("Message already posted to Star Board") and return $promise) if $self->_starboard_message_id($message_id);
        say "8. Message Not already posted";

        # If we got here we can return true - This reaction is actionable.
        $promise->resolve();
    })->catch(sub
    {
        my $reason = shift;
        say "Reaction is not actionable: [$reason]";
    });

    return $promise;
}

sub _extract_channel_id
{
    my ($self, $channel) = @_;

    $channel =~ s/^\<\#(.*)\>/$1/;
    return $channel;
}

##########################
#
# DB Config Functions
#
##########################

sub _starboard_channel
{
    my ($self, $guild_id) = @_;

    my $sql = "SELECT channel_id FROM star_config WHERE guild_id = ?";
    my $query = $self->db->query($sql, $guild_id);
    my $row = $query->fetchrow_hashref;
    my $channel_id = $row->{'channel_id'};

    return $channel_id;
}

sub _set_starboard_channel
{
    my ($self, $guild_id, $channel_id) = @_;

    my $sql = "INSERT INTO star_config (guild_id, channel_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE channel_id = ?";
    my $query = $self->db->query($sql, $guild_id, $channel_id, $channel_id);
   
    return $self->_starboard_channel($guild_id);
}

sub _starboard_enabled
{
    my ($self, $guild_id) = @_;

    my $sql = "SELECT enabled FROM star_config WHERE guild_id = ?";
    my $query = $self->db->query($sql, $guild_id);
    my $row = $query->fetchrow_hashref;
    my $enabled = $row->{'enabled'};

    return $enabled;
}

# Returns a boolean confirming whether starboard was enabled
sub _set_starboard_enabled
{
    my ($self, $guild_id) = @_;

    my $sql = "INSERT INTO star_config (guild_id, enabled) VALUES (?, ?) ON DUPLICATE KEY UPDATE enabled = ?";
    my $query = $self->db->query($sql, $guild_id, 1, 1);

    return $self->_starboard_enabled($guild_id);
}

# Returns a boolean confirming whether starboard was disabled
sub _set_starboard_disabled
{
    my ($self, $guild_id) = @_;

    my $sql = "INSERT INTO star_config (guild_id, enabled) VALUES (?, ?) ON DUPLICATE KEY UPDATE enabled = ?";
    my $query = $self->db->query($sql, $guild_id, 0, 0);

    return $self->_starboard_enabled($guild_id) == 0;
}


sub _starboard_threshold
{
    my ($self, $guild_id) = @_;

    my $sql = "SELECT threshold FROM star_config WHERE guild_id = ?";
    my $query = $self->db->query($sql, $guild_id);
    my $row = $query->fetchrow_hashref;
    my $threshold = $row->{'threshold'};

    return $threshold;
}

sub _set_starboard_threshold
{
    my ($self, $guild_id, $threshold) = @_;

    my $sql = "INSERT INTO star_config (guild_id, threshold) VALUES (?, ?) ON DUPLICATE KEY UPDATE threshold = ?";
    my $query = $self->db->query($sql, $guild_id, $threshold, $threshold);

    return $self->_starboard_threshold($guild_id);
}

sub _starboard_mode
{
    my ($self, $guild_id) = @_;

    my $sql = "SELECT mode FROM star_config WHERE guild_id = ?";
    my $query = $self->db->query($sql, $guild_id);
    my $row = $query->fetchrow_hashref;
    my $mode = $row->{'mode'};

    return $mode;
}

sub _set_starboard_mode
{
    my ($self, $guild_id, $mode) = @_;

    my $sql = "INSERT INTO star_config (guild_id, mode) VALUES (?, ?) ON DUPLICATE KEY UPDATE mode = ?";
    my $query = $self->db->query($sql, $guild_id, $mode, $mode);

    return $self->_starboard_mode($guild_id);
}

##########################
#
# DB Channel List Functions
#
##########################

# Return the inclusion list as a comma-separated string of channel ids
sub _included_channels
{
    my ($self, $guild_id) = @_;

    my $sql = "SELECT channel_id FROM star_include";
    my $query = $self->db->query($sql);
    my $result = $query->fetchall_arrayref();
    
    return join('', map { "<#" . $_->[0] . "> " } @$result);
}

# Add a channel to the inclusion list
# Returns the updated list of included channels
sub _add_to_included
{
    my ($self, $guild_id, $channel_id) = @_;

    my $sql = "INSERT INTO star_include (guild_id, channel_id) VALUES (?, ?)";
    my $query = $self->db->query($sql, $guild_id, $channel_id);
    
    return $self->_included_channels($guild_id);
}

# Delete a channel from the inclusion list
# Returns the updated list of included channels
sub _remove_from_included
{
    my ($self, $guild_id, $channel_id) = @_;
    
    my $sql = "DELETE FROM star_include WHERE guild_id = ? AND channel_id = ?";
    my $query = $self->db->query($sql, $guild_id, $channel_id);

    return $self->_included_channels($guild_id);
}

# Delete all entries from the inclusion list
# Returns the updated (empty) list of included channels
sub _reset_included
{
    my ($self, $guild_id) = @_;

    my $sql = "DELETE FROM star_include WHERE guild_id = ?";
    my $query = $self->db->query($sql, $guild_id);

    return $self->_included_channels($guild_id);
}

# Check if a channel is in the inclusion list
# Returns true or false
sub _is_included_channel
{
    my ($self, $guild_id, $channel_id) = @_;

    # Be smart, accept <#channel_id> format as well.
    $channel_id =~ s/\<\#(\d+)\>/$1/;

    my $sql = "SELECT channel_id FROM star_include WHERE guild_id = ? AND channel_id = ?";
    my $query = $self->db->query($sql, $guild_id, $channel_id);

    return scalar @{ $query->fetchall_arrayref() };
}
    

# Returns a string of excluded channels
sub _excluded_channels
{
    my ($self, $guild_id) = @_;

    my $sql = "SELECT channel_id FROM star_exclude";
    my $query = $self->db->query($sql);
    my $result = $query->fetchall_arrayref();
    
    return join('', map { "<#" . $_->[0] . "> " } @$result);
}

# Add a channel to the exclusion list
# Returns the updated list of excluded channels
sub _add_to_excluded
{
    my ($self, $guild_id, $channel_id) = @_;

    my $sql = "INSERT INTO star_exclude (guild_id, channel_id) VALUES (?, ?)";
    my $query = $self->db->query($sql, $guild_id, $channel_id);
    
    return $self->_excluded_channels($guild_id);
}

# Delete a channel from the exclusion list
# Returns the updated list of excluded channels
sub _remove_from_excluded
{
    my ($self, $guild_id, $channel_id) = @_;
    
    my $sql = "DELETE FROM star_exclude WHERE guild_id = ? AND channel_id = ?";
    my $query = $self->db->query($sql, $guild_id, $channel_id);

    return $self->_included_channels($guild_id);
}

# Delete all entries from the exclusion list
# Returns the updated (empty) list of excluded channels
sub _reset_excluded
{
    my ($self, $guild_id) = @_;

    my $sql = "DELETE FROM star_include WHERE guild_id = ?";
    my $query = $self->db->query($sql, $guild_id);

    return $self->_included_channels($guild_id);
}

# Check if a channel is in the exclusion list
# Returns true or false
sub _is_excluded_channel
{
    my ($self, $guild_id, $channel_id) = @_;

    # Be smart, accept <#channel_id> format as well.
    $channel_id =~ s/\<\#(\d+)\>/$1/;

    my $sql = "SELECT channel_id FROM star_exclude WHERE guild_id = ? AND channel_id = ?";
    my $query = $self->db->query($sql, $guild_id, $channel_id);

    return scalar @{ $query->fetchall_arrayref() };
}
 
##########################
#
# DB Message Functions
#
##########################

# If the message ID was posted to the starboard, return the starboard message id
# If not, return undef
sub _starboard_message_id
{
    my ($self, $message_id) = @_;

    my $sql = "SELECT starboard_message_id FROM star_messages WHERE original_message_id = ?";
    my $query = $self->db->query($sql, $message_id);
    my $row = $query->fetchrow_arrayref();

    return undef unless defined $row;
    return scalar @$row ? $row->[0] : undef;
}

sub _add_starboard_message
{
    my ($self, $guild_id, $user_id, $channel_id, $message_id, $starboard_channel_id, $starboard_message_id) = @_;

    my $sql = "INSERT INTO star_messages (guild_id, user_id, original_channel_id, original_message_id, starboard_channel_id, starboard_message_id) VALUES (?, ?, ?, ?, ?, ?)";
    my $query = $self->db->query($sql, $guild_id, $user_id, $channel_id, $message_id, $starboard_channel_id, $starboard_message_id);

    return $self->_starboard_message_id($message_id);
}

sub _remove_starboard_message
{
    my ($self, $guild_id, $channel_id, $message_id) = @_;

    my $starboard_message = $self->_get_starboard_message($guild_id, $channel_id, $message_id);

    if ( $starboard_message )
    {
        # Remove it from the DB
        my $delete_sql = "DELETE FROM star_messages WHERE guild_id = ? AND starboard_channel_id = ? AND starboard_message_id = ?";
        my $delete = $self->db->query($delete_sql, $guild_id, $starboard_message->{'starboard_channel_id'}, $starboard_message->{'starboard_message_id'});

        # Also delete it from Discord
        $self->discord->delete_message($starboard_message->{'starboard_channel_id'}, $starboard_message->{'starboard_message_id'});
    }
}

# Query by the original message ids
sub _get_starboard_message
{
    my ($self, $guild_id, $channel_id, $message_id) = @_;

    my $query_sql = "SELECT * FROM star_messages WHERE guild_id = ? AND original_channel_id = ? AND original_message_id = ?";
    my $query = $self->db->query($query_sql, $guild_id, $channel_id, $message_id);
    my $query_row = $query->fetchrow_hashref();

    return $query_row;
}

# Query by the posted star board message ids
sub _get_original_message
{
    my ($self, $guild_id, $channel_id, $message_id) = @_;

    my $query_sql = "SELECT * FROM star_messages WHERE guild_id = ? AND starboard_channel_id = ? AND starboard_message_id = ?";
    my $query = $self->db->query($query_sql, $guild_id, $channel_id, $message_id);
    my $query_row = $query->fetchrow_hashref();

    return $query_row;
}



1;
