package Command::MLB;
use feature 'say';

use Moo;
use strictures 2;

use Mojo::Discord;
use Mojo::AsyncAwait;
use Bot::Goose;
use Component::MLB;
use Text::ASCIITable;
use Math::Expression;
use Data::Dumper;

use namespace::clean;

has bot             => ( is => 'rw', required => 1 );
has discord         => ( is => 'rw' );
has mlb             => ( is => 'rw', default => sub { Component::MLB->new() } );

# Sorting and combining rules provided by @NYVGF - Thanks John!
has sorting         => ( is => 'ro', default => sub
{
    {
        'Career Hitting'  => [ qw(g ab h d t hr tb r rbi bb ibb so bb_so hbp sf sac gidp sb cs sb_per go ao go_ao avg obp slg ops iso) ],
        'Season Hitting'  => [ qw(g ab tpa h d t hr xbh tb r rbi bb ibb so hbp roe sf sac gidp gidp_opp lob go ao go_ao hfly hgnd hldr hpop sb cs avg obp slg ops babip ppa np wo) ],
        'Career Fielding' => [ qw(position position_txt g gs inn tc po a e dp sb cs pb fpct rf) ],
        'Season Fielding' => [ qw(position position_txt g gs inn tc po a e dp sb cs pb cwp fpct rf) ],
        'Career Pitching' => [ qw(w l era g gs cg sho sv svo ir irs ip tbf ab h r er hr hr_9 so so_9 so_per bb bb_9 bb_per ibb so_bb hb gidp go ao go_ao wp bk avg whip np s) ],
        'Season Pitching' => [ qw(w l wpct era g gs qs cg sho hld sv svo gf bq bqs ir irs ip tbf ab h h9 r er db tr hr hr9 so k9 bb bb9 ibb kbb hb gidp gidp_opp go ao go_ao hfly hgnd hldr hpop wp sb cs pk bk avg obp slg ops babip whip rs9 ppa pip pgs np s spct) ],
    }
});

# Each field should pair with a mathematical expression used to combine this field into a career total.
has combine         => ( is => 'ro', default => sub
{
    { 
        'hitting'       => {
            'g'     => 'g           := sum_args(g_list)',
            'ab'    => 'ab          := sum_args(ab_list)',
            'h'     => 'h           := sum_args(h_list)',
            'd'     => 'd           := sum_args(d_list)',
            't'     => 't           := sum_args(t_list)',
            'hr'    => 'hr          := sum_args(hr_list)',
            'tb'    => 'tb          := sum_args(tb_list)',
            'r'     => 'r           := sum_args(r_list)',
            'rbi'   => 'rbi         := sum_args(rbi_list)',
            'bb'    => 'bb          := sum_args(bb_list)',
            'ibb'   => 'ibb         := sum_args(ibb_list)',
            'so'    => 'so          := sum_args(so_list)',
            'bb_so' => 'bb_so       := (bb + ibb) / so',
            'hbp'   => 'hbp         := sum_args(hbp_list)',
            'sf'    => 'sf          := sum_args(sf_list)',
            'sac'   => 'sac         := sum_args(sac_list)',
            'gidp'  => 'gidp        := sum_args(gidp_list)',
            'sb'    => 'sb          := sum_args(sb_list)',
            'cs'    => 'cs          := sum_args(cs_list)',
            'sb_per'=> 'sb_percent  := sb / (sb + cs)',
            'go'    => 'go          := sum_args(go_list)',
            'ao'    => 'ao          := sum_args(ao_list)',
            'go_ao' => 'go_ao       := go / ao', 
            'avg'   => 'avg         := h / ab',    # Batting Average is the number of hits (H) divided by number of at-bats (AB)
            'obp'   => 'obp         := (h + bb + hbp) / (ab + bb + hbp + sf)', # On Base Percentage is Hits (H) + Walks (BB) + Hit By Pitch (HBP) all over At Bats (AB) + Walks (BB) + Hit By Pitch (HBP) + Sacrifice Flies (SF)
            'slg'   => 'slg         := (h + d + (t*2) + (hr*3))/ab', # Slugging is Hits (H) + Doubles (D) + 2x Triples (T) + 3x Home Runs (HR), all divided by At Bats (AB)
            'ops'   => 'ops         := obp + slg', # On Base Percentage + Slugging
            'iso'   => 'iso_avg     := slg - avg',
        },
        'pitching'      => {
            'w'     => 'w           := sum_args(w_list)',
            'l'     => 'l           := sum_args(l_list)',
            'era'   => 'era         := (sum_args(er_list) / sum_args(ip_list)) * 9', # Earned Runs Average = (Earned Runs / Innings Pitched) * 9
            'g'     => 'g           := sum_args(g_list)',
            'gs'    => 'gs          := sum_args(gs_list)',
            'cg'    => 'cg          := sum_args(cg_list)',
            'sho'   => 'sho         := sum_args(sho_list)',
            'sv'    => 'sv          := sum_args(sv_list)',
            'svo'   => 'svo         := sum_args(svo_list)',
            'ir'    => 'ir          := sum_args(ir_list)',
            'irs'   => 'irs         := sum_args(irs_list)',
            'ip'    => 'ip          := sum_innings(ip_list)', # 0.3 = 1 inning pitched
            'tbf'   => 'tbf         := sum_args(tbf_list)',
            'ab'    => 'ab          := sum_args(ab_list)',
            'h'     => 'h           := sum_args(h_list)',
            'r'     => 'r           := sum_args(r_list)',
            'er'    => 'er          := sum_args(er_list)',
            'hr'    => 'hr          := sum_args(hr_list)',
            'hr_9'  => 'hr_9        := (hr * 9) / ip',
            'so'    => 'so          := sum_args(so_list)',
            'so_9'  => 'so_9        := (so * 9) / ip',
            'so_per'=> 'so_percent  := so / tbf',
            'bb'    => 'bb          := sum_args(bb_list)',
            'bb_9'  => 'bb_9        := (bb * 9) / ip',
            'bb_per'=> 'bb_percent  := bb / tbf',
            'ibb'   => 'ibb         := sum_args(ibb_list)',
            'so_bb' => 'so_bb       := so / (bb + ibb)',
            'hb'    => 'hb          := sum_args(hb_list)',
            'gidp'  => 'gidp        := sum_args(gidp_list)',
            'go'    => 'go          := sum_args(go_list)',
            'ao'    => 'ao          := sum_args(ao_list)',
            'go_ao' => 'go_ao       := sum_args(go_ao_list)',
            'wp'    => 'wp          := sum_args(wp_list)',
            'bk'    => 'bk          := sum_args(bk_list)',
            'avg'   => 'avg         := sum_args(avg_list)',
            'whip'  => 'whip        := sum_args(whip_list)',
            'np'    => 'np          := sum_args(np_list)',
            's'     => 's           := sum_args(s_list)',
        },
        'fielding'      => {
            'g'     => 'g_sum       := sum_args(g_list)',
            'gs'    => 'gs_sum      := sum_args(gs_list)',
            'inn'   => 'inn_sum     := sum_innings(inn_list)', # 0.3 = 1 inning
            'tc'    => 'tc_sum      := sum_args(tc_list)',
            'po'    => 'po_sum      := sum_args(po_list)',
            'a'     => 'a_sum       := sum_args(a_list)',
            'e'     => 'e_sum       := sum_args(e_list)',
            'dp'    => 'dp_sum      := sum_args(dp_list)',
            'sb'    => 'sb_sum      := sum_args(sb_list)',
            'cs'    => 'cs_sum      := sum_args(cs_list)',
            'pb'    => 'pb_sum      := sum_args(pb_list)',
            'fpct'  => 'fpct_avg    := avg_args(fpct_list)',
            'rf'    => 'rf_avg      := avg_args(fpct_rf)',
        },
    }
});

