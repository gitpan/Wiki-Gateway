use inc::Module::Install;

name('Wiki-Gateway');
abstract('API for interaction with wikis');
author('Bayle Shanks');
version_from('lib/Wiki/Gateway.pm');
license('perl');
no_index(directory => 't');
sign(1);

include('ExtUtils::AutoInstall');

build_requires  ('Test::Unit');

requires('SOAP::Lite');
requires('XMLRPC::Lite');
requires('Date::Manip');
requires('LWP::Simple');
requires('XML::RSS');
requires('HTML::Form');
requires('LWP::UserAgent');
requires('HTTP::Cookies');
requires('SOAP::Lite');

# features(
#     'Client/Server for Atom API' => [
#         -default => 1,
#         recommends('LWP'),
#         recommends('LWP::Authen::Wsse'),
#         recommends('Digest::SHA1'),
#         recommends('DateTime'),
#     ],

#     'Feed and API Auto-discovery' => [
#         -default => 1,
#         recommends('HTML::Parser'),
#     ],

#     'Namespace Normalization' => [
#         -default => 0,
#         recommends('XML::LibXSLT'),
#     ],
# );

auto_include();
auto_install();

&WriteAll;
