package Component::YouTube;

use v5.10;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(playlist channel_id search);

use Mojo::UserAgent;
use URI::Escape;
use Data::Dumper;

# This module exists to make it easier to include the database in command modules.
# The modules don't have to care about connection info or manually connecting, they can just call this module's 'do' function.

sub new
{
    my ($class, %params) = @_;
    my $self = {};
   
    my $api_key = $params{'api_key'};
    my $api_url = 'https://www.googleapis.com/youtube/v3';
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(5);

    $self->{'ua'} = $ua;
    $self->{'api_key'} = $api_key;
    $self->{'api_url'} = $api_url;
    
    bless($self, $class); 
    return $self;
}

# Returns all video IDs for a specified Playlist ID
sub playlist_contents
{
    my ($self, $id, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};
    my $url     = $api_url . '/playlistItems?key=' . $api_key . '&part=contentDetails&maxResults=50&playlistId=' . $id;

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;

        my @videos;
        
        foreach my $item ( @{$json->{'items'}} ) 
        {
            push @videos, $item->{'contentDetails'}{'videoId'};
        }

        $callback->(@videos);
    });
}

# Returns all playlists for a specified Channel ID
sub playlists
{
    my ($self, $id, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};
    my $url     = $api_url . '/playlists?key=' . $api_key . '&part=contentDetails&maxResults=50&channelId=' . $id;

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;

        my @plists;
        
        foreach my $item ( @{$json->{'items'}} ) 
        {
            push @plists, $item->{'id'};
        }

        $callback->(@plists);
    });
}

# Returns the channel ID for a specified Username
sub channel_id
{
    my ($self, $username, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};
    my $url     = $api_url . '/channels?key=' . $api_key . '&part=id&forUsername=' . $username . '&maxResults=1';

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;
        $callback->($json->{'items'}[0]->{'id'});
    });
}

sub search
{
    my ($self, $q, $callback) = @_;

    my $ua      = $self->{'ua'};
    my $api_key = $self->{'api_key'};
    my $api_url = $self->{'api_url'};
    my $url     = $api_url . '/search?key=' . $api_key . '&part=snippet&maxResults=10&safeSearch=none&type=video&q=' . uri_escape($q);

    $ua->get($url => sub {
        my ($ua, $tx) = @_;

        my $json = $tx->res->json;
        $callback->($json);
    });
}



1;
