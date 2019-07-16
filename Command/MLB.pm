package Command::MLB;
use feature 'say';

use Moo;
use strictures 2;

use Mojo::Discord;
use Mojo::AsyncAwait;
use Bot::Goose;
use Component::MLB;
use Text::ASCIITable;
use Data::Dumper;

use namespace::clean;

has bot             => ( is => 'rw', required => 1 );
has discord         => ( is => 'rw' );
has mlb             => ( is => 'rw', default => sub { Component::MLB->new() } );

has name            => ( is => 'ro', default => 'MLB' );
has access          => ( is => 'ro', default => 0 ); # Public
has description     => ( is => 'ro', default => 'Lookup Baseball Stats from the MLB API' );
has pattern         => ( is => 'ro', default => '^(mlb|bb) ?(.*)$' );
has function        => ( is => 'ro', default => sub { return \&cmd_mlb } );
has subcommand      => ( is => 'ro', default => sub 
                                                {
                                                    my $hash = 
                                                    {
                                                        'stats' => \&_player_stats,
                                                    }; 
                                                    return $hash;
                                                });
has usage           => ( is => 'ro', default => sub { return <<EOF;
Use the MLB API to look up stats about players

**Usage:**

`!mlb stats <player name> [year] [hitting|pitching|fielding]`

By default it will return career hitting stats for a player. To see stats for a specific season just specify the year. To see stats for pitching or fielding just add `pitching` or `fielding` after the name.

**Examples:**

Get career hitting stats: `!mlb stats Chase Utley`
Get career pitching stats: `!mlb stats CC Sabathia pitching`
Get 2019 fielding stats: `!mlb stats Javier Baez 2019 fielding`

**Aliases:**

Also accepts: `!bb`
EOF
});

sub BUILD
{
    my $self = shift;

    $self->discord( $self->bot->discord );    
}

sub cmd_mlb
{
    my ($self, $channel, $author, $msg) = @_;

    my $discord = $self->discord;
    my $args = $msg;
    my $pattern = $self->pattern;
    $args =~ s/$pattern/$2/i;
    my $cmd = (split ' ',$args)[0];

    if ( defined $cmd and exists $self->subcommand->{$cmd} )
    {
        $args =~ s/^$cmd //;
        $self->subcommand->{$cmd}->($self, $channel, $author, $args);
    }
    else
    {
        $discord->send_message($channel, "Invalid Command. Valid options are: `stats <Player Name>`");
    }
}

async _player_stats => sub
{
    my ($self, $channel, $author, $args) = @_;
    my $discord = $self->discord;

    # $args should contain
    # - A player name (mandatory)
    # - A four digit year (optional)
    # - 1-2 digit result number for multiple matches (optional)
    # - "hitting", "pitching", or "fielding" (optional - default to all three)
    my $season = ( $args =~ /\b(\d{4})\b/ ? $1 : undef );
    say "=> _player_stats season=$season" if defined $season;
    my $match = ( $args =~ /\b(\d{1,2})\b/ ? $1 : undef );
    say "=> _player_stats match=$match" if defined $match;
    my $group = ( $args =~/(hitting|pitching|fielding)/i ? lc $1 : 'hitting' );
    my $name = $args;
    $name =~ s/ ?$match// if defined $match; # Remove the match number
    $name =~ s/ ?$season// if defined $season; # Remove the year
    $name =~ s/ ?$group// if defined $group; # Remove the group
    say "=> _player_stats name=$name";

    # Only one of career and season should be defined.
    my $career = ( defined $season ? undef : '1' );

    # Do some validation...

    my $mlb = $self->mlb;

    say "=> _player_stats is calling lookup_player on active players";
    my $player = await $mlb->lookup_player($name, 'Y');

    if ( !defined $player or $player->{'totalSize'} == 0 )
    {
        say "=> _player_stats is calling lookup_player on inactive players";
        $player = await $mlb->lookup_player($name, 'N');
    }

    say Dumper($player);
    if ( !defined $player or $player->{'totalSize'} == 0 )
    {
        $discord->send_message($channel, "No results.");
        return undef;
    }

    say "=> _player_stats is calling _raw_stats";
    my $stats = await $mlb->player_stats
    ({
        id => $player->{'row'}{'player_id'},
        game_type => 'R',
        career => $career,
        group => $group,
        season => $season,
    });

    my $size = $stats->{'totalSize'};
    say "=> _player_stats totalSize=$size";
    
    # Row is not returned as an array if there is only one result.
    # So in that case, make it an array of one element.
    my @row = $size == 1 ? ($stats->{'row'}) : @{$stats->{'row'}};
    my $maxcols = 3; # Show results for three teams at a time.
    $maxcols = 1 if $group eq 'pitching' and defined $season; # Too many stats, will max out discord message length with more than one col.

    if ( $size > 0 ) 
    {
        my $stats;

        say "=> _player_stats size=" . scalar @row;
        while (scalar @row)
        {
            my @s = splice @row, 0, $maxcols;
            say "=> _player_stats splice=@s";

            say "=> _player_stats calling _format_stats";
            my $table = $self->_format_stats
            ({
                player => $player,
                stats => \@s,
                career => $career,
                season => $season,
                group => $group,
            });

            $discord->send_message($channel, $table);
        }
    }
    else
    {
        $discord->send_message($channel, "No $group stats.");
    }
};

sub _format_stats
{
    my ($self, $params) = @_;

    my $player = $params->{'player'};
    my $stats = $params->{'stats'};
    my $career = $params->{'career'};
    my $season = $params->{'season'};
    my $group = $params->{'group'};

    say "=> _format_stats got all args";


    my $mlb = $self->mlb;
    my $player_id = $player->{'row'}{'player_id'};
    my $player_name = $player->{'row'}{'name_display_first_last'};
    say "=> _format_stats player_name=$player_name";
    say "=> _format_stats player_id=$player_id";
    
    say "=> _format_stats size=" . scalar @$stats;
    if ( scalar @$stats )
    {
        my $group_str = $career ? "Career " : "$season ";
        $group_str .= ucfirst $group;

        say "=> _format_stats is calling _ascii_table";
        my $table = $self->_ascii_table($stats, "$player_name\n$group_str");
        say "=> _format_stats has a table: ";
        say $table;
        my $msg = '```' . "\n" . $table . "\n" . '```';
        say "=> _format_stats has a message of size " . length $msg . " characters";

        return $msg;
    }
    else
    {
        return undef;
    }

}


sub _ascii_table
{
    my ($self, $stats, $heading) = @_;

    my $size = scalar @$stats;
    # Don't do anything if we weren't provided any stats.
    return undef unless defined $size and $size > 0;

    my $t = Text::ASCIITable->new({ headingText => $heading });

    # Columns
    my @cols = ("Stats");
    foreach (0..$size-1)
    {
        my $team = $stats->[$_]{'team_short'};
        push @cols, $team;
    }
    $t->setCols(@cols);

    # Rows
    my @rows = sort keys %{$stats->[0]};

    foreach my $row (@rows)
    {
        next if $row =~ /(team|league|player_id|sport|end_date)/;
        my @arr = ("$row");
        push @arr, $stats->[$_]{$row} foreach (0..$size-1);
        $t->addRow(@arr);
    }

    # Align cols
    $t->alignCol($cols[0],'left');
    foreach (1..$size)
    {
        $t->alignCol($cols[$_],'right');
    }

    print $t;

    return $t;
}



__PACKAGE__->meta->make_immutable;

1;
