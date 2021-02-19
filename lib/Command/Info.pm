package Command::Info;
use feature 'say';

use Moo;
use strictures 2;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(cmd_info);

has bot                 => ( is => 'ro' );
has discord             => ( is => 'lazy', builder => sub { shift->bot->discord } );
has log                 => ( is => 'lazy', builder => sub { shift->bot->log } );

has name                => ( is => 'ro', default => 'Info' );
has access              => ( is => 'ro', default => 0 ); # 0 = Public, 1 = Bot-Owner Only
has description         => ( is => 'ro', default => 'Display information about the bot, including framework, creator, and source code links"' );
has pattern             => ( is => 'ro', default => '^info ?' );
has function            => ( is => 'ro', default => sub { \&cmd_info } );
has usage               => ( is => 'ro', default => <<EOF
Basic Usage: `!info`
EOF
);

sub cmd_info
{
    my ($self, $msg) = @_;

    my $channel = $msg->{'channel_id'};
    my $author = $msg->{'author'};
    my $args = $msg->{'content'};

    my $info;

    $info = "**Info**\n" .
            'I am a Goose Bot by vsTerminus' . "\n" .
            "I am a semi-useful chat-bot that provides services such as `!weather`, `!nowplaying`, and `!youtube`\n".
            "Try the `!help` command for a complete listing.\n\n" .
            "**Source Code**\n" .
            "I am open source! I am written in Perl, and am built on the Mojo::Discord library `[1]`\n" .
            "My source code is available on GitHub `[2]`\n\n" .
            "**Add Me**\n" .
            "You can add me to your own server(s) by clicking the link below `[3]` or by sharing it with your server admin.\n\n".
            "**Join My Server**\n" .
            "I have a public Discord server you can join where you can monitor my github feed and mess with the bot without irritating all your friends. Check it out below! `[4]`\n\n" .
            "**Links**\n".
            "`[1]` <https://github.com/vsTerminus/Net-Discord>\n".
            "`[2]` <https://github.com/vsTerminus/Goose>\n".
            "`[3]` <https://discord.com/oauth2/authorize?client_id=231059560977137664&scope=bot&permissions=872803392>\n" .
            "`[4]` <https://discord.gg/FuKTcHF>\n";

    $self->discord->send_ack_dm($channel, $msg->{'id'}, $author->{'id'}, $info);
}

1;
