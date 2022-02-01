package Command::Invite;
use feature 'say';

use Moo;
use strictures 2;
use Mojo::URL;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_pick);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Invite' );
has access              => ( is => 'ro', default => 2 ); # 0 = Public, 1 = Bot-Owner Only, 2 = Server owner
has description         => ( is => 'ro', default => 'Generate an invite URL for this channel' );
has pattern             => ( is => 'ro', default => '^invite ?' );
has function            => ( is => 'ro', default => sub { \&cmd_invite } );
has usage               => ( is => 'ro', default => <<EOF
```!invite```
    Generates an invite URL for the current channel that you can then share with people.
    Let me know what else you'd like this command to be able to do I guess?
EOF
);

sub cmd_invite
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    #say "synchronous ver";
    #say Dumper($self->discord->create_invite($channel));

    #say "callback ver";
    #$self->discord->create_invite($channel, sub{ $self->discord->send_message($channel, shift->{code}) });

    #say "promise ver";
    $self->discord->create_invite_p($channel)->then(sub {
        my $invite = shift;
        my $url = $invite->{'url'};
     
        # Send a message back to the channel
        $self->discord->send_message($channel, ":link: $url");
    })->catch(sub{
        $self->discord->send_message($channel, ":x: Failed to create invite. Do I have the CREATE_INSTANT_INVITE permission?");
    });
}

1;
