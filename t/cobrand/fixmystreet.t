use FixMyStreet::Script::UpdateAllReports;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok( 2514, 'Birmingham' );

my $data;
FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $data = FixMyStreet::Script::UpdateAllReports::generate_dashboard($body);
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    TEST_DASHBOARD_DATA => $data,
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    # Not logged in, redirected
    $mech->get_ok('/reports/Birmingham/summary');
    is $mech->uri->path, '/about/council-dashboard';

    $mech->submit_form_ok({ with_fields => { username => 'someone@somewhere.example.org' }});
    $mech->content_contains('We will be in touch');
    # XXX Check email arrives

    $mech->log_in_ok('someone@somewhere.example.org');
    $mech->get_ok('/reports/Birmingham/summary');
    is $mech->uri->path, '/about/council-dashboard';
    $mech->content_contains('Ending in .gov.uk');

    $mech->submit_form_ok({ with_fields => { name => 'Someone', username => 'someone@birmingham.gov.uk' }});
    $mech->content_contains('Now check your email');
    # XXX Check email arrives, click link

    $mech->log_in_ok('someone@birmingham.gov.uk');
    # Logged in, redirects
    $mech->get_ok('/about/council-dashboard');
    is $mech->uri->path, '/reports/Birmingham/summary';
    $mech->content_contains('Top 5 wards');

};

END {
    done_testing();
}
