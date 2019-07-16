package Component::MLB;

use feature 'say';
use Moo;
use strictures 2;
use Mojo::UserAgent;
use Mojo::AsyncAwait;
use Mojo::Promise;
use Data::Dumper;
use namespace::clean;

use Exporter qw(import);
our @EXPORT_OK = qw(player_id lookup_player);

# Implements parts of the MLB API, documented here: https://appac.github.io/mlb-data-api-docs/

has 'base_url'  => ( is => 'ro', default => 'http://lookup-service-prod.mlb.com/json' );
has 'ua'        => ( is => 'rw', default => sub { Mojo::UserAgent->new } );

sub BUILD
{
    my $self = shift;

    $self->ua->connect_timeout(5);
    $self->ua->inactivity_timeout(120);
}

async player_stats => sub
{
    my ($self, $params, $callback) = @_;

    say "=> player_stats params: ";
    say Dumper($params);

    my $id = $params->{'id'};
    my $game_type = $params->{'game_type'} // 'R';
    my $season = $params->{'season'} // undef;
    my $career = $params->{'career'} // undef;
    my $group = $params->{'group'}; # hitting, pitching, or fielding;

    return undef unless $group eq 'hitting' or $group eq 'pitching' or $group eq 'fielding';

    say "=> player_stats passed validation";

    my $sport = "sport_";
    $sport .= "career_" if defined $career;
    $sport .= $group . "_tm";

    # Get player career stats
    my $base = $self->base_url;
    
    # Figure out which endpoint to hit
    my $endpoint = "/named.$sport.bam";

    # Define the arguments
    my $args = "?league_list_id='mlb'\&player_id='$id'\&game_type='$game_type'";
    $args .= "&season='$season'" if defined $season;

    # Create the whole URL
    my $url = $base . $endpoint . $args;

    # Get the stats
    say "=> player_stats is getting URL: $url";
    my $tx = await $self->ua->get_p($url);

    # The resulting object is pretty ugly. We can clean it up and put it into a nice hashref.
    my $result = $tx->res->json->{$sport}{'queryResults'};
    say "=> player_stats result: ";
    say Dumper($result);
    
    return $result;
};

async lookup_player => sub
{
    my ($self, $name, $active, $callback) = @_;
    
    my $base = $self->base_url;
    return undef unless $active eq 'Y' or $active eq 'N';
    
    my $endpoint = "/named.search_player_all.bam";
    
    my $params = "?sport_code='mlb'" 
    . "&name_part='" . _strip($name) . "'"
    . "&active_sw='$active'";
    #. "&search_player_all.col_in=name_display_first_last"
    #. "&search_player_all.col_in=player_id";

    my $url = $base . $endpoint . $params;
    say "=> lookup_player is getting URL: $url";
    my $tx = await $self->ua->get_p($url);
    my $result = $tx->res->json->{'search_player_all'}{'queryResults'};

    defined $callback ? $callback->($result) : return $result;
};

# Use the lookup_player function to just return the player ID as a string.
async player_id => sub
{
    my ($self, $name, $callback) = @_;
    my $json;

    $json = await $self->lookup_player($name, 'Y');
    $json = await $self->lookup_player($name, 'N') unless _players_returned($json);

    if ( _players_returned($json) == 1 )
    {
        my $id = _extract_player_id($json);
        defined $callback ? $callback->($id) : return $id;
    }
    elsif ( _players_returned($json) > 1 )
    {
        # What does this look like?
        return undef;
    }
    else
    {
        return undef;
    }
};

sub _players_returned
{
    my $json = shift;
    exists $json->{'totalSize'} ? return $json->{'totalSize'} : return -1;
}

sub _extract_player_id
{
    my $json = shift;

    # We can assume a valid response with at least one result.
    if ( $json->{'totalSize'} == 1 )
    {
        return $json->{'row'}{'player_id'};
    }
    elsif ( $json->{'totalSize'} > 1 ) # Just to be explicit
    {
        # retrn an array of ids - need to see what this looks like first.
        return undef;
    }
    else
    {
        return undef;
    }
}

sub _strip
{
    my $str = shift;
    $str =~ s/[\\"']//g;
    return $str;
}

__PACKAGE__->meta->make_immutable;

1;
