package Koha::Plugin::Com::PTFSEurope::Browzine::Api;

use Modern::Perl;
use strict;
use warnings;

use JSON qw( decode_json );
use HTTP::Request::Common;

use Mojo::Base 'Mojolicious::Controller';
use Koha::Plugin::Com::PTFSEurope::Browzine;

sub search {

    # Validate what we've received
    my $c = shift->openapi->valid_input or return;

    my $base_url = "https://public-api.thirdiron.com/public/v1/libraries";

    # Check we've got an API key and library ID to append to the API call
    # Error if not
    my $plugin = Koha::Plugin::Com::PTFSEurope::Browzine->new();
    my $config = decode_json($plugin->retrieve_data('browzine_config') || '{}');
    my $key = $config->{ill_browzine_api_key};
    my $library_id = $config->{ill_browzine_library_id};
    $key =~ s/^\s+|\s+$//g;
    $library_id =~ s/^\s+|\s+$//g;
    if (!$key || length $key == 0 || !$library_id || length $library_id == 0) {
        _return_response({ error => 'API key and library ID must be configured'});
    }

    my $doi = $c->validation->param('doi');
    my $pmid = $c->validation->param('pmid');

    my $using = {};
    if ($pmid && length $pmid > 0) {
        $using->{identifier} = 'pmid';
        $using->{value} = $pmid;
    } elsif ($doi && length $doi > 0) {
        $using->{identifier} = 'doi';
        $using->{value} = $doi;
    }

    if (scalar keys %{$using} == 0) {
        _return_response({ error => 'Must supply either DOI or PMID' });
    }

    my $ua = LWP::UserAgent->new;
    $ua->default_header( 'Authorization' => "Bearer $key" );
    my $response = $ua->request(GET "${base_url}/$library_id/articles/$using->{identifier}/$using->{value}");

    if ( $response->is_success ) {
        _return_response({ success => decode_json($response->decoded_content) }, $c);
    } else {
        _return_response(
            {
                error => $response->status_line,
                errorcode => $response->code
            },
            $c
        );

    }        
}

sub _return_response {
    my ( $response, $c ) = @_;
    return $c->render(
        status => $response->{errorcode} || 200,
        openapi => {
            results => {
                result => $response->{success} || [],
                errors => $response->{error} || []
            }
        }
    );
}

1;
