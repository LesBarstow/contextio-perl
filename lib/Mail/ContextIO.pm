package Mail::ContextIO;

# This code is a port of the PHP Context.IO API to Perl, with
# minor changes

# Code sanity
use 5.006;
use strict;
use warnings;
use Carp;

=head1 NAME

Mail::ContextIO - API access to e-mail via Context.io
(see: http://www.context.io for access details)

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module provides full API access to e-mail via the Context.io
REST API service.

=cut

# Required external modules
use Net::OAuth;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Cwd qw(abs_path);
use URI::Escape;
use JSON;

# Related modules
use Mail::ContextIO::Response;

=head1 SUBROUTINES/METHODS

Unless otherwise stated, method calls return a
Mail::ContextIO::Response object, which can be queried
for success or failure and data contents

Example:
    $res = $cio->listAccounts();
    if ( !$res ) {
        $res = $cio->getLastResponse();
        print STDERR "Failure: " . $res->getHttpCode() . "\n";
    } else {
        $myData = $res->getData();
    }

=head2 new

Instantiate a new Mail::ContextIO object. Your OAuth consumer key and secret
can be found under the "settings" tab of the developer console. Returns the
new object.

Example: $cio = Mail::ContextIO->new( $key, $secret );
   * $key: Your Context.IO OAuth consumer key
   * $secret : Your Context.IO OAuth consumer secret

(see L<https://console.context.io/#settings>)

=cut
sub new {
    my $type = shift;
    my $class = ref $type || $type;
    my ($key, $secret) = @_;
    my $self = {
        'responseHeaders'=> undef,
        'requestHeaders' => undef,
        'oauthKey' => $key,
        'oauthSecret' => $secret,
        'saveHeaders' => 0,
        'ssl' => 1,
        'endPoint' => 'api.context.io',
        'apiVersion' => '2.0',
        'lastResponse' => undef,
        'authHeaders' => 1,
    };
    bless($self, $class);
    return $self;
}

=head2 discovery

Attempts to discover IMAP settings for a given email address

Example: $res = $cio->discovery( $params );
   * $params: A string containing the e-mail address on which to
     perform automated discovery, or a hashref with key 'email' 

(see L<http://context.io/docs/2.0/discovery>)

=cut

sub discovery {
    my $self = shift;
    my $params = shift;
    if ($self->_is_string($params)) {
        $params = {'email' => $params};
    } else {
        $params = $self->_filterParams($params, ['email'], ['email']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget(undef, 'discovery?source_type=imap&email=' . $params->{'email'});
}

=head2 listConnectTokens

List OAuth tokens for an account's email sources

Example: $res = $cio->listConnectTokens( $act_id );
   * $act_id: your Context.IO account ID

(see L<http://context.io/docs/2.0/connect_tokens>)

=cut

sub listConnectTokens {
    my $self = shift;
    my $account = undef;
    $account = shift if (scalar(@_));
    return $self->HTTPget($account, 'connect_tokens');
}

=head2 getConnectToken

Retrieve details for a single OAuth token

Example: $res = $cio->getConnectToken( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing the token, or hashref with key
     'token'

(see L<http://context.io/docs/2.0/connect_tokens>)

=cut

sub getConnectToken {
    my $self = shift;
    my $account = shift;
    my $params = shift;
    if ($self->_is_string($params)) {
        $params = {'token' => $params};
    } else {
        $params = $self->_filterParams($params, ['token']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'connect_tokens/' . $params->{'token'});
}

=head2 addConnnectToken

Add a new OAuth token

Example: $res = $cio->addConnectToken( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: hashref containing at least the key 'callback_url'
     (see the documentation for other options)

(see L<http://context.io/docs/2.0/connect_tokens>)

=cut

sub addConnectToken {
    my $self = shift;
    my $account = shift;
    my $params = shift;
    $params = $self->_filterParams($params, ['service_level','email','callback_url','first_name','last_name','source_sync_all_folders','source_callback_url'], ['callback_url']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost($account, 'connect_tokens', $params);
}

=head2 deleteConnectToken

Delete an OAuth connection token

Example: $res = $cio->deleteConnectToken( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing the token, or hashref with key
     'token'

(see L<http://context.io/docs/2.0/connect_tokens>)

=cut

sub deleteConnectToken {
    my $self = shift;
    my $account = shift;
    my $params = shift;
    if ($self->_is_string($params)) {
        $params = {'token' => $params};
    } else {
        $params = $self->_filterParams($params, ['token'], ['token']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPdelete($account, 'connect_tokens/' . $params->{'token'});
}

=head2 listOAuthProviders

Example: $res = $cio->listOAuthProviders( );

(see L<http://context.io/docs/2.0/oauth_providers>)

=cut

sub listOAuthProviders {
    my $self = shift;
    return $self->HTTPget(undef, 'oauth_providers');
}

=head2 getOAuthProvider

Example: $res = $cio->getOAuthProvider( $params );
   * $params = string containing the provider consumer key, or
     a hashref with the key 'provider_consumer_key' set

(see L<http://context.io/docs/2.0/oauth_providers>)

=cut

sub getOAuthProvider {
    my $self = shift;
    my $params = shift;
    if ($self->_is_string($params)) {
        $params = {'provider_consumer_key' => $params};
    } else {
        $params = $self->_filterParams($params, ['provider_consumer_key'], ['provider_consumer_key']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget(undef, 'oauth_providers/' . $params->{'provider_consumer_key'});
}

=head2 addOAuthProvider

Example: $res = $cio->addOAuthProvider( $params );
   * $params = a hashref containing the following data:
     + 'type'
     + 'provider_consumer_key'
     + 'provider_consumer_secret'

(see L<http://context.io/docs/2.0/oauth_providers>)

=cut

sub addOAuthProvider {
    my $self = shift;
    my $params = shift;
    $params = $self->_filterParams($params, ['type','provider_consumer_key','provider_consumer_secret'], ['type','provider_consumer_key','provider_consumer_secret']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost(undef, 'oauth_providers', $params);
}

=head2 deleteOAuthProvider

Example: $res = $cio->deleteOAuthProvider( $params );
   * $params = string containing the provider consumer key, or
     a hashref with the key 'provider_consumer_key' set

(see L<http://context.io/docs/2.0/oauth_providers>)

=cut

sub deleteOAuthProvider {
    my $self = shift;
    my $params = shift;
    if ($self->_is_string($params)) {
        $params = {'provider_consumer_key' => $params};
    }
    else {
        $params = $self->_filterParams($params, ['provider_consumer_key'], ['provider_consumer_key']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPdelete(undef, 'oauth_providers/' . $params->{'provider_consumer_key'});
}

=head2 listContacts

Returns a list of contacts with whom emails have been exchanged.
(Note from the PHP code: with whom the most emails have been exchanged...)

Example: $res = $cio->listContacts( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: optional hashref containing keys set for filtering
     (see the documentation for filter options)

(see L<http://context.io/docs/2.0/accounts/contacts>)

=cut

sub listContacts {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);
    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['active_after','active_before','limit','offset','search']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'contacts', $params);
}

=head2 getContact

Get contact information

Example: $res = $cio->getContact( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing contact email, or hashref
     with key 'email' set to contact email

(see L<http://context.io/docs/2.0/accounts/contacts>)

=cut

sub getContact {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'email' => $params};
    } else {
        $params = $self->_filterParams($params, ['email'], ['email']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'contacts/' . $params->{'email'});
}

=head2 listContactFiles

List file attachments exchanged with a contact

Example: $res = $cio->listContactFiles( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing contact email, or hashref
     with key 'email' set to contact email
     (and see documentation for other filter options)

(see L<http://context.io/docs/2.0/accounts/contacts/files>)

=cut

sub listContactFiles {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['email','limit','offset','scope','group_by_revisions','include_person_info'], ['email']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPget($account, 'contacts/' . $params->{'email'} . '/files', $params);
}

=head2 listContactMessages

List messages exchanged with a contact

Example: $res = $cio->listContactMessages( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing contact email, or hashref
     with key 'email' set to contact email
     (and see documentation for other filter options)

(see L<http://context.io/docs/2.0/accounts/contacts/messages>)

=cut

sub listContactMessages {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['email','limit','offset','scope','folder','include_person_info'], ['email']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPget($account, 'contacts/' . $params->{'email'} . '/messages', $params);
}

=head2 listContactThreads

List conversation threads exchanged with a contact

Example: $res = $cio->listContactThreads( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing contact email, or hashref
     with key 'email' set to contact email
     (and see documentation for other filter options)

(see L<http://context.io/docs/2.0/accounts/contacts/threads>)

=cut

sub listContactThreads {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['email','limit','offset','scope','folder'], ['email']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPget($account, 'contacts/' . $params->{'email'} . '/threads', $params);
}

=head2 listFiles

List file attachments for an account

Example: $res = $cio->listFiles( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: optional hashref containing filter options
     (see documentation for filter options)

(see L<http://context.io/docs/2.0/accounts/files>)

=cut

sub listFiles {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['indexed_before', 'indexed_after','date_before','date_after','file_name','limit', 'offset', 'email', 'to','from','cc','bcc','group_by_revisions','include_person_info']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'files', $params);
}

=head2 getFile

Retrieve information on a specific file attachment

Example: $res = $cio->getFile( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing the attachment file_id
     or a hashref with the key 'file_id' set

(see L<http://context.io/docs/2.0/accounts/files/content>)

=cut

sub getFile {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'file_id' => $params};
    } else {
        $params = $self->_filterParams($params, ['file_id'], ['file_id']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'files/' . $params->{'file_id'});
}

=head2 getFileURL

Retrieve a temporary URL to a file attachment.
The URL will be good for 2 minutes. (Note: downloading is metered!)

Example: $res = $cio->getFileURL( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing the attachment file_id
     or a hashref with the key 'file_id' set

(see L<http://context.io/docs/2.0/accounts/files/content>)

=cut

sub getFileURL {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'file_id' => $params};
    } else {
        $params = $self->_filterParams($params, ['file_id'], ['file_id']);
    }
    return $self->HTTPget($account, 'files/' . $params->{'file_id'} . '/content', {'as_link' => 1}, ['text/uri-list']);
}

=head2 getFileContent

Retrieve a file attachment  (Note: metered service!)

Example: $res = $cio->getFileContent( $act_id, $params, $saveAs );
   * $act_id: your Context.IO account ID
   * $params: string containing the attachment file_id
     or a hashref with the key 'file_id' set

To save directly to file, set $saveAs. Leaving $saveAs undefined returns the
attachment as the response data.

(see L<http://context.io/docs/2.0/accounts/files/content>)

=cut

sub getFileContent {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);
    my $saveAs =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'file_id' => $params};
    } else {
        $params = $self->_filterParams($params, ['file_id'], ['file_id']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }

    my $baseUrl = $self->build_url('accounts/' . $account . '/files/' . $params->{'file_id'} . '/content');
    my $req = Net::OAuth->request('consumer')->new(
        consumer_key => $self->{'oauthKey'},
        consumer_secret => $self->{'oauthSecret'},
        request_method => 'GET',
        request_url => $baseUrl,
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => $self->generate_nonce()
    );
    $req->sign();

    # get data using signed url
    my $ua = LWP::UserAgent->new();
    my $urlreq;
    if ($self->{'authHeaders'}) {
        $urlreq = HTTP::Request->new( GET => $baseUrl );
        $urlreq->header('Authorization' => $req->to_authorization_header());
    }
    else {
        $urlreq = HTTP::Request->new( GET => $req->to_url());
    }

    if ($self->{'ssl'}) {
        # If we go to LWP >= 6.0, we'll need to set ssl_opt => {verify_hostname => 0}
        # curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
    }

    $ua->agent('ContextIOLibrary/2.0 (Perl)');

    if (defined($saveAs)) {
        # Save the response to file
        my $res = $ua->request($urlreq, $saveAs);
        if ($res->code() != 200) {
            my $response = Mail::ContextIO::Response->new(undef,$res);
            $self->{'lastResponse'} = $response;
            return;
        }
        return 1;  # Note - no failure testing in PHP
    } else {
        my $res = $ua->request($urlreq);
        if ($res->code() != 200) {
            my $response = Mail::ContextIO::Response->new(undef,$res);
            $self->{'lastResponse'} = $response;
            return;
        }
        return $res->decoded_content();
    }
}

=head2 getFileChanges

Given two files, this will return the list of insertions and deletions made
from the oldest of the two files to the newest one.

Example: $res = $cio->getFileChanges( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: hashref containing the following key/value pairs
     + file_id1: the file_id of the first file in the comparison
     + file_id2: the file_id of the 2nd file in the comparison
     + generate: (optional) triggers comparison

(see L<http://context.io/docs/2.0/accounts/files/changes>)

=cut

sub getFileChanges {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['file_id1', 'file_id2', 'generate'], ['file_id1','file_id2']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    my $newParams = { 'file_id' => $params->{'file_id2'} };
    $newParams->{'generate'} = (exists($params->{'generate'}) ? $params->{'generate'} : 1);
    return $self->HTTPget($account, 'files/' . $params->{'file_id1'} . '/changes', $newParams);
}

=head2 listFileRevisions

Returns a list of revisions attached to other emails in the
mailbox for one or more given files (see fileid parameter below).

Example: $res = $cio->listFileRevisions( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing the file_id to be searched against
     or a hashref containing the key 'file_id' and other options
     (see documentation)

(see L<http://context.io/docs/2.0/accounts/files/revisions>)

=cut

sub listFileRevisions {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'file_id' => $params};
    } else {
        $params = $self->_filterParams($params, ['file_id', 'include_person_info'], ['file_id']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'files/' . $params->{'file_id'} . '/revisions', $params);
}

=head2

Returns a list of files that are related to the given file.
Currently, relation between files is based on how similar their names are.

Example: $res = $cio->listFileRevisions( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: string containing the file_id to be searched against
     or a hashref containing the key 'file_id' and other options
     (see documentation)

(see L<http://context.io/docs/2.0/accounts/files/related>)

=cut

sub listFileRelated {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'file_id' => $params};
    } else {
        $params = $self->_filterParams($params, ['file_id','include_person_info'], ['file_id']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'files/' . $params->{'file_id'} . '/related', $params);
}

=head2 listMessagesBySourceAndFolder

Returns message information, limited by source ID and folder

Example:
   $res = $cio->listMessagesBySourceAndFolder( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a hashref containing at minimum the key/values for
     + 'label': the label of the source (e-mail account)
     + 'folder': the folder to be searched within that source
     (and see documentation for more filters)

(see L<http://context.io/docs/2.0/accounts/messages>)

=cut

sub listMessagesBySourceAndFolder {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        # TODO - PHP library says this can be null, but that would be "difficult" with the following GET...
        $params = $self->_filterParams($params, ['label','folder','limit','offset','type','include_body','include_headers','include_flags','flag_seen','async','async_job_id'], ['label','folder']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    my $source = $params->{'label'};
    my $folder = $params->{'folder'};
    delete $params->{'label'};
    delete $params->{'folder'};
    if (exists($params->{'async_job_id'})) {
        return $self->HTTPget($account, "sources/$source/folders/$folder/messages/" . $params->{'async_job_id'});
    }
    return $self->HTTPget($account, "sources/$source/folders/$folder/messages", $params);
}

=head2 listMessages

Returns message information across multiple sources

Example:
   $res = $cio->listMessages( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: an optional hashref containing filter parameters
     (see documentation for filter options)

(see L<http://context.io/docs/2.0/accounts/messages>)

=cut

sub listMessages {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['subject', 'date_before', 'date_after', 'indexed_after', 'indexed_before', 'limit', 'offset','email', 'to','from','cc','bcc','email_message_id','type','include_body','include_headers','include_flags','folder','gm_search','include_person_info']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'messages', $params);
}

=head2 addMessageToFolder

Insert a message into a folder. The message can be a locally stored RFC-822
message, or it can be a remotely available message given a message ID.

Example:
   $res = $cio->addMessageToFolder( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a hashref containing the following:
     + 'dst_label': the destination source label
     + 'dst_folder': the destination folder
     One of the following:
     + 'src_file': the full path to a local RFC-822 message
     + 'message_id': a valid Context.IO message_id
     + 'email_message_id': a valid e-mail message ID
     + 'gmail_message_id': a valid Gmail message ID

(see L<http://context.io/docs/2.0/accounts/messages>)

=cut

sub addMessageToFolder {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['dst_label','dst_folder','src_file','message_id','email_message_id','gmail_message_id'], ['dst_label','dst_folder']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (exists($params->{'src_file'})) {
        $params->{'src_file'} = abs_path($params->{'src_file'});
        if (!$params->{'src_file'} || (!-r $params->{'src_file'})) {
            croak("invalid source file");
        }
        my $src_file = '@' . $params->{'src_file'};
        delete $params->{'src_file'};
        return $self->HTTPpost($account, 'messages', $params, {'field' => 'message', 'filename' => $src_file});
    } elsif (exists($params->{'message_id'})) {
        return $self->HTTPpost($account, 'messages/' . $params->{'message_id'}, $params);
    } elsif (exists($params->{'email_message_id'})) {
        return $self->HTTPpost($account, 'messages/' . uri_escape($params->{'email_message_id'}), $params);
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            return $self->HTTPpost($account, 'messages/' . $params->{'gmail_message_id'}, $params);
        }
        return $self->HTTPpost($account, 'messages/gm-' . $params->{'gmail_message_id'}, $params);
    } else {
        croak('src_file, message_id, email_message_id or gmail_message_id is a required hash key');
    }
}

=head2 getMessage

Returns document and contact information about a message.

Example:
   $res = $cio->getMessage( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
     (and see documentation for additional options)

(see L<http://context.io/docs/2.0/accounts/messages#id-get>)

=cut

sub getMessage {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params));
    } else {
        $params = $self->_filterParams($params, ['message_id', 'email_message_id', 'gmail_message_id', 'include_person_info', 'type','include_body','include_headers','include_flags']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
        if (exists($params->{'message_id'})) {
            return $self->HTTPget($account, 'messages/' . $params->{'message_id'}, $params);
        } elsif (exists($params->{'email_message_id'})) {
            return $self->HTTPget($account, 'messages/' . uri_escape($params->{'email_message_id'}), $params);
        } elsif (exists($params->{'gmail_message_id'})) {
            if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
                return $self->HTTPget($account, 'messages/' . $params->{'gmail_message_id'}, $params);
            }
            return $self->HTTPget($account, 'messages/gm-' . $params->{'gmail_message_id'}, $params);
        } else {
            croak('message_id, email_message_id or gmail_message_id is a required hash key');
        }
    }
}

=head2 getMessageHeaders

Returns message headers

Example:
   $res = $cio->getMessageHeaders( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
     and optionally, the following:
     + 'raw': return raw header data

(see L<http://context.io/docs/2.0/accounts/messages/headers>)

=cut

sub getMessageHeaders {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params) . '/headers');
    }
    else {
        $params = $self->_filterParams($params, ['message_id','email_message_id', 'gmail_message_id', 'raw']);
        if (exists($params->{'message_id'})) {
            return $self->HTTPget($account, 'messages/' . $params->{'message_id'}. '/headers', $params);
        }
        elsif (exists($params->{'email_message_id'})) {
            return $self->HTTPget($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/headers', $params);
        }
        elsif (exists($params->{'gmail_message_id'})) {
            if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
                return $self->HTTPget($account, 'messages/' . $params->{'gmail_message_id'} . '/headers', $params);
            }
            return $self->HTTPget($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/headers', $params);
        } else {
            croak('message_id, email_message_id or gmail_message_id is a required hash key');
        }
    }
}

=head2 getMessageSource

Returns the message source of a message. (Note: this is metered!)

Example:
   $res = $cio->getMessageSource( $act_id, $params, $saveAs );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
   * $saveAs: if set, message source will be saved to file
     if left undefined, message source will be returned in response

(see L<http://context.io/docs/2.0/accounts/messages/source>)

=cut

sub getMessageSource {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);
    my $saveAs =  (scalar(@_) ? shift : undef);
    my $url;

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $url = 'messages/' . uri_escape($params) . '/source';
    } elsif (exists($params->{'message_id'})) {
        $url = 'messages/' . $params->{'message_id'}. '/source';
    } elsif (exists($params->{'email_message_id'})) {
        $url = 'messages/' . uri_escape($params->{'email_message_id'}) . '/source';
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            $url = 'messages/' . $params->{'gmail_message_id'} . '/source';
        } else {
            $url = 'messages/gm-' . $params->{'gmail_message_id'} . '/source';
        }
    } else {
        croak('message_id, email_message_id or gmail_message_id is a required hash key');
    }

    my $baseUrl = $self->build_url('accounts/' . $account . '/' . $url);
    my $req = Net::OAuth->request('consumer')->new(
        consumer_key => $self->{'oauthKey'},
        consumer_secret => $self->{'oauthSecret'},
        request_method => 'GET',
        request_url => $baseUrl,
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => $self->generate_nonce()
    );
    $req->sign();

    # get data using signed url
    my $ua = LWP::UserAgent->new();
    my $urlreq;
    if ($self->{'authHeaders'}) {
        $urlreq = HTTP::Request->new( GET => $baseUrl );
        $urlreq->header('Authorization' => $req->to_authorization_header());
    }
    else {
        $urlreq = HTTP::Request->new( GET => $req->to_url());
    }

    if ($self->{'ssl'}) {
        # If we go to LWP >= 6.0, we'll need to set ssl_opt => {verify_hostname => 0}
        # curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
    }

    $ua->agent('ContextIOLibrary/2.0 (Perl)');

    if (defined($saveAs)) {
        # Save the response to file
        my $res = $ua->request($urlreq, $saveAs);
        if ($res->code() != 200) {
            my $response = Mail::ContextIO::Response->new(undef,$res);
            $self->{'lastResponse'} = $response;
            return;
        }
        return 1;  # Note - no failure testing in PHP
    } else {
        my $res = $ua->request($urlreq);
        if ($res->code() != 200) {
            my $response = Mail::ContextIO::Response->new(undef,$res);
            $self->{'lastResponse'} = $response;
            return;
        }
        return $res->decoded_content();
    }
}

=head2 getMessageFlags

Returns message flags (e.g. Seen, Deleted)

Example:
   $res = $cio->getMessageFlags( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID

(see L<http://context.io/docs/2.0/accounts/messages/flags>)

=cut

sub getMessageFlags {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params) . '/flags');
    } elsif (exists($params->{'message_id'})) {
        return $self->HTTPget($account, 'messages/' . $params->{'message_id'}. '/flags');
    } elsif (exists($params->{'email_message_id'})) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/flags');
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            return $self->HTTPget($account, 'messages/' . $params->{'gmail_message_id'} . '/flags');
        }
        return $self->HTTPget($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/flags');
    } else {
        croak('message_id, email_message_id or gmail_message_id is a required hash key');
    }
}

=head2 getMessageFolders

Returns folders containing a message

Example:
   $res = $cio->getMessageFolders( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID

(see L<http://context.io/docs/2.0/accounts/messages/folders>)

=cut

sub getMessageFolders {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params) . '/folders');
    } elsif (exists($params->{'message_id'})) {
        return $self->HTTPget($account, 'messages/' . $params->{'message_id'} . '/folders');
    } elsif (exists($params->{'email_message_id'})) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/folders');
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            return $self->HTTPget($account, 'messages/' . $params->{'gmail_message_id'} . '/folders');
        }
        return $self->HTTPget($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/folders');
    } else {
        croak('message_id, email_message_id or gmail_message_id is a required hash key');
    }
}

=head2 setMessageFolders

Update list of folders containing a message

Example:
   $res = $cio->setMessageFolders( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
     And one or more of the following:
     + 'add': folder name that the message should be added to
     + 'remove': folder to remove message from
     + 'folders': array of folders that should contain the message

(NOTE: The Context.IO API supports the PHP concept of multi-valued 'add'
and 'remove', but the Perl API does not at this time.)

(see L<http://context.io/docs/2.0/accounts/messages/folders>)

=cut

sub setMessageFolders {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['message_id', 'email_message_id', 'gmail_message_id', 'add','remove','folders']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (exists($params->{'folders'})) {
        if (ref($params->{'folders'}) ne 'ARRAY') {
            croak("folders must be array");
        }
        my $folderStr = encode_json($params->{'folders'});
        if (exists($params->{'email_message_id'})) {
            return $self->HTTPput($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/folders', $folderStr);
        } elsif (exists($params->{'message_id'})) {
            return $self->HTTPput($account, 'messages/' . $params->{'message_id'} . '/folders', $folderStr);
        } elsif (exists($params->{'gmail_message_id'})) {
            if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
                return $self->HTTPput($account, 'messages/' . $params->{'gmail_message_id'} . '/folders', $folderStr);
            }
            return $self->HTTPput($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/folders', $folderStr);
        } else {
            croak('message_id, email_message_id or gmail_message_id is a required hash key');
        }
    } else {
        my $addRemoveParams = {};
        foreach my $currentName ('add','remove') {
            if (exists($params->{$currentName})) {
                $addRemoveParams->{$currentName} = $params->{$currentName};
            }
        }
        if (scalar(keys(%$addRemoveParams)) == 0) {
            croak("must specify at least one of add,remove");
        }

        if (exists($params->{'email_message_id'})) {
            return $self->HTTPpost($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/folders', $addRemoveParams);
        } elsif (exists($params->{'message_id'})) {
            return $self->HTTPpost($account, 'messages/' . $params->{'message_id'} . '/folders', $addRemoveParams);
        } elsif (exists($params->{'gmail_message_id'})) {
            if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
                return $self->HTTPpost($account, 'messages/' . $params->{'gmail_message_id'} . '/folders', $addRemoveParams);
            }
            return $self->HTTPpost($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/folders', $addRemoveParams);
        } else {
            croak('message_id, email_message_id or gmail_message_id is a required hash key');
        }
    }
}

=head2 setMessageFlags

Update one or more message flags

Example:
   $res = $cio->setMessageFlags( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
     And one or more of the following boolean flag values:
     + 'seen', 'answered', 'deleted', 'flagged', 'draft'

(see L<http://context.io/docs/2.0/accounts/messages/flags>)

=cut

sub setMessageFlags {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['message_id', 'email_message_id', 'gmail_message_id', 'seen','answered','flagged','deleted','draft']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    my $flagParams = {};
    foreach my $currentFlagName ('seen','answered','flagged','deleted','draft') {
        if (exists($params->{$currentFlagName})) {
            if (($params->{$currentFlagName} != 1) && ($params->{$currentFlagName} != 0)) {
                croak("$currentFlagName must be boolean");
            }
            $flagParams->{$currentFlagName} = $params->{$currentFlagName};
        }
    }
    if (scalar(keys(%$flagParams)) == 0) {
        croak("must specify at least one of seen,answered,flagged,deleted,draft");
    }

    if (exists($params->{'email_message_id'})) {
        return $self->HTTPpost($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/flags', $flagParams);
    } elsif (exists($params->{'message_id'})) {
        return $self->HTTPpost($account, 'messages/' . $params->{'message_id'} . '/flags', $flagParams);
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            return $self->HTTPpost($account, 'messages/' . $params->{'gmail_message_id'} . '/flags', $flagParams);
        }
        return $self->HTTPpost($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/flags', $flagParams);
    }
    else {
        croak('message_id, email_message_id or gmail_message_id is a required hash key');
    }
}

=head2 getMessageBody

Returns the message body (excluding attachments) of a message

Example:
   $res = $cio->getMessageBody( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
     And, optionally, the 'type' parameter can be set

(see L<http://context.io/docs/2.0/accounts/messages/body>)

=cut

sub getMessageBody {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params) . '/body');
    }
    $params = $self->_filterParams($params, ['message_id', 'email_message_id', 'gmail_message_id', 'type']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (exists($params->{'email_message_id'})) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/body', $params);
    } elsif (exists($params->{'message_id'})) {
        return $self->HTTPget($account, 'messages/' . $params->{'message_id'} . '/body', $params);
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            return $self->HTTPget($account, 'messages/' . $params->{'gmail_message_id'} . '/body', $params);
        }
        return $self->HTTPget($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/body', $params);
    } else {
        croak('message_id, email_message_id or gmail_message_id is a required hash key');
    }
}

=head2 getMessageThread

Returns message and contact information about a given email thread.

Example:
   $res = $cio->getMessageThread( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
     (and see documentation for optional filters)

(see L<http://context.io/docs/2.0/accounts/messages/thread>)

=cut

sub getMessageThread {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params) . '/thread');
    }
    $params = $self->_filterParams($params, ['message_id', 'email_message_id', 'gmail_message_id', 'include_body', 'include_headers', 'include_flags', 'type', 'include_person_info']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (exists($params->{'email_message_id'})) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/thread', $params);
    } elsif (exists($params->{'message_id'})) {
        return $self->HTTPget($account, 'messages/' . $params->{'message_id'} . '/thread', $params);
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            return $self->HTTPget($account, 'messages/' . $params->{'gmail_message_id'} . '/thread', $params);
        }
        return $self->HTTPget($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/thread', $params);
    } else {
        croak('message_id, email_message_id or gmail_message_id is a required hash key');
    }
}

=head2 listThreads

Returns a list of message threads

Example:
   $res = $cio->listThreads( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: an optional hashref of filter options
     (see documentation for optional filters)

(see L<http://context.io/docs/2.0/accounts/threads>)

=cut

sub listThreads {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['subject', 'indexed_after', 'indexed_before', 'active_after', 'active_before', 'started_after', 'started_before', 'limit', 'offset','email', 'to','from','cc','bcc','folder']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'threads', $params);
}

=head2 getThread

Returns message and contact information about a given email thread.
(Can locate threads by message ID like getMessageThread, or by
Gmail Thread ID)

Example:
   $res = $cio->getThread( $act_id, $params );
   * $act_id: your Context.IO account ID
   * $params: a string containing a valid Context.IO message ID
     or a hashref specifying one of the following
     + 'message_id': a Context.IO message ID
     + 'email_message_id': an e-mail message ID
     + 'gmail_message_id': a Gmail message ID
     + 'gmail_thread_id': a Gmail Thread ID
     (and see documentation for optional filters)

(see L<http://context.io/docs/2.0/accounts/threads>)

=cut

sub getThread {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['message_id', 'gmail_thread_id','gmail_message_id','email_message_id','include_body','include_headers','include_flags','type','include_person_info','limit','offset']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (exists($params->{'email_message_id'})) {
        return $self->HTTPget($account, 'messages/' . uri_escape($params->{'email_message_id'}) . '/thread', $params);
    } elsif (exists($params->{'message_id'})) {
        return $self->HTTPget($account, 'messages/' . $params->{'message_id'} . '/thread', $params);
    } elsif (exists($params->{'gmail_message_id'})) {
        if (substr($params->{'gmail_message_id'},0,3) eq 'gm-') {
            return $self->HTTPget($account, 'messages/' . $params->{'gmail_message_id'} . '/thread', $params);
        }
        return $self->HTTPget($account, 'messages/gm-' . $params->{'gmail_message_id'} . '/thread', $params);
    } elsif (exists($params->{'gmail_thread_id'})) {
        if (substr($params->{'gmail_thread_id'},0,3) eq 'gm-') {
            return $self->HTTPget($account, 'threads/' . $params->{'gmail_thread_id'}, $params);
        }
        return $self->HTTPget($account, 'threads/gm-' . $params->{'gmail_thread_id'}, $params);
    } else {
        croak('gmail_thread_id, messageId, email_message_id or gmail_message_id are required hash keys');
    }
}

=head2 listAccounts

List Context.IO Accounts

Example:
   $res = $cio->listAccounts( $act_id, $params );
   * $params: a hashref containing optional filter parameters
     (see documentation for filter options)

(see L<http://context.io/docs/2.0/accounts>)

=cut

sub listAccounts {
    my $self = shift;
    my $params =  (scalar(@_) ? shift : undef);
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['limit','offset','email','status_ok','status']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget(undef, 'accounts', $params);
}

=head2 addAccount

Add a new Context.IO Account to your access key

Example:
   $res = $cio->addAccount( $params );
   * $params: a hashref specifying at least
     + 'email': the account holder's primary e-mail
     (and see documentation for additional optional info)

(see L<http://context.io/docs/2.0/accounts>)

=cut

sub addAccount {
    my $self = shift;
    my $params =  shift;
    $params = $self->_filterParams($params, ['email','first_name','last_name','type','server','username','provider_consumer_key','provider_token','provider_token_secret','service_level','sync_period','password','use_ssl','port','callback_url'], ['email']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost(undef, 'accounts', $params);
}

=head2 modifyAccount

Modify a Context.IO Account

Example:
   $res = $cio->modifyAccount( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a hashref specifying 'last_name' and/or 'first_name'

(see L<http://context.io/docs/2.0/accounts>)

=cut

sub modifyAccount {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['first_name','last_name']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost($account, '', $params);
}

=head2 getAccount

Get details about a Context.IO Account

Example:
   $res = $cio->getAccount( $act_id, $params );
   * $act_id: a valid Context.IO account ID

(see L<http://context.io/docs/2.0/accounts>)

=cut

sub getAccount {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    return $self->HTTPget($account);
}

=head2 deleteAccount

Delete a Context.IO Account

Example:
   $res = $cio->deleteAccount( $act_id, $params );
   * $act_id: a valid Context.IO account ID

(see L<http://context.io/docs/2.0/accounts>)

=cut

sub deleteAccount {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    return $self->HTTPdelete($account);
}

=head2 listAccountAddresses

List all e-mail addresses assigned to a Context.IO Account

Example:
   $res = $cio->listAccountAddresses( $act_id, $params );
   * $act_id: a valid Context.IO account ID

(see L<http://context.io/docs/2.0/accounts/email_addresses>)

=cut

sub listAccountEmailAddresses {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    return $self->HTTPget($account, 'email_addresses');
}

=head2 addEmailAddressToAccount

Add an e-mail address to a Context.IO Account

Example:
   $res = $cio->addEmailAddressToAccount( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a hashref with the key 'email_address', specifying
     an e-mail address to assign to the accounts address aliases

(see L<http://context.io/docs/2.0/accounts/email_addresses>)

=cut

sub addEmailAddressToAccount {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['email_address'], ['email_address']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost($account, 'email_addresses', $params);
}

=head2 deleteEmailAddressFromAccount

Delete an e-mail address from a Context.IO Account

Example:
   $res = $cio->deleteEmailAddressFromAccount( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a hashref with the key 'email_address', specifying
     an e-mail address to remove from the accounts address aliases

(see L<http://context.io/docs/2.0/accounts/email_addresses>)

=cut

sub deleteEmailAddressFromAccount {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPdelete($account, 'email_addresses/' . $params);
    }
    $params = $self->_filterParams($params, ['email_address'], ['email_address']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPdelete($account, 'email_addresses/' . $params->{'email_address'});
}

=head2 setPrimaryEmailAddressForAccount

Change the default e-mail address of a Context.IO Account

Example:
   $res = $cio->setPrimaryEmailAddressForAccount( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: string containing an email_address, or
     a hashref with the key 'email_address', specifying
     an e-mail address to use as the account's primary address

(see L<http://context.io/docs/2.0/accounts/email_addresses>)

=cut

sub setPrimaryEmailAddressForAccount {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        return $self->HTTPpost($account, 'email_addresses/' . $params, {'primary' => 1});
    }
    $params = $self->_filterParams($params, ['email_address'], ['email_address']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost($account, 'email_addresses/' . $params->{'email_address'}, {'primary' => 1});
}

=head2 modifySource

Modify the IMAP server settings of an already indexed account

Example:
   $res = $cio->modifySource( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a hashref with at least the key/value pair 'label'
     specifying the source label to modify.
     See documentation for other keys specifying changes to source

(see L<http://context.io/docs/2.0/accounts/sources>)

=cut

sub modifySource {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['provider_token', 'provider_token_secret', 'provider_refresh_token', 'password', 'provider_consumer_key', 'label', 'mailboxes', 'sync_all_folders', 'service_level','sync_period'], ['label']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost($account, 'sources/' . $params->{'label'}, $params);
}

=head2 resetSourceStatus

Re-enable a source if it has been set disabled

Example:
   $res = $cio->resetSourceStatus( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a string containing the source identifier label
     or a hashref with the key/value pair 'label'

(see L<http://context.io/docs/2.0/accounts/sources>)

=cut

sub resetSourceStatus {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'label' => $params};
    } else {
        $params = $self->_filterParams($params, ['label'], ['label']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPpost($account, 'sources/' . $params->{'label'}, {'status' => 1});
}

=head2 listSources

List all e-mail sources available for a Context.IO Account

Example:
   $res = $cio->listSources( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: an optional hashref containing filter options
     (See documentation for filter options)

(see L<http://context.io/docs/2.0/accounts/sources>)

=cut

sub listSources {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['status_ok','status']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'sources', $params);
}

=head2 getSource

Get details about a single configured e-mail source

Example:
   $res = $cio->getSource( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a string containing the source label, or
     a hashref containing the key/value pair 'label'

(see L<http://context.io/docs/2.0/accounts/sources>)

=cut

sub getSource {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'label' => $params};
    } else {
        $params = $self->_filterParams($params, ['label'], ['label']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'sources/' . $params->{'label'});
}

=head2 addSource

Add a new e-mail source to a Context.IO Account

Example:
   $res = $cio->addSource( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a hashref containing at least the
     key/value pairs 'server' and 'username',
     Optionally, may contain further configuration
     values (see documentation for a full list).

(see L<http://context.io/docs/2.0/accounts/sources>)

=cut

sub addSource {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['type','email','server','username','provider_consumer_key','provider_token','provider_token_secret','provider_refresh_token','service_level','sync_period','sync_all_folders','password','use_ssl','port','callback_url'], ['server','username']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (! exists($params->{'type'})) {
        $params->{'type'} = 'imap';
    }
    return $self->HTTPpost($account, 'sources/', $params);
}

=head2 deleteSource

Delete a source from a Context.IO Account.

Example:
   $res = $cio->deleteSource( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a string containing the source label, or
     a hashref containing the key/value pair 'label'

(see L<http://context.io/docs/2.0/accounts/sources>)

=cut

sub deleteSource {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = {'label' => $params};
    } else {
        $params = $self->_filterParams($params, ['label'], ['label']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPdelete($account, 'sources/' . $params->{'label'});
}

=head2 syncSource

Sync a single e-mail source, or all e-mail sources for a Context.IO Account.

Example:
   $res = $cio->syncSource( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: an optional hashref containing
     the key/value pair 'label' specifying the source
     (If not present, will sync all sources)

(see L<http://context.io/docs/2.0/accounts/sources/sync>) and
(see L<http://context.io/docs/2.0/accounts/sync>)

=cut

sub syncSource {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['label']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    if (!defined($params) || scalar(keys(%$params)) == 0) {
        return $self->HTTPpost($account, 'sync');
    }
    return $self->HTTPpost($account, 'sources/' . $params->{'label'} . '/sync');
}

=head2 getSync

Get the sync status of a single e-mail source, or for all e-mail sources for
a Context.IO Account.

Example:
   $res = $cio->getSync( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: an optional hashref containing
     the key/value pair 'label' specifying the source
     (If not present, will sync all sources)

(see L<http://context.io/docs/2.0/accounts/sources/sync>) and
(see L<http://context.io/docs/2.0/accounts/sync>)

=cut

sub getSync {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if (ref($params) eq 'HASH') {
        $params = $self->_filterParams($params, ['label']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    if (!defined($params) || scalar(keys(%$params)) == 0) {
        return $self->HTTPget($account, 'sync');
    }
    return $self->HTTPget($account, 'sources/' . $params->{'label'} . '/sync');
}

=head2 addFolderToSource

Creates a folder at the remote e-mail source

Example:
   $res = $cio->addFolderToSource( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a hashref containing the key/value pairs
     'label' and 'folder', and optionally 'delim'
     (See documentation for further details on 'delim')

(see L<http://context.io/docs/2.0/accounts/sources/folders>)

=cut

sub addFolderToSource {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['label','folder','delim'], ['label','folder']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (exists($params->{'delim'})) {
        return $self->HTTPput($account, 'sources/' . $params->{'label'} . '/folders/' . uri_escape($params->{'folder'}), {'delim' => $params->{'delim'}});
    }
    return $self->HTTPput($account, 'sources/' . $params->{'label'} . '/folders/' . uri_escape($params->{'folder'}));
}

=head2 listSourceFolders

Return a list of all folders for an e-mail source

Example:
   $res = $cio->listSourceFolders( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: a string containing the source label, or
     a hashref containing the key/value pair 'label'

(see L<http://context.io/docs/2.0/accounts/sources/folders>)

=cut

sub listSourceFolders {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = array('label' => $params);
    } else {
        $params = $self->_filterParams($params, ['label'], ['label']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'sources/' . $params->{'label'} . '/folders');
}

sub sendMessage {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['label','rcpt','message','message_id', 'gmail_thread_id'], ['label']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    if (! exists($params->{'message_id'}) && ! exists($params->{'message'}) && ! exists($params->{'gmail_thread_id'})) {
        croak('gmail_thread_id, message_id or message is a required hash key');
    }

    return $self->HTTPpost($account, 'exits/' . $params->{'label'}, $params);
}

=head2 listWebhooks

=head2 getWebhook

=head2 addWebhook

=head2 deleteWebhook

=head2 modifyWebhook

Utilize Webhooks to have Context.IO POST data to your web service
rather than polling Context.IO

Example:
   $res = $cio->addWebhook( $act_id, $params );
   * $act_id: a valid Context.IO account ID
   * $params: varies by call - a string containing a webhook ID
     or a hashref containing webhook parameters

See the documentation for details about using webhooks:
(see L<http://context.io/docs/2.0/accounts/webhooks>)

=cut
sub listWebhooks {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    return $self->HTTPget($account, 'webhooks');
}

sub getWebhook {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = array('webhook_id' => $params);
    } else {
        $params = $self->_filterParams($params, ['webhook_id'], ['webhook_id']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPget($account, 'webhooks/' . $params->{'webhook_id'});
}

sub addWebhook {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['filter_to', 'filter_from', 'filter_cc', 'filter_subject', 'filter_thread', 'filter_new_important', 'filter_file_name', 'filter_file_revisions', 'sync_period', 'callback_url', 'failure_notif_url','filter_folder_added','filter_folder_removed'], ['callback_url','failure_notif_url']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost($account, 'webhooks/', $params);
}

sub deleteWebhook {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    if ($self->_is_string($params)) {
        $params = array('webhook_id' => $params);
    } else {
        $params = $self->_filterParams($params, ['webhook_id'], ['webhook_id']);
        if (!$params) {
            croak("params array contains invalid parameters or misses required parameters");
        }
    }
    return $self->HTTPdelete($account, 'webhooks/' . $params->{'webhook_id'});
}

sub modifyWebhook {
    my $self = shift;
    my $account = (scalar(@_) ? shift : undef);
    my $params =  (scalar(@_) ? shift : undef);

    if ( !defined($account) || ! $self->_is_string($account) || (index($account, '@') != -1) ) {
        croak('account must be string representing accountId');
    }
    $params = $self->_filterParams($params, ['webhook_id', 'active'], ['webhook_id','active']);
    if (!$params) {
        croak("params array contains invalid parameters or misses required parameters");
    }
    return $self->HTTPpost($account, 'webhooks/' . $params->{'webhook_id'}, $params);
}

###
#  Specify the API endpoint.
#  @param string $endPoint
#  @return boolean success
###
sub setEndPoint {
    my $self = shift;
    my $endPoint = shift;
    $self->{'endPoint'} = $endPoint;
    return 1;
}

###
#  Specify whether or not API calls should be made over a secure connection.
#  HTTPS is used on all calls by default.
#  @param bool $sslOn Set to false to make calls over HTTP, true to use HTTPS
###
sub setSSL {
    my $self = shift;
    my $sslOn =  (scalar(@_) ? shift : 1);
    $self->{'ssl'} = ($sslOn == 0 ? 0 : 1);
    return 1;
}

###
#  Set the API version. By default, the latest official version will be used
#  for all calls.
#  @param string $apiVersion Context.IO API version to use
#  @return boolean success
###
sub setApiVersion {
    my $self = shift;
    my $apiVersion = shift;
    if ($apiVersion != '2.0') {
        return 0;
    }
    $self->{'apiVersion'} = $apiVersion;
    return 1;
}

###
#  Specify whether OAuth parameters should be included as URL query parameters
#  or sent as HTTP Authorization headers. The default is URL query parameters.
#  @param bool $authHeadersOn Set to true to use HTTP Authorization headers, false to use URL query params
###
sub useAuthorizationHeaders {
    my $self = shift;
    my $authHeadersOn =  (scalar(@_) ? shift : 1);
    $self->{'authHeaders'} = ($authHeadersOn == 0 ? 0 : 1);
}

###
#  Returns the ContextIOResponse object for the last API call.
#  @return ContextIOResponse
###
sub getLastResponse {
    my $self = shift;
    return $self->{'lastResponse'};
}


sub build_baseurl {
    my $self = shift;
    my $url = 'http';
    if ($self->{'ssl'}) {
        $url = 'https';
    }
    return "$url://" . $self->{'endPoint'} . "/" . $self->{'apiVersion'} . '/';
}

sub build_url {
    my $self = shift;
    my $action =  (scalar(@_) ? shift : '');
    return $self->build_baseurl() . $action;
}

sub saveHeaders {
    my $self = shift;
    my $yes =  (scalar(@_) ? shift : 1);
    $self->{'saveHeaders'} = $yes;
    return 1;
}

sub HTTPget {
    my $self = shift;
    my $account = shift;
    my $action =  (scalar(@_) ? shift : '');
    my $parameters =  (scalar(@_) ? shift : undef);
    my $acceptableContentTypes =  (scalar(@_) ? shift : undef);
    if (ref($account) eq 'ARRAY') {
        my $tmp_results = {};
        foreach my $accnt (@$account) {
            my $result = $self->_doCall('GET', $accnt, $action, $parameters, undef, $acceptableContentTypes);
            if (!defined($result)) {
                return;
            }
            $tmp_results->{$accnt} = $result;
        }
        return $tmp_results;
    } else {
        return $self->_doCall('GET', $account, $action, $parameters, undef, $acceptableContentTypes);
    }
}

sub HTTPput {
    my $self = shift;
    my $account = shift;
    my $action =  (scalar(@_) ? shift : '');
    my $parameters =  (scalar(@_) ? shift : undef);
    return $self->_doCall('PUT', $account, $action, $parameters);
}

sub HTTPpost {
    my $self = shift;
    my $account = shift;
    my $action =  (scalar(@_) ? shift : '');
    my $parameters =  (scalar(@_) ? shift : undef);
    my $file =  (scalar(@_) ? shift : undef);
    return $self->_doCall('POST', $account, $action, $parameters, $file);
}

sub HTTPdelete {
    my $self = shift;
    my $account = shift;
    my $action =  (scalar(@_) ? shift : '');
    my $parameters =  (scalar(@_) ? shift : undef);
    return $self->_doCall('DELETE', $account, $action, $parameters);
}

sub _doCall {
    my $self = shift;
    my $httpMethod = shift;
    my $account = shift;
    my $action = shift;
    my $parameters = (scalar(@_) ? shift : undef);
    my $file = (scalar(@_) ? shift : undef);
    my $acceptableContentTypes = (scalar(@_) ? shift : undef);
    $action = '' if (!defined($action));
    if (defined($account)) {
        $action = 'accounts/' . $account . '/' . $action;
        if (substr($action,-1) eq '/') {
            $action = substr($action,0,-1);
        }
    }
    my $baseUrl = $self->build_url($action);
    my $isMultiPartPost = (
        defined($file) &&
        exists($file->{'field'}) &&
        exists($file->{'filename'})
    );
    my $req = Net::OAuth->request('consumer')->new(
        consumer_key => $self->{'oauthKey'},
        consumer_secret => $self->{'oauthSecret'},
        request_method => $httpMethod,
        request_url => $baseUrl,
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => $self->generate_nonce()
    );
    if ($isMultiPartPost || $self->_is_string($parameters)) {
        # Note: this is a persistent change; maybe not what we really want
        $self->{'authHeaders'} = 1;
    } else {
        $req->{'extra_params'} = $parameters;
    }

    $req->sign();

    # get data using signed url
    my $ua = LWP::UserAgent->new();
    my $useUrl;

    if ($self->{'ssl'}) {
        # If we go to LWP >= 6.0, we'll need to set ssl_opt => {verify_hostname => 0}
        # curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
    }

    $ua->agent('ContextIOLibrary/2.0 (Perl)');

    my $httpHeadersToSet = [];
    # get data using signed url
    if ($self->{'authHeaders'}) {
        if ($httpMethod ne 'POST') {
            if (
                !defined($parameters) ||
                $self->_is_string($parameters) ||
                !scalar(keys(%$parameters))
            ) {
                $useUrl = $baseUrl;
            } else {
                $useUrl = $req->normalized_request_url . 
                    '?' . $self->build_query($req);
            }
        } else {
            # POST always uses $baseURL
            $useUrl = $baseUrl;
        }
        my $oauth_header = $req->to_authorization_header();
        push @$httpHeadersToSet, ({'Authorization' => $oauth_header});
    } else {
        $useUrl = $req->to_url();
    }
    my $urlreq;

    if ($httpMethod ne 'GET') {
        if ($httpMethod eq 'POST') {
            if (defined($parameters)) {
                if (!defined($file)) {
                    $urlreq = POST $useUrl, $parameters;
                } else {
                    $parameters->{$file->{'field'}} = $file->{'filename'};
                    $urlreq = POST $useUrl, $parameters;
                }
            } elsif (defined($file)) {
                $urlreq = POST $useUrl, { $file->{'field'} => $file->{'filename'} };
            }
        } else {
            $urlreq = HTTP::Request->new( $httpMethod => $useUrl);
            if (($httpMethod == 'PUT') && $self->_is_string($parameters)) {
                push @$httpHeadersToSet, ( {'Content-Length' => length($parameters)} );
                push @$httpHeadersToSet, ( {'Content-Type' => 'application/json'} );
                $urlreq->content($parameters);
            }
        }
    } else {
        $urlreq = HTTP::Request->new( $httpMethod => $useUrl );
    }
    if (scalar(@$httpHeadersToSet)) {
        foreach my $hp (@$httpHeadersToSet) {
            my @hpkeys = keys(%$hp);
            my $key = $hpkeys[0];
            my $value = $hp->{$key};
            $urlreq->header($key, $value);
        }
    }
    
    my $result = $ua->request($urlreq);

    my $hdrreq = $urlreq;
    if ($self->{'saveHeaders'}) {
        $hdrreq = undef;
    }
    my $response;
    if (!defined($acceptableContentTypes)) {
        $response = Mail::ContextIO::Response->new($hdrreq,$result);
    }
    else {
        $response = Mail::ContextIO::Response->new($hdrreq,$result, $acceptableContentTypes);
    }
    if ($response->hasError()) {
        $self->{'lastResponse'} = $response;
        return;
    }
    return $response;
}

sub _filterParams {
    my $self = shift;
    my $givenParams = shift;
    my $validParams = shift;
    my %validPKeys = map {$_ => 1} @$validParams;
    my $requiredParams = (scalar(@_) ? shift : []);
    my $filteredParams = {};
    foreach my $gname (keys(%$givenParams)) {
        my $value = $givenParams->{$gname};
        if (exists($validPKeys{lc($gname)})) {
            $filteredParams->{lc($gname)} = $value;
        } else {
            return;
        }
    }
    foreach my $rname (@$requiredParams) {
        if (!exists($filteredParams->{lc($rname)})) {
            return;
        }
    }
    return $filteredParams;
}

sub _is_string {
    my $self = shift;
    my $test = shift;
    return if (!defined($test)); # it's not defined, it's not a string
    return if (ref($test)); # it's a reference, not a string
    return 1;
}

sub generate_nonce {
    # This is a pretty lousy nonce generator, but for now...
    my $self = shift;
    my @a = ('A'..'Z', 'a'..'z', 0..9);
    my $nonce = '';
    for(0..31) {
        $nonce .= $a[rand(scalar(@a))];
    }
    return $nonce;
}

sub build_query {
    my $self = shift;
    my $oauth_req = shift;
    my $oauth_query = $oauth_req->normalized_message_parameters;
    my @plist = split('&',$oauth_query);
    my $i = 0;
    while ($i < scalar(@plist)) {
        # remove oauth_ params
        if ($plist[$i] =~ /^oauth_/) {
            splice @plist,$i,1;
        } else {
            $i++;
        }
    }
    if (scalar(@plist)) {
        return join('&',@plist);
    } else {
        return '';
    }
}

=head1 AUTHOR

Les Barstow, C<< <Les.Barstow at returnpath.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mail-contextio at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mail-ContextIO>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mail::ContextIO


You can also look for information at:

=over 4

=item * Context.IO

L<http://context.io>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2013 Les Barstow for Return Path, Inc.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


=cut

1; # End of Mail::ContextIO
