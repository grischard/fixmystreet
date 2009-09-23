#!/usr/bin/perl -w
#
# Cobrand.t:
# Tests for the cobranding functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Cobrand.t,v 1.11 2009-09-23 11:31:32 louise Exp $
#

use strict;
use warnings;
use Test::More tests => 38;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Cobrand;
use MockQuery;

sub test_site_restriction { 
    my $q  = new MockQuery('mysite');
    my ($site_restriction, $site_id) = Cobrand::set_site_restriction($q);
    like($site_restriction, qr/ and council = 1 /, 'should return result of cobrand module site_restriction function');
    ok($site_id == 99, 'should return result of cobrand module site_restriction function');    
    
    $q = new MockQuery('nosite');
    ($site_restriction, $site_id) = Cobrand::set_site_restriction($q);
    ok($site_restriction eq '', 'should return "" and zero if no module exists' );
    ok($site_id == 0, 'should return "" and zero if no module exists');
}

sub test_form_elements {
    my $q  = new MockQuery('mysite');
    my $element_html = Cobrand::form_elements('mysite', 'postcodeForm', $q);
    ok($element_html eq 'Extra html', 'should return result of cobrand module element_html function') or diag("Got $element_html");

    $element_html = Cobrand::form_elements('nosite', 'postcodeForm', $q);
    ok($element_html eq '', 'should return an empty string if no cobrand module exists') or diag("Got $element_html");
}

sub test_disambiguate_location {
    my $q  = new MockQuery('mysite');
    my $s = 'London Road';
    $s = Cobrand::disambiguate_location('mysite', $s, $q);
    ok($s eq 'Specific Location', 'should return result of cobrand module disambiguate_location function') or diag("Got $s");;
    
    $q = new MockQuery('nosite');
    $s = 'London Road';
    $s = Cobrand::disambiguate_location('nosite', $s, $q);
    ok($s eq 'London Road', 'should return location string as passed if no cobrand module exists') or diag("Got $s");
  
}

sub test_cobrand_handle {
    my $cobrand = 'mysite';
    my $handle = Cobrand::cobrand_handle($cobrand);
    like($handle->site_name(), qr/mysite/, 'should get a module handle if Util module exists for cobrand');
    $cobrand = 'nosite';    
    $handle = Cobrand::cobrand_handle($cobrand);
    ok($handle == 0, 'should return zero if no module exists');
}

sub test_cobrand_page {
    my $q  = new MockQuery('mysite');
    # should get the result of the page function in the cobrand module if one exists
    my ($html, $params) = Cobrand::cobrand_page($q);
    like($html, qr/A cobrand produced page/, 'cobrand_page returns output from cobrand module'); 

    # should return 0 if no cobrand module exists
    $q  = new MockQuery('mynonexistingsite');
    ($html, $params) = Cobrand::cobrand_page($q);
    is($html, 0, 'cobrand_page returns 0 if there is no cobrand module'); 
    return 1;

}

sub test_extra_problem_data {
    my $cobrand = 'mysite'; 
    my $q = new MockQuery($cobrand);
   
    # should get the result of the page function in the cobrand module if one exists
    my $cobrand_data = Cobrand::extra_problem_data($cobrand, $q);
    ok($cobrand_data eq 'Cobrand problem data', 'extra_problem_data should return data from cobrand module') or diag("Got $cobrand_data");

    # should return an empty string if no cobrand module exists
    $q = new MockQuery('nosite');
    $cobrand_data = Cobrand::extra_problem_data('nosite', $q);
    ok($cobrand_data eq '', 'extra_problem_data should return an empty string if there is no cobrand module') or diag("Got $cobrand_data");
}

sub test_extra_update_data {
    my $cobrand = 'mysite';
    my $q = new MockQuery($cobrand);
   
    # should get the result of the page function in the cobrand module if one exists
    my $cobrand_data = Cobrand::extra_update_data($cobrand, $q);
    ok($cobrand_data eq 'Cobrand update data', 'extra_update_data should return data from cobrand module') or diag("Got $cobrand_data");

    # should return an empty string if no cobrand module exists
    $q = new MockQuery('nosite');
    $cobrand_data = Cobrand::extra_update_data('nosite', $q);
    ok($cobrand_data eq '', 'extra_update_data should return an empty string if there is no cobrand module') or diag("Got $cobrand_data");
}

