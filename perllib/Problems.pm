#!/usr/bin/perl
#
# Problems.pm:
# Various problem report database fetching related functions for FixMyStreet.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Problems.pm,v 1.16 2009-07-01 13:02:07 louise Exp $
#

package Problems;

use strict;
use Memcached;
use mySociety::DBHandle qw/dbh select_all/;
use mySociety::Locale;
use mySociety::Web qw/ent/;
use mySociety::MaPit;

my $site_restriction = '';
my $site_key = 0;
sub set_site_restriction {
    my $site = shift;
    my @cats = Page::scambs_categories();
    my $cats = join("','", @cats);
    $site_restriction = " and council=2260 and category in
        ('$cats') "
        if $site eq 'scambs';
    $site_key = 1;
}

# Front page statistics

sub recent_fixed {
    my $key = "recent_fixed:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = dbh()->selectrow_array("select count(*) from problem
            where state='fixed' and lastupdate>ms_current_timestamp()-'1 month'::interval
            $site_restriction");
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub number_comments {
    my $key = "number_comments:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        if ($site_restriction) {
            $result = dbh()->selectrow_array("select count(*) from comment, problem
                where comment.problem_id=problem.id and comment.state='confirmed'
                $site_restriction");
        } else {
            $result = dbh()->selectrow_array("select count(*) from comment
                where state='confirmed'");
        }
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub recent_new {
    my $interval = shift;
    (my $key = $interval) =~ s/\s+//g;
    $key = "recent_new:$site_key:$key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = dbh()->selectrow_array("select count(*) from problem
            where state in ('confirmed','fixed') and confirmed>ms_current_timestamp()-'$interval'::interval
            $site_restriction");
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

# Front page recent lists

sub recent_photos {
    my ($num, $e, $n, $dist) = @_;
    my $probs;
    if ($e) {
        my $key = "recent_photos:$site_key:$num:$e:$n:$dist";
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = select_all("select id, title
                from problem_find_nearby(?, ?, ?) as nearby, problem
                where nearby.problem_id = problem.id
                and state in ('confirmed', 'fixed') and photo is not null
                $site_restriction
                order by confirmed desc limit $num", $e, $n, $dist);
            Memcached::set($key, $probs, 3600);
        }
    } else {
        my $key = "recent_photos:$site_key:$num";
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = select_all("select id, title from problem
                where state in ('confirmed', 'fixed') and photo is not null
                $site_restriction
                order by confirmed desc limit $num");
            Memcached::set($key, $probs, 3600);
        }
    }
    my $out = '';
    foreach (@$probs) {
        my $title = ent($_->{title});
        $out .= '<a href="/report/' . $_->{id} .
            '"><img border="0" height="100" src="/photo?tn=1;id=' . $_->{id} .
            '" alt="' . $title . '" title="' . $title . '"></a>';
    }
    return $out;
}

sub recent {
    my $key = "recent:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = select_all("select id,title from problem
            where state in ('confirmed', 'fixed')
            $site_restriction
            order by confirmed desc limit 5");
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

# Problems around a location

sub around_map {
    my ($min_e, $max_e, $min_n, $max_n, $interval) = @_;
    mySociety::Locale::in_gb_locale { select_all(
        "select id,title,easting,northing,state from problem
        where state in ('confirmed', 'fixed')
            and easting>=? and easting<? and northing>=? and northing<? " .
        ($interval ? " and ms_current_timestamp()-lastupdate < '$interval'::interval" : '') .
        " $site_restriction
        order by created desc", $min_e, $max_e, $min_n, $max_n);
    };
}

sub nearby {
    my ($dist, $ids, $limit, $mid_e, $mid_n, $interval) = @_;
    mySociety::Locale::in_gb_locale { select_all(
        "select id, title, easting, northing, distance, state
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id " .
        ($interval ? " and ms_current_timestamp()-lastupdate < '$interval'::interval" : '') .
        " and state in ('confirmed', 'fixed')" . ($ids ? ' and id not in (' . $ids . ')' : '') . "
        $site_restriction
        order by distance, created desc limit $limit", $mid_e, $mid_n);
    }
}

sub fixed_nearby {
    my ($dist, $mid_e, $mid_n) = @_;
    mySociety::Locale::in_gb_locale { select_all(
        "select id, title, easting, northing, distance
        from problem_find_nearby(?, ?, $dist) as nearby, problem
        where nearby.problem_id = problem.id and state='fixed'
        $site_restriction
        order by lastupdate desc", $mid_e, $mid_n);
    }
}

# Fetch an individual problem

sub fetch_problem {
    my $id = shift;
    dbh()->selectrow_hashref(
        "select id, easting, northing, council, category, title, detail, photo,
        used_map, name, anonymous, extract(epoch from confirmed) as time,
        state, extract(epoch from whensent-confirmed) as whensent,
        extract(epoch from ms_current_timestamp()-lastupdate) as duration, service
        from problem where id=? and state in ('confirmed','fixed', 'hidden')
        $site_restriction", {}, $id
    );
}

# API functions

sub problems_matching_criteria{
    my ($criteria) = @_;
    my $problems = select_all(
        "select title, easting, northing, council, category, detail, name, anonymous,
        confirmed, whensent, service
        from problem
        $criteria
	$site_restriction");

    my @councils;
    foreach my $problem (@$problems){
        if ($problem->{anonymous} == 1){
            $problem->{name} = '';
        }
	if ($problem->{service} == ''){
            $problem->{service} = 'Web interface';
        }
        if ($problem->{council}) {
            $problem->{council} =~ s/\|.*//g;
	    my @council_ids = split /,/, $problem->{council};
            push(@councils, @council_ids);
	    $problem->{council} = \@council_ids;
	}
    }
    my $areas_info = mySociety::MaPit::get_voting_areas_info(\@councils);
    foreach my $problem (@$problems){
    	if ($problem->{council}) {
             my @council_names = map { $areas_info->{$_}->{name}} @{$problem->{council}} ;
	     $problem->{council} = join(' and ', @council_names);
    	}
    }
    return $problems;
}

sub fixed_in_interval {
    my ($start_date, $end_date) = @_; 
    my $criteria = "where state='fixed' and date_trunc('day',lastupdate)>='$start_date' and 
date_trunc('day',lastupdate)<='$end_date'";
    return problems_matching_criteria($criteria);
}

sub created_in_interval {
    my ($start_date, $end_date) = @_; 
    my $criteria = "where state='confirmed' and date_trunc('day',created)>='$start_date' and 
date_trunc('day',created)<='$end_date'";
    return problems_matching_criteria($criteria);
}
1;
