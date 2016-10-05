package Commands::Comic;

use v5.10;
use strict;
use warnings;

use Net::Discord;
use Mojo::UserAgent;
use DBI;
use Data::Dumper;

sub new
{
    my ($class, %params) = @_;
    my $self = {};
    
    # Setting up this command module requires the Discord connection 
    $self->{'discord'} = $params{'discord'};

    bless $self, $class;
    return $self;
}

# The main bot should call this for every module it has registered whenever a message comes in.
sub on_message_create
{
    my ($self, $channel, $author, $message) = @_;

    if ( $message =~ /^(rcg?|explosm|comic)/i)
    {
        cmd_rcg($self, $channel, $author);
    }
}

sub cmd_rcg
{
    my ($self, $channel, $author, $user) = @_;

    my $discord = $self->{'discord'};

    my $replyto = '<@' . $author->{'id'} . '>';

    my $ua = Mojo::UserAgent->new;

    my $html = $ua->get('http://explosm.net/rcg')->res->body;

    if ( $html =~ /src=\"\/\/(files.explosm.net\/rcg\/.*.png)\"/ )
    {
        my $comic = "http://" . $1;
        $discord->send_message($channel, $comic);
    }
}

1;