sub test_base_url {
    my $cobrand = 'mysite';

    # should get the result of the page function in the cobrand module if one exists
    my $base_url = Cobrand::base_url($cobrand);
    is('http://mysite.example.com', $base_url, 'base_url returns output from cobrand module');

    # should return the base url from the config if there is no cobrand module
    $cobrand = 'nosite';
    $base_url = Cobrand::base_url($cobrand);
    is(mySociety::Config::get('BASE_URL'), $base_url, 'base_url returns config base url if no cobrand module');

}

sub test_base_url_for_emails {
    my $cobrand = 'mysite';    

    # should get the results of the base_url_for_emails function in the cobrand module if one exists
    my $base_url = Cobrand::base_url_for_emails($cobrand);
    is('http://mysite.foremails.example.com', $base_url, 'base_url_for_emails returns output from cobrand module') ;

    # should return the result of Cobrand::base_url otherwise
    $cobrand = 'nosite';
    $base_url = Cobrand::base_url_for_emails($cobrand);
    is(mySociety::Config::get('BASE_URL'), $base_url, 'base_url_for_emails returns config base url if no cobrand module');

}

sub test_extra_params { 
    my $cobrand = 'mysite';    
    my $q = new MockQuery($cobrand);

    # should get the results of the extra_params function in the cobrand module if one exists
    my $extra_params = Cobrand::extra_params($cobrand, $q);
    is($extra_params, 'key=value', 'extra_params returns output from cobrand module') ;

    # should return an empty string otherwise
    $cobrand = 'nosite';
    $extra_params = Cobrand::extra_params($cobrand, $q);
    is($extra_params, '', 'extra_params returns an empty string if no cobrand module');
    
}

sub test_header_params {
    my $cobrand = 'mysite';
    my $q = new MockQuery($cobrand);

    # should get the results of the header_params function in the cobrand module if one exists
    my $header_params = Cobrand::header_params($cobrand, $q);
    is_deeply($header_params, {'key' => 'value'}, 'header_params returns output from cobrand module') ;

    # should return an empty string otherwise
    $cobrand = 'nosite';
    $header_params = Cobrand::header_params($cobrand, $q);
    is_deeply($header_params, {}, 'header_params returns an empty hash ref if no cobrand module');
}

sub test_root_path_pattern {
    my $cobrand = 'mysite';
    my $root_path_pattern = Cobrand::root_path_pattern($cobrand);
 
    # should get the results of the root_path_pattern function in the cobrand module if one exists
    is($root_path_pattern, 'root path pattern', 'root_path_pattern returns output from cobrand module');

    # should return an empty regex string otherwise
    $cobrand = 'nosite';
    $root_path_pattern = Cobrand::root_path_pattern($cobrand);
    is($root_path_pattern, '//g', 'root_path_pattern returns an empty regex string if no cobrand module');
}

ok(test_cobrand_handle() == 1, 'Ran all tests for the cobrand_handle function');
ok(test_cobrand_page() == 1, 'Ran all tests for the cobrand_page function');
ok(test_site_restriction() == 1, 'Ran all tests for the site_restriction function');
ok(test_base_url() == 1, 'Ran all tests for the base url');
ok(test_disambiguate_location() == 1, 'Ran all tests for disambiguate location');
ok(test_form_elements() == 1, 'Ran all tests for form_elements');
ok(test_base_url_for_emails() == 1, 'Ran all tests for base_url_for_emails');
ok(test_extra_problem_data() == 1, 'Ran all tests for extra_problem_data');
ok(test_extra_update_data() == 1, 'Ran all tests for extra_update_data');
ok(test_extra_params() == 1, 'Ran all tests for extra_params');
ok(test_header_params() == 1, 'Ran all tests for header_params');
ok(test_root_path_pattern() == 1, 'Ran all tests for root_path_pattern');