# sprintf formatting for various fields when they get combined
has round           => ( is => 'ro', default => sub
{
    {
        'go_ao'     => '%0.2f',
        'avg'       => '%0.3f',
        'obp'       => '%0.3f',
        'slg'       => '%0.3f',
        'ops'       => '%0.3f',
        'iso'       => '%0.3f',
        'hr_9'      => '%02.2f',
        'so_9'      => '%02.2f',
        'so_per'    => '%02.2f',
        'bb_9'      => '%02.2f',
        'bb_per'    => '%02.2f',
        'so_bb'     => '%0.2f',
        'era'       => '%0.2f',
        'whip'      => '%0.3f',
        'bb_so'     => '%0.2f',
        'sb_per'    => '%0.2f',
    }
});

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

# This is the main player stats sub.
# It parses arguments, fetches the correct stats, and combines/sorts them into an ASCII table
# and writes that to the discord channel.
# 
# It leverages _format_stats to do some of this work.
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
    my $group = ( $args =~/(hitting|pitching|fielding)/i ? lc $1 : 'hitting');
    my $name = $args;
    $name =~ s/ ?$match// if defined $match; # Remove the match number
    $name =~ s/ ?$season// if defined $season; # Remove the year
    $name =~ s/ ?$group//i if defined $group; # Remove the group
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
    $maxcols = scalar @row if $career; # This will need to be modified when the option to show per-team results is re-introduced.

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

