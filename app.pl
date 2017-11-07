#!/usr/bin/env perl
use Mojolicious::Lite;
use YAML::XS qw/LoadFile/;
use Hash::Merge qw/merge/;
use List::Gather;
use File::chdir;
use Capture::Tiny qw/capture_stdout capture/;
use List::Util qw/first/;
use v5.24;

my $projects = {
    "Code4Health" => {
        url => 'https://opusvl-intranet/wiki/index.php/NHS_England_Code4Health_(C4H)_Infrastructure',
        dir => '/home/alastair.mcgowan/src/Code4Health/C4H-Docker/compose/c4h',
        services => [qw/admin user/],
    },
    "PREM" => {
        url => 'https://opusvl-intranet/wiki/index.php/PREM_Staging_Infrastructure',
        dir => '/home/alastair.mcgowan/src/PREM-FB11-CMS/PREM-docker/compose/prem-fb11',
        services => [qw/admin website/],
    },
    "BCA" => {
        url => 'https://opusvl-intranet/wiki/index.php/BCA_Infrastructure',
        dir => '/home/alastair.mcgowan/src/dvla/BCA/BCA-docker/compose/bca',
        services => [qw/pulsar odoo nginx/],
    },
    "Aquarius" => {
        url => 'https://opusvl-intranet/wiki/index.php/Category:Aquarius',
        dir => '/home/alastair.mcgowan/src/Aquarius/Aquarius-docker/compose/aquarius',
        services => [qw/aquarius openerp smtp/],
    },
};

get '/' => sub {
    my $c = shift;

    my @projects = sort keys %$projects;

    $c->stash(projects => \@projects);
    $c->render;
} => 'index';

get '/p/:project' => sub {
    my $c = shift;

    my $project = $c->param('project');
    exists $projects->{$project} or return $c->render(template => 'does_not_exist');

    my $pdata = project_data($project);
    $c->render( json => $pdata );
};

post '/p/:project/docker' => sub {
    my $c = shift;

    my $project = $c->param('project');

    exists $projects->{$project} or return $c->render(template => 'does_not_exist');

    my $up_or_down = $c->param('up_or_down');
    local $CWD = $projects->{$project}->{dir};

    if ($up_or_down eq 'Up') {
        capture { system qw/docker-compose --no-ansi up -d/ };
    }
    else {
        capture { system qw/docker-compose --no-ansi stop/ };
    }

    $c->redirect_to('/');
};

my @dockerfile_order = qw/
    docker-compose.yml
    docker-compose.override.yml
    docker-compose.dev.yml
    docker-compose.dev.local.yml
    docker-compose.open-ports.yml
/;

sub project_data {
    my $project = shift;
    my $dir = $projects->{$project}->{dir};
    my $config = merge_yamls($dir);
    my @ps = map { [ split /\s{2,}/ ] } split /\n/, get_ps($dir);

    my $service_data = [ gather {
        for my $s ($projects->{$project}->{services}->@*) {
            my $ports = $config->{$s}->{ports}->[0];
            my ($p) = split /:/, $ports;

            my $ps = first { $_->[0] =~ /${s}_\d/ } @ps;
            next unless $ps;

            take {
                url => "http://dev-05:$p",
                up => $ps->[2] eq 'Up',
                container => $ps->[0],
            };
        }
    }];
    
    return (
        url => $projects->{$project}->{url},
        services => $service_data
    );
}

sub merge_yamls {
    my $dir = shift;

    my $config = {};
    for my $f (@dockerfile_order) {
        next unless -f "$dir/$f";
        my $c = LoadFile("$dir/$f");
        $config = merge( $config, $c->{services} );
    }

    return $config;
}

sub get_ps {
    my $dir = shift;

    local $CWD = $dir;

    my $ps = capture_stdout { system qw/docker-compose ps/ };
}

app->secrets(['does this work?']);
app->start;

__DATA__
@@index.html.ep
<!DOCTYPE html>
<html>
    <head>
        <link rel="stylesheet" href="/normalize.css">
        <link rel="stylesheet" href="/skeleton.css">
        <link rel="stylesheet" href="/app.css">
        <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
        <script src="/app.js"></script>
    </head>
    <body>
        <div class="container">
            <h1>Al's computer. Go away.</h1>
            <section class="row">
                <h1>Search</h1>
                <article class="seven columns">
                    <h2>Wiki</h2>
                    <div class="row">
                        <form method="post" action="https://opusvl-intranet/wiki/index.php">
                            <input type="text" name="search" class="eight columns"/>
                            <input type="submit" name="go" value="Go" class="four columns" />
                            <input type="hidden" name="title" value="Special:Search"/>
                        </form>
                    </div>
                    
                    <h2>Tracker</h2>
                    <div class="row">
                        <form method="get" action="https://secure.opusvl.com/support/view.php">
                            <input name="id" type="number" increment="1" class="eight columns" />
                            <input type="submit" value="Go" class="four columns" />
                        </form>
                    </div>
                </article>
                <article class="four columns">
                    <p>
                        <a href="http://intranet/modules/timelogger/entries">Timelogger</a>
                    </p>
                </article>
            </section>
            <section>
                <h1>Projects</h1>
                % for my $project (@$projects) {
                    <article class="project">
                        <h2 class="field field-name"><%= $project %></h2>

                        <div class="loading"></div>
                        <div class="service record record-service row template">
                            <div class="field field-container-name seven columns">
                            </div>
                            <div class="field field-container-status two columns" >
                            </div>
                            <div class="three columns field-url">
                                <a></a>
                            </div>
                        </div>
                    </article>
                % }
            </section>
        </div>
    </body>
</html>
