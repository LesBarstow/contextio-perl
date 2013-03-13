package Mail::ContextIO::Response;

# Code sanity
use 5.006;
use strict;
use warnings;
use Carp;

=head1 NAME

Mail::ContextIO::Response - Internal methods for creating error responses

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

Mail::ContextIO::Response objects are created as a result of
Mail::ContextIO method calls. They contain result codes and
any data that may have been returned from the method.

=cut

use LWP::UserAgent;
use JSON;

=head1 SUBROUTINES/METHODS

=cut

sub new {
    my $type = shift;
    my $class = ref $type || $type;
    my $httpRequest = shift;
    my $httpResponse = shift;
    my $acceptableContentTypes = (scalar(@_) ? shift : 'application/json');
    if (!ref($acceptableContentTypes)) {
        $acceptableContentTypes = [ $acceptableContentTypes ];
    }
    my $requestHeaders = [];
    my $responseHeaders = [];
    if ($httpRequest) {
        @$requestHeaders = split(/(?:\n|\r){1,2}/,$httpRequest->headers()->as_string());
        @$responseHeaders = split(/(?:\n|\r){1,2}/,$httpResponse->headers()->as_string());
    } else {
        $requestHeaders = undef;
        $responseHeaders = undef;
    }
    my $self = {
        httpCode => int($httpResponse->code()),
        contentType => $httpResponse->header('Content-Type'),
        rawResponseHeaders => $responseHeaders,
        rawRequestHeaders => $requestHeaders,
        headers => { request => undef, response=> undef },
        rawResponse => $httpResponse->content(),
        decodedResponse => undef,
        hasError => 0,
    };
    bless($self, $class);

    $self->_decodeResponse($httpResponse, $acceptableContentTypes);
    $self->_parseHeaders('request', $httpRequest);
    $self->_parseHeaders('response', $httpResponse);
    return $self;
}

sub _parseHeaders {
    my $self = shift;
    my $which = shift;
    my $httpMessage = shift;

    return if (!defined($httpMessage));
    my $httpHeaders = $httpMessage->headers();
    my $headers = {};
    #    $headers->{($which eq 'response') ? 'Status-Line' : 'Request-Line'} = chomp(shift @$raw);
    my @header_names = $httpHeaders->header_field_names();
    foreach my $name (@header_names) {
        my @header_out = $httpHeaders->header($name);
        if (scalar(@header_out) == 1) {
            $headers->{$name} = $header_out[0];
        } else {
            $headers->{$name} = \@header_out;
        }
    }
    if ( $which eq 'response' ) {
        $headers->{'Status-Line'} = $httpMessage->status_line();
    } elsif ( $which eq 'request' ) {
        my $uri = $httpMessage->uri->as_string();
        $headers->{'Request-Line'} = $uri;
    }
    $self->{'headers'}->{$which} = $headers;
}    

sub _decodeResponse {
    my $self = shift;
    my $httpResponse = shift;
    my $acceptableContentTypes = shift;
    my $code = $self->{'httpCode'};
    if ( ! (($code >= 200) && ($code < 400)) ) {
        $self->{'hasError'} = 1;
    }
    my $contentType = $self->{'contentType'};
    my $foundType = 0;
    foreach my $type (@$acceptableContentTypes) {
        if ($type eq $contentType) {
            $foundType = 1;
            last;
        }
    }
    if (!$foundType) {
        $self->{'hasError'} = 1;
        return;
    }

    if ($contentType eq 'application/json') {
        $self->{'decodedResponse'} = decode_json($httpResponse->content());
    }
    return 1;
}

=head2 getRawResponse

Returns the unprocessed response content for the request
(usually a JSON formatted string)

=cut

sub getRawResponse {
    my $self = shift;
    return $self->{'rawResponse'};
}

sub getRawResponseHeaders {
    my $self = shift;
    return $self->{'rawResponseHeaders'};
}

=head2 getResponseHeaders

Returns a hashref of header name/value (or array of value) pairs
from the response.

=cut

sub  getResponseHeaders {
    my $self = shift;
    return $self->{'headers'}->{'response'};
}

sub  getRawRequestHeaders {
    my $self = shift;
    return $self->{'rawRequestHeaders'};
}

=head2 getRequestHeaders

Returns a hashref of header name/value (or array of value) pairs
from the request

=cut

sub  getRequestHeaders {
    my $self = shift;
    return $self->{'headers'}->{'request'};
}

=head2 getHttpCode

Returns the numeric HTTP response code

=cut

sub  getHttpCode {
    my $self = shift;
    return $self->{'httpCode'};
}

=head2 getData

Returns the response body parsed into a Perl structure. To get the JSON
string, use getRawResponse()

=cut

sub  getData {
    my $self = shift;
    return $self->{'decodedResponse'};
}

=head2 getDataProperty

Let's you access the value of one specific property in the response body.
This supports nested properties. For example:
   $response = $ContextIO->getMessage($accountId, {"message_id"=>"1234abcd"});
   $data = $response->getData();
   $firstRecipientEmail = $data->{'addresses'}->{'to'}->[0]->{'email'};

 ... is equivalent to ...

   $response = $ContextIO->getMessage($accountId, array("message_id"=>"1234abcd"));
   $firstRecipientEmail = $response->getDataProperty("addresses.to.0.email");


=cut

sub  getDataProperty {
    my $self = shift;
    my $propertyName = shift;
    my @props = split(".", $propertyName);
    my $value = $self->{'decodedResponse'};
    do {
        my $prop = shift @props;
        $value = (($prop =~ /^[0-9]+$/) ? 
            $value->[$prop] :
            (exists($value->{$prop}) ? $value->{$prop} : undef)
        );
    } while (@props && defined($value));
    return $value;
}

=head2 hasError

Will return TRUE (1) if the call resulted in an error

=cut

sub  hasError() {
    my $self = shift;
    return $self->{'hasError'};
}


=head1 AUTHOR

Les Barstow, C<< <Les.Barstow at returnpath.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mail-contextio at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mail-ContextIO>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mail::ContextIO::Response


You can also look for information at:

=over 4

=item * Context.IO

L<http://context.io>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012-2013 by Les Barstow for Return Path, Inc.

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

1; # End of Mail::ContextIO::Response