# This sub is resposible sorting, combining, and prettifying stats, returning a discord-friendly formatted string.
# It leverages _ascii_table and _career_totals to do some of this work.
sub _format_stats
{
    my ($self, $params) = @_;

    my $player = $params->{'player'};
    my $stats = $params->{'stats'};
    my $career = $params->{'career'};
    my $season = $params->{'season'};
    my $group = $params->{'group'};
    my $combine = $params->{'combine'} // 1;    # This option should allow the user to decide whether to combine career stats into a "career total" or keep it per-team.

    say "=> _format_stats got all args";

    # Each call to _format_stats requires its own Math::Expression object or there will be variable collisions.
    my $math = Math::Expression->new();
    
    # Make sure Math::Expression knows about additional functions we have defined.
    $math->{Functions}->{sum_args} = 1;
    $math->{Functions}->{avg_args} = 1;
    $math->{Functions}->{sum_innings} = 1;
    $math->SetOpt(
        ExtraFuncEval => \&_math_functions,
        AutoInit => 1,
    );

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
        my $table;
        
        # Combine stats if applicable
        if ( $career and $combine )
        {
            say "=> _format_stats is calling _career_totals";
            my $combined_stats = $self->_career_totals($stats, $math, $group);
            say "=> _format_stats is calling _ascii_table";
            $table = $self->_ascii_table($combined_stats, "$player_name\n$group_str");
        }
        else
        {
            say "=> _format_stats is calling _ascii_table";
            $table = $self->_ascii_table($stats, "$player_name\n$group_str");
        }

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

# This sub generates and returns an ASCII table of the stats provided to it.
# It uses the provided heading string to determine sorting rules.
sub _ascii_table
{
    my ($self, $stats, $heading) = @_;

    my $size = scalar @$stats;
    say "=> _ascii_table size=$size";
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

    # Get the sorting order for this table
    my $sort_cat = $heading; 
    $sort_cat =~ s/^.*\n//;
    $sort_cat =~ s/\d+/Season/;
    say "=> _ascii_table sort_cat=$sort_cat";
    my $rows = $self->sorting->{$sort_cat};

    foreach my $row (@$rows)
    {
        my @arr = ("$row");
        push @arr, $stats->[$_]{$row} foreach (0..$size-1);
        $t->addRow(@arr);
    }

    # Align cols
    $t->alignCol($cols[0],'left');
    foreach (1..$size)
    {
        $t->alignColName($cols[$_],'right');
        $t->alignCol($cols[$_],'right');
    }

    return $t;
}

# This sub takes a hashref containing per-team career stats and totals them into a single set.
sub _career_totals
{
    my ($self, $stats, $math, $group) = @_;

    my $combined_stats = [{}];

    my $size = scalar @$stats;
    say "=> _ascii_table size=$size";
    return undef unless defined $size and $size > 0;

    my $sort_key = 'Career ' . ucfirst $group; # Key for the sorting array so we know what order to process fields in.

    # Step two, generate lists of values for each row
    foreach my $row (@{$self->sorting->{$sort_key}})
    {
        # Not all rows in the sort array will exist. Some are purely calculated.
        # Don't try to build '_list' variables for those.
        if ( exists ( $stats->[0]{$row} ) )
        {
            my $row_str = $row . "_list";
            my @arr;
            push @arr, $stats->[$_]{$row} foreach (0..$size-1);
            $math->{VarHash}->{$row_str} = [@arr];
            say "=> _career_totals $row_str = " . "@{$math->{VarHash}->{$row_str}}";
        }
    }

    # Step three, evaluate the expression for each entry and populate the combined_stats hash
    foreach my $row (@{$self->sorting->{$sort_key}})
    {
        my $expr = $self->combine->{$group}->{$row};
        say "=> _career_totals expr=$expr";

        my $val = "null";
        eval {
            $val = $math->ParseToScalar($expr);
        };
        say "=> _career_totals $row (Combined) = $val";

        # Round field?
        if ($val ne "null" and exists $self->round->{$row})
        {
            my $format = $self->round->{$row};
            $val = sprintf("$format", $val);
        }

        $combined_stats->[0]->{$row} = $val;
    }

    my $teams = scalar @$stats;
    $teams .= $teams != 1 ? " Teams" : " Team";
    $combined_stats->[0]->{team_short} = $teams;

    return $combined_stats;
}

sub _math_functions 
{
    my ($self, $tree, $fname, @arglist) = @_;
 
    if ( $fname eq 'sum_args' ) 
    {
        my $sum = 0;
        $sum += $_ for @arglist;
        return $sum;
    }

    if ( $fname eq 'avg_args' ) 
    {
        my $num = 0;
        my $total = 0;
        $total += $_ for @arglist;
        $num = $total / scalar @arglist if scalar @arglist > 0;
        return $num;
    }

    # This is a weird one.
    # Innings Pitched are returned like this:
    # 1 = 1 inning pitched = 3 outs
    # 1.1 = 1 inning + 1 out = 4 outs
    # 1.2 = 1 inning + 1 out = 5 outs
    # 2 = 2 innings pitched = 6 outs
    # This function correctly sums up a list of these values and returns the sum in the correct format.
    # eg, 1.2 + 0.2 = 2.1
    if ( $fname eq 'sum_innings' )
    {
        my $sum = 0;
        foreach my $num (@arglist)
        {
            $sum += $num;
            my $remainder = _remainder($sum, 1);
            say "=> _math_functions remainder is " . $remainder;
            $sum += 0.7 if ( $remainder >= 0.3 );    # 0.3 rounds up to the next integer.
        }
        return $sum;
    }

    # Return undef so that in built functions are scanned
    return undef;
}

# Perl does not have a remainder function and the modulo operator is an integer operation.
sub _remainder {
    my ($a, $b) = @_;
    return 0 unless $b && $a;
    return $a / $b - int($a / $b);
}

__PACKAGE__->meta->make_immutable;

1;
